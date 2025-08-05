import 'package:insightflo_app/features/keywords/domain/entities/keyword_entity.dart';

class KeywordModel extends KeywordEntity {
  const KeywordModel({
    required super.id,
    required super.userId,
    required super.keyword,
    required super.weight,
    super.category,
    required super.createdAt,
  });

  factory KeywordModel.fromJson(Map<String, dynamic> json) {
    return KeywordModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      // API의 interest_category를 keyword로 매핑
      keyword: json['interest_category'] as String? ?? json['keyword'] as String,
      // API의 priority_level을 weight로 매핑 (1-5를 0.2-1.0으로 변환)
      weight: json['priority_level'] != null 
          ? (json['priority_level'] as num).toDouble() / 5.0
          : (json['weight'] as num?)?.toDouble() ?? 1.0,
      category: json['category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'keyword': keyword,
      'weight': weight,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateJson() {
    return {
      // API가 기대하는 필드명으로 변환
      'interest_category': keyword,
      // weight (0.2-1.0)를 priority_level (1-5)로 변환
      'priority_level': (weight * 5).round().clamp(1, 5),
      if (category != null) 'category': category,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      // API가 기대하는 필드명으로 변환
      if (keyword.isNotEmpty) 'interest_category': keyword,
      // weight (0.2-1.0)를 priority_level (1-5)로 변환
      'priority_level': (weight * 5).round().clamp(1, 5),
      'category': category,
    };
  }

  KeywordModel copyWith({
    String? id,
    String? userId,
    String? keyword,
    double? weight,
    String? category,
    DateTime? createdAt,
  }) {
    return KeywordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      keyword: keyword ?? this.keyword,
      weight: weight ?? this.weight,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory KeywordModel.fromEntity(KeywordEntity entity) {
    return KeywordModel(
      id: entity.id,
      userId: entity.userId,
      keyword: entity.keyword,
      weight: entity.weight,
      category: entity.category,
      createdAt: entity.createdAt,
    );
  }
}