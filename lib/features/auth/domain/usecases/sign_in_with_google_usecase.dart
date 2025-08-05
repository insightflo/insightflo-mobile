import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for signing in with Google OAuth
/// 
/// This use case handles Google OAuth authentication through Supabase Auth.
/// It follows Clean Architecture principles and provides comprehensive
/// error handling and security features.
/// 
/// Example usage:
/// ```dart
/// final result = await signInWithGoogleUseCase(NoParams());
/// result.fold(
///   (failure) => _handleAuthFailure(failure),
///   (user) => _handleAuthSuccess(user),
/// );
/// ```
class SignInWithGoogleUseCase implements UseCase<User, NoParams> {
  final AuthRepository repository;

  const SignInWithGoogleUseCase(this.repository);

  @override
  Future<Either<Failure, User>> call(NoParams params) async {
    try {
      // Delegate to repository for actual Google OAuth implementation
      return await repository.signInWithGoogle();
    } catch (e) {
      // Convert any unexpected exceptions to appropriate failures
      return Left(
        AuthFailure(
          message: 'Unexpected error during Google sign in: ${e.toString()}',
          statusCode: 500,
        ),
      );
    }
  }
}

/// Parameters for Google sign-in (currently none required)
class GoogleSignInParams {
  const GoogleSignInParams();
}