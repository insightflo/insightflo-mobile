import 'package:insightflo_app/features/news/domain/entities/news_article.dart';

/// Data model for NewsArticle entity
class NewsArticleModel extends NewsArticle {
  const NewsArticleModel({
    required super.id,
    required super.title,
    required super.summary,
    required super.content,
    required super.url,
    required super.source,
    required super.publishedAt,
    required super.keywords,
    super.imageUrl,
    super.sentimentScore,
    super.sentimentLabel,
    super.isBookmarked,
  });

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

  /// Factory constructor from JSON
  factory NewsArticleModel.fromJson(Map<String, dynamic> json) {
    return NewsArticleModel(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      content: json['content'] as String,
      url: json['url'] as String,
      source: json['source'] as String,
      publishedAt: DateTime.parse(json['published_at'] as String),
      keywords: _parseKeywords(json['keywords']),
      imageUrl: json['image_url'] as String?,
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble(),
      sentimentLabel: json['sentiment_label'] as String?,
      isBookmarked: json['is_bookmarked'] as bool? ?? false,
    );
  }

  /// Convert to JSON
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
    };
  }

  /// Create a copy with updated fields
  NewsArticleModel copyWith({
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
  }) {
    return NewsArticleModel(
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
    );
  }

  /// Convert entity to model
  factory NewsArticleModel.fromEntity(NewsArticle article) {
    return NewsArticleModel(
      id: article.id,
      title: article.title,
      summary: article.summary,
      content: article.content,
      url: article.url,
      source: article.source,
      publishedAt: article.publishedAt,
      keywords: article.keywords,
      imageUrl: article.imageUrl,
      sentimentScore: article.sentimentScore,
      sentimentLabel: article.sentimentLabel,
      isBookmarked: article.isBookmarked,
    );
  }
}