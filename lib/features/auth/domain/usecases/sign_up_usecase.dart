import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/email.dart';
import '../value_objects/password.dart';

/// Use case for signing up a new user with email and password
/// 
/// This use case encapsulates the business logic for user registration,
/// including comprehensive input validation, business rules enforcement,
/// and error handling. It follows Clean Architecture principles by depending
/// only on abstractions (AuthRepository).
class SignUpUseCase implements UseCase<User, SignUpParams> {
  final AuthRepository _authRepository;

  const SignUpUseCase(this._authRepository);

  @override
  Future<Either<Failure, User>> call(SignUpParams params) async {
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

    // Validate password confirmation if provided
    if (params.passwordConfirmation != null) {
      final password = passwordValidation.getOrElse(() => throw Exception('Password validation failed'));
      final confirmationValidation = _validatePasswordConfirmation(password, params.passwordConfirmation!);
      if (confirmationValidation.isLeft()) {
        return confirmationValidation.fold(
          (failure) => Left(failure),
          (_) => throw Exception('Unexpected state'),
        );
      }
    }

    // Extract validated values
    final email = emailValidation.getOrElse(() => throw Exception('Email validation failed'));
    final password = passwordValidation.getOrElse(() => throw Exception('Password validation failed'));

    // Business rule: Validate display name if provided
    if (params.displayName != null) {
      final displayNameValidation = _validateDisplayName(params.displayName!);
      if (displayNameValidation.isLeft()) {
        return displayNameValidation.fold(
          (failure) => Left(failure),
          (_) => throw Exception('Unexpected state'),
        );
      }
    }

    // Business rule: Check password strength requirements
    final strengthValidation = _validatePasswordStrength(password);
    if (strengthValidation.isLeft()) {
      return strengthValidation.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected state'),
      );
    }

    // Business rule: Check if email domain is allowed for registration
    if (!_isEmailDomainAllowed(email)) {
      return const Left(ValidationFailure(
        message: 'Registration is not allowed for this email domain.',
        statusCode: 400,
      ));
    }

