import 'package:equatable/equatable.dart';

class KeywordEntity extends Equatable {
  final String id;
  final String userId;
  final String keyword;
  final double weight;
  final String? category;
  final DateTime createdAt;

  const KeywordEntity({
    required this.id,
    required this.userId,
    required this.keyword,
    required this.weight,
    this.category,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        keyword,
        weight,
        category,
        createdAt,
      ];

  @override
  String toString() {
    return 'KeywordEntity(id: $id, keyword: $keyword, weight: $weight, category: $category)';
  }
}