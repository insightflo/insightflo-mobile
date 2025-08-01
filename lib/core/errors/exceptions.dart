/// Base exception class for all exceptions in the application
abstract class AppException implements Exception {
  final String message;
  final int? statusCode;

  const AppException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => 'AppException(message: $message, statusCode: $statusCode)';
}

/// Server-related exceptions
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.statusCode,
  });
}

/// Cache-related exceptions
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.statusCode,
  });
}

/// Network-related exceptions
class NetworkException extends AppException {
  const NetworkException({
    required super.message,
    super.statusCode,
  });
}

/// Authentication-related exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.statusCode,
  });
}

/// Validation-related exceptions
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.statusCode,
  });
}