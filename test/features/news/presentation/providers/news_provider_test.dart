import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:insightflo_app/features/news/data/models/news_model.dart';
import 'package:insightflo_app/features/news/domain/usecases/get_personalized_news.dart';
import 'package:insightflo_app/features/news/domain/usecases/search_news.dart';
import 'package:insightflo_app/features/news/domain/usecases/bookmark_article.dart';
import 'package:insightflo_app/features/news/data/datasources/news_local_data_source.dart';
import 'package:insightflo_app/features/news/presentation/providers/news_provider.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/features/keywords/presentation/providers/keyword_provider.dart';
import 'package:insightflo_app/core/services/api_auth_service.dart';

// Generate mocks
@GenerateMocks([
  GetPersonalizedNews,
  SearchNews,
  BookmarkArticle,
  NewsLocalDataSource,
  AuthProvider,
  KeywordProvider,
  ApiAuthService,
])
// Mock rebuild trigger
import 'news_provider_test.mocks.dart';

// Simple mock for KeywordProvider since MockKeywordProvider is not generated properly
class MockKeywordProvider extends Mock implements KeywordProvider {}

void main() {
  late NewsProvider provider;
  late MockGetPersonalizedNews mockGetPersonalizedNews;
  late MockSearchNews mockSearchNews;
  late MockBookmarkArticle mockBookmarkArticle;
  late MockNewsLocalDataSource mockLocalDataSource;
  late MockAuthProvider mockAuthProvider;
  late MockKeywordProvider mockKeywordProvider;
  late MockApiAuthService mockAuthService;

  setUp(() {
    mockGetPersonalizedNews = MockGetPersonalizedNews();
    mockSearchNews = MockSearchNews();
    mockBookmarkArticle = MockBookmarkArticle();
    mockLocalDataSource = MockNewsLocalDataSource();
    mockAuthProvider = MockAuthProvider();
    mockKeywordProvider = MockKeywordProvider();
    mockAuthService = MockApiAuthService();

    // Setup default ApiAuthService mock behavior - return false to skip API calls
    when(mockAuthService.isAuthenticated).thenReturn(false);
    when(mockAuthService.getAuthHeaders()).thenReturn({
      'Content-Type': 'application/json',
    });
    // Make signInAnonymously throw to prevent actual API calls in tests
    when(mockAuthService.signInAnonymously()).thenThrow(Exception('API calls disabled in tests'));

    provider = NewsProvider(
      getPersonalizedNews: mockGetPersonalizedNews,
      searchNews: mockSearchNews,
      bookmarkArticle: mockBookmarkArticle,
      localDataSource: mockLocalDataSource,
      authProvider: mockAuthProvider,
      keywordProvider: mockKeywordProvider,
      authService: mockAuthService,
    );
  });

  group('NewsProvider', () {
    final testNewsModel = NewsModel(
      id: 'test-id',
      title: 'Test News',
      summary: 'Test summary',
      content: 'Test content',
      url: 'https://example.com',
      source: 'Test Source',
      publishedAt: DateTime.now(),
      imageUrl: null,
      keywords: ['test'],
      sentimentScore: 0.5,
      sentimentLabel: 'neutral',
      isBookmarked: false,
      cachedAt: DateTime.now(),
      userId: 'test-user-id',
    );

    final testNewsList = [testNewsModel];

    group('getPersonalizedNewsForUser', () {
      test('should load personalized news successfully', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockLocalDataSource.getFreshNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);
        when(mockLocalDataSource.getPersonalizedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => testNewsList);
        when(mockAuthProvider.currentUser).thenReturn(null);

        // Act
        await provider.getPersonalizedNewsForUser(userId);

        // Assert
        expect(provider.articles, equals(testNewsList));
        expect(provider.isLoading, isFalse);
        // Since we're mocking getFreshNews to return data, no error should occur
        expect(provider.error, isNull);
      });

      test('should handle loading news failure', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockLocalDataSource.getFreshNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenThrow(Exception('Cache error'));
        when(mockLocalDataSource.getPersonalizedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => []);
        when(mockAuthProvider.currentUser).thenReturn(null);

        // Act
        await provider.getPersonalizedNewsForUser(userId);

        // Assert
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNotNull);
        expect(provider.error, contains('Network error'));
      });
    });

    group('searchNewsArticles', () {
      test('should search articles successfully', () async {
        // Arrange
        const query = 'test query';
        when(mockLocalDataSource.searchNews(
          query: anyNamed('query'),
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);

        // Act
        await provider.searchNewsArticles(query);

        // Assert
        expect(provider.articles, equals(testNewsList));
        expect(provider.isLoading, isFalse);
        expect(provider.searchQuery, equals(query));
        expect(provider.error, isNull);
      });

      test('should handle search failure', () async {
        // Arrange
        const query = 'test query';
        when(mockLocalDataSource.searchNews(
          query: anyNamed('query'),
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenThrow(Exception('Search error'));

        // Act
        await provider.searchNewsArticles(query);

        // Assert
        expect(provider.isLoading, isFalse);
        expect(provider.error, contains('Search failed'));
      });
    });

    group('loadBookmarkedArticles', () {
      test('should load bookmarked articles successfully', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockLocalDataSource.getBookmarkedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);

        // Act
        await provider.loadBookmarkedArticles(userId);

        // Assert
        expect(provider.bookmarkedArticles, equals(testNewsList));
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
        verify(mockLocalDataSource.getBookmarkedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).called(1);
      });

      test('should handle loading bookmarked articles failure', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockLocalDataSource.getBookmarkedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenThrow(Exception('Database error'));

        // Act
        await provider.loadBookmarkedArticles(userId);

        // Assert
        expect(provider.bookmarkedArticles, isEmpty);
        expect(provider.isLoading, isFalse);
        expect(provider.error, contains('Failed to load bookmarked articles'));
        verify(mockLocalDataSource.getBookmarkedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).called(1);
      });
    });

    group('refreshNews', () {
      test('should refresh news successfully', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockLocalDataSource.getFreshNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);
        when(mockLocalDataSource.getPersonalizedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => testNewsList);
        when(mockAuthProvider.currentUser).thenReturn(null);

        // Act
        await provider.refreshNews(userId);

        // Assert
        expect(provider.articles, equals(testNewsList));
        expect(provider.isLoading, isFalse);
        // Since we're mocking getFreshNews to return data, no error should occur
        expect(provider.error, isNull);
      });
    });

    group('loadMoreNews', () {
      test('should load more news successfully', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockLocalDataSource.getFreshNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);
        when(mockLocalDataSource.getPersonalizedNews(
          userId: anyNamed('userId'),
          limit: anyNamed('limit'),
          offset: anyNamed('offset'),
        )).thenAnswer((_) async => testNewsList);
        when(mockAuthProvider.currentUser).thenReturn(null);

        // Act
        await provider.loadMoreNews(userId);

        // Assert
        expect(provider.isLoadingMore, isFalse);
      });
    });

    group('utility methods', () {
      test('should clear data correctly', () {
        // Act
        provider.clearData();

        // Assert
        expect(provider.articles, isEmpty);
        expect(provider.bookmarkedArticles, isEmpty);
        expect(provider.searchQuery, isEmpty);
        expect(provider.error, isNull);
      });

      test('should get correct state values', () {
        // Assert
        expect(provider.isLoading, isFalse);
        expect(provider.isLoadingMore, isFalse);
        expect(provider.hasMoreData, isTrue);
        expect(provider.isOfflineMode, isFalse);
      });
    });
  });
}