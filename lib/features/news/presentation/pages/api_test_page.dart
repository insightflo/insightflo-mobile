import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/api_auth_service.dart';
import '../../data/models/news_article_model.dart';
import 'dart:convert';

/// 간단한 API 테스트 페이지
class ApiTestPage extends StatefulWidget {
  const ApiTestPage({Key? key}) : super(key: key);

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  late ApiAuthService authService;
  late http.Client httpClient;
  List<NewsArticleModel> articles = [];
  bool isLoading = false;
  String? error;
  String? authToken;
  String? userId;

  @override
  void initState() {
    super.initState();
    httpClient = http.Client();
    authService = ApiAuthService(httpClient: httpClient);
    _initializeAuth();
  }

  @override
  void dispose() {
    httpClient.close();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      print('Initializing authentication...');
      
      // 저장된 세션 복원 시도
      await authService.restoreSession();
      
      if (!authService.isAuthenticated) {
        // 세션이 없으면 익명 사용자로 로그인
        print('No valid session, creating anonymous user...');
        final result = await authService.signInAnonymously();
        
        if (result.success) {
          print('Anonymous login successful: ${result.userId}');
        } else {
          throw Exception(result.error ?? 'Anonymous login failed');
        }
      } else {
        print('Session restored successfully');
      }
      
      setState(() {
        authToken = authService.currentToken;
        userId = authService.currentUserId;
        isLoading = false;
      });
      
    } catch (e) {
      print('Auth initialization error: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _loadNews() async {
    if (!authService.isAuthenticated) {
      setState(() {
        error = 'Not authenticated. Please initialize authentication first.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      print('Loading news from API...');
      
      // API 호출을 위한 URL 구성
      final uri = Uri.parse('http://localhost:3000/api/news')
          .replace(queryParameters: {
        'limit': '5',
      });

      // 인증 헤더와 함께 API 호출
      final response = await httpClient.get(
        uri, 
        headers: authService.getAuthHeaders(),
      ).timeout(const Duration(seconds: 10));

      print('API Response status: ${response.statusCode}');
      print('API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        if (jsonData['success'] == true && jsonData.containsKey('articles')) {
          final articlesJson = jsonData['articles'] as List;
          
          // API 응답을 NewsArticleModel로 변환
          final newsArticles = articlesJson.map((articleJson) {
            // API 응답 형식을 Flutter 모델에 맞게 조정
            final modelJson = <String, dynamic>{
              'id': articleJson['id'],
              'title': articleJson['title'],
              'summary': articleJson['summary'],
              'content': articleJson['content'],
              'url': articleJson['url'],
              'source': articleJson['source'],
              'published_at': articleJson['published_at'],
              'keywords': articleJson['keywords'] ?? [],
              'image_url': articleJson['image_url'],
              'sentiment_score': articleJson['sentiment_score']?.toDouble() ?? 0.0,
              'sentiment_label': articleJson['sentiment_label'] ?? 'neutral',
              'is_bookmarked': articleJson['is_bookmarked'] ?? false,
            };
            
            return NewsArticleModel.fromJson(modelJson);
          }).toList();
          
          setState(() {
            articles = newsArticles;
            isLoading = false;
          });
          
          print('Successfully loaded ${newsArticles.length} articles');
        } else {
          throw Exception('Invalid API response format');
        }
      } else {
        final errorData = json.decode(response.body) as Map<String, dynamic>;
        throw Exception('API request failed: ${errorData['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('Error loading news: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Test'),
        actions: [
          IconButton(
            onPressed: _loadNews,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // 상태 정보 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'API Server: http://localhost:3000',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Authentication: ${authService.isAuthenticated ? "✅ Authenticated" : "❌ Not authenticated"}'),
                if (userId != null) Text('User ID: $userId'),
                if (authToken != null) Text('Token: ${authToken!.substring(0, 20)}...'),
                Text('Articles loaded: ${articles.length}'),
                if (error != null)
                  Text(
                    'Error: $error',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          
          // 로딩 또는 뉴스 목록 표시
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : articles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.article, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text('No articles loaded'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadNews,
                              child: const Text('Load News from API'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: articles.length,
                        itemBuilder: (context, index) {
                          final article = articles[index];
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: ListTile(
                              title: Text(
                                article.title,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.summary,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.source, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        article.source,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.sentiment_satisfied, size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${article.sentimentLabel ?? 'neutral'} (${(article.sentimentScore ?? 0.0).toStringAsFixed(1)})',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: article.isBookmarked
                                  ? const Icon(Icons.bookmark, color: Colors.blue)
                                  : const Icon(Icons.bookmark_border),
                              onTap: () {
                                // 상세 페이지로 이동하거나 URL 열기
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(article.title),
                                    content: Text(article.content),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}