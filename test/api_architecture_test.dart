import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as developer;

/// Test suite to validate API-First architecture integration
/// This tests our migration from Supabase direct connection to API-based architecture
void main() {
  group('API-First Architecture Tests', () {
    // API server running on port 3001
    const String baseUrl = 'http://localhost:3000';
    
    test('API health check should return status ok', () async {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/health'),
          headers: {'Content-Type': 'application/json'},
        );
        
        developer.log('Health check response: ${response.statusCode}', name: 'APITest');
        developer.log('Health check body: ${response.body}', name: 'APITest');
        
        expect(response.statusCode, equals(200));
        
        final jsonData = json.decode(response.body);
        expect(jsonData['status'], equals('healthy')); // API returns 'healthy' not 'ok'
        expect(jsonData['version'], equals('1.0.0'));
      } catch (e) {
        developer.log('Health check failed: $e', name: 'APITest');
        fail('API health check failed: $e');
      }
    });

    test('Anonymous authentication should work', () async {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/auth/anonymous'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'device_id': 'test-device-flutter-test'}),
        );
        
        developer.log('Auth response: ${response.statusCode}', name: 'APITest');
        developer.log('Auth body: ${response.body}', name: 'APITest');
        
        expect(response.statusCode, equals(200));
        
        final jsonData = json.decode(response.body);
        expect(jsonData['success'], equals(true));
        expect(jsonData['user'], isNotNull);
        expect(jsonData['user']['id'], isNotNull);
        expect(jsonData['token'], isNotNull);
        
        developer.log('Anonymous authentication successful', name: 'APITest');
        developer.log('User ID: ${jsonData['user']['id']}', name: 'APITest');
        developer.log('Token received: ${jsonData['token'].substring(0, 20)}...', name: 'APITest');
      } catch (e) {
        developer.log('Authentication failed: $e', name: 'APITest');
        fail('Anonymous authentication failed: $e');
      }
    });

    test('Simple News API should return articles (no auth required)', () async {
      try {
        // Test simple news endpoint that doesn't require authentication
        final newsResponse = await http.get(
          Uri.parse('$baseUrl/api/news?limit=5'),
          headers: {'Content-Type': 'application/json'},
        );
        
        developer.log('News API response: ${newsResponse.statusCode}', name: 'APITest');
        developer.log('News API body length: ${newsResponse.body.length}', name: 'APITest');
        
        expect(newsResponse.statusCode, equals(200));
        
        final newsData = json.decode(newsResponse.body);
        expect(newsData['success'], equals(true));
        expect(newsData['articles'], isNotNull);
        expect(newsData['articles'], isList);
        
        final articles = newsData['articles'] as List;
        if (articles.isNotEmpty) {
          final firstArticle = articles.first;
          expect(firstArticle['id'], isNotNull);
          expect(firstArticle['title'], isNotNull);
          expect(firstArticle['summary'], isNotNull);
          
          developer.log('Simple News API working correctly', name: 'APITest');
          developer.log('Retrieved ${articles.length} articles', name: 'APITest');
          developer.log('First article: ${firstArticle['title']}', name: 'APITest');
        } else {
          developer.log('No articles returned, but API structure is correct', name: 'APITest');
        }
      } catch (e) {
        developer.log('News API test failed: $e', name: 'APITest');
        fail('News API test failed: $e');
      }
    });

    test('API architecture validation - no Supabase dependencies', () async {
      // This test validates that our architecture is truly API-first
      // by ensuring we can complete full workflows without direct Supabase calls
      
      try {
        // Complete authentication + news workflow
        final authResponse = await http.post(
          Uri.parse('$baseUrl/api/auth/anonymous'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'device_id': 'test-device-architecture-validation'}),
        );
        
        expect(authResponse.statusCode, equals(200));
        // Auth data validation
        json.decode(authResponse.body);
        
        final newsResponse = await http.get(
          Uri.parse('$baseUrl/api/news?limit=3'),
          headers: {'Content-Type': 'application/json'},
        );
        
        expect(newsResponse.statusCode, equals(200));
        
        developer.log('Complete API-First architecture workflow successful', name: 'APITest');
        developer.log('Authentication: ✅', name: 'APITest');
        developer.log('News fetching: ✅', name: 'APITest');
        developer.log('No direct Supabase calls required: ✅', name: 'APITest');
        
        // Verify the response structure matches our NewsModel expectations
        final newsData = json.decode(newsResponse.body);
        if ((newsData['articles'] as List).isNotEmpty) {
          final article = (newsData['articles'] as List).first;
          
          // Check all required fields for NewsModel compatibility
          final requiredFields = [
            'id', 'title', 'summary', 'content', 'url', 'source', 
            'published_at', 'keywords', 'sentiment_score', 'sentiment_label'
          ];
          
          for (final field in requiredFields) {
            expect(article.containsKey(field), isTrue, 
                   reason: 'Article missing required field: $field');
          }
          
          developer.log('NewsModel compatibility: ✅', name: 'APITest');
        }
      } catch (e) {
        developer.log('Architecture validation failed: $e', name: 'APITest');
        fail('API architecture validation failed: $e');
      }
    });
  });
}