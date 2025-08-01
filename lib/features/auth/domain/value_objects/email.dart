import 'package:email_validator/email_validator.dart';
import 'package:equatable/equatable.dart';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

/// Email value object that encapsulates email validation logic
/// 
/// This value object ensures that email addresses are always valid
/// and provides a type-safe way to handle email data in the domain layer.
class Email extends Equatable {
  final String _value;

  const Email._(this._value);

  /// Gets the string value of the email
  String get value => _value;

  /// Creates an Email value object from a string
  /// 
  /// Returns [Right(Email)] if the email is valid,
  /// [Left(ValidationFailure)] if the email is invalid
  static Either<ValidationFailure, Email> create(String input) {
    final trimmedInput = input.trim();
    
    // Check if email is empty
    if (trimmedInput.isEmpty) {
      return const Left(ValidationFailure(
        message: 'Email cannot be empty',
        statusCode: 400,
      ));
    }
    
    // Check email length (reasonable limits)
    if (trimmedInput.length > 254) {
      return const Left(ValidationFailure(
        message: 'Email is too long (maximum 254 characters)',
        statusCode: 400,
      ));
    }
    
    // Validate email format using email_validator package
    if (!EmailValidator.validate(trimmedInput)) {
      return const Left(ValidationFailure(
        message: 'Invalid email format',
        statusCode: 400,
      ));
    }
    
    // Additional business rules
    if (!_isAllowedDomain(trimmedInput)) {
      return const Left(ValidationFailure(
        message: 'Email domain is not allowed',
        statusCode: 400,
      ));
    }
    
    return Right(Email._(trimmedInput.toLowerCase()));
  }

  /// Creates an Email value object without validation (for trusted sources)
  /// 
  /// Use this method only when you're certain the email is valid,
  /// such as when loading from a trusted data source
  static Email fromTrustedSource(String email) {
    return Email._(email.toLowerCase());
  }

  /// Checks if the email domain is allowed
  /// 
  /// This can be customized based on business requirements
  static bool _isAllowedDomain(String email) {
    const blockedDomains = [
      'tempmail.org',
      '10minutemail.com',
      'guerrillamail.com',
      'mailinator.com',
    ];
    
    final domain = email.split('@').last.toLowerCase();
    return !blockedDomains.contains(domain);
  }

  /// Extracts the local part of the email (before @)
  String get localPart => _value.split('@').first;

  /// Extracts the domain part of the email (after @)
  String get domain => _value.split('@').last;

  /// Checks if this is a business email (not from common free providers)
  bool get isBusinessEmail {
    const freeProviders = [
      'gmail.com',
      'yahoo.com',
      'hotmail.com',
      'outlook.com',
      'icloud.com',
      'aol.com',
    ];
    
    return !freeProviders.contains(domain);
  }

  /// Generates a gravatar URL for this email
  String gravatarUrl({int size = 80}) {
    final emailHash = _value.hashCode.abs().toString();
    return 'https://www.gravatar.com/avatar/$emailHash?s=$size&d=identicon';
  }

  @override
  List<Object> get props => [_value];

  @override
  String toString() => _value;
}

/// Email validation helper functions
class EmailValidation {
  EmailValidation._();

  /// Validates multiple emails at once
  static Either<ValidationFailure, List<Email>> validateMultiple(List<String> emails) {
    final validEmails = <Email>[];
    
    for (final emailString in emails) {
      final emailResult = Email.create(emailString);
      
      if (emailResult.isLeft()) {
        return emailResult.fold(
          (failure) => Left(failure),
          (_) => throw Exception('Unexpected state'),
        );
      }
      
      emailResult.fold(
        (_) => throw Exception('Unexpected state'),
        (email) => validEmails.add(email),
      );
    }
    
    return Right(validEmails);
  }

  /// Checks if an email string is valid without creating an Email object
  static bool isValid(String email) {
    return Email.create(email).isRight();
  }

  /// Gets validation error message for an email string
  static String? getValidationError(String email) {
    final result = Email.create(email);
    return result.fold(
      (failure) => failure.message,
      (_) => null,
    );
  }
}