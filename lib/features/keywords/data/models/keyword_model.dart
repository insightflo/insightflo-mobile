import '../../domain/entities/keyword_entity.dart';

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
      keyword: json['keyword'] as String,
      weight: (json['weight'] as num).toDouble(),
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
      'keyword': keyword,
      'weight': weight,
      if (category != null) 'category': category,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      if (keyword.isNotEmpty) 'keyword': keyword,
      'weight': weight,
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
}