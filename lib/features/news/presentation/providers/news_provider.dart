import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:insightflo_app/core/utils/logger.dart';
import 'package:insightflo_app/features/news/domain/entities/news_entity.dart';
import 'package:insightflo_app/features/news/data/models/news_model.dart';
import 'package:insightflo_app/features/news/data/datasources/news_local_data_source.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/features/keywords/presentation/providers/keyword_provider.dart';
import 'package:insightflo_app/features/keywords/domain/entities/keyword_entity.dart';
import 'package:insightflo_app/features/news/domain/entities/user_keyword.dart';
import 'package:insightflo_app/features/news/domain/usecases/get_personalized_news.dart';
import 'package:insightflo_app/features/news/domain/usecases/search_news.dart';
import 'package:insightflo_app/features/news/domain/usecases/bookmark_article.dart';
import 'package:insightflo_app/core/services/api_auth_service.dart';

/// State management for news features using Provider with integrated Drift Database and Vercel API
class NewsProvider extends ChangeNotifier {
  final GetPersonalizedNews getPersonalizedNews;
  final SearchNews searchNews;
  final BookmarkArticle bookmarkArticle;
  final NewsLocalDataSource localDataSource;
  final AuthProvider authProvider;
  final KeywordProvider keywordProvider;
  final ApiAuthService authService;

  NewsProvider({
    required this.getPersonalizedNews,
    required this.searchNews,
    required this.bookmarkArticle,
    required this.localDataSource,
    required this.authProvider,
    required this.keywordProvider,
    required this.authService,
  });

  // State variables - Updated to use new NewsEntity
  List<NewsEntity> _articles = [];
  List<NewsEntity> _bookmarkedArticles = [];
  final List<UserKeyword> _userKeywords = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreData = true;
  String _searchQuery = '';
  bool _isOfflineMode = false;

  // Getters
  List<NewsEntity> get articles => _articles;
  List<NewsEntity> get bookmarkedArticles => _bookmarkedArticles;
  List<UserKeyword> get userKeywords => _userKeywords;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMoreData => _hasMoreData;
  String get searchQuery => _searchQuery;
  bool get isOfflineMode => _isOfflineMode;

  /// Get personalized news using integrated Vercel API + Drift Database caching
  Future<void> getPersonalizedNewsForUser(
    String userId, {
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _articles.clear();
    }

    if (_isLoading || _isLoadingMore || !_hasMoreData) return;

    _setLoading(refresh ? true : false, refresh ? false : true);

    try {
      // First, try to load from local cache for immediate UI response
      if (!refresh && _articles.isEmpty) {
        await _loadFromLocalCache(userId);
      }

      // Then fetch fresh data from Vercel API and cache it
      await _fetchAndCachePersonalizedNews(userId, refresh);
    } catch (e, stackTrace) {
      _setError('Failed to load news: ${e.toString()}');
    }

    _setLoading(false, false);
  }

  /// Load cached articles from Drift Database for immediate display
  Future<void> _loadFromLocalCache(String userId) async {
    try {
      final cachedArticles = await localDataSource.getFreshNews(
        userId: userId,
        limit: 20,
      );

      if (cachedArticles != null && cachedArticles.isNotEmpty) {
        // Additional null safety check before casting
        final safeArticles = cachedArticles
            .where((article) => article != null)
            .cast<NewsEntity>()
            .toList();

        if (safeArticles.isNotEmpty) {
          _articles = safeArticles;
          _isOfflineMode = true;
          notifyListeners();
        }
      }
    } catch (e, stackTrace) {
      // Silent fail - cache loading is best effort
      // Safe error logging to prevent type cast issues
      AppLogger.warning('Cache loading failed: ${e.toString()}');
    }
  }

