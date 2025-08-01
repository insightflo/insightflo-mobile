import 'package:drift/drift.dart';
import '../models/news_model.dart';
import '../../../../core/database/database.dart';

/// Abstract interface for local news data operations
abstract class NewsLocalDataSource {
  /// Gets personalized news for a user from local cache
  Future<List<NewsModel>> getPersonalizedNews({
    required String userId,
    int limit = 20,
    int offset = 0,
  });

  /// Gets fresh news articles (cached within 24 hours)
  Future<List<NewsModel>> getFreshNews({
    required String userId,
    int limit = 20,
  });

  /// Searches cached news articles
  Future<List<NewsModel>> searchNews({
    required String userId,
    required String query,
    int limit = 20,
  });

  /// Gets bookmarked articles for a user
  Future<List<NewsModel>> getBookmarkedNews({
    required String userId,
    int limit = 20,
  });

  /// Gets articles by sentiment range
  Future<List<NewsModel>> getNewsBySentiment({
    required String userId,
    required double minSentiment,
    required double maxSentiment,
    int limit = 20,
  });

  /// Caches a single news article
  Future<void> cacheNewsArticle(NewsModel article);

  /// Batch caches multiple news articles
  Future<void> batchCacheNewsArticles(List<NewsModel> articles);

  /// Updates bookmark status for an article
  Future<bool> updateBookmarkStatus({
    required String articleId,
    required String userId,
    required bool isBookmarked,
  });

  /// Cleans up old cached articles
  Future<int> cleanupOldArticles({
    required String userId,
    int keepCount = 1000,
  });

  /// Gets database statistics
  Future<Map<String, int>> getDatabaseStats({required String userId});

  /// Checks if an article exists in cache
  Future<bool> hasArticle({
    required String articleId,
    required String userId,
  });

  // Advanced queries for performance optimization

  /// Gets news articles within a specific date range
  Future<List<NewsModel>> getNewsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 20,
  });

  /// Gets top news articles by sentiment label with highest scores
  Future<List<NewsModel>> getTopNewsBySentiment({
    required String userId,
    required String sentimentLabel,
    int limit = 20,
  });

  /// Gets comprehensive statistics by news source
  Future<List<Map<String, dynamic>>> getSourceStatistics({
    required String userId,
    int limit = 50,
  });

  // Batch operations for high-performance data manipulation

  /// Batch updates sentiment scores for multiple articles
  Future<int> batchUpdateSentiment({
    required String userId,
    required Map<String, double> sentimentUpdates,
  });

  /// Performs database optimization including VACUUM and index maintenance
  Future<Map<String, dynamic>> optimizeDatabase();
}

/// Implementation of NewsLocalDataSource using Drift database
class NewsLocalDataSourceImpl implements NewsLocalDataSource {
  final AppDatabase database;

  const NewsLocalDataSourceImpl({required this.database});

