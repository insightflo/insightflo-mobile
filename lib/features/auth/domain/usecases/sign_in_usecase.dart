import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/email.dart';
import '../value_objects/password.dart';

/// Use case for signing in a user with email and password
/// 
/// This use case encapsulates the business logic for user authentication,
/// including input validation and error handling. It follows Clean Architecture
/// principles by depending only on abstractions (AuthRepository).
class SignInUseCase implements UseCase<User, SignInParams> {
  final AuthRepository _authRepository;

  const SignInUseCase(this._authRepository);

  @override
  Future<Either<Failure, User>> call(SignInParams params) async {
    // Validate email
    final emailValidation = Email.create(params.email);
    if (emailValidation.isLeft()) {
      return emailValidation.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected state'),
      );
    }

    // Validate password
    final passwordValidation = Password.create(params.password);
    if (passwordValidation.isLeft()) {
      return passwordValidation.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected state'),
      );
    }

    // Extract validated values
    final email = emailValidation.getOrElse(() => throw Exception('Email validation failed'));
    final password = passwordValidation.getOrElse(() => throw Exception('Password validation failed'));

    // Business rule: Check if we need to apply rate limiting
    // This could be expanded to include more sophisticated rate limiting logic
    if (await _shouldApplyRateLimit(email)) {
      return const Left(AuthFailure(
        message: 'Too many sign-in attempts. Please try again later.',
        statusCode: 429,
      ));
    }

    // Perform sign-in operation
    try {
      final result = await _authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.fold(
        (failure) => Left(failure),
        (user) {
          // Business rule: Check if user account is active and verified
          if (!user.isActive) {
            return const Left(AuthFailure(
              message: 'Account is deactivated. Please contact support.',
              statusCode: 403,
            ));
          }

          // Business rule: For enhanced security, require email verification for sign-in
          // This can be configured based on business requirements
          if (user.needsEmailVerification && _requireEmailVerification()) {
            return const Left(AuthFailure(
              message: 'Please verify your email address before signing in.',
              statusCode: 403,
            ));
          }

          return Right(user);
        },
      );
    } catch (e) {
      return Left(ServerFailure(
        message: 'An unexpected error occurred during sign-in.',
        statusCode: 500,
      ));
    }
  }

  /// Business rule: Rate limiting check
  /// 
  /// In a real implementation, this would check against a rate limiting service
  /// or database to prevent brute force attacks.
  Future<bool> _shouldApplyRateLimit(Email email) async {
    // Placeholder for rate limiting logic
    // In production, this would check:
    // - Number of failed attempts for this email
    // - Time window for rate limiting
    // - IP-based rate limiting
    return false;
  }

  /// Business rule: Email verification requirement
  /// 
  /// This method determines whether email verification is required for sign-in.
  /// Can be configured based on application security requirements.
  bool _requireEmailVerification() {
    // In production, this could be:
    // - A feature flag
    // - A configuration setting
    // - Based on user role or account type
    return false; // For now, allow unverified users to sign in
  }
}

/// Parameters for the SignInUseCase
/// 
/// This class encapsulates all the data needed for the sign-in operation.
/// Using a dedicated parameter class makes the use case more maintainable
/// and allows for easier testing.
class SignInParams {
  /// User's email address
  final String email;
  
  /// User's password
  final String password;
  
  /// Optional: Remember user session for longer period
  final bool rememberMe;
  
  /// Optional: Additional metadata for logging/analytics
  final Map<String, dynamic>? metadata;

  const SignInParams({
    required this.email,
    required this.password,
    this.rememberMe = false,
    this.metadata,
  });

  /// Creates a copy of this SignInParams with the given fields replaced
  SignInParams copyWith({
    String? email,
    String? password,
    bool? rememberMe,
    Map<String, dynamic>? metadata,
  }) {
    return SignInParams(
      email: email ?? this.email,
      password: password ?? this.password,
      rememberMe: rememberMe ?? this.rememberMe,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'SignInParams{email: $email, rememberMe: $rememberMe}';
  }
}