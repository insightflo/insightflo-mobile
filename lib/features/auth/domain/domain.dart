/// Authentication Domain Layer Exports
/// 
/// This barrel file exports all public interfaces and entities from the
/// authentication domain layer following Clean Architecture principles.

// Entities
export 'entities/user.dart';

// Value Objects
export 'value_objects/email.dart';
export 'value_objects/password.dart';

// Repositories
export 'repositories/auth_repository.dart';

// Core Failures (re-exported for convenience)
export '../../../core/errors/failures.dart';