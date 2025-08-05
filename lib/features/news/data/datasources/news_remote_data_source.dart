import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:insightflo_app/core/errors/exceptions.dart';
import '../models/news_article_model.dart';
import '../models/user_keyword_model.dart';

/// Abstract class for news remote data source
abstract class NewsRemoteDataSource {
  Future<List<NewsArticleModel>> getPersonalizedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  Future<List<NewsArticleModel>> getAllNews({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    List<String>? keywords,
  });

  Future<NewsArticleModel> getNewsArticleById(String articleId);

  Future<List<NewsArticleModel>> searchNews({
    required String query,
    int page = 1,
    int limit = 20,
  });

  Future<List<NewsArticleModel>> getBookmarkedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  });

  Future<void> bookmarkArticle({
    required String userId,
    required String articleId,
  });

  Future<void> removeBookmark({
    required String userId,
    required String articleId,
  });

  Future<List<UserKeywordModel>> getUserKeywords(String userId);

  Future<UserKeywordModel> addUserKeyword({
    required String userId,
    required String keyword,
    double? weight,
  });

  Future<void> removeUserKeyword({
    required String userId,
    required String keywordId,
  });
}

/// Implementation of NewsRemoteDataSource using API-First architecture
class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  static const String _baseUrl = 'http://localhost:3000';

  NewsRemoteDataSourceImpl();

  @override
  Future<List<NewsArticleModel>> getPersonalizedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // API를 통한 개인화 뉴스 조회
      final response = await http.get(
        Uri.parse('$_baseUrl/api/news/personalized?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> articlesJson = responseData['articles'] ?? [];
        
        return articlesJson.map((articleJson) {
          return NewsArticleModel.fromJson(_processApiResponse(articleJson, userId));
        }).toList();
      } else {
        throw ServerException(
          message: 'Failed to fetch personalized news',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error fetching personalized news: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

@override
  Future<List<NewsArticleModel>> getAllNews({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    List<String>? keywords,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/news?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> articlesJson = responseData['articles'] ?? [];
        
        return articlesJson.map((articleJson) {
          return NewsArticleModel.fromJson(_processApiResponse(articleJson, 'anonymous'));
        }).toList();
      } else {
        throw ServerException(
          message: 'Failed to fetch all news',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error fetching all news: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

@override
  Future<NewsArticleModel> getNewsArticleById(String articleId) async {
    // TODO: API에서 개별 기사 조회 구현 필요
    throw UnimplementedError('Get news article by ID not yet implemented for API-First architecture');
  }

@override
  Future<List<NewsArticleModel>> searchNews({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // 기본 뉴스를 조회하여 클라이언트 사이드에서 검색 (서버 사이드 검색은 추후 구현)
      final response = await http.get(
        Uri.parse('$_baseUrl/api/news?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> articlesJson = responseData['articles'] ?? [];
        
        // 간단한 클라이언트 사이드 필터링 (임시)
        final filteredArticles = articlesJson.where((article) {
          final title = article['title']?.toString().toLowerCase() ?? '';
          final summary = article['summary']?.toString().toLowerCase() ?? '';
          final searchLower = query.toLowerCase();
          return title.contains(searchLower) || summary.contains(searchLower);
        }).toList();
        
        return filteredArticles.map((articleJson) {
          return NewsArticleModel.fromJson(_processApiResponse(articleJson, 'anonymous'));
        }).toList();
      } else {
        throw ServerException(
          message: 'Failed to search news',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      throw ServerException(
        message: 'Error searching news: ${e.toString()}',
        statusCode: 500,
      );
    }
  }

@override
  Future<List<NewsArticleModel>> getBookmarkedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    // TODO: API에서 북마크된 뉴스 조회 구현 필요
    return [];
  }

@override
  Future<void> bookmarkArticle({
    required String userId,
    required String articleId,
  }) async {
    // TODO: API를 통한 북마크 추가 구현 필요
    // 현재는 로컬에서만 처리
  }

@override
  Future<void> removeBookmark({
    required String userId,
    required String articleId,
  }) async {
    // TODO: API를 통한 북마크 제거 구현 필요
    // 현재는 로컬에서만 처리
  }

@override
  Future<List<UserKeywordModel>> getUserKeywords(String userId) async {
    // TODO: API를 통한 사용자 키워드 조회 구현 필요
    return [];
  }

@override
  Future<UserKeywordModel> addUserKeyword({
    required String userId,
    required String keyword,
    double? weight,
  }) async {
    // TODO: API를 통한 키워드 추가 구현 필요
    throw UnimplementedError('Add user keyword not yet implemented for API-First architecture');
  }


@override
  Future<void> removeUserKeyword({
    required String userId,
    required String keywordId,
  }) async {
    // TODO: API를 통한 키워드 제거 구현 필요
    throw UnimplementedError('Remove user keyword not yet implemented for API-First architecture');
  }

  /// API 응답을 NewsArticleModel과 호환되도록 변환
  Map<String, dynamic> _processApiResponse(Map<String, dynamic> apiJson, String userId) {
    final now = DateTime.now();
    
    return {
      'id': apiJson['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': apiJson['title'] ?? 'No Title',
      'summary': apiJson['summary'] ?? apiJson['description'] ?? 'No Summary',
      'content': apiJson['content'] ?? apiJson['body'] ?? '',
      'url': apiJson['url'] ?? '',
      'source': apiJson['source'] ?? 'Unknown',
      'published_at': apiJson['published_at'] ?? apiJson['publishedAt'] ?? now.toIso8601String(),
      'keywords': (apiJson['keywords'] is List) 
        ? apiJson['keywords'] 
        : (apiJson['keywords'] is String) 
          ? apiJson['keywords'].split(',')
          : [],
      'image_url': apiJson['image_url'] ?? apiJson['imageUrl'],
      'sentiment_score': (apiJson['sentiment_score'] ?? 0.0).toDouble(),
      'sentiment_label': apiJson['sentiment_label'] ?? 'neutral',
      'is_bookmarked': false,
      'cached_at': now.toIso8601String(),
      'user_id': userId,
    };
  }
}