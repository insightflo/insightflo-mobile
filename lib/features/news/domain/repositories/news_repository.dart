import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/news_article.dart';
import '../entities/user_keyword.dart';

/// Abstract repository interface for news-related operations
abstract class NewsRepository {
  /// Get personalized news articles based on user keywords
  Future<Either<Failure, List<NewsArticle>>> getPersonalizedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Get all news articles with optional filtering
  Future<Either<Failure, List<NewsArticle>>> getAllNews({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    List<String>? keywords,
  });

  /// Get a single news article by ID
  Future<Either<Failure, NewsArticle>> getNewsArticleById(String articleId);

  /// Search news articles by query
  Future<Either<Failure, List<NewsArticle>>> searchNews({
    required String query,
    int page = 1,
    int limit = 20,
  });

  /// Get user's bookmarked articles
  Future<Either<Failure, List<NewsArticle>>> getBookmarkedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  /// Add article to bookmarks
  Future<Either<Failure, void>> bookmarkArticle({
    required String userId,
    required String articleId,
  });

  /// Remove article from bookmarks
  Future<Either<Failure, void>> removeBookmark({
    required String userId,
    required String articleId,
  });

  /// Get user keywords for personalization
  Future<Either<Failure, List<UserKeyword>>> getUserKeywords(String userId);

  /// Add new user keyword
  Future<Either<Failure, UserKeyword>> addUserKeyword({
    required String userId,
    required String keyword,
    double weight = 1.0,
  });

  /// Update user keyword
  Future<Either<Failure, UserKeyword>> updateUserKeyword({
    required String keywordId,
    String? keyword,
    double? weight,
    bool? isActive,
  });

  /// Delete user keyword
  Future<Either<Failure, void>> deleteUserKeyword(String keywordId);

  /// Get trending keywords
  Future<Either<Failure, List<String>>> getTrendingKeywords({
    int limit = 10,
  });
}