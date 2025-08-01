import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/user.dart';
import '../value_objects/email.dart';
import '../value_objects/password.dart';

/// Authentication repository interface defining the contract for authentication operations
/// 
/// This interface follows Clean Architecture principles by defining the contract
/// that data layer implementations must follow. It is independent of any specific
/// authentication provider or framework.
abstract class AuthRepository {
  /// Signs up a new user with email and password
  /// 
  /// Parameters:
  /// - [email]: User's email address (validated)
  /// - [password]: User's password (validated)
  /// - [displayName]: Optional display name for the user
  /// - [metadata]: Optional additional user metadata
  /// 
  /// Returns:
  /// - [Right(User)]: Successfully created user
  /// - [Left(Failure)]: Error occurred during signup
  Future<Either<Failure, User>> signUpWithEmailAndPassword({
    required Email email,
    required Password password,
    String? displayName,
    Map<String, dynamic>? metadata,
  });

  /// Signs in an existing user with email and password
  /// 
  /// Parameters:
  /// - [email]: User's email address (validated)
  /// - [password]: User's password (validated)
  /// 
  /// Returns:
  /// - [Right(User)]: Successfully authenticated user
  /// - [Left(Failure)]: Error occurred during signin
  Future<Either<Failure, User>> signInWithEmailAndPassword({
    required Email email,
    required Password password,
  });

  /// Signs in a user anonymously (guest mode)
  /// 
  /// Returns:
  /// - [Right(User)]: Successfully created anonymous user
  /// - [Left(Failure)]: Error occurred during anonymous signin
  Future<Either<Failure, User>> signInAnonymously();

  /// Signs in a user with Google OAuth
  /// 
  /// Returns:
  /// - [Right(User)]: Successfully authenticated user
  /// - [Left(Failure)]: Error occurred during Google signin
  Future<Either<Failure, User>> signInWithGoogle();

  /// Signs in a user with Apple OAuth
  /// 
  /// Returns:
  /// - [Right(User)]: Successfully authenticated user
  /// - [Left(Failure)]: Error occurred during Apple signin
  Future<Either<Failure, User>> signInWithApple();

  /// Signs out the current user
  /// 
  /// Returns:
  /// - [Right(void)]: Successfully signed out
  /// - [Left(Failure)]: Error occurred during signout
  Future<Either<Failure, void>> signOut();

  /// Gets the currently authenticated user
  /// 
  /// Returns:
  /// - [Right(User)]: Current authenticated user
  /// - [Right(null)]: No user is currently authenticated
  /// - [Left(Failure)]: Error occurred while fetching user
  Future<Either<Failure, User?>> getCurrentUser();

  /// Sends a password reset email to the user
  /// 
  /// Parameters:
  /// - [email]: User's email address to send reset link
  /// 
  /// Returns:
  /// - [Right(void)]: Password reset email sent successfully
  /// - [Left(Failure)]: Error occurred while sending reset email
  Future<Either<Failure, void>> sendPasswordResetEmail({
    required Email email,
  });

  /// Updates the user's password
  /// 
  /// Parameters:
  /// - [currentPassword]: User's current password for verification
  /// - [newPassword]: New password to set
  /// 
  /// Returns:
  /// - [Right(void)]: Password updated successfully
  /// - [Left(Failure)]: Error occurred while updating password
  Future<Either<Failure, void>> updatePassword({
    required Password currentPassword,
    required Password newPassword,
  });

  /// Updates the user's profile information
  /// 
  /// Parameters:
  /// - [displayName]: New display name (optional)
  /// - [avatarUrl]: New avatar URL (optional)
  /// - [metadata]: Additional metadata to update (optional)
  /// 
  /// Returns:
  /// - [Right(User)]: Updated user information
  /// - [Left(Failure)]: Error occurred while updating profile
  Future<Either<Failure, User>> updateProfile({
    String? displayName,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  });

  /// Sends email verification to the current user
  /// 
  /// Returns:
  /// - [Right(void)]: Verification email sent successfully
  /// - [Left(Failure)]: Error occurred while sending verification email
  Future<Either<Failure, void>> sendEmailVerification();

  /// Confirms email verification with a token
  /// 
  /// Parameters:
  /// - [token]: Email verification token received via email
  /// 
  /// Returns:
  /// - [Right(void)]: Email verified successfully
  /// - [Left(Failure)]: Error occurred during verification
  Future<Either<Failure, void>> confirmEmailVerification({
    required String token,
  });

  /// Refreshes the current user's authentication token
  /// 
  /// Returns:
  /// - [Right(void)]: Token refreshed successfully
  /// - [Left(Failure)]: Error occurred while refreshing token
  Future<Either<Failure, void>> refreshToken();

  /// Deletes the current user's account permanently
  /// 
  /// Parameters:
  /// - [password]: User's current password for verification
  /// 
  /// Returns:
  /// - [Right(void)]: Account deleted successfully
  /// - [Left(Failure)]: Error occurred while deleting account
  Future<Either<Failure, void>> deleteAccount({
    required Password password,
  });

  /// Stream of authentication state changes
  /// 
  /// Emits:
  /// - [User]: When user signs in or user data changes
  /// - [null]: When user signs out or becomes unauthenticated
  Stream<User?> get authStateChanges;

  /// Checks if a user is currently authenticated
  /// 
  /// Returns:
  /// - [true]: User is authenticated
  /// - [false]: User is not authenticated
  bool get isAuthenticated;

  /// Gets the current user synchronously (if available)
  /// 
  /// Returns:
  /// - [User]: Current authenticated user
  /// - [null]: No user is currently authenticated
  User? get currentUserSync;
}

/// Parameters for sign up operation
class SignUpParams {
  final Email email;
  final Password password;
  final String? displayName;
  final Map<String, dynamic>? metadata;

  const SignUpParams({
    required this.email,
    required this.password,
    this.displayName,
    this.metadata,
  });
}

/// Parameters for sign in operation
class SignInParams {
  final Email email;
  final Password password;

  const SignInParams({
    required this.email,
    required this.password,
  });
}

/// Parameters for password reset operation
class PasswordResetParams {
  final Email email;

  const PasswordResetParams({
    required this.email,
  });
}

/// Parameters for password update operation
class PasswordUpdateParams {
  final Password currentPassword;
  final Password newPassword;

  const PasswordUpdateParams({
    required this.currentPassword,
    required this.newPassword,
  });
}

/// Parameters for profile update operation
class ProfileUpdateParams {
  final String? displayName;
  final String? avatarUrl;
  final Map<String, dynamic>? metadata;

  const ProfileUpdateParams({
    this.displayName,
    this.avatarUrl,
    this.metadata,
  });

  /// Checks if any fields are provided for update
  bool get hasUpdates => 
      displayName != null || 
      avatarUrl != null || 
      (metadata != null && metadata!.isNotEmpty);
}

/// Parameters for email verification confirmation
class EmailVerificationParams {
  final String token;

  const EmailVerificationParams({
    required this.token,
  });
}

/// Parameters for account deletion
class AccountDeletionParams {
  final Password password;

  const AccountDeletionParams({
    required this.password,
  });
}