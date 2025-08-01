import 'package:equatable/equatable.dart';

/// Domain entity representing a news article with comprehensive properties
/// for financial news analysis and personalization.
class NewsEntity extends Equatable {
  /// Unique identifier for the news article
  final String id;
  
  /// Article title
  final String title;
  
  /// Brief summary of the article
  final String summary;
  
  /// Full article content
  final String content;
  
  /// Original article URL
  final String url;
  
  /// News source/publisher
  final String source;
  
  /// Article publication timestamp
  final DateTime publishedAt;
  
  /// Relevant keywords for categorization and search
  final List<String> keywords;
  
  /// Article image URL (optional)
  final String? imageUrl;
  
  /// AI-computed sentiment score (-1.0 to 1.0)
  final double sentimentScore;
  
  /// Human-readable sentiment label
  final String sentimentLabel;
  
  /// Whether the article is bookmarked by the user
  final bool isBookmarked;
  
  /// Timestamp when the article was cached locally
  final DateTime cachedAt;
  
  /// User ID associated with this cached article
  final String userId;

  const NewsEntity({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.url,
    required this.source,
    required this.publishedAt,
    required this.keywords,
    this.imageUrl,
    required this.sentimentScore,
    required this.sentimentLabel,
    this.isBookmarked = false,
    required this.cachedAt,
    required this.userId,
  });

  /// Creates a copy of this entity with updated properties
  NewsEntity copyWith({
    String? id,
    String? title,
    String? summary,
    String? content,
    String? url,
    String? source,
    DateTime? publishedAt,
    List<String>? keywords,
    String? imageUrl,
    double? sentimentScore,
    String? sentimentLabel,
    bool? isBookmarked,
    DateTime? cachedAt,
    String? userId,
  }) {
    return NewsEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      url: url ?? this.url,
      source: source ?? this.source,
      publishedAt: publishedAt ?? this.publishedAt,
      keywords: keywords ?? this.keywords,
      imageUrl: imageUrl ?? this.imageUrl,
      sentimentScore: sentimentScore ?? this.sentimentScore,
      sentimentLabel: sentimentLabel ?? this.sentimentLabel,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      cachedAt: cachedAt ?? this.cachedAt,
      userId: userId ?? this.userId,
    );
  }

  /// Returns true if the article is considered fresh (within 24 hours)
  bool get isFresh {
    final now = DateTime.now();
    final cacheAge = now.difference(cachedAt);
    return cacheAge.inHours <= 24;
  }

  /// Returns true if the article has positive sentiment
  bool get hasPositiveSentiment => sentimentScore > 0.1;

  /// Returns true if the article has negative sentiment
  bool get hasNegativeSentiment => sentimentScore < -0.1;

  /// Returns true if the article has neutral sentiment
  bool get hasNeutralSentiment => 
      sentimentScore >= -0.1 && sentimentScore <= 0.1;

  /// Returns formatted publication time for display
  String get formattedPublishedAt {
    final now = DateTime.now();
    final difference = now.difference(publishedAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Returns sentiment color based on score
  String get sentimentColor {
    if (hasPositiveSentiment) return 'green';
    if (hasNegativeSentiment) return 'red';
    return 'gray';
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
        cachedAt,
        userId,
      ];

  @override
  String toString() {
    return 'NewsEntity(id: $id, title: $title, source: $source, '
           'publishedAt: $publishedAt, sentimentScore: $sentimentScore, '
           'isBookmarked: $isBookmarked, userId: $userId)';
  }
}