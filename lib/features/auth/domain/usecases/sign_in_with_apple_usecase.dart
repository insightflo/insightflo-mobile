import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for signing in with Apple OAuth
/// 
/// This use case handles Apple OAuth authentication through Supabase Auth.
/// It follows Clean Architecture principles and provides comprehensive
/// error handling and security features.
/// 
/// Note: Apple Sign In is only available on iOS 13+ and macOS 10.15+
/// 
/// Example usage:
/// ```dart
/// final result = await signInWithAppleUseCase(NoParams());
/// result.fold(
///   (failure) => _handleAuthFailure(failure),
///   (user) => _handleAuthSuccess(user),
/// );
/// ```
class SignInWithAppleUseCase implements UseCase<User, NoParams> {
  final AuthRepository repository;

  const SignInWithAppleUseCase(this.repository);

  @override
  Future<Either<Failure, User>> call(NoParams params) async {
    try {
      // Delegate to repository for actual Apple OAuth implementation
      return await repository.signInWithApple();
    } catch (e) {
      // Convert any unexpected exceptions to appropriate failures
      return Left(
        AuthFailure(
          message: 'Unexpected error during Apple sign in: ${e.toString()}',
          statusCode: 500,
        ),
      );
    }
  }
}

/// Parameters for Apple sign-in (currently none required)
class AppleSignInParams {
  const AppleSignInParams();
}