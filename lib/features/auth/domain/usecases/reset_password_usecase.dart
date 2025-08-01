import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/auth_repository.dart';
import '../value_objects/email.dart';

/// Use case for sending password reset email to users
/// 
/// This use case encapsulates the business logic for password reset operations,
/// including email validation, rate limiting, and security considerations.
/// It follows Clean Architecture principles by depending only on abstractions.
class ResetPasswordUseCase implements UseCase<void, ResetPasswordParams> {
  final AuthRepository _authRepository;

  const ResetPasswordUseCase(this._authRepository);

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) async {
    // Validate email address
    final emailValidation = Email.create(params.email);
    if (emailValidation.isLeft()) {
      return emailValidation.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected state'),
      );
    }

    final email = emailValidation.getOrElse(() => throw Exception('Email validation failed'));

    // Business rule: Check rate limiting for password reset requests
    final rateLimitResult = await _checkRateLimit(email, params);
    if (rateLimitResult.isLeft()) {
      return rateLimitResult.fold(
        (failure) => Left(failure),
        (_) => throw Exception('Unexpected state'),
      );
    }

    // Business rule: Validate email domain is allowed for password reset
    if (!_isEmailDomainAllowedForReset(email)) {
      return const Left(ValidationFailure(
        message: 'Password reset is not available for this email domain.',
        statusCode: 400,
      ));
    }

    // Business rule: Check if user exists (optional security consideration)
    if (params.verifyUserExists) {
      final userExistsResult = await _verifyUserExists(email);
      if (userExistsResult.isLeft()) {
        return userExistsResult.fold(
          (failure) => Left(failure),
          (_) => throw Exception('Unexpected state'),
        );
      }
    }

    try {
      // Send password reset email
      final result = await _authRepository.sendPasswordResetEmail(email: email);

      return result.fold(
        (failure) => Left(failure),
        (_) {
          // Business rule: Log password reset request for security auditing
          _logPasswordResetRequest(email, params);

          // Business rule: Update rate limiting counters
          _updateRateLimitCounters(email, params);

          return const Right(null);
        },
      );
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to send password reset email. Please try again later.',
        statusCode: 500,
      ));
    }
  }

  /// Business rule: Check rate limiting for password reset requests
  Future<Either<ValidationFailure, void>> _checkRateLimit(
    Email email,
    ResetPasswordParams params,
  ) async {
    // In production, this would check:
    // - Number of reset requests for this email in the last hour/day
    // - Number of reset requests from this IP address
    // - Global rate limits to prevent abuse
    
    // Simulate rate limiting logic
    final rateLimitWindow = Duration(minutes: params.rateLimitWindowMinutes);
    
    // Check if too many requests have been made recently
    if (await _hasExceededRateLimit(email, rateLimitWindow, params.maxRequestsPerWindow)) {
      return Left(ValidationFailure(
        message: 'Too many password reset requests. Please wait ${params.rateLimitWindowMinutes} minutes before trying again.',
        statusCode: 429,
      ));
    }

    return const Right(null);
  }

  /// Simulated rate limit check
  Future<bool> _hasExceededRateLimit(
    Email email,
    Duration window,
    int maxRequests,
  ) async {
    // In production, this would:
    // - Query rate limiting database/cache
    // - Check Redis counters
    // - Implement sliding window algorithm
    // - Consider IP-based limiting
    
    return false; // Placeholder - always allow for now
  }

  /// Business rule: Check if email domain is allowed for password reset
  bool _isEmailDomainAllowedForReset(Email email) {
    // Some organizations might restrict password reset to certain domains
    // or block temporary email providers
    
    const blockedDomains = [
      'tempmail.org',
      '10minutemail.com',
      'guerrillamail.com',
      'mailinator.com',
    ];
    
    return !blockedDomains.contains(email.domain.toLowerCase());
  }

  /// Business rule: Verify that user exists before sending reset email
  Future<Either<ValidationFailure, void>> _verifyUserExists(Email email) async {
    // This is optional for security - some applications prefer not to reveal
    // whether an email is registered or not to prevent user enumeration attacks
    
    // In production, this might:
    // - Check user database
    // - Return generic success even if user doesn't exist (for security)
    // - Log attempts for suspicious activity monitoring
    
    return const Right(null); // Always proceed for now
  }

  /// Business rule: Log password reset request for security auditing
  void _logPasswordResetRequest(Email email, ResetPasswordParams params) {
    final logData = {
      'event_type': 'password_reset_requested',
      'email_domain': email.domain,
      'timestamp': DateTime.now().toIso8601String(),
      'request_source': params.requestSource,
      'user_agent': params.userAgent,
      'ip_address': params.ipAddress,
    };

    // In production, this would:
    // - Send to security audit system
    // - Log to security monitoring service
    // - Update user activity timeline
    // - Alert on suspicious patterns
    
    _logSecurityEvent(logData);
  }

  /// Update rate limiting counters after successful request
  void _updateRateLimitCounters(Email email, ResetPasswordParams params) {
    // In production, this would:
    // - Increment rate limit counters in Redis/database
    // - Update last request timestamp
    // - Clean up expired rate limit entries
    // - Update global rate limiting statistics
  }

  /// Log security events for monitoring and analysis
  void _logSecurityEvent(Map<String, dynamic> eventData) {
    // Implementation would send to:
    // - Security information and event management (SIEM) system
    // - Application logging service
    // - Monitoring and alerting systems
    // - Compliance audit trails
  }
}

