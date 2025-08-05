import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';

/// Use case for signing out the current user
/// 
/// This use case encapsulates the business logic for user sign-out,
/// including session cleanup, security considerations, and error handling.
/// It follows Clean Architecture principles by depending only on abstractions.
class SignOutUseCase implements UseCase<void, SignOutParams> {
  final AuthRepository _authRepository;

  const SignOutUseCase(this._authRepository);

  @override
  Future<Either<Failure, void>> call(SignOutParams params) async {
    // Business rule: Check if user is currently authenticated
    if (!_authRepository.isAuthenticated) {
      // Not an error - user is already signed out
      return const Right(null);
    }

    // Business rule: Handle different types of sign-out
    try {
      // Perform the sign-out operation
      final result = await _authRepository.signOut();

      return result.fold(
        (failure) => Left(failure),
        (_) {
          // Business rule: Perform post-signout cleanup
          _performPostSignOutCleanup(params);

          // Business rule: Log sign-out event for security auditing
          _logSignOutEvent(params);

          return const Right(null);
        },
      );
    } catch (e) {
      // Even if sign-out fails on the server side, we should still
      // clear local session data to prevent security issues
      _performLocalCleanup();

      return Left(ServerFailure(
        message: 'Sign-out completed locally but server sync failed.',
        statusCode: 500,
      ));
    }
  }

  /// Business rule: Perform post-signout cleanup operations
  void _performPostSignOutCleanup(SignOutParams params) {
    // In production, this would handle:
    // - Clear cached user data
    // - Reset app state to unauthenticated
    // - Clear sensitive data from memory
    // - Cancel ongoing background tasks
    // - Reset notification tokens
    
    if (params.clearAllData) {
      _clearAllUserData();
    }

    if (params.revokeAllTokens) {
      _revokeAllAuthTokens();
    }
  }

  /// Business rule: Log sign-out event for security auditing
  void _logSignOutEvent(SignOutParams params) {
    // In production, this would:
    // - Log to security audit system
    // - Record timestamp and device info
    // - Track sign-out reason (user initiated, timeout, etc.)
    // - Update user session history
    
    final eventData = {
      'event_type': 'user_signout',
      'signout_type': params.signOutType.name,
      'timestamp': DateTime.now().toIso8601String(),
      'clear_all_data': params.clearAllData,
      'revoke_all_tokens': params.revokeAllTokens,
    };

    // Log event (implementation would depend on logging service)
    _logSecurityEvent(eventData);
  }

  /// Clears all user-related data from local storage
  void _clearAllUserData() {
    // Implementation would:
    // - Clear shared preferences
    // - Clear secure storage
    // - Clear database cache
    // - Clear file cache
    // - Reset user preferences
  }

  /// Revokes all authentication tokens for enhanced security
  void _revokeAllAuthTokens() {
    // Implementation would:
    // - Call server API to revoke refresh tokens
    // - Invalidate all active sessions
    // - Clear token storage
    // - Notify other devices of session termination
  }

  /// Performs local cleanup when server sign-out fails
  void _performLocalCleanup() {
    // Even if server operations fail, we need to:
    // - Clear local authentication state
    // - Remove cached credentials
    // - Reset app to anonymous state
    // - Clear sensitive data
  }

  /// Logs security events for auditing purposes
  void _logSecurityEvent(Map<String, dynamic> eventData) {
    // Implementation would send to:
    // - Security audit service
    // - Analytics service
    // - Local log files
    // - Monitoring systems
  }
}

/// Parameters for the SignOutUseCase
/// 
/// This class encapsulates configuration options for the sign-out operation,
/// allowing for different types of sign-out behavior based on security requirements.
class SignOutParams {
  /// Type of sign-out operation
  final SignOutType signOutType;
  
  /// Whether to clear all user data from local storage
  final bool clearAllData;
  
  /// Whether to revoke all authentication tokens
  final bool revokeAllTokens;
  
