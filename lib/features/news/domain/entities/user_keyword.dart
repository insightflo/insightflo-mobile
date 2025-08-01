import 'package:equatable/equatable.dart';

/// User keyword entity for personalized news filtering
class UserKeyword extends Equatable {
  final String id;
  final String userId;
  final String keyword;
  final double weight;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserKeyword({
    required this.id,
    required this.userId,
    required this.keyword,
    required this.weight,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create a copy of this keyword with updated fields
  UserKeyword copyWith({
    String? id,
    String? userId,
    String? keyword,
    double? weight,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserKeyword(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      keyword: keyword ?? this.keyword,
      weight: weight ?? this.weight,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        keyword,
        weight,
        isActive,
        createdAt,
        updatedAt,
      ];
}