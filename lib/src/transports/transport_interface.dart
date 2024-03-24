import 'package:protoo_client/src/enhanced_event_emitter.dart';

abstract class TransportInterface extends EnhancedEventEmitter {
  TransportInterface(String url) : super();

  bool get closed;

  Future<void> send(Object? message);

  void close();
}
