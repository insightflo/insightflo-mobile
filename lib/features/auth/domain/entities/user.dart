import 'package:equatable/equatable.dart';

/// User entity representing an authenticated user in the domain layer
/// 
/// This entity follows Clean Architecture principles and contains
/// only the essential data that defines a user in the business logic.
/// It is independent of any external frameworks or data sources.
class User extends Equatable {
  /// Unique identifier for the user
  final String id;
  
  /// User's email address
  final String email;
  
  /// User's display name (optional)
  final String? displayName;
  
  /// URL to user's avatar/profile picture (optional)
  final String? avatarUrl;
  
  /// Phone number (optional)
  final String? phoneNumber;
  
  /// Whether the user's email has been verified
  final bool emailConfirmed;
  
  /// Whether the user's phone has been verified
  final bool phoneConfirmed;
  
  /// Timestamp when the user account was created
  final DateTime createdAt;
  
  /// Timestamp when the user was last updated
  final DateTime? updatedAt;
  
  /// Timestamp when the user last signed in
  final DateTime? lastSignInAt;
  
  /// User's role in the application
  final UserRole role;
  
  /// Whether the user account is active
  final bool isActive;
  
  /// User metadata (additional custom fields)
  final Map<String, dynamic>? metadata;

  const User({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.phoneNumber,
    required this.emailConfirmed,
    this.phoneConfirmed = false,
    required this.createdAt,
    this.updatedAt,
    this.lastSignInAt,
    this.role = UserRole.user,
    this.isActive = true,
    this.metadata,
  });

  /// Creates a copy of this user with the given fields replaced with new values
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
    bool? emailConfirmed,
    bool? phoneConfirmed,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSignInAt,
    UserRole? role,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emailConfirmed: emailConfirmed ?? this.emailConfirmed,
      phoneConfirmed: phoneConfirmed ?? this.phoneConfirmed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Returns the user's full name or display name
  String get fullName => displayName ?? email.split('@').first;
  
  /// Returns the user's initials for avatar display
  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final names = displayName!.split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    return email[0].toUpperCase();
  }
  
  /// Checks if the user has completed their profile
  bool get isProfileComplete {
    return displayName != null && 
           displayName!.isNotEmpty && 
           emailConfirmed && 
           isActive;
  }
  
  /// Checks if the user needs email verification
  bool get needsEmailVerification => !emailConfirmed;
  
  /// Compatibility getter for isEmailVerified
  bool get isEmailVerified => emailConfirmed;
  
  /// Checks if the user can access admin features
  bool get isAdmin => role == UserRole.admin;
  
  /// Checks if the user can access moderator features
  bool get isModerator => role == UserRole.moderator || isAdmin;

  // ====================
  // Compatibility Properties
  // ====================

  /// Compatibility getter for isPremium (always false for now)
  bool get isPremium => false; // TODO: Implement premium subscription logic

  /// Compatibility getter for roles list
  List<String> get roles => [role.value];

  /// Compatibility getter for name
  String get name => fullName;

  /// Compatibility getter for profileImageUrl
  String? get profileImageUrl => avatarUrl;

  @override
  List<Object?> get props => [
        id,
        email,
        displayName,
        avatarUrl,
        phoneNumber,
        emailConfirmed,
        phoneConfirmed,
        createdAt,
        updatedAt,
        lastSignInAt,
        role,
        isActive,
        metadata,
      ];

  @override
  String toString() {
    return 'User{id: $id, email: $email, displayName: $displayName, '
           'emailConfirmed: $emailConfirmed, role: $role, isActive: $isActive}';
  }
}

/// Enumeration of user roles in the application
enum UserRole {
  /// Regular user with basic permissions
  user('user'),
  
  /// Moderator with additional content management permissions
  moderator('moderator'),
  
  /// Administrator with full system access
  admin('admin');

  const UserRole(this.value);
  
  /// String representation of the role
  final String value;
  
  /// Creates a UserRole from a string value
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'moderator':
        return UserRole.moderator;
      default:
        return UserRole.user;
    }
  }
  
  @override
  String toString() => value;
}