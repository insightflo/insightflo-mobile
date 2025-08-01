import 'package:equatable/equatable.dart';

/// Base failure class for all errors in the application
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({
    required this.message,
    this.statusCode,
  });

  @override
  List<Object?> get props => [message, statusCode];
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure({
    required super.message,
    super.statusCode,
  });
}

/// Cache-related failures
class CacheFailure extends Failure {
  const CacheFailure({
    required super.message,
    super.statusCode,
  });
}

/// Network-related failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    required super.message,
    super.statusCode,
  });
}

/// Authentication-related failures
class AuthFailure extends Failure {
  const AuthFailure({
    required super.message,
    super.statusCode,
  });
}

/// Specific authentication failure types
class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure({
    super.message = 'Invalid email or password',
    super.statusCode = 401,
  });
}

class UserNotFoundFailure extends AuthFailure {
  const UserNotFoundFailure({
    super.message = 'User not found',
    super.statusCode = 404,
  });
}

class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure({
    super.message = 'Email is already registered',
    super.statusCode = 409,
  });
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure({
    super.message = 'Password is too weak',
    super.statusCode = 400,
  });
}

class EmailNotVerifiedFailure extends AuthFailure {
  const EmailNotVerifiedFailure({
    super.message = 'Email address is not verified',
    super.statusCode = 403,
  });
}

class SessionExpiredFailure extends AuthFailure {
  const SessionExpiredFailure({
    super.message = 'Session has expired',
    super.statusCode = 401,
  });
}

class AccountDisabledFailure extends AuthFailure {
  const AccountDisabledFailure({
    super.message = 'Account has been disabled',
    super.statusCode = 403,
  });
}

class TooManyRequestsFailure extends AuthFailure {
  const TooManyRequestsFailure({
    super.message = 'Too many requests. Please try again later',
    super.statusCode = 429,
  });
}

/// Validation-related failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.statusCode,
  });
}

/// Unknown failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    required super.message,
    super.statusCode,
  });
}