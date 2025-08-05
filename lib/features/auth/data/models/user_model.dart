import 'package:insightflo_app/features/auth/domain/entities/user.dart';

/// UserModel data transfer object for the User entity
/// 
/// This model extends the User entity and provides JSON serialization
/// capabilities for data transfer between the data layer and external
/// data sources (Supabase). It handles conversion between Supabase
/// response format and the domain entity.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    super.displayName,
    super.avatarUrl,
    super.phoneNumber,
    required super.emailConfirmed,
    super.phoneConfirmed = false,
    required super.createdAt,
    super.updatedAt,
    super.lastSignInAt,
    super.role = UserRole.user,
    super.isActive = true,
    super.metadata,
  });

  /// Creates a UserModel from JSON data received from Supabase
  /// 
  /// Maps Supabase user object fields to UserModel properties.
  /// Handles null safety and provides default values where appropriate.
  /// 
  /// Example Supabase user object structure:
  /// ```json
  /// {
  ///   "id": "123e4567-e89b-12d3-a456-426614174000",
  ///   "email": "user@example.com",
  ///   "user_metadata": {},
  ///   "app_metadata": {},
  ///   "email_confirmed_at": "2024-01-01T00:00:00.000Z",
  ///   "phone_confirmed_at": null,
  ///   "created_at": "2024-01-01T00:00:00.000Z",
  ///   "updated_at": "2024-01-01T00:00:00.000Z",
  ///   "last_sign_in_at": "2024-01-01T00:00:00.000Z"
  /// }
  /// ```
  factory UserModel.fromJson(Map<String, dynamic> json) {
    try {
      // Extract user metadata with null safety
      final userMetadata = json['user_metadata'] as Map<String, dynamic>? ?? {};
      final appMetadata = json['app_metadata'] as Map<String, dynamic>? ?? {};
      
      // Parse timestamps with error handling
      DateTime? parseDateTime(String? dateString) {
        if (dateString == null || dateString.isEmpty) return null;
        try {
          return DateTime.parse(dateString);
        } catch (e) {
          return null;
        }
      }

      // Determine email confirmation status
      final emailConfirmedAt = json['email_confirmed_at'] as String?;
      final isEmailConfirmed = emailConfirmedAt != null && emailConfirmedAt.isNotEmpty;

      // Determine phone confirmation status
      final phoneConfirmedAt = json['phone_confirmed_at'] as String?;
      final isPhoneConfirmed = phoneConfirmedAt != null && phoneConfirmedAt.isNotEmpty;

      // Extract role from app_metadata or user_metadata
      String? roleString = appMetadata['role'] as String? ?? 
                          userMetadata['role'] as String?;
      
      // Get display name from multiple possible sources
      String? displayName = userMetadata['full_name'] as String? ??
                           userMetadata['display_name'] as String? ??
                           userMetadata['name'] as String?;

      // Get avatar URL from multiple possible sources
      String? avatarUrl = userMetadata['avatar_url'] as String? ??
                         userMetadata['picture'] as String?;

      // Parse phone number
      String? phoneNumber = json['phone'] as String? ?? 
                           userMetadata['phone'] as String?;

      // Combine metadata
      Map<String, dynamic>? combinedMetadata;
      if (userMetadata.isNotEmpty || appMetadata.isNotEmpty) {
        combinedMetadata = {
          ...userMetadata,
          if (appMetadata.isNotEmpty) 'app_metadata': appMetadata,
        };
      }

      return UserModel(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: displayName,
        avatarUrl: avatarUrl,
        phoneNumber: phoneNumber,
        emailConfirmed: isEmailConfirmed,
        phoneConfirmed: isPhoneConfirmed,
        createdAt: parseDateTime(json['created_at'] as String?) ?? DateTime.now(),
        updatedAt: parseDateTime(json['updated_at'] as String?),
        lastSignInAt: parseDateTime(json['last_sign_in_at'] as String?),
        role: roleString != null ? UserRole.fromString(roleString) : UserRole.user,
        isActive: !(json['banned_until'] != null || 
                   appMetadata['disabled'] == true),
        metadata: combinedMetadata,
      );
    } catch (e) {
      throw FormatException('Failed to parse UserModel from JSON: $e');
    }
  }

  /// Converts UserModel to JSON format for Supabase requests
  /// 
  /// Creates a JSON representation suitable for sending to Supabase.
  /// Only includes fields that can be updated through the API.
  /// 
  /// Returns a Map containing user data in Supabase format.
  Map<String, dynamic> toJson() {
    final userMetadata = <String, dynamic>{};
    
    // Add updatable fields to user_metadata
    if (displayName != null) {
      userMetadata['display_name'] = displayName;
      userMetadata['full_name'] = displayName; // Also add as full_name for compatibility
    }
    
    if (avatarUrl != null) {
      userMetadata['avatar_url'] = avatarUrl;
    }
    
    if (phoneNumber != null) {
      userMetadata['phone'] = phoneNumber;
    }

    // Add existing metadata if present
    if (metadata != null) {
      for (final entry in metadata!.entries) {
        if (entry.key != 'app_metadata') {
          userMetadata[entry.key] = entry.value;
        }
      }
    }

    return {
      'id': id,
      'email': email,
      if (userMetadata.isNotEmpty) 'user_metadata': userMetadata,
      if (phoneNumber != null) 'phone': phoneNumber,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (lastSignInAt != null) 'last_sign_in_at': lastSignInAt!.toIso8601String(),
      'email_confirmed_at': emailConfirmed ? createdAt.toIso8601String() : null,
      'phone_confirmed_at': phoneConfirmed && phoneNumber != null ? 
                           createdAt.toIso8601String() : null,
    };
  }

  /// Creates a UserModel from a Supabase Auth User object
  /// 
  /// Specifically handles the user object returned from Supabase Auth methods
  /// like signUp, signInWithPassword, etc. This method provides additional
  /// validation and error handling for auth-specific user data.
  factory UserModel.fromSupabaseUser(dynamic supabaseUser) {
    if (supabaseUser == null) {
      throw ArgumentError('Supabase user cannot be null');
    }

    // Handle both Map and object types
    Map<String, dynamic> userData;
    if (supabaseUser is Map<String, dynamic>) {
      userData = supabaseUser;
    } else {
      // Try to convert object to map (for supabase_flutter User objects)
      try {
        userData = {
          'id': supabaseUser.id,
          'email': supabaseUser.email,
          'user_metadata': supabaseUser.userMetadata ?? {},
          'app_metadata': supabaseUser.appMetadata ?? {},
          'email_confirmed_at': supabaseUser.emailConfirmedAt?.toIso8601String(),
          'phone_confirmed_at': supabaseUser.phoneConfirmedAt?.toIso8601String(),
          'created_at': supabaseUser.createdAt?.toIso8601String(),
          'updated_at': supabaseUser.updatedAt?.toIso8601String(),
          'last_sign_in_at': supabaseUser.lastSignInAt?.toIso8601String(),
          'phone': supabaseUser.phone,
        };
      } catch (e) {
        throw FormatException('Unable to convert Supabase user object: $e');
      }
    }

    return UserModel.fromJson(userData);
  }

  /// Creates a copy of this UserModel with updated values
  @override
  UserModel copyWith({
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
    return UserModel(
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

  /// Creates a UserModel with minimal required data
  /// 
  /// Useful for creating user objects during authentication flows
  /// where only basic information is available.
  factory UserModel.minimal({
    required String id,
    required String email,
    bool emailConfirmed = false,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id,
      email: email,
      emailConfirmed: emailConfirmed,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Creates a UserModel for testing purposes
  /// 
  /// Provides sensible defaults for all required fields to facilitate
  /// unit testing and mock data creation.
  factory UserModel.test({
    String id = 'test-user-id',
    String email = 'test@example.com',
    String? displayName = 'Test User',
    bool emailConfirmed = true,
    UserRole role = UserRole.user,
  }) {
    return UserModel(
      id: id,
      email: email,
      displayName: displayName,
      emailConfirmed: emailConfirmed,
      createdAt: DateTime.now(),
      role: role,
    );
  }

  @override
  String toString() {
    return 'UserModel{id: $id, email: $email, displayName: $displayName, '
           'emailConfirmed: $emailConfirmed, role: $role, isActive: $isActive}';
  }

  /// Validates the UserModel data integrity
  /// 
  /// Performs validation checks to ensure the user data is consistent
  /// and meets business rules. Returns null if valid, or an error message
  /// describing the validation failure.
  String? validate() {
    if (id.isEmpty) {
      return 'User ID cannot be empty';
    }

    if (email.isEmpty) {
      return 'Email cannot be empty';
    }

    // Basic email format validation
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      return 'Invalid email format';
    }

    if (phoneNumber != null && phoneNumber!.isNotEmpty) {
      // Basic phone number validation
      if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phoneNumber!)) {
        return 'Invalid phone number format';
      }
    }

    return null; // Valid
  }

  /// Returns user data safe for logging (removes sensitive information)
  /// 
  /// Creates a sanitized version of user data that can be safely logged
  /// without exposing sensitive information like metadata or full email.
  Map<String, dynamic> toLogSafeMap() {
    return {
      'id': id,
      'email': email.length > 3 ? '${email.substring(0, 3)}***' : '***',
      'hasDisplayName': displayName != null,
      'hasAvatarUrl': avatarUrl != null,
      'hasPhoneNumber': phoneNumber != null,
      'emailConfirmed': emailConfirmed,
      'phoneConfirmed': phoneConfirmed,
      'role': role.toString(),
      'isActive': isActive,
      'metadataKeys': metadata?.keys.toList() ?? [],
    };
  }
}