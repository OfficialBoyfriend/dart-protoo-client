import 'dart:convert';
import 'dart:html';

import 'package:logging/logging.dart';

import 'package:protoo_client/src/message.dart';
import 'package:protoo_client/src/transports/transport_interface.dart';

final _logger = Logger('Logger::WebTransport');

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
      _ws?.send(jsonEncode(message));
    } catch (error) {
      _logger.warning('send() failed:$error');
    }
  }

  void _runWebSocket() {
    _ws = WebSocket(_url, 'protoo');
    _ws?.onOpen.listen((e) {
      _logger.fine('onOpen');
      safeEmit('open');
    });

    _ws?.onClose.listen((e) {
      _logger.warning(
        'WebSocket "close" event [wasClean:${e.wasClean}, code:${e.code}, reason:"${e.reason}"]',
      );
      _closed = true;

      safeEmit('close');
    });

    _ws?.onError.listen((e) {
      _logger.severe('WebSocket "error" event');
    });

    _ws?.onMessage.listen((e) {
      final message = Message.parse(e.data as String);

      if (message == null) return;

      safeEmit('message', message);
    });
  }
}