  @override
  Future<List<NewsModel>> getPersonalizedNews({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await database.getPersonalizedNews(
      userId: userId,
      limit: limit,
      offset: offset,
    );
    
    return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
  }

  @override
  Future<List<NewsModel>> getFreshNews({
    required String userId,
    int limit = 20,
  }) async {
    final data = await database.getFreshNews(
      userId: userId,
      limit: limit,
    );
    
    return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
  }

  @override
  Future<List<NewsModel>> searchNews({
    required String userId,
    required String query,
    int limit = 20,
  }) async {
    final data = await database.searchNews(
      userId: userId,
      query: query,
      limit: limit,
    );
    
    return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
  }

  @override
  Future<List<NewsModel>> getBookmarkedNews({
    required String userId,
    int limit = 20,
  }) async {
    final data = await database.getBookmarkedNews(
      userId: userId,
      limit: limit,
    );
    
    return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
  }

  @override
  Future<List<NewsModel>> getNewsBySentiment({
    required String userId,
    required double minSentiment,
    required double maxSentiment,
    int limit = 20,
  }) async {
    final data = await database.getNewsBySentiment(
      userId: userId,
      minSentiment: minSentiment,
      maxSentiment: maxSentiment,
      limit: limit,
    );
    
    return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
  }

  @override
  Future<void> cacheNewsArticle(NewsModel article) async {
    try {
      final companion = _newsModelToCompanion(article);
      await database.insertOrUpdateNews(companion);
    } catch (e) {
      print('Error caching news article: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  @override
  Future<void> batchCacheNewsArticles(List<NewsModel> articles) async {
    if (articles.isEmpty) return;
    
    try {
      final companions = articles.map(_newsModelToCompanion).toList();
      await database.batchInsertNews(companions);
    } catch (e) {
      print('Error batch caching articles: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  @override
  Future<bool> updateBookmarkStatus({
    required String articleId,
    required String userId,
    required bool isBookmarked,
  }) async {
    try {
      return await database.updateBookmarkStatus(
        articleId: articleId,
        userId: userId,
        isBookmarked: isBookmarked,
      );
    } catch (e) {
      print('Error updating bookmark status: $e');
      return false;
    }
  }

  @override
  Future<int> cleanupOldArticles({
    required String userId,
    int keepCount = 1000,
  }) async {
    try {
      return await database.cleanupOldArticles(
        userId: userId,
        keepCount: keepCount,
        retentionDays: 7, // Use enhanced 7-day retention policy
      );
    } catch (e) {
      print('Error cleaning up old articles: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, int>> getDatabaseStats({required String userId}) async {
    try {
      return await database.getDatabaseStats(userId: userId);
    } catch (e) {
      print('Error getting database stats: $e');
      return {
        'total': 0,
        'bookmarked': 0,
        'fresh': 0,
      };
    }
  }

  @override
  Future<bool> hasArticle({
    required String articleId,
    required String userId,
  }) async {
    try {
      final result = await (database.select(database.newsTable)
            ..where((tbl) => 
                tbl.id.equals(articleId) & 
                tbl.userId.equals(userId))
            ..limit(1))
          .get();
      
      return result.isNotEmpty;
    } catch (e) {
      // Log error and return false to prevent app crashes
      print('Error checking article existence: $e');
      return false;
    }
  }

  // Advanced queries implementation

  @override
  Future<List<NewsModel>> getNewsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 20,
  }) async {
    try {
      final data = await database.getNewsByDateRange(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
      
      return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
    } catch (e) {
      print('Error getting news by date range: $e');
      return [];
    }
  }

  @override
  Future<List<NewsModel>> getTopNewsBySentiment({
    required String userId,
    required String sentimentLabel,
    int limit = 20,
  }) async {
    try {
      final data = await database.getTopNewsBySentiment(
        userId: userId,
        sentimentLabel: sentimentLabel,
        limit: limit,
      );
      
      return data.map((row) => NewsModel.fromDatabaseRow(row.toJson())).toList();
    } catch (e) {
      print('Error getting top news by sentiment: $e');
      return [];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getSourceStatistics({
    required String userId,
    int limit = 50,
  }) async {
    try {
      return await database.getSourceStatistics(
        userId: userId,
        limit: limit,
      );
    } catch (e) {
      print('Error getting source statistics: $e');
      return [];
    }
  }

  // Batch operations implementation

  @override
  Future<int> batchUpdateSentiment({
    required String userId,
    required Map<String, double> sentimentUpdates,
  }) async {
    if (sentimentUpdates.isEmpty) return 0;
    
    try {
      return await database.batchUpdateSentiment(
        userId: userId,
        sentimentUpdates: sentimentUpdates,
      );
    } catch (e) {
      print('Error in batch sentiment update: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> optimizeDatabase() async {
    try {
      return await database.optimizeDatabase();
    } catch (e) {
      print('Error optimizing database: $e');
      return {
        'success': false,
        'error': e.toString(),
        'durationMs': 0,
      };
    }
  }

  /// Converts NewsModel to Drift Companion for database operations
  NewsTableCompanion _newsModelToCompanion(NewsModel model) {
    return NewsTableCompanion.insert(
      id: model.id,
      title: model.title,
      summary: model.summary,
      content: model.content,
      url: model.url,
      source: model.source,
      publishedAt: model.publishedAt.millisecondsSinceEpoch,
      keywords: Value(model.toDatabaseRow()['keywords'] as String),
      imageUrl: Value(model.imageUrl),
      sentimentScore: Value(model.sentimentScore),
      sentimentLabel: Value(model.sentimentLabel),
      isBookmarked: Value(model.isBookmarked ? 1 : 0),
      cachedAt: model.cachedAt.millisecondsSinceEpoch,
      userId: model.userId,
    );
  }
}