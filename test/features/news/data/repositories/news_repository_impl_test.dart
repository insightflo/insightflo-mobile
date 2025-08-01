import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/utils/network_info.dart';
import 'package:insightflo_app/core/cache/cache_service.dart';
import 'package:insightflo_app/features/news/data/datasources/news_local_data_source.dart';
import 'package:insightflo_app/features/news/data/datasources/news_remote_data_source.dart';
import 'package:insightflo_app/features/news/data/models/news_article_model.dart';
import 'package:insightflo_app/features/news/data/repositories/news_repository_impl.dart';
import 'package:insightflo_app/features/news/domain/entities/news_article.dart';

// Generate mocks
@GenerateMocks([
  NewsRemoteDataSource,
  NewsLocalDataSource,
  NetworkInfo,
  CacheService,
])
import 'news_repository_impl_test.mocks.dart';

void main() {
  late NewsRepositoryImpl repository;
  late MockNewsRemoteDataSource mockRemoteDataSource;
  late MockNewsLocalDataSource mockLocalDataSource;
  late MockNetworkInfo mockNetworkInfo;
  late MockCacheService mockCacheService;

  setUp(() {
    mockRemoteDataSource = MockNewsRemoteDataSource();
    mockLocalDataSource = MockNewsLocalDataSource();
    mockNetworkInfo = MockNetworkInfo();
    mockCacheService = MockCacheService();

    repository = NewsRepositoryImpl(
      remoteDataSource: mockRemoteDataSource,
      localDataSource: mockLocalDataSource,
      networkInfo: mockNetworkInfo,
      cacheService: mockCacheService,
    );
  });

  group('NewsRepositoryImpl', () {
    final testNewsArticleModel = NewsArticleModel(
      id: 'test-id',
      title: 'Test News',
      summary: 'Test summary',
      content: 'Test content',
      url: 'https://example.com',
      source: 'Test Source',
      publishedAt: DateTime.now(),
      keywords: ['test', 'news'],
    );

    final testNewsList = [testNewsArticleModel];

    group('getAllNews', () {
      test('should return news from remote when network is available', () async {
        // Arrange
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.getAllNews(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);

        // Act
        final result = await repository.getAllNews(page: 1, limit: 10);

        // Assert
        expect(result, isA<Right<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (news) => expect(news.length, equals(1)),
        );
        verify(mockRemoteDataSource.getAllNews(page: 1, limit: 10)).called(1);
      });

      test('should return NetworkFailure when no internet connection', () async {
        // Arrange
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        // Act
        final result = await repository.getAllNews(page: 1, limit: 10);

        // Assert
        expect(result, isA<Left<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) {
            expect(failure, isA<NetworkFailure>());
            expect(failure.message, equals('No internet connection'));
          },
          (news) => fail('Expected Left but got Right: $news'),
        );
      });

      test('should return ServerFailure when remote data source fails', () async {
        // Arrange
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.getAllNews(
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenThrow(const ServerException(
          message: 'Server error',
          statusCode: 500,
        ));

        // Act
        final result = await repository.getAllNews(page: 1, limit: 10);

        // Assert
        expect(result, isA<Left<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, equals('Server error'));
          },
          (news) => fail('Expected Left but got Right: $news'),
        );
      });
    });

    group('searchNews', () {
      test('should return search results from remote when network is available', () async {
        // Arrange
        const query = 'test query';
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.searchNews(
          query: anyNamed('query'),
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);

        // Act
        final result = await repository.searchNews(query: query, page: 1, limit: 10);

        // Assert
        expect(result, isA<Right<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (news) => expect(news.length, equals(1)),
        );
        verify(mockRemoteDataSource.searchNews(
          query: query,
          page: 1,
          limit: 10,
        )).called(1);
      });

      test('should return NetworkFailure when no internet connection', () async {
        // Arrange
        const query = 'test query';
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => false);

        // Act
        final result = await repository.searchNews(query: query, page: 1, limit: 10);

        // Assert
        expect(result, isA<Left<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) {
            expect(failure, isA<NetworkFailure>());
            expect(failure.message, equals('No internet connection'));
          },
          (news) => fail('Expected Left but got Right: $news'),
        );
      });
    });

    group('getPersonalizedNews', () {
      test('should return personalized news when network is available', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.getPersonalizedNews(
          userId: anyNamed('userId'),
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);

        // Act
        final result = await repository.getPersonalizedNews(
          userId: userId,
          page: 1,
          limit: 10,
        );

        // Assert
        expect(result, isA<Right<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (news) => expect(news.length, equals(1)),
        );
        verify(mockRemoteDataSource.getPersonalizedNews(
          userId: userId,
          page: 1,
          limit: 10,
        )).called(1);
      });
    });

    group('bookmarkArticle', () {
      test('should bookmark article successfully when network is available', () async {
        // Arrange
        const articleId = 'test-article-id';
        const userId = 'test-user-id';
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.bookmarkArticle(
          articleId: anyNamed('articleId'),
          userId: anyNamed('userId'),
        )).thenAnswer((_) async {});

        // Act
        final result = await repository.bookmarkArticle(
          articleId: articleId,
          userId: userId,
        );

        // Assert
        expect(result, isA<Right<Failure, void>>());
        verify(mockRemoteDataSource.bookmarkArticle(
          articleId: articleId,
          userId: userId,
        )).called(1);
      });

      test('should return ServerFailure when bookmark fails', () async {
        // Arrange
        const articleId = 'test-article-id';
        const userId = 'test-user-id';
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.bookmarkArticle(
          articleId: anyNamed('articleId'),
          userId: anyNamed('userId'),
        )).thenThrow(const ServerException(
          message: 'Failed to save bookmark',
          statusCode: 500,
        ));

        // Act
        final result = await repository.bookmarkArticle(
          articleId: articleId,
          userId: userId,
        );

        // Assert
        expect(result, isA<Left<Failure, void>>());
        result.fold(
          (failure) {
            expect(failure, isA<ServerFailure>());
            expect(failure.message, equals('Failed to save bookmark'));
          },
          (_) => fail('Expected Left but got Right'),
        );
      });
    });

    group('getBookmarkedNews', () {
      test('should return bookmarked news when network is available', () async {
        // Arrange
        const userId = 'test-user-id';
        when(mockNetworkInfo.isConnected).thenAnswer((_) async => true);
        when(mockRemoteDataSource.getBookmarkedNews(
          userId: anyNamed('userId'),
          page: anyNamed('page'),
          limit: anyNamed('limit'),
        )).thenAnswer((_) async => testNewsList);

        // Act
        final result = await repository.getBookmarkedNews(
          userId: userId,
          page: 1,
          limit: 10,
        );

        // Assert
        expect(result, isA<Right<Failure, List<NewsArticle>>>());
        result.fold(
          (failure) => fail('Expected Right but got Left: $failure'),
          (articles) => expect(articles.length, equals(1)),
        );
        verify(mockRemoteDataSource.getBookmarkedNews(
          userId: userId,
          page: 1,
          limit: 10,
        )).called(1);
      });
    });
  });
}