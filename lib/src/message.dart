import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:protoo_client/src/utils.dart' as utils;

final logger = Logger('Message');

class Message {
  static JsonEncoder encoder = JsonEncoder();
  static JsonDecoder decoder = JsonDecoder();

  static Map<String, dynamic>? parse(String raw) {
    var object;
    final message = <String, dynamic>{};

    try {
      object = decoder.convert(raw);
    } catch (error) {
      logger.severe('parse() | invalid JSON: $error');
      return null;
    }

    // Request.
    if (object['request'] != null) {
      message['request'] = true;

      if (!(object['method'] is String)) {
        logger.severe('parse() | missing/invalid method field');
      }

      if (!(object['id'] is num)) {
        logger.severe('parse() | missing/invalid id field');
      }

      message['id'] = object['id'];
      message['method'] = object['method'];
      message['data'] = object['data'] ?? {};
    }
    // Response.
    else if (object['response'] != null) {
      message['response'] = true;
      if (!(object['id'] is num)) {
        logger.severe('parse() | missing/invalid id field');
      }

      message['id'] = object['id'];

      // Success.
      if (object['ok'] is bool) {
        message['ok'] = true;
        message['data'] = object['data'] ?? {};
      }
      // Error.
      else {
        message['errorCode'] = object['errorCode'];
        message['errorReason'] = object['errorReason'];
      }
    }
    // Notification.
    else if (object['notification'] != null) {
      message['notification'] = true;
      if (!(object['method'] is String)) {
        logger.severe('parse() | missing/invalid method field');
      }

      message['method'] = object['method'];
      message['data'] = object['data'] ?? {};
    }
    // Invalid.
    else {
      logger.severe('parse() | missing request/response field');
      return null;
    }

    return message;
  }

  static createRequest(method, data) {
    var requestObj = {
      'request': true,
      'id': utils.randomNumber,
      'method': method,
      'data': data ?? {}
    };
    return requestObj;
  }

  static createSuccessResponse(request, data) {
    var responseObj = {
      'response': true,
      'id': request['id'],
      'ok': true,
      'data': data ?? {}
    };

    return responseObj;
  }

  static createErrorResponse(request, errorCode, errorReason) {
    var responseObj = {
      'response': true,
      'id': request['id'],
      'errorCode': errorCode,
      'errorReason': errorReason
    };

    return responseObj;
  }

  static createNotification(method, data) {
    var notificationObj = {
      'notification': true,
      'method': method,
      'data ': data ?? {},
    };

    return notificationObj;
  }
}
