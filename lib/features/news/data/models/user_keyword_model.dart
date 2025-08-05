import 'package:insightflo_app/features/news/domain/entities/user_keyword.dart';

/// Data model for UserKeyword entity
class UserKeywordModel extends UserKeyword {
  const UserKeywordModel({
    required super.id,
    required super.userId,
    required super.keyword,
    required super.weight,
    required super.isActive,
    required super.createdAt,
    super.updatedAt,
  });

  /// Factory constructor from JSON
  factory UserKeywordModel.fromJson(Map<String, dynamic> json) {
    return UserKeywordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      keyword: json['keyword'] as String,
      weight: (json['weight'] as num).toDouble(),
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'keyword': keyword,
      'weight': weight,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  @override
  UserKeywordModel copyWith({
    String? id,
    String? userId,
    String? keyword,
    double? weight,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserKeywordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      keyword: keyword ?? this.keyword,
      weight: weight ?? this.weight,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Convert entity to model
  factory UserKeywordModel.fromEntity(UserKeyword keyword) {
    return UserKeywordModel(
      id: keyword.id,
      userId: keyword.userId,
      keyword: keyword.keyword,
      weight: keyword.weight,
      isActive: keyword.isActive,
      createdAt: keyword.createdAt,
      updatedAt: keyword.updatedAt,
    );
  }
}