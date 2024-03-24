import 'dart:async';

import 'package:logging/logging.dart';
import 'package:protoo_client/src/enhanced_event_emitter.dart';
import 'package:protoo_client/src/message.dart';
import 'package:protoo_client/src/transports/transport_interface.dart';
export 'transports/native_transport.dart'
    if (dart.library.html) 'transports/web_transport.dart';

final logger = Logger('Peer');

class SentObject {
  SentObject(
      {required this.id,
      required this.method,
      required this.resolve,
      required this.reject,
      required this.timer,
      required this.close});
  final int id;
  final String method;
  final Function(dynamic) resolve;
  final Function(dynamic) reject;
  final Timer timer;
  final Function() close;
}

class Peer extends EnhancedEventEmitter {
  Peer(TransportInterface transport) {
    _transport = transport;
    logger.fine('constructor()');
    _handleTransport();
  }

  // Closed flag.
  bool _closed = false;

  // Connected flag.
  bool _connected = false;

  // Custom data object.
  dynamic _data = {};

  // Map of pending sent request objects indexed by request id.
  var _sents = Map<String, SentObject>();

  // Transport.
  late TransportInterface _transport;

  /// Whether the Peer is closed.
  bool get closed => _closed;

  /// Whether the Peer is connected.
  bool get connected => _connected;

  /// App custom data
  dynamic get data => _data;

  void close() {
    if (_closed) return;

    logger.fine('close()');

    _closed = true;
    _connected = false;

    // close transport
    _transport.close();

    // Close every pending sent.
    _sents.forEach((key, sent) {
      sent.close();
    });

    // Emit 'close' event.
    safeEmit('close');
  }

  /// Send a protoo request to the server-side Room.
  request(method, data) async {
    final completer = Completer();
    final request = Message.createRequest(method, data);
    final requestId = request['id'].toString();
    logger.fine('request() [method: $method, id: $requestId]');

    // This may throw.
    await _transport.send(request);

    final timeout = (1500 * (15 + (0.1 * _sents.length))).toInt();
    final sent = SentObject(
        id: request['id'],
        method: request['method'],
        resolve: (data2) {
          final sent = _sents.remove(requestId);
          sent?.timer.cancel();
          completer.complete(data2);
        },
        reject: (error) {
          final sent = _sents.remove(requestId);
          sent?.timer.cancel();
          completer.completeError(error);
        },
        timer: Timer.periodic(Duration(milliseconds: timeout), (Timer timer) {
          if (_sents.remove(requestId) == null) return;
          completer.completeError('request timeout');
        }),
        close: () {
          final sent = _sents[requestId];
          sent?.timer.cancel();
          completer.completeError('peer closed');
        });

    _sents[requestId] = sent;
    return completer.future;
  }

  void _handleTransport() {
    if (_transport.closed) {
      _closed = true;

      Future.delayed(const Duration(seconds: 0), () {
        if (!_closed) {
          _connected = false;

          safeEmit('close');
        }
      });

      return;
    }

    _transport.on('connecting', (currentAttempt) {
      logger.fine(
        'emit "connecting" [currentAttempt: $currentAttempt]',
      );
      safeEmit('connecting', currentAttempt);
    });

    _transport.on('open', () {
      if (_closed) return;
      logger.fine('emit "open"');

      _connected = true;

      safeEmit('open');
    });

    _transport.on('disconnected', () {
      if (_closed) return;
      logger.fine('emit "disconnected"');

      _connected = false;

      safeEmit('disconnected');
    });

    _transport.on('failed', (currentAttempt) {
      if (_closed) return;
      // logger.debug('emit "failed" [currentAttempt:' + currentAttempt + ']');

      _connected = false;

      safeEmit('failed', currentAttempt);
    });

    _transport.on('close', () {
      if (_closed) return;
      _closed = true;
      logger.fine('emit "close"');

      _connected = false;

      safeEmit('close');
    });

    _transport.on('message', (message) {
      if (message['request'] != null && message['request'] == true) {
        _handleRequest(message);
      } else if (message['response'] != null && message['response'] == true) {
        _handleResponse(message);
      } else if (message['notification'] != null &&
          message['notification'] == true) {
        _handleNotification(message);
      }
    });
  }

  _handleRequest(request) {
    try {
      emit('request', request,
          // accept() function.
          ([data]) {
        final response = Message.createSuccessResponse(request, data ?? {});
        _transport.send(response).catchError((error) {
          logger
              .warning('accept() failed, response could not be sent: ' + error);
        });
      },
          // reject() function.
          (errorCode, errorReason) {
        if (errorCode is! num) {
          errorReason = errorCode.toString();
          errorCode = 500;
        } else if (errorReason is String) {
          errorReason = errorReason.toString();
        }

        final response =
            Message.createErrorResponse(request, errorCode, errorReason);

        _transport.send(response).catchError((error) {
          logger
              .warning('reject() failed, response could not be sent: ' + error);
        });
      });
    } catch (error) {
      final response =
          Message.createErrorResponse(request, 500, error.toString());
      _transport.send(response).catchError(() => {});
    }
  }

  void _handleResponse(response) {
    final sent = _sents[response['id'].toString()];
    if (sent == null) {
      logger.severe('received response does not match any sent request');
      return;
    }

    if (response['ok'] != null && response['ok'] == true) {
      sent.resolve(response['data']);
    } else {
      final error = {
        'code': response['errorCode'] ?? 500,
        'error': response['errorReason'] ?? ''
      };
      sent.reject(error);
    }
  }

  void _handleNotification(notification) {
    safeEmit('notification', notification);
  }

  Future<void> notify(method, data) {
    final notification = Message.createNotification(method, data);
    logger.fine('${'notify() [method:' + method}]');
    return _transport.send(notification);
  }
}
