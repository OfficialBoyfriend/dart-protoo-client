import 'dart:async';

import 'package:events2/events2.dart';
import 'package:logging/logging.dart';

Logger _logger = Logger('EnhancedEventEmitter');

class EnhancedEventEmitter extends EventEmitter {
  EnhancedEventEmitter() : super();
  void safeEmit(String event, [Map<String, dynamic>? args]) {
    try {
      emit(event, args);
    } catch (error) {
      _logger.severe(
        'safeEmit() event listener threw an error [event:$event]:$error',
      );
    }
  }

  Future<dynamic> safeEmitAsFuture(String event,
      [Map<String, dynamic>? args]) async {
    try {
      return emitAsFuture(event, args);
    } catch (error) {
      _logger.severe(
        'safeEmitAsFuture() event listener threw an error [event:$event]:$error',
      );
    }
  }
}
