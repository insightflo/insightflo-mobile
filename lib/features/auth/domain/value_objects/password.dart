import 'package:equatable/equatable.dart';
import 'package:dartz/dartz.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../../core/errors/failures.dart';

/// Password value object that encapsulates password validation and security logic
/// 
/// This value object ensures that passwords meet security requirements
/// and provides type-safe password handling in the domain layer.
class Password extends Equatable {
  final String _value;

  const Password._(this._value);

  /// Gets the string value of the password
  /// Note: In production, consider if this should be available or use hashed version
  String get value => _value;

  /// Creates a Password value object from a string
  /// 
  /// Returns [Right(Password)] if the password is valid,
  /// [Left(ValidationFailure)] if the password is invalid
  static Either<ValidationFailure, Password> create(String input) {
    // Check if password is empty
    if (input.isEmpty) {
      return const Left(ValidationFailure(
        message: 'Password cannot be empty',
        statusCode: 400,
      ));
    }
    
    // Check minimum length
    if (input.length < 8) {
      return const Left(ValidationFailure(
        message: 'Password must be at least 8 characters long',
        statusCode: 400,
      ));
    }
    
    // Check maximum length (reasonable security limit)
    if (input.length > 128) {
      return const Left(ValidationFailure(
        message: 'Password is too long (maximum 128 characters)',
        statusCode: 400,
      ));
    }
    
    // Check for at least one lowercase letter
    if (!input.contains(RegExp(r'[a-z]'))) {
      return const Left(ValidationFailure(
        message: 'Password must contain at least one lowercase letter',
        statusCode: 400,
      ));
    }
    
    // Check for at least one uppercase letter
    if (!input.contains(RegExp(r'[A-Z]'))) {
      return const Left(ValidationFailure(
        message: 'Password must contain at least one uppercase letter',
        statusCode: 400,
      ));
    }
    
    // Check for at least one digit
    if (!input.contains(RegExp(r'[0-9]'))) {
      return const Left(ValidationFailure(
        message: 'Password must contain at least one number',
        statusCode: 400,
      ));
    }
    
    // Check for at least one special character
    if (!input.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return const Left(ValidationFailure(
        message: 'Password must contain at least one special character',
        statusCode: 400,
      ));
    }
    
    // Check for common weak patterns
    if (_isWeakPassword(input)) {
      return const Left(ValidationFailure(
        message: 'Password is too common or weak',
        statusCode: 400,
      ));
    }
    
    return Right(Password._(input));
  }

  /// Creates a Password value object without validation (for trusted sources)
  /// 
  /// Use this method only when you're certain the password meets requirements,
  /// such as when loading from a trusted data source
  static Password fromTrustedSource(String password) {
    return Password._(password);
  }

  /// Checks if the password contains weak patterns
  static bool _isWeakPassword(String password) {
    final lowercasePassword = password.toLowerCase();
    
    // Common weak passwords
    const weakPasswords = [
      'password',
      '12345678',
      'qwerty123',
      'abc12345',
      'password123',
      'admin123',
      'welcome123',
      'letmein123',
    ];
    
    // Check against common weak passwords
    if (weakPasswords.contains(lowercasePassword)) {
      return true;
    }
    
    // Check for simple patterns like "12345678" or "abcdefgh"
    if (_hasSequentialCharacters(password)) {
      return true;
    }
    
    // Check for repeated characters like "aaaaaaaa"
    if (_hasRepeatedCharacters(password)) {
      return true;
    }
    
    return false;
  }

  /// Checks for sequential characters in password
  static bool _hasSequentialCharacters(String password) {
    for (int i = 0; i < password.length - 3; i++) {
      final char1 = password.codeUnitAt(i);
      final char2 = password.codeUnitAt(i + 1);
      final char3 = password.codeUnitAt(i + 2);
      final char4 = password.codeUnitAt(i + 3);
      
      if (char2 == char1 + 1 && char3 == char2 + 1 && char4 == char3 + 1) {
        return true;
      }
    }
    return false;
  }

  /// Checks for repeated characters in password
  static bool _hasRepeatedCharacters(String password) {
    final Map<String, int> charCount = {};
    
    for (final char in password.split('')) {
      charCount[char] = (charCount[char] ?? 0) + 1;
    }
    
    // If any character appears more than 40% of the password length
    final maxAllowedRepeats = (password.length * 0.4).ceil();
    return charCount.values.any((count) => count > maxAllowedRepeats);
  }

  /// Calculates password strength score (0-100)
  int get strengthScore {
    int score = 0;
    
    // Length bonus
    if (_value.length >= 8) score += 25;
    if (_value.length >= 12) score += 15;
    if (_value.length >= 16) score += 10;
    
    // Character variety bonus
    if (_value.contains(RegExp(r'[a-z]'))) score += 10;
    if (_value.contains(RegExp(r'[A-Z]'))) score += 10;
    if (_value.contains(RegExp(r'[0-9]'))) score += 10;
    if (_value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score += 15;
    
    // Uniqueness bonus
    final uniqueChars = _value.split('').toSet().length;
    score += (uniqueChars / _value.length * 15).round();
    
    return score.clamp(0, 100);
  }

  /// Gets password strength level
  PasswordStrength get strength {
    final score = strengthScore;
    if (score >= 80) return PasswordStrength.strong;
    if (score >= 60) return PasswordStrength.medium;
    if (score >= 40) return PasswordStrength.weak;
    return PasswordStrength.veryWeak;
  }

  /// Generates a hash of the password for storage
  /// Note: In production, use proper password hashing like bcrypt or Argon2
  String get hash {
    final bytes = utf8.encode(_value);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Checks if this password matches a hash
  bool matchesHash(String hash) {
    return this.hash == hash;
  }

  @override
  List<Object> get props => [_value];

  @override
  String toString() => '*' * _value.length; // Hide password in logs
}

/// Password strength levels
enum PasswordStrength {
  veryWeak('Very Weak'),
  weak('Weak'),
  medium('Medium'),
  strong('Strong');

  const PasswordStrength(this.label);
  
  final String label;
  
  @override
  String toString() => label;
}

/// Password validation helper functions
class PasswordValidation {
  PasswordValidation._();

  /// Validates password confirmation
  static Either<ValidationFailure, void> validateConfirmation(
    Password password,
    String confirmation,
  ) {
    if (password.value != confirmation) {
      return const Left(ValidationFailure(
        message: 'Password confirmation does not match',
        statusCode: 400,
      ));
    }
    
    return const Right(null);
  }

  /// Checks if a password string is valid without creating a Password object
  static bool isValid(String password) {
    return Password.create(password).isRight();
  }

  /// Gets validation error message for a password string
  static String? getValidationError(String password) {
    final result = Password.create(password);
    return result.fold(
      (failure) => failure.message,
      (_) => null,
    );
  }

  /// Generates password requirements text
  static String getRequirementsText() {
    return '''
Password must contain:
• At least 8 characters
• One uppercase letter (A-Z)
• One lowercase letter (a-z)
• One number (0-9)
• One special character (!@#\$%^&*(),.?":{}|<>)
''';
  }

  /// Validates password strength meets minimum requirements
  static Either<ValidationFailure, void> validateStrength(
    Password password, {
    PasswordStrength minimumStrength = PasswordStrength.medium,
  }) {
    if (password.strength.index < minimumStrength.index) {
      return Left(ValidationFailure(
        message: 'Password strength must be at least ${minimumStrength.label}',
        statusCode: 400,
      ));
    }
    
    return const Right(null);
  }
}