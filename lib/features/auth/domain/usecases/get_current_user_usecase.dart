import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Use case for retrieving the current authenticated user
/// 
/// This use case encapsulates the business logic for fetching current user data,
/// including caching strategies, data validation, and error handling.
/// It follows Clean Architecture principles by depending only on abstractions.
class GetCurrentUserUseCase implements UseCase<User?, GetCurrentUserParams> {
  final AuthRepository _authRepository;

  const GetCurrentUserUseCase(this._authRepository);

  @override
  Future<Either<Failure, User?>> call(GetCurrentUserParams params) async {
    try {
      // Business rule: Check for quick synchronous access if available
      if (params.preferCached) {
        final cachedUser = _authRepository.currentUserSync;
        if (cachedUser != null && _isCachedUserValid(cachedUser, params)) {
          return Right(cachedUser);
        }
      }

      // Fetch current user from repository
      final result = await _authRepository.getCurrentUser();

      return result.fold(
        (failure) => Left(failure),
        (user) {
          if (user == null) {
            // No user is currently authenticated
            return const Right(null);
          }

          // Business rule: Validate user data integrity
          final validationResult = _validateUserData(user, params);
          if (validationResult.isLeft()) {
            return validationResult.fold(
              (failure) => Left(failure),
              (_) => throw Exception('Unexpected state'),
            );
          }

          // Business rule: Check if user needs profile updates
          final userWithStatus = _enrichUserWithStatus(user, params);

          // Business rule: Apply data filtering based on parameters
          final filteredUser = _applyDataFiltering(userWithStatus, params);

          return Right(filteredUser);
        },
      );
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to retrieve current user information.',
        statusCode: 500,
      ));
    }
  }

  /// Business rule: Check if cached user data is still valid
  bool _isCachedUserValid(User user, GetCurrentUserParams params) {
    // Check if we should force refresh
    if (params.forceRefresh) {
      return false;
    }

    // Check if user data is too old (based on cache duration)
    if (params.maxCacheAge != null) {
      final userAge = DateTime.now().difference(
        user.lastSignInAt ?? user.updatedAt ?? user.createdAt,
      );
      
      if (userAge > params.maxCacheAge!) {
        return false;
      }
    }

    // Check if user account is still active
    if (!user.isActive) {
      return false;
    }

    // Check if required fields are present
    if (params.includeProfile && !user.isProfileComplete) {
      return false;
    }

    return true;
  }

  /// Business rule: Validate user data integrity
  Either<Failure, void> _validateUserData(User user, GetCurrentUserParams params) {
    // Check for required fields
    if (user.id.isEmpty) {
      return const Left(ValidationFailure(
        message: 'User ID is missing or invalid.',
        statusCode: 422,
      ));
    }

    if (user.email.isEmpty) {
      return const Left(ValidationFailure(
        message: 'User email is missing or invalid.',
        statusCode: 422,
      ));
    }

    // Business rule: Check account status
    if (!user.isActive && params.requireActiveAccount) {
      return const Left(AuthFailure(
        message: 'User account is not active.',
        statusCode: 403,
      ));
    }

    // Business rule: Check email verification requirements
    if (user.needsEmailVerification && params.requireVerifiedEmail) {
      return const Left(AuthFailure(
        message: 'Email verification is required.',
        statusCode: 403,
      ));
    }

    return const Right(null);
  }

  /// Business rule: Enrich user data with additional status information
  User _enrichUserWithStatus(User user, GetCurrentUserParams params) {
    // Add computed fields or status information
    final metadata = Map<String, dynamic>.from(user.metadata ?? {});

    // Add last access information
    metadata['last_accessed'] = DateTime.now().toIso8601String();

    // Add profile completion status
    metadata['profile_complete'] = user.isProfileComplete;

    // Add verification status
    metadata['verification_status'] = {
      'email_verified': user.emailConfirmed,
      'phone_verified': user.phoneConfirmed,
    };

    // Add role information
    metadata['role_info'] = {
      'role': user.role.value,
      'is_admin': user.isAdmin,
      'is_moderator': user.isModerator,
    };

    return user.copyWith(metadata: metadata);
  }

  /// Business rule: Apply data filtering based on parameters
  User _applyDataFiltering(User user, GetCurrentUserParams params) {
    // If minimal data is requested, exclude optional fields
    if (params.minimalData) {
      return User(
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        emailConfirmed: user.emailConfirmed,
        createdAt: user.createdAt,
        role: user.role,
        isActive: user.isActive,
      );
    }

    // If profile data is excluded, remove personal information
    if (!params.includeProfile) {
      return user.copyWith(
        displayName: null,
        avatarUrl: null,
        phoneNumber: null,
        metadata: _filterMetadata(user.metadata, excludeProfile: true),
      );
    }

    return user;
  }

  /// Filters metadata based on inclusion/exclusion rules
  Map<String, dynamic>? _filterMetadata(
    Map<String, dynamic>? metadata, {
    bool excludeProfile = false,
  }) {
    if (metadata == null) return null;

    final filtered = Map<String, dynamic>.from(metadata);

    if (excludeProfile) {
      // Remove profile-related metadata
      filtered.removeWhere((key, value) => 
        key.startsWith('profile_') || 
        key.startsWith('personal_') ||
        key.contains('avatar') ||
        key.contains('phone'));
    }

    return filtered.isNotEmpty ? filtered : null;
  }
}

