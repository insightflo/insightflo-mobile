import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case for verifying email with a verification token
/// 
/// This use case handles email verification when users click on verification
/// links sent to their email addresses. It supports both deep link handling
/// and manual token entry.
/// 
/// Example usage:
/// ```dart
/// final result = await verifyEmailUseCase(
///   VerifyEmailParams(token: 'verification_token_from_email')
/// );
/// result.fold(
///   (failure) => _handleVerificationFailure(failure),
///   (_) => _handleVerificationSuccess(),
/// );
/// ```
class VerifyEmailUseCase implements UseCase<void, VerifyEmailParams> {
  final AuthRepository repository;

  const VerifyEmailUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(VerifyEmailParams params) async {
    try {
      // Validate token format
      if (params.token.isEmpty) {
        return const Left(
          AuthFailure(
            message: 'Email verification token cannot be empty',
            statusCode: 400,
          ),
        );
      }

      // Delegate to repository for actual email verification
      return await repository.confirmEmailVerification(token: params.token);
    } catch (e) {
      // Convert any unexpected exceptions to appropriate failures
      return Left(
        AuthFailure(
          message: 'Unexpected error during email verification: ${e.toString()}',
          statusCode: 500,
        ),
      );
    }
  }
}

/// Parameters for email verification
class VerifyEmailParams {
  final String token;

  const VerifyEmailParams({
    required this.token,
  });
}

/// Use case for sending email verification
/// 
/// This use case sends an email verification link to the current user's
/// email address. The user must be authenticated to use this.
/// 
/// Example usage:
/// ```dart
/// final result = await sendEmailVerificationUseCase(NoParams());
/// result.fold(
///   (failure) => _handleSendVerificationFailure(failure),
///   (_) => _handleSendVerificationSuccess(),
/// );
/// ```
class SendEmailVerificationUseCase implements UseCase<void, NoParams> {
  final AuthRepository repository;

  const SendEmailVerificationUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(NoParams params) async {
    try {
      // Check if user is authenticated first
      final currentUserResult = await repository.getCurrentUser();
      
      return await currentUserResult.fold(
        (failure) => Left(failure),
        (user) async {
          if (user == null) {
            return const Left(
              AuthFailure(
                message: 'User must be authenticated to send email verification',
                statusCode: 401,
              ),
            );
          }

          // Delegate to repository for sending verification email
          return await repository.sendEmailVerification();
        },
      );
    } catch (e) {
      // Convert any unexpected exceptions to appropriate failures
      return Left(
        AuthFailure(
          message: 'Unexpected error sending email verification: ${e.toString()}',
          statusCode: 500,
        ),
      );
    }
  }
}