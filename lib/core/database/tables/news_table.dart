import 'package:drift/drift.dart';

/// Drift table definition for news articles with performance-optimized indexes
@DataClassName('NewsTableData')
class NewsTable extends Table {
  /// Unique identifier for the news article
  TextColumn get id => text()();
  
  /// Article title
  TextColumn get title => text().withLength(min: 1, max: 500)();
  
  /// Brief summary of the article
  TextColumn get summary => text().withLength(min: 1, max: 1000)();
  
  /// Full article content
  TextColumn get content => text()();
  
  /// Original article URL
  TextColumn get url => text().withLength(min: 1, max: 2000)();
  
  /// News source/publisher
  TextColumn get source => text().withLength(min: 1, max: 200)();
  
  /// Article publication timestamp (stored as milliseconds since epoch)
  IntColumn get publishedAt => integer().named('published_at')();
  
  /// Relevant keywords for categorization (stored as JSON string)
  TextColumn get keywords => text().withDefault(const Constant('[]'))();
  
  /// Article image URL (optional)
  TextColumn get imageUrl => text().named('image_url').nullable()();
  
  /// AI-computed sentiment score (-1.0 to 1.0)
  RealColumn get sentimentScore => real().named('sentiment_score').withDefault(const Constant(0.0))();
  
  /// Human-readable sentiment label
  TextColumn get sentimentLabel => text().named('sentiment_label').withDefault(const Constant('neutral'))();
  
  /// Whether the article is bookmarked by the user (stored as integer: 0 = false, 1 = true)
  IntColumn get isBookmarked => integer().named('is_bookmarked').withDefault(const Constant(0))();
  
  /// Timestamp when the article was cached locally (stored as milliseconds since epoch)
  IntColumn get cachedAt => integer().named('cached_at')();
  
  /// User ID associated with this cached article
  TextColumn get userId => text().named('user_id')();

  @override
  Set<Column> get primaryKey => {id};

  // Note: Indexes will be created manually in database initialization
  // to avoid Drift parsing issues with complex index syntax

  @override
  String get tableName => 'news_articles';
}

/// Custom Drift index definitions for performance optimization
class NewsTableIndexes {
  /// Index for finding fresh articles (general purpose index)
  static const String freshArticlesIndex = '''
    CREATE INDEX IF NOT EXISTS idx_news_fresh_articles 
    ON news_articles (user_id, cached_at, published_at)
  ''';
  
  /// Index for full-text search on title and summary
  static const String searchIndex = '''
    CREATE INDEX IF NOT EXISTS idx_news_search 
    ON news_articles (title, summary)
  ''';
  
  /// Partial index for positive sentiment articles only
  static const String positiveSentimentIndex = '''
    CREATE INDEX IF NOT EXISTS idx_news_positive_sentiment 
    ON news_articles (user_id, published_at) 
    WHERE sentiment_score > 0.1
  ''';
  
  /// Partial index for negative sentiment articles only
  static const String negativeSentimentIndex = '''
    CREATE INDEX IF NOT EXISTS idx_news_negative_sentiment 
    ON news_articles (user_id, published_at) 
    WHERE sentiment_score < -0.1
  ''';
}