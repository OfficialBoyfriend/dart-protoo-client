import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'package:protoo_client/src/message.dart';
import 'package:protoo_client/src/transports/transport_interface.dart';

final _logger = Logger('Logger::NativeTransport');

class Transport extends TransportInterface {
  Transport(String url) : super(url) {
    _logger.fine('constructor() [url:$url]');

    _closed = false;
    _url = url;
    _ws = null;

    _runWebSocket();
  }

  late bool _closed;
  late String _url;
  WebSocket? _ws;

  @override
  bool get closed => _closed;

  @override
  void close() {
    _logger.fine('close()');

    _closed = true;
    safeEmit('close');

    try {
      _ws?.close();
    } catch (error) {
      _logger.severe('close() | error closing the WebSocket: $error');
    }
  }

  @override
  Future<void> send(Object? message) async {
    try {
      _ws?.add(jsonEncode(message));
    } catch (error) {
      _logger.warning('send() failed:$error');
    }
  }

  void _onOpen() {
    _logger.fine('onOpen');
    safeEmit('open');
  }

  // _onClose(event) {
  //   logger.warn(
  //       'WebSocket "close" event [wasClean:${e.wasClean}, code:${e.code}, reason:"${e.reason}"]');
  //   this._closed = true;

  //   this.safeEmit('close');
  // }

  void _onError(Object? err) {
    _closed = true;
    safeEmit('failed');
  }

  void _runWebSocket() {
    WebSocket.connect(_url, protocols: ['protoo']).then((ws) {
      if (ws.readyState == WebSocket.open) {
        _ws = ws;

        _onOpen();

        ws.listen(
          (event) {
            final message = Message.parse(event as String);

            if (message == null) return;

            safeEmit('message', message);
          },
          onError: _onError,
        );
      } else {
        _logger.warning(
          'WebSocket "close" event code:${ws.closeCode}, reason:"${ws.closeReason}"]',
        );

        _closed = true;
        safeEmit('close');
      }
    }).catchError((Object? err, StackTrace stackTrace) {
      _onError(err);
    });

    // this._ws.listen((e) {
    //   logger.debug('onOpen');
    //   this.safeEmit('open');
    // });

    // this._ws.onClose.listen((e) {
    //   logger.warn(
    //       'WebSocket "close" event [wasClean:${e.wasClean}, code:${e.code}, reason:"${e.reason}"]');
    //   this._closed = true;

    //   this.safeEmit('close');
    // });

    // this._ws.onError.listen((e) {
    //   logger.error('WebSocket "error" event');
    // });

    // this._ws.onMessage.listen((e) {
    //   final message = Message.parse(e.data);

    //   if (message == null) return;

    //   this.safeEmit('message', message);
    // });
  }
}
