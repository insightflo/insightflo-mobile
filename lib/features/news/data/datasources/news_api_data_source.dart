import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/utils/logger.dart';
import 'package:insightflo_app/features/news/data/models/news_article_model.dart';

/// API-based news remote data source for communication with insightflo-api
abstract class NewsApiDataSource {
  Future<List<NewsArticleModel>> getNewsFromApi({int page = 1, int limit = 20});
}

/// Implementation of NewsApiDataSource using HTTP client to communicate with API server
class NewsApiDataSourceImpl implements NewsApiDataSource {
  final http.Client httpClient;
  final SupabaseClient supabaseClient;
  final String apiBaseUrl;

  NewsApiDataSourceImpl({
    required this.httpClient,
    required this.supabaseClient,
    this.apiBaseUrl = 'http://localhost:3000', // API 서버 주소
  });

  @override
  Future<List<NewsArticleModel>> getNewsFromApi({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Supabase에서 현재 사용자의 액세스 토큰 가져오기
      final session = supabaseClient.auth.currentSession;
      String? accessToken;

      if (session != null) {
        accessToken = session.accessToken;
      } else {
        // 익명 사용자인 경우 Supabase 익명 토큰 사용
        AppLogger.info('No active session, using anonymous access');
      }

      // API 호출을 위한 URL 구성
      final uri = Uri.parse('$apiBaseUrl/api/news').replace(
        queryParameters: {'page': page.toString(), 'limit': limit.toString()},
      );

      // HTTP 헤더 설정
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // 액세스 토큰이 있으면 Authorization 헤더 추가
      if (accessToken != null) {
        headers['Authorization'] = 'Bearer $accessToken';
      }

      AppLogger.debug('Making API request to: $uri');
      AppLogger.debug('Headers: $headers');

      // API 호출
      final response = await httpClient
          .get(uri, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('API request timeout');
            },
          );

      AppLogger.debug('API Response status: ${response.statusCode}');
      AppLogger.debug('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;

        if (jsonData['success'] == true && jsonData.containsKey('articles')) {
          final articlesJson = jsonData['articles'] as List;

          // API 응답을 NewsArticleModel로 변환
          return articlesJson.map((articleJson) {
            // API 응답 형식을 Flutter 모델에 맞게 조정
            final modelJson = <String, dynamic>{
              'id': articleJson['id'],
              'title': articleJson['title'],
              'summary': articleJson['summary'],
              'content': articleJson['content'],
              'url': articleJson['url'],
              'source': articleJson['source'],
              'published_at': articleJson['published_at'],
              'keywords': articleJson['keywords'] ?? '',
              'image_url': articleJson['image_url'],
              'sentiment_score':
                  articleJson['sentiment_score']?.toDouble() ?? 0.0,
              'sentiment_label': articleJson['sentiment_label'] ?? 'neutral',
              'is_bookmarked': articleJson['is_bookmarked'] ?? false,
            };

            return NewsArticleModel.fromJson(modelJson);
          }).toList();
        } else {
          throw ServerException(
            message: 'Invalid API response format',
            statusCode: response.statusCode,
          );
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw ServerException(
          message:
              'API request failed: ${errorData['message'] ?? 'Unknown error'}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ServerException) {
        rethrow;
      }
      throw ServerException(
        message: 'Failed to get news from API: $e',
        statusCode: 500,
      );
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
