// Use case implementations
export 'sign_in_usecase.dart';
export 'sign_up_usecase.dart';
export 'sign_out_usecase.dart';
export 'get_current_user_usecase.dart';
export 'reset_password_usecase.dart';
export 'sign_in_with_google_usecase.dart';
export 'sign_in_with_apple_usecase.dart';
export 'verify_email_usecase.dart';

/// Authentication Use Cases Overview
/// 
/// The following use cases are available:
/// 
/// 1. [SignInUseCase] - Authenticates users with email and password
///    - Validates email and password format
///    - Implements rate limiting and security checks
///    - Handles business rules for account status
/// 
/// 2. [SignUpUseCase] - Registers new users with email and password
///    - Comprehensive input validation
///    - Password strength enforcement
///    - Business rules for registration eligibility
///    - Automatic email verification triggering
/// 
/// 3. [SignOutUseCase] - Signs out the current user
///    - Multiple sign-out types (normal, secure, timeout, administrative)
///    - Configurable data cleanup options
///    - Security auditing and logging
///    - Token revocation capabilities
/// 
/// 4. [GetCurrentUserUseCase] - Retrieves current authenticated user
///    - Flexible caching strategies
///    - Data filtering options (minimal, full profile)
///    - Account status validation
///    - Metadata enrichment
/// 
/// 5. [ResetPasswordUseCase] - Sends password reset emails
///    - Email validation and domain checking
///    - Rate limiting protection
///    - Security logging and monitoring
///    - Configurable verification requirements
/// 
/// All use cases:
/// - Follow Clean Architecture principles
/// - Return Either<Failure, T> for error handling
/// - Implement comprehensive input validation
/// - Include business rule enforcement
/// - Provide detailed parameter classes
/// - Support extensive configuration options
/// - Include security considerations
/// - Maintain separation of concerns