/// Parameters for the ResetPasswordUseCase
/// 
/// This class encapsulates all configuration and metadata needed for
/// password reset operations, including security and rate limiting parameters.
class ResetPasswordParams {
  /// Email address to send the password reset link to
  final String email;
  
  /// Whether to verify that the user exists before sending email
  final bool verifyUserExists;
  
  /// Rate limiting window in minutes
  final int rateLimitWindowMinutes;
  
  /// Maximum number of requests allowed per rate limit window
  final int maxRequestsPerWindow;
  
  /// Source of the password reset request (web, mobile, etc.)
  final String requestSource;
  
  /// User agent string for logging and security analysis
  final String? userAgent;
  
  /// IP address of the requester for security logging
  final String? ipAddress;
  
  /// Custom redirect URL for the password reset flow
  final String? redirectUrl;
  
  /// Optional metadata for the reset operation
  final Map<String, dynamic>? metadata;

  const ResetPasswordParams({
    required this.email,
    this.verifyUserExists = false,
    this.rateLimitWindowMinutes = 60,
    this.maxRequestsPerWindow = 3,
    this.requestSource = 'unknown',
    this.userAgent,
    this.ipAddress,
    this.redirectUrl,
    this.metadata,
  });

  /// Creates parameters for a standard password reset request
  const ResetPasswordParams.standard({
    required String email,
    String requestSource = 'web',
    String? userAgent,
    String? ipAddress,
    String? redirectUrl,
    Map<String, dynamic>? metadata,
  }) : this(
          email: email,
          verifyUserExists: false,
          rateLimitWindowMinutes: 60,
          maxRequestsPerWindow: 3,
          requestSource: requestSource,
          userAgent: userAgent,
          ipAddress: ipAddress,
          redirectUrl: redirectUrl,
          metadata: metadata,
        );

  /// Creates parameters for a secure password reset request
  /// (with user verification and stricter rate limiting)
  const ResetPasswordParams.secure({
    required String email,
    String requestSource = 'web',
    String? userAgent,
    String? ipAddress,
    String? redirectUrl,
    Map<String, dynamic>? metadata,
  }) : this(
          email: email,
          verifyUserExists: true,
          rateLimitWindowMinutes: 60,
          maxRequestsPerWindow: 2,
          requestSource: requestSource,
          userAgent: userAgent,
          ipAddress: ipAddress,
          redirectUrl: redirectUrl,
          metadata: metadata,
        );

  /// Creates parameters for mobile app password reset requests
  const ResetPasswordParams.mobile({
    required String email,
    String? userAgent,
    String? ipAddress,
    String? redirectUrl,
    Map<String, dynamic>? metadata,
  }) : this(
          email: email,
          verifyUserExists: false,
          rateLimitWindowMinutes: 30,
          maxRequestsPerWindow: 5,
          requestSource: 'mobile',
          userAgent: userAgent,
          ipAddress: ipAddress,
          redirectUrl: redirectUrl,
          metadata: metadata,
        );

  /// Creates a copy of this ResetPasswordParams with the given fields replaced
  ResetPasswordParams copyWith({
    String? email,
    bool? verifyUserExists,
    int? rateLimitWindowMinutes,
    int? maxRequestsPerWindow,
    String? requestSource,
    String? userAgent,
    String? ipAddress,
    String? redirectUrl,
    Map<String, dynamic>? metadata,
  }) {
    return ResetPasswordParams(
      email: email ?? this.email,
      verifyUserExists: verifyUserExists ?? this.verifyUserExists,
      rateLimitWindowMinutes: rateLimitWindowMinutes ?? this.rateLimitWindowMinutes,
      maxRequestsPerWindow: maxRequestsPerWindow ?? this.maxRequestsPerWindow,
      requestSource: requestSource ?? this.requestSource,
      userAgent: userAgent ?? this.userAgent,
      ipAddress: ipAddress ?? this.ipAddress,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Gets a sanitized version of the email for logging (masks sensitive parts)
  String get sanitizedEmail {
    final emailParts = email.split('@');
    if (emailParts.length != 2) return '***@***';
    
    final localPart = emailParts[0];
    final domain = emailParts[1];
    
    if (localPart.length <= 2) {
      return '***@$domain';
    }
    
    return '${localPart.substring(0, 2)}***@$domain';
  }

  @override
  String toString() {
    return 'ResetPasswordParams{email: $sanitizedEmail, requestSource: $requestSource, '
           'rateLimitWindow: ${rateLimitWindowMinutes}min, maxRequests: $maxRequestsPerWindow}';
  }
}