/// Parameters for the GetCurrentUserUseCase
/// 
/// This class provides configuration options for retrieving user data,
/// allowing for different levels of data inclusion and caching behavior.
class GetCurrentUserParams {
  /// Whether to prefer cached data over fresh data
  final bool preferCached;
  
  /// Whether to force refresh of user data
  final bool forceRefresh;
  
  /// Maximum age for cached user data
  final Duration? maxCacheAge;
  
  /// Whether to include full profile information
  final bool includeProfile;
  
  /// Whether to return minimal user data only
  final bool minimalData;
  
  /// Whether to require an active account
  final bool requireActiveAccount;
  
  /// Whether to require verified email
  final bool requireVerifiedEmail;
  
  /// Optional metadata for the operation
  final Map<String, dynamic>? metadata;

  const GetCurrentUserParams({
    this.preferCached = true,
    this.forceRefresh = false,
    this.maxCacheAge,
    this.includeProfile = true,
    this.minimalData = false,
    this.requireActiveAccount = true,
    this.requireVerifiedEmail = false,
    this.metadata,
  });

  /// Creates parameters for getting fresh user data
  const GetCurrentUserParams.fresh({
    bool includeProfile = true,
    bool requireActiveAccount = true,
    bool requireVerifiedEmail = false,
    Map<String, dynamic>? metadata,
  }) : this(
          preferCached: false,
          forceRefresh: true,
          includeProfile: includeProfile,
          requireActiveAccount: requireActiveAccount,
          requireVerifiedEmail: requireVerifiedEmail,
          metadata: metadata,
        );

  /// Creates parameters for getting cached user data
  const GetCurrentUserParams.cached({
    Duration? maxAge,
    bool includeProfile = true,
    bool requireActiveAccount = true,
    Map<String, dynamic>? metadata,
  }) : this(
          preferCached: true,
          forceRefresh: false,
          maxCacheAge: maxAge,
          includeProfile: includeProfile,
          requireActiveAccount: requireActiveAccount,
          metadata: metadata,
        );

  /// Creates parameters for getting minimal user data
  const GetCurrentUserParams.minimal({
    bool preferCached = true,
    bool requireActiveAccount = true,
    Map<String, dynamic>? metadata,
  }) : this(
          preferCached: preferCached,
          includeProfile: false,
          minimalData: true,
          requireActiveAccount: requireActiveAccount,
          metadata: metadata,
        );

  /// Creates parameters for getting user data with verification requirements
  const GetCurrentUserParams.verified({
    bool includeProfile = true,
    bool forceRefresh = false,
    Map<String, dynamic>? metadata,
  }) : this(
          preferCached: !forceRefresh,
          forceRefresh: forceRefresh,
          includeProfile: includeProfile,
          requireActiveAccount: true,
          requireVerifiedEmail: true,
          metadata: metadata,
        );

  /// Creates a copy of this GetCurrentUserParams with the given fields replaced
  GetCurrentUserParams copyWith({
    bool? preferCached,
    bool? forceRefresh,
    Duration? maxCacheAge,
    bool? includeProfile,
    bool? minimalData,
    bool? requireActiveAccount,
    bool? requireVerifiedEmail,
    Map<String, dynamic>? metadata,
  }) {
    return GetCurrentUserParams(
      preferCached: preferCached ?? this.preferCached,
      forceRefresh: forceRefresh ?? this.forceRefresh,
      maxCacheAge: maxCacheAge ?? this.maxCacheAge,
      includeProfile: includeProfile ?? this.includeProfile,
      minimalData: minimalData ?? this.minimalData,
      requireActiveAccount: requireActiveAccount ?? this.requireActiveAccount,
      requireVerifiedEmail: requireVerifiedEmail ?? this.requireVerifiedEmail,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'GetCurrentUserParams{preferCached: $preferCached, forceRefresh: $forceRefresh, '
           'includeProfile: $includeProfile, minimalData: $minimalData, '
           'requireActiveAccount: $requireActiveAccount, requireVerifiedEmail: $requireVerifiedEmail}';
  }
}