  /// Fetch personalized news from Vercel API and cache in Drift Database
  Future<void> _fetchAndCachePersonalizedNews(
    String userId,
    bool refresh,
  ) async {
    try {
      // Get local keywords for personalization
      final keywords = await _getLocalKeywords();
      final keywordParams = keywords.map((k) => k.keyword).join(',');
      final weightParams = keywords.map((k) => k.weight.toString()).join(',');

      // Build URL with keyword parameters for personalized news
      final queryParams = <String, String>{
        'page': _currentPage.toString(),
        'limit': '20',
      };
      
      // Add keywords for personalization if available
      if (keywordParams.isNotEmpty) {
        queryParams['keywords'] = keywordParams;
        queryParams['weights'] = weightParams;
      }

      final uri = Uri.parse('http://127.0.0.1:3000/api/keywords').replace(
        queryParameters: queryParams,
      );
      
      AppLogger.info('Fetching personalized news with keywords: $keywordParams');

      // Call news API endpoint without authentication (guest-first)
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Handle new API response structure: {success: true, data: {articles: [...], total: n}}
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];
          final List<dynamic> articlesJson = data['articles'] ?? [];
          
          AppLogger.info('Received ${articlesJson.length} articles from personalized news API');

          // API가 빈 목록을 반환하면 더 이상 데이터가 없는 것으로 간주합니다.
          if (articlesJson.isEmpty) {
            _hasMoreData = false;
            _setLoading(false, false);
            return;
          }

          // Convert API response to NewsModel objects
          final newsModels = articlesJson.map((articleJson) {
            // Ensure all required fields are present with proper structure
            final processedJson = _processVercelApiResponse(articleJson, userId);
            return NewsModel.fromJson(processedJson);
          }).toList();

          // Cache all articles in Drift Database
          await localDataSource.batchCacheNewsArticles(newsModels);

          // Update UI state with null safety
          final safeNewsModels = newsModels
              .where((model) => model != null)
              .cast<NewsEntity>()
              .toList();

          if (refresh) {
            _articles = safeNewsModels;
          } else {
            // 중복 기사를 방지하기 위해 이미 목록에 없는 기사만 추가합니다.
            final existingIds = _articles.map((a) => a.id).toSet();
            final newArticles = safeNewsModels.where(
              (a) => !existingIds.contains(a.id),
            );
            _articles.addAll(newArticles);
          }

          _isOfflineMode = false;
          _currentPage++;
          _clearError();
        } else {
          // API response format error
          throw Exception('Invalid API response format: ${jsonData.toString()}');
        }
      } else {
        throw Exception('API call failed with status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e, stackTrace) {
      // Log the actual error for debugging
      AppLogger.error('API call failed: ${e.toString()}');
      print('DEBUG: API Error Details: ${e.toString()}');

      // If API fails, try to load from cache
      if (_articles.isEmpty) {
        final cachedArticles = await localDataSource.getPersonalizedNews(
          userId: userId,
          limit: 20,
          offset: (_currentPage - 1) * 20,
        );

        if (cachedArticles != null && cachedArticles.isNotEmpty) {
          final safeArticles = cachedArticles
              .where((article) => article != null)
              .cast<NewsEntity>()
              .toList();

          if (safeArticles.isNotEmpty) {
            _articles = safeArticles;
            _isOfflineMode = true;
          } else {
            _hasMoreData = false;
          }
        } else {
          _hasMoreData = false;
        }
      }

      _setError('Network error: $e. Showing cached content.');
    }
  }

  /// Process Vercel API response to ensure compatibility with NewsModel
  Map<String, dynamic> _processVercelApiResponse(
    Map<String, dynamic> apiJson,
    String userId,
  ) {
    final now = DateTime.now();

    return {
      'id': apiJson['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': apiJson['title'] ?? 'No Title',
      'summary': apiJson['summary'] ?? apiJson['description'] ?? 'No Summary',
      'content': apiJson['content'] ?? apiJson['body'] ?? '',
      'url': apiJson['url'] ?? '',
      'source': apiJson['source'] ?? 'Unknown',
      'published_at':
          apiJson['published_at'] ??
          apiJson['publishedAt'] ??
          now.toIso8601String(),
      'keywords': _processKeywords(apiJson['keywords']),
      'image_url': apiJson['image_url'] ?? apiJson['imageUrl'],
      'sentiment_score': (apiJson['sentiment_score'] ?? 0.0).toDouble(),
      'sentiment_label': apiJson['sentiment_label'] ?? 'neutral',
      'is_bookmarked': false,
      'cached_at': now.toIso8601String(),
      'user_id': userId,
    };
  }

  /// Helper method to process keywords from API response
  List<String> _processKeywords(dynamic keywords) {
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

  /// Search news articles using local Drift Database cache
  Future<void> searchNewsArticles(String query, {bool refresh = false}) async {
    if (query.trim().isEmpty) {
      _searchQuery = '';
      _articles.clear();
      notifyListeners();
      return;
    }

    _searchQuery = query;

    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _articles.clear();
    }

    if (_isLoading || _isLoadingMore || !_hasMoreData) return;

    _setLoading(refresh ? true : false, refresh ? false : true);

    try {
      final userId = authProvider.currentUser?.id ?? '';

      // Search in local Drift Database cache
      final searchResults = await localDataSource.searchNews(
        userId: userId,
        query: query,
        limit: 20,
      );

      if (searchResults == null || searchResults.isEmpty) {
        _hasMoreData = false;
      } else {
        final safeSearchResults = searchResults
            .where((result) => result != null)
            .cast<NewsEntity>()
            .toList();

        if (safeSearchResults.isEmpty) {
          _hasMoreData = false;
        } else {
          if (refresh) {
            _articles = safeSearchResults;
          } else {
            _articles.addAll(safeSearchResults);
          }
          _currentPage++;
        }
      }
      _clearError();
    } catch (e, stackTrace) {
      _setError('Search failed: ${e.toString()}');
    }

    _setLoading(false, false);
  }

  /// Bookmark an article using local Drift Database
  Future<bool> bookmarkNewsArticle(String userId, String articleId) async {
    try {
      // Update bookmark status in local Drift Database
      final success = await localDataSource.updateBookmarkStatus(
        articleId: articleId,
        userId: userId,
        isBookmarked: true,
      );

      if (success) {
        // Update the article's bookmark status in the UI list
        _updateArticleBookmarkStatus(articleId, true);
        return true;
      } else {
        _setError('Failed to bookmark article');
        return false;
      }
    } catch (e, stackTrace) {
      _setError('Failed to bookmark article: ${e.toString()}');
      return false;
    }
  }

  /// Remove bookmark from an article using local Drift Database
  Future<bool> removeBookmarkFromArticle(
    String userId,
    String articleId,
  ) async {
    try {
      // Update bookmark status in local Drift Database
      final success = await localDataSource.updateBookmarkStatus(
        articleId: articleId,
        userId: userId,
        isBookmarked: false,
      );

      if (success) {
        // Update the article's bookmark status in the UI list
        _updateArticleBookmarkStatus(articleId, false);
        return true;
      } else {
        _setError('Failed to remove bookmark');
        return false;
      }
    } catch (e, stackTrace) {
      _setError('Failed to remove bookmark: ${e.toString()}');
      return false;
    }
  }

  /// Load bookmarked articles from local Drift Database
  Future<void> loadBookmarkedArticles(String userId) async {
    try {
      _setLoading(true, false);

      final bookmarkedArticles = await localDataSource.getBookmarkedNews(
        userId: userId,
        limit: 100, // Load more bookmarks as they're typically fewer
      );

      final safeBookmarkedArticles = bookmarkedArticles
          .where((article) => article != null)
          .cast<NewsEntity>()
          .toList();
      _bookmarkedArticles = safeBookmarkedArticles;
      _clearError();
    } catch (e, stackTrace) {
      _setError('Failed to load bookmarked articles: ${e.toString()}');
    } finally {
      _setLoading(false, false);
    }
  }

  /// Clear all data (useful for logout)
  void clearData() {
    _articles.clear();
    _bookmarkedArticles.clear();
    _userKeywords.clear();
    _currentPage = 1;
    _hasMoreData = true;
    _searchQuery = '';
    _clearError();
    notifyListeners();
  }

  /// Refresh news data
  Future<void> refreshNews(String userId) async {
    if (_searchQuery.isNotEmpty) {
      await searchNewsArticles(_searchQuery, refresh: true);
    } else {
      await getPersonalizedNewsForUser(userId, refresh: true);
    }
  }

  /// Refresh news data when keywords are changed
  Future<void> refreshNewsOnKeywordChange(String userId) async {
    AppLogger.info('NewsProvider: Refreshing news due to keyword change');
    
    // Clear search query to show personalized news with new keywords
    _searchQuery = '';
    
    // Refresh personalized news with updated keywords
    await getPersonalizedNewsForUser(userId, refresh: true);
    
    AppLogger.info('NewsProvider: News refresh completed after keyword change');
  }

  /// Load more news data
  Future<void> loadMoreNews(String userId) async {
    if (_searchQuery.isNotEmpty) {
      await searchNewsArticles(_searchQuery, refresh: false);
    } else {
      await getPersonalizedNewsForUser(userId, refresh: false);
    }
  }

  // Private helper methods
  void _setLoading(bool loading, bool loadingMore) {
    _isLoading = loading;
    _isLoadingMore = loadingMore;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  void _updateArticleBookmarkStatus(String articleId, bool isBookmarked) {
    for (int i = 0; i < _articles.length; i++) {
      if (_articles[i].id == articleId) {
        _articles[i] = NewsEntity(
          id: _articles[i].id,
          title: _articles[i].title,
          summary: _articles[i].summary,
          content: _articles[i].content,
          url: _articles[i].url,
          source: _articles[i].source,
          publishedAt: _articles[i].publishedAt,
          keywords: _articles[i].keywords,
          imageUrl: _articles[i].imageUrl,
          sentimentScore: _articles[i].sentimentScore,
          sentimentLabel: _articles[i].sentimentLabel,
          isBookmarked: isBookmarked,
          cachedAt: _articles[i].cachedAt,
          userId: _articles[i].userId,
        );
        break;
      }
    }
    notifyListeners();
  }

  /// Get local keywords for personalization
  /// Returns local keywords from KeywordProvider or empty list if none found
  Future<List<KeywordEntity>> _getLocalKeywords() async {
    try {
      // Get keywords from KeywordProvider
      final keywords = keywordProvider.keywords;
      
      AppLogger.info('Found ${keywords.length} local keywords for personalization');
      
      return keywords;
    } catch (e) {
      AppLogger.warning('Failed to get local keywords: ${e.toString()}');
      return [];
    }
  }
}
