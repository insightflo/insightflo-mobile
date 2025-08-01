import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/network_info.dart';
import '../../../../core/cache/cache_service.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/user_keyword.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/news_remote_data_source.dart';
import '../datasources/news_local_data_source.dart';

/// Implementation of NewsRepository with API-First architecture and intelligent caching
class NewsRepositoryImpl implements NewsRepository {
  final NewsRemoteDataSource remoteDataSource;
  final NewsLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final CacheService cacheService;

  NewsRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.cacheService,
  });

  @override
  Future<Either<Failure, List<NewsArticle>>> getPersonalizedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'news_personalized_${userId}_p${page}_l$limit';
    
    try {
      // 1. 캐시에서 데이터 확인 (stale-while-revalidate 전략)
      final cacheResult = await cacheService.getFromCache<List<NewsTableData>>(cacheKey);
      
      // 캐시된 데이터가 있고, 네트워크가 없다면 캐시 데이터 반환
      if (cacheResult.data.isNotEmpty && !(await networkInfo.isConnected)) {
        final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
        return Right(articles);
      }
      
      // 2. 네트워크에서 새로운 데이터 가져오기
      if (await networkInfo.isConnected) {
        try {
          final articles = await remoteDataSource.getPersonalizedNews(
            userId: userId,
            page: page,
            limit: limit,
          );
          
          // 3. 새로운 데이터를 캐시에 저장
          final articlesData = articles.map((article) => _convertToMap(article)).toList();
          await cacheService.putInCache(cacheKey, articlesData);
          
          return Right(articles);
        } on ServerException catch (e) {
          // API 실패 시 캐시된 데이터가 있다면 반환
          if (cacheResult.data.isNotEmpty) {
            final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
            return Right(articles);
          }
          return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
        } on NetworkException catch (e) {
          // 네트워크 실패 시 캐시된 데이터가 있다면 반환
          if (cacheResult.data.isNotEmpty) {
            final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
            return Right(articles);
          }
          return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
        }
      } else {
        // 네트워크 없음 - 캐시 데이터 있으면 반환, 없으면 오류
        if (cacheResult.data.isNotEmpty) {
          final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
          return Right(articles);
        }
        return const Left(NetworkFailure(message: 'No internet connection and no cached data'));
      }
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NewsArticle>>> getAllNews({
    int page = 1,
    int limit = 20,
    String? searchQuery,
    List<String>? keywords,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final articles = await remoteDataSource.getAllNews(
          page: page,
          limit: limit,
          searchQuery: searchQuery,
          keywords: keywords,
        );
        return Right(articles);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, NewsArticle>> getNewsArticleById(String articleId) async {
    if (await networkInfo.isConnected) {
      try {
        final article = await remoteDataSource.getNewsArticleById(articleId);
        return Right(article);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, List<NewsArticle>>> searchNews({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    final cacheKey = 'search_${query}_p${page}_l$limit';
    
    try {
      // 1. 캐시에서 검색 결과 확인 (짧은 캐시 기간 15분)
      final cacheResult = await cacheService.getFromCache<List<NewsTableData>>(cacheKey);
      
      // 캐시된 데이터가 있고, 네트워크가 없다면 캐시 데이터 반환
      if (cacheResult.data.isNotEmpty && !(await networkInfo.isConnected)) {
        final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
        return Right(articles);
      }
      
      // 2. 네트워크에서 검색 수행
      if (await networkInfo.isConnected) {
        try {
          final articles = await remoteDataSource.searchNews(
            query: query,
            page: page,
            limit: limit,
          );
          
          // 3. 검색 결과를 캐시에 저장 (15분 TTL)
          final articlesData = articles.map((article) => _convertToMap(article)).toList();
          await cacheService.putInCache(
            cacheKey, 
            articlesData, 
            ttl: const Duration(minutes: 15),
          );
          
          return Right(articles);
        } on ServerException catch (e) {
          // API 실패 시 캐시된 데이터가 있다면 반환
          if (cacheResult.data.isNotEmpty) {
            final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
            return Right(articles);
          }
          return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
        } on NetworkException catch (e) {
          // 네트워크 실패 시 캐시된 데이터가 있다면 반환
          if (cacheResult.data.isNotEmpty) {
            final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
            return Right(articles);
          }
          return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
        }
      } else {
        // 네트워크 없음 - 캐시 데이터 있으면 반환, 없으면 오류
        if (cacheResult.data.isNotEmpty) {
          final articles = cacheResult.data.map((data) => _convertToNewsArticle(data)).toList();
          return Right(articles);
        }
        return const Left(NetworkFailure(message: 'No internet connection and no cached search results'));
      }
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<NewsArticle>>> getBookmarkedNews({
    required String userId,
    int page = 1,
    int limit = 20,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final articles = await remoteDataSource.getBookmarkedNews(
          userId: userId,
          page: page,
          limit: limit,
        );
        return Right(articles);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, void>> bookmarkArticle({
    required String userId,
    required String articleId,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.bookmarkArticle(
          userId: userId,
          articleId: articleId,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, void>> removeBookmark({
    required String userId,
    required String articleId,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.removeBookmark(
          userId: userId,
          articleId: articleId,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, List<UserKeyword>>> getUserKeywords(String userId) async {
    if (await networkInfo.isConnected) {
      try {
        final keywords = await remoteDataSource.getUserKeywords(userId);
        return Right(keywords);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, UserKeyword>> addUserKeyword({
    required String userId,
    required String keyword,
    double weight = 1.0,
  }) async {
    if (await networkInfo.isConnected) {
      try {
        final userKeyword = await remoteDataSource.addUserKeyword(
          userId: userId,
          keyword: keyword,
          weight: weight,
        );
        return Right(userKeyword);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, UserKeyword>> updateUserKeyword({
    required String keywordId,
    String? keyword,
    double? weight,
    bool? isActive,
  }) async {
    // TODO: API 엔드포인트에서 updateUserKeyword 메서드 구현 필요
    return Left(ServerFailure(
      message: 'Update user keyword not yet implemented for API-First architecture',
      statusCode: 501,
    ));
  }

  @override
  Future<Either<Failure, void>> deleteUserKeyword(String keywordId) async {
    if (await networkInfo.isConnected) {
      try {
        await remoteDataSource.removeUserKeyword(
          userId: 'temp', // TODO: 실제 사용자 ID 사용
          keywordId: keywordId,
        );
        return const Right(null);
      } on ServerException catch (e) {
        return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
      } on NetworkException catch (e) {
        return Left(NetworkFailure(message: e.message, statusCode: e.statusCode));
      } catch (e) {
        return Left(UnknownFailure(message: e.toString()));
      }
    } else {
      return const Left(NetworkFailure(message: 'No internet connection'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTrendingKeywords({
    int limit = 10,
  }) async {
    // TODO: API 엔드포인트에서 getTrendingKeywords 메서드 구현 필요
    return Left(ServerFailure(
      message: 'Get trending keywords not yet implemented for API-First architecture',
      statusCode: 501,
    ));
  }

  /// NewsTableData를 NewsArticle 엔티티로 변환
  NewsArticle _convertToNewsArticle(NewsTableData data) {
    return NewsArticle(
      id: data.id,
      title: data.title,
      summary: data.summary,
      content: data.content,
      url: data.url,
      source: data.source,
      publishedAt: DateTime.fromMillisecondsSinceEpoch(data.publishedAt),
      keywords: data.keywords.isNotEmpty 
          ? (data.keywords.startsWith('[') 
              ? List<String>.from(
                  (data.keywords.replaceAll(RegExp(r'[\[\]"]'), '').split(','))
                      .map((k) => k.trim())
                      .where((k) => k.isNotEmpty)
                )
              : data.keywords.split(',').map((k) => k.trim()).toList())
          : [],
      imageUrl: data.imageUrl,
      sentimentScore: data.sentimentScore,
      sentimentLabel: data.sentimentLabel,
      isBookmarked: data.isBookmarked == 1,
    );
  }

  /// NewsArticle 엔티티를 Map으로 변환 (캐시 저장용)
  Map<String, dynamic> _convertToMap(NewsArticle article) {
    return {
      'id': article.id,
      'title': article.title,
      'summary': article.summary,
      'content': article.content,
      'url': article.url,
      'source': article.source,
      'published_at': article.publishedAt.millisecondsSinceEpoch,
      'keywords': article.keywords,
      'image_url': article.imageUrl,
      'sentiment_score': article.sentimentScore,
      'sentiment_label': article.sentimentLabel,
      'is_bookmarked': article.isBookmarked,
    };
  }
}