    // Business rule: Check for duplicate email registration
    // This is typically handled by the repository/data layer, but we can add
    // additional business logic here if needed
    final existingUserCheck = await _checkExistingUser(email);
    if (existingUserCheck.isLeft()) {
      return existingUserCheck.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected state'),
      );
    }

    // Prepare metadata with business-specific information
    final metadata = _prepareUserMetadata(params);

    // Perform sign-up operation
    try {
      final result = await _authRepository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        displayName: params.displayName,
        metadata: metadata,
      );

      return result.fold(
        (failure) => Left(failure),
        (user) {
          // Business rule: Automatically trigger email verification for new users
          _triggerEmailVerification(user);

          // Business rule: Apply default user settings
          _applyDefaultUserSettings(user);

          return Right(user);
        },
      );
    } catch (e) {
      return Left(ServerFailure(
        message: 'An unexpected error occurred during sign-up.',
        statusCode: 500,
      ));
    }
  }

  /// Validates password confirmation matches the password
  Either<ValidationFailure, void> _validatePasswordConfirmation(
    Password password,
    String confirmation,
  ) {
    if (password.value != confirmation) {
      return const Left(ValidationFailure(
        message: 'Password confirmation does not match.',
        statusCode: 400,
      ));
    }
    return const Right(null);
  }

  /// Validates display name according to business rules
  Either<ValidationFailure, void> _validateDisplayName(String displayName) {
    final trimmed = displayName.trim();
    
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure(
        message: 'Display name cannot be empty.',
        statusCode: 400,
      ));
    }
    
    if (trimmed.length < 2) {
      return const Left(ValidationFailure(
        message: 'Display name must be at least 2 characters long.',
        statusCode: 400,
      ));
    }
    
    if (trimmed.length > 50) {
      return const Left(ValidationFailure(
        message: 'Display name cannot exceed 50 characters.',
        statusCode: 400,
      ));
    }
    
    // Check for inappropriate content (basic implementation)
    if (_containsInappropriateContent(trimmed)) {
      return const Left(ValidationFailure(
        message: 'Display name contains inappropriate content.',
        statusCode: 400,
      ));
    }
    
    return const Right(null);
  }

  /// Validates password strength meets business requirements
  Either<ValidationFailure, void> _validatePasswordStrength(Password password) {
    // Business rule: Require at least medium strength password
    if (password.strength.index < PasswordStrength.medium.index) {
      return Left(ValidationFailure(
        message: 'Password strength is too weak. ${_getPasswordRequirements()}',
        statusCode: 400,
      ));
    }
    
    return const Right(null);
  }

  /// Business rule: Check if email domain is allowed for registration
  bool _isEmailDomainAllowed(Email email) {
    // In production, this could check against:
    // - Allow list of corporate domains
    // - Block list of temporary email providers
    // - Geographic restrictions based on domain
    
    const blockedDomains = [
      'tempmail.org',
      '10minutemail.com',
      'guerrillamail.com',
      'mailinator.com',
      'throwaway.email',
    ];
    
    return !blockedDomains.contains(email.domain.toLowerCase());
  }

  /// Business rule: Check for existing user registration
  Future<Either<ValidationFailure, void>> _checkExistingUser(Email email) async {
    // This could be implemented to check for:
    // - Previously registered but unverified accounts
    // - Soft-deleted accounts that should be restored
    // - Rate limiting for registration attempts
    
    // For now, we rely on the repository layer to handle duplicate detection
    return const Right(null);
  }

  /// Prepares user metadata with business-specific information
  Map<String, dynamic> _prepareUserMetadata(SignUpParams params) {
    final metadata = <String, dynamic>{
      'registration_method': 'email_password',
      'registration_timestamp': DateTime.now().toIso8601String(),
      'initial_user_agent': 'flutter_app', // Could be extracted from context
      'email_domain': Email.create(params.email)
          .fold((_) => 'unknown', (email) => email.domain),
    };

    // Merge with any additional metadata provided
    if (params.metadata != null) {
      metadata.addAll(params.metadata!);
    }

    return metadata;
  }

  /// Business rule: Trigger email verification for new users
  void _triggerEmailVerification(User user) {
    // In production, this would:
    // - Send welcome email with verification link
    // - Set up follow-up reminder emails
    // - Log verification attempt for analytics
    
    // This is typically handled by the repository layer or a separate service
    // We're just documenting the business intent here
  }

  /// Business rule: Apply default user settings
  void _applyDefaultUserSettings(User user) {
    // In production, this would:
    // - Set default notification preferences
    // - Apply default privacy settings
    // - Initialize user preferences
    // - Set up default user groups/roles
    
    // This is typically handled by a separate service or use case
    // We're just documenting the business intent here
  }

  /// Checks for inappropriate content in display names
  bool _containsInappropriateContent(String text) {
    // Basic implementation - in production, this would use:
    // - Content moderation API
    // - Machine learning models
    // - Configurable word filters
    
    const inappropriateWords = [
      'admin',
      'moderator',
      'system',
      'support',
      'root',
    ];
    
    final lowerText = text.toLowerCase();
    return inappropriateWords.any((word) => lowerText.contains(word));
  }

  /// Gets password requirements text for error messages
  String _getPasswordRequirements() {
    return 'Password must be at least 8 characters with uppercase, lowercase, numbers, and special characters.';
  }
}

/// Parameters for the SignUpUseCase
/// 
/// This class encapsulates all the data needed for the sign-up operation.
/// Using a dedicated parameter class makes the use case more maintainable
/// and allows for easier testing and validation.
class SignUpParams {
  /// User's email address
  final String email;
  
  /// User's password
  final String password;
  
  /// Password confirmation for validation
  final String? passwordConfirmation;
  
  /// Optional display name for the user
  final String? displayName;
  
  /// Optional terms of service acceptance
  final bool acceptedTerms;
  
  /// Optional marketing communication consent
  final bool acceptedMarketing;
  
  /// Optional additional metadata
  final Map<String, dynamic>? metadata;

  const SignUpParams({
    required this.email,
    required this.password,
    this.passwordConfirmation,
    this.displayName,
    this.acceptedTerms = false,
    this.acceptedMarketing = false,
    this.metadata,
  });

  /// Creates a copy of this SignUpParams with the given fields replaced
  SignUpParams copyWith({
    String? email,
    String? password,
    String? passwordConfirmation,
    String? displayName,
    bool? acceptedTerms,
    bool? acceptedMarketing,
    Map<String, dynamic>? metadata,
  }) {
    return SignUpParams(
      email: email ?? this.email,
      password: password ?? this.password,
      passwordConfirmation: passwordConfirmation ?? this.passwordConfirmation,
      displayName: displayName ?? this.displayName,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      acceptedMarketing: acceptedMarketing ?? this.acceptedMarketing,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Validates that required legal agreements are accepted
  bool get hasAcceptedRequiredTerms => acceptedTerms;

  @override
  String toString() {
    return 'SignUpParams{email: $email, displayName: $displayName, acceptedTerms: $acceptedTerms}';
  }
}