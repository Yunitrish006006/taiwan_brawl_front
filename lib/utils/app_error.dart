import 'package:flutter/foundation.dart';

import '../services/api_client.dart' show ApiException;

/// Unified error types for the application
enum AppErrorType {
  network,
  server,
  auth,
  validation,
  unknown,
}

/// App-wide error wrapper with type, message, and optional details
class AppError implements Exception {
  AppError(
    this.message, {
    this.type = AppErrorType.unknown,
    this.originalError,
    this.stackTrace,
    this.statusCode,
  });

  final String message;
  final AppErrorType type;
  final Object? originalError;
  final StackTrace? stackTrace;
  final int? statusCode;

  /// Create from ApiException
  factory AppError.fromApiException(dynamic e, {StackTrace? st}) {
    if (e is ApiException) {
      final type = _mapStatusCodeToErrorType(e.statusCode);
      return AppError(
        e.message,
        type: type,
        originalError: e,
        stackTrace: st,
        statusCode: e.statusCode,
      );
    }
    return AppError(
      'An unexpected error occurred',
      type: AppErrorType.unknown,
      originalError: e,
      stackTrace: st,
    );
  }

  /// Create from network error
  factory AppError.network(Object e, {StackTrace? st}) {
    return AppError(
      'Network error. Please check your connection.',
      type: AppErrorType.network,
      originalError: e,
      stackTrace: st,
    );
  }

  /// Create from generic error
  factory AppError.generic(Object e, {StackTrace? st}) {
    debugPrint('AppError: $e\n$st');
    return AppError(
      'An unexpected error occurred',
      type: AppErrorType.unknown,
      originalError: e,
      stackTrace: st,
    );
  }

  static AppErrorType _mapStatusCodeToErrorType(int? statusCode) {
    if (statusCode == null) return AppErrorType.unknown;
    if (statusCode == 401 || statusCode == 403) return AppErrorType.auth;
    if (statusCode >= 400 && statusCode < 500) return AppErrorType.validation;
    if (statusCode >= 500) return AppErrorType.server;
    return AppErrorType.unknown;
  }

  @override
  String toString() => 'AppError($type: $message)';

  /// User-friendly error message for display
  String get userMessage {
    switch (type) {
      case AppErrorType.network:
        return 'Network error. Please check your connection.';
      case AppErrorType.server:
        return 'Server error. Please try again later.';
      case AppErrorType.auth:
        return 'Session expired. Please log in again.';
      case AppErrorType.validation:
        return message;
      case AppErrorType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }
}