  /// Optional reason for sign-out (for logging/analytics)
  final String? reason;
  
  /// Optional metadata for the sign-out operation
  final Map<String, dynamic>? metadata;

  const SignOutParams({
    this.signOutType = SignOutType.normal,
    this.clearAllData = false,
    this.revokeAllTokens = false,
    this.reason,
    this.metadata,
  });

  /// Creates a SignOutParams for normal user-initiated sign-out
  const SignOutParams.normal({
    String? reason,
    Map<String, dynamic>? metadata,
  }) : this(
          signOutType: SignOutType.normal,
          clearAllData: false,
          revokeAllTokens: false,
          reason: reason,
          metadata: metadata,
        );

  /// Creates a SignOutParams for security-focused sign-out
  /// (e.g., when security breach is suspected)
  const SignOutParams.secure({
    String? reason,
    Map<String, dynamic>? metadata,
  }) : this(
          signOutType: SignOutType.secure,
          clearAllData: true,
          revokeAllTokens: true,
          reason: reason,
          metadata: metadata,
        );

  /// Creates a SignOutParams for session timeout sign-out
  const SignOutParams.timeout({
    String? reason,
    Map<String, dynamic>? metadata,
  }) : this(
          signOutType: SignOutType.timeout,
          clearAllData: false,
          revokeAllTokens: false,
          reason: reason ?? 'Session timeout',
          metadata: metadata,
        );

  /// Creates a SignOutParams for administrative sign-out
  const SignOutParams.administrative({
    String? reason,
    Map<String, dynamic>? metadata,
  }) : this(
          signOutType: SignOutType.administrative,
          clearAllData: true,
          revokeAllTokens: true,
          reason: reason ?? 'Administrative action',
          metadata: metadata,
        );

  /// Creates a copy of this SignOutParams with the given fields replaced
  SignOutParams copyWith({
    SignOutType? signOutType,
    bool? clearAllData,
    bool? revokeAllTokens,
    String? reason,
    Map<String, dynamic>? metadata,
  }) {
    return SignOutParams(
      signOutType: signOutType ?? this.signOutType,
      clearAllData: clearAllData ?? this.clearAllData,
      revokeAllTokens: revokeAllTokens ?? this.revokeAllTokens,
      reason: reason ?? this.reason,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'SignOutParams{signOutType: $signOutType, clearAllData: $clearAllData, '
           'revokeAllTokens: $revokeAllTokens, reason: $reason}';
  }
}

/// Enumeration of different sign-out types
/// 
/// This helps categorize sign-out operations for proper handling,
/// logging, and security measures.
enum SignOutType {
  /// Normal user-initiated sign-out
  normal('normal'),
  
  /// Security-focused sign-out (suspicious activity detected)
  secure('secure'),
  
  /// Automatic sign-out due to session timeout
  timeout('timeout'),
  
  /// Administrative sign-out (forced by admin)
  administrative('administrative'),
  
  /// Sign-out due to device change or security policy
  deviceChange('device_change');

  const SignOutType(this.value);
  
  /// String representation of the sign-out type
  final String value;
  
  /// Creates a SignOutType from a string value
  static SignOutType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'secure':
        return SignOutType.secure;
      case 'timeout':
        return SignOutType.timeout;
      case 'administrative':
        return SignOutType.administrative;
      case 'device_change':
        return SignOutType.deviceChange;
      default:
        return SignOutType.normal;
    }
  }
  
  /// Gets the display name for the sign-out type
  String get displayName {
    switch (this) {
      case SignOutType.normal:
        return 'Normal Sign Out';
      case SignOutType.secure:
        return 'Security Sign Out';
      case SignOutType.timeout:
        return 'Session Timeout';
      case SignOutType.administrative:
        return 'Administrative Sign Out';
      case SignOutType.deviceChange:
        return 'Device Change Sign Out';
    }
  }
  
  @override
  String toString() => value;
}