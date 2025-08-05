import 'dart:convert';
import 'package:insightflo_app/features/news/domain/entities/news_entity.dart';

/// Data model for news articles with JSON serialization support
/// Maps between API responses and domain entities
class NewsModel extends NewsEntity {
  const NewsModel({
    required super.id,
    required super.title,
    required super.summary,
    required super.content,
    required super.url,
    required super.source,
    required super.publishedAt,
    required super.keywords,
    super.imageUrl,
    required super.sentimentScore,
    required super.sentimentLabel,
    super.isBookmarked = false,
    required super.cachedAt,
    required super.userId,
  });

  /// Creates a NewsModel from JSON response (API format)
  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      content: json['content'] as String,
      url: json['url'] as String,
      source: json['source'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      keywords: _parseKeywords(json['keywords']),
      imageUrl: json['image_url'] as String?,
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble() ?? 0.0,
      sentimentLabel: json['sentiment_label'] as String? ?? 'neutral',
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
      cachedAt: json['cached_at'] != null 
          ? DateTime.parse(json['cached_at'] as String)
          : DateTime.now(),
      userId: json['user_id'] as String,
    );
  }

  /// Creates a NewsModel from database row (Drift format)
  factory NewsModel.fromDatabaseRow(Map<String, dynamic> row) {
    final now = DateTime.now();
    
    return NewsModel(
      id: (row['id'] as String?) ?? '',
      title: (row['title'] as String?) ?? 'No Title',
      summary: (row['summary'] as String?) ?? 'No Summary',
      content: (row['content'] as String?) ?? '',
      url: (row['url'] as String?) ?? '',
      source: (row['source'] as String?) ?? 'Unknown',
      publishedAt: (row['published_at'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(row['published_at'] as int)
          : now,
      keywords: _safeParseKeywordsFromDatabase(row['keywords']),
      imageUrl: row['image_url'] as String?,
      sentimentScore: (row['sentiment_score'] as num?)?.toDouble() ?? 0.0,
      sentimentLabel: (row['sentiment_label'] as String?) ?? 'neutral',
      isBookmarked: (row['is_bookmarked'] as int?) == 1,
      cachedAt: (row['cached_at'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(row['cached_at'] as int)
          : now,
      userId: (row['user_id'] as String?) ?? '',
    );
  }

  /// Converts the model to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'url': url,
      'source': source,
      'published_at': publishedAt.toIso8601String(),
      'keywords': keywords,
      'image_url': imageUrl,
      'sentiment_score': sentimentScore,
      'sentiment_label': sentimentLabel,
      'is_bookmarked': isBookmarked,
      'cached_at': cachedAt.toIso8601String(),
      'user_id': userId,
    };
  }

  /// Converts the model to database row format
  Map<String, dynamic> toDatabaseRow() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'content': content,
      'url': url,
      'source': source,
      'published_at': publishedAt.millisecondsSinceEpoch,
      'keywords': jsonEncode(keywords),
      'image_url': imageUrl,
      'sentiment_score': sentimentScore,
      'sentiment_label': sentimentLabel,
      'is_bookmarked': isBookmarked ? 1 : 0,
      'cached_at': cachedAt.millisecondsSinceEpoch,
      'user_id': userId,
    };
  }

  /// Creates a NewsModel from a NewsEntity
  factory NewsModel.fromEntity(NewsEntity entity) {
    return NewsModel(
      id: entity.id,
      title: entity.title,
      summary: entity.summary,
      content: entity.content,
      url: entity.url,
      source: entity.source,
      publishedAt: entity.publishedAt,
      keywords: entity.keywords,
      imageUrl: entity.imageUrl,
      sentimentScore: entity.sentimentScore,
      sentimentLabel: entity.sentimentLabel,
      isBookmarked: entity.isBookmarked,
      cachedAt: entity.cachedAt,
      userId: entity.userId,
    );
  }

  /// Converts the model to a domain entity
  NewsEntity toEntity() {
    return NewsEntity(
      id: id,
      title: title,
      summary: summary,
      content: content,
      url: url,
      source: source,
      publishedAt: publishedAt,
      keywords: keywords,
      imageUrl: imageUrl,
      sentimentScore: sentimentScore,
      sentimentLabel: sentimentLabel,
      isBookmarked: isBookmarked,
      cachedAt: cachedAt,
      userId: userId,
    );
  }

  /// Helper method to parse keywords from various formats
  static List<String> _parseKeywords(dynamic keywords) {
    if (keywords == null) return [];
    
    if (keywords is List) {
      return keywords.map((e) => e.toString()).toList();
    }
    
    if (keywords is String) {
      if (keywords.isEmpty) return [];
      
      // Handle comma-separated keywords
      return keywords
          .split(',')
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty)
          .toList();
    }
    
    return [];
  }

  /// Safe parsing of keywords from database with proper null handling
  static List<String> _safeParseKeywordsFromDatabase(dynamic keywordsData) {
    try {
      if (keywordsData == null) return [];
      
      final keywordsString = keywordsData as String?;
      if (keywordsString == null || keywordsString.isEmpty) return [];
      
      final decoded = jsonDecode(keywordsString);
      if (decoded is List) {
        return decoded
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      
      return [];
    } catch (e) {
      // Return empty list on any parsing error
      return [];
    }
  }

  /// Creates a copy with updated properties
  @override
  NewsModel copyWith({
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
    return NewsModel(
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

  /// Test factory for creating mock data
  factory NewsModel.test({
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
    final now = DateTime.now();
    return NewsModel(
      id: id ?? 'test-news-id',
      title: title ?? 'Test News Article',
      summary: summary ?? 'Test news summary for testing purposes',
      content: content ?? 'Full test content of the news article...',
      url: url ?? 'https://example.com/test-article',
      source: source ?? 'Test Source',
      publishedAt: publishedAt ?? now.subtract(const Duration(hours: 2)),
      keywords: keywords ?? ['test', 'finance', 'news'],
      imageUrl: imageUrl,
      sentimentScore: sentimentScore ?? 0.5,
      sentimentLabel: sentimentLabel ?? 'positive',
      isBookmarked: isBookmarked ?? false,
      cachedAt: cachedAt ?? now,
      userId: userId ?? 'test-user-id',
    );
  }
}