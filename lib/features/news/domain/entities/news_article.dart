import 'package:equatable/equatable.dart';

/// News article entity representing the core business model
class NewsArticle extends Equatable {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String url;
  final String source;
  final DateTime publishedAt;
  final List<String> keywords;
  final String? imageUrl;
  final double? sentimentScore;
  final String? sentimentLabel;
  final bool isBookmarked;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.keywords,
    this.imageUrl,
    this.sentimentScore,
    this.sentimentLabel,
    this.isBookmarked = false,
  });

  /// Check if article is recent (published within last 24 hours)
  bool get isRecent {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);
    return difference.inHours <= 24;
  }

  /// Check if article has positive sentiment
  bool get isPositive {
    if (sentimentScore == null) return false;
    return sentimentScore! > 0.1;
  }

  /// Check if article has negative sentiment
  bool get isNegative {
    if (sentimentScore == null) return false;
    return sentimentScore! < -0.1;
  }

  /// Get sentiment emoji based on score
  String get sentimentEmoji {
    if (sentimentScore == null) return '😐';
    if (sentimentScore! > 0.3) return '😊';
    if (sentimentScore! > 0.1) return '🙂';
    if (sentimentScore! < -0.3) return '😟';
    if (sentimentScore! < -0.1) return '😕';
    return '😐';
  }

  @override
  List<Object?> get props => [
        id,
        title,
        summary,
        content,
        url,
        source,
        publishedAt,
        keywords,
        imageUrl,
        sentimentScore,
        sentimentLabel,
        isBookmarked,
      ];
}