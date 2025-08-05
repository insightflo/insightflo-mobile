import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:insightflo_app/core/database/app_database.dart';
import 'package:insightflo_app/core/monitoring/performance_monitor.dart';

/// 고성능 API 캐시 매니저
/// API-First 아키텍처를 위한 지능형 캐싱 전략 구현
class ApiCacheManager {
  final AppDatabase _database;
  final Connectivity _connectivity;
  final MetricCollector _metricsCollector;

  /// 캐시 설정
  static const Duration _defaultCacheDuration = Duration(hours: 1);
  static const Duration _searchCacheDuration = Duration(minutes: 15);
  static const Duration _staleWhileRevalidateWindow = Duration(hours: 2);

  /// 캐시 상태 상수
  static const String _cacheStatusFresh = 'fresh';
  static const String _cacheStatusStale = 'stale';
  static const String _cacheStatusExpired = 'expired';

  ApiCacheManager({
    required AppDatabase database,
    required Connectivity connectivity,
    required MetricCollector metricsCollector,
  }) : _database = database,
       _connectivity = connectivity,
       _metricsCollector = metricsCollector;

  /// 뉴스 기사를 캐시에 저장하고 API에서 가져온 데이터와 동기화
  Future<void> cacheNewsArticles({
    required String userId,
    required List<Map<String, dynamic>> articles,
    required String cacheKey,
    Duration? cacheDuration,
  }) async {
    await _metricsCollector.measureDatabaseQuery(
      'cache_news_articles',
      () async {
        final now = DateTime.now().millisecondsSinceEpoch;
        final effectiveCacheDuration = cacheDuration ?? _defaultCacheDuration;

        // 캐시된 기사를 NewsTableCompanion으로 변환
        final newsCompanions = articles.map((article) {
          return NewsTableCompanion.insert(
            id: article['id'] as String,
            title: article['title'] as String,
            summary: article['summary'] as String,
            content: article['content'] as String? ?? '',
            url: article['url'] as String,
            source: article['source'] as String,
            publishedAt: _parseTimestamp(article['published_at']),
            keywords: Value(
              article['keywords'] is List
                  ? jsonEncode(article['keywords'])
                  : article['keywords'] as String? ?? '[]',
            ),
            imageUrl: Value(article['image_url'] as String?),
            sentimentScore: Value(
              (article['sentiment_score'] as num?)?.toDouble() ?? 0.0,
            ),
            sentimentLabel: Value(
              article['sentiment_label'] as String? ?? 'neutral',
            ),
            isBookmarked: Value(
              (article['is_bookmarked'] as bool?) == true ? 1 : 0,
            ),
            cachedAt: now,
            userId: userId,
          );
        }).toList();

        // 배치 삽입으로 성능 최적화
        await _database.batchInsertNews(newsCompanions);

        // 동기화 메타데이터 업데이트
        await _database.upsertSyncMetadata(
          tableName: 'news_articles',
          syncDirection: 'download',
          syncStatus: 'completed',
          recordCount: articles.length,
          metadata: jsonEncode({
            'cache_key': cacheKey,
            'cache_duration_hours': effectiveCacheDuration.inHours,
            'cached_at': now,
            'expires_at': now + effectiveCacheDuration.inMilliseconds,
          }),
        );
      },
      metadata: {
        'user_id': userId,
        'article_count': articles.length,
        'cache_key': cacheKey,
        'operation': 'cache_news_articles',
      },
    );
  }

  /// 캐시에서 뉴스 기사 가져오기 (stale-while-revalidate 전략 포함)
  Future<CacheResult<List<NewsTableData>>> getCachedNews({
    required String userId,
    required String cacheKey,
    int limit = 20,
    Duration? maxAge,
  }) async {
    return await _metricsCollector.measureDatabaseQuery(
      'get_cached_news',
      () async {
        final effectiveMaxAge = maxAge ?? _defaultCacheDuration;
        final now = DateTime.now().millisecondsSinceEpoch;
        final freshThreshold = now - effectiveMaxAge.inMilliseconds;
        final staleThreshold = now - _staleWhileRevalidateWindow.inMilliseconds;

        // 동기화 메타데이터 확인
        final syncMetadata = await _database.getSyncMetadata(
          tableName: 'news_articles',
          syncDirection: 'download',
        );

        String cacheStatus = _cacheStatusExpired;
        if (syncMetadata != null) {
          final cachedAt = syncMetadata.lastSyncTime;
          if (cachedAt > freshThreshold) {
            cacheStatus = _cacheStatusFresh;
          } else if (cachedAt > staleThreshold) {
            cacheStatus = _cacheStatusStale;
          }
        }

        // 캐시된 데이터 가져오기
        List<NewsTableData> cachedArticles;
        if (cacheStatus != _cacheStatusExpired) {
          cachedArticles = await _database.getFreshNews(
            userId: userId,
            limit: limit,
          );
        } else {
          // 만료된 경우 최신 데이터라도 가져오기
          cachedArticles = await _database.getPersonalizedNews(
            userId: userId,
            limit: limit,
          );
        }

        return CacheResult<List<NewsTableData>>(
          data: cachedArticles,
          status: cacheStatus,
          isStale: cacheStatus == _cacheStatusStale,
          shouldRevalidate: cacheStatus != _cacheStatusFresh,
          cacheKey: cacheKey,
          lastUpdated: syncMetadata?.lastSyncTime != null
              ? DateTime.fromMillisecondsSinceEpoch(syncMetadata!.lastSyncTime)
              : null,
        );
      },
      metadata: {
        'user_id': userId,
        'cache_key': cacheKey,
        'limit': limit,
        'operation': 'get_cached_news',
      },
    );
  }

  /// 검색 결과 캐싱 (짧은 캐시 기간)
  Future<void> cacheSearchResults({
    required String userId,
    required String query,
    required List<Map<String, dynamic>> results,
  }) async {
    final cacheKey = 'search_${query.hashCode}';
    await cacheNewsArticles(
      userId: userId,
      articles: results,
      cacheKey: cacheKey,
      cacheDuration: _searchCacheDuration,
    );

    // 검색별 메타데이터 저장
    await _database.upsertSyncMetadata(
      tableName: 'search_cache',
      syncDirection: 'download',
      syncStatus: 'completed',
      recordCount: results.length,
      metadata: jsonEncode({
        'search_query': query,
        'cache_key': cacheKey,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// 캐시된 검색 결과 가져오기
  Future<CacheResult<List<NewsTableData>>> getCachedSearchResults({
    required String userId,
    required String query,
    int limit = 20,
  }) async {
    return await getCachedNews(
      userId: userId,
      cacheKey: 'search_${query.hashCode}',
      limit: limit,
      maxAge: _searchCacheDuration,
    );
  }

  /// 네트워크 상태 기반 캐시 전략
  Future<CacheStrategy> determineCacheStrategy() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final isConnected =
          connectivityResults.isNotEmpty &&
          !connectivityResults.contains(ConnectivityResult.none);

      if (!isConnected) {
        return CacheStrategy.cacheOnly;
      }

      final isWiFi = connectivityResults.contains(ConnectivityResult.wifi);
      if (isWiFi) {
        return CacheStrategy.networkFirst;
      } else {
        // 모바일 데이터인 경우 캐시 우선
        return CacheStrategy.cacheFirst;
      }
    } catch (e) {
      // 연결 상태를 확인할 수 없는 경우 캐시 우선
      return CacheStrategy.cacheFirst;
    }
  }

  /// 캐시 무효화 (특정 사용자의 캐시 삭제)
  Future<void> invalidateUserCache({
    required String userId,
    String? cacheKey,
  }) async {
    await _metricsCollector.measureDatabaseQuery(
      'invalidate_user_cache',
      () async {
        if (cacheKey != null) {
          // 특정 캐시 키만 무효화
          await _database.updateSyncStatus(
            tableName: 'news_articles',
            syncDirection: 'download',
            syncStatus: 'invalidated',
          );
        } else {
          // 사용자의 모든 캐시 삭제
          await _database.customStatement(
            'DELETE FROM news_articles WHERE user_id = ?',
            [userId],
          );

          // 동기화 메타데이터도 리셋
          await _database.upsertSyncMetadata(
            tableName: 'news_articles',
            syncDirection: 'download',
            syncStatus: 'pending',
            recordCount: 0,
          );
        }
      },
      metadata: {
        'user_id': userId,
        'cache_key': cacheKey,
        'operation': 'invalidate_cache',
      },
    );
  }

  /// 캐시 정리 (만료된 데이터 및 공간 확보)
  Future<CacheCleanupResult> performCacheCleanup({
    required String userId,
    bool forceCleanup = false,
  }) async {
    return await _metricsCollector.measureDatabaseQuery(
      'cache_cleanup',
      () async {
        final stopwatch = Stopwatch()..start();

        try {
          // 데이터베이스 통계 가져오기 (정리 전)
          final statsBefore = await _database.getDatabaseStats(userId: userId);

          // 1. 만료된 기사 정리 (기본 7일 보관)
          final deletedArticles = await _database.cleanupOldArticles(
            userId: userId,
            keepCount: forceCleanup ? 500 : 1000,
            retentionDays: forceCleanup ? 3 : 7,
          );

          // 2. 오래된 동기화 메타데이터 정리
          final deletedMetadata = await _database.cleanupSyncMetadata(
            retentionPeriod: Duration(days: forceCleanup ? 7 : 30),
          );

          // 3. 데이터베이스 최적화 (주기적으로만)
          Map<String, dynamic>? optimizationResult;
          if (forceCleanup || DateTime.now().day % 7 == 0) {
            optimizationResult = await _database.optimizeDatabase();
          }

          // 데이터베이스 통계 가져오기 (정리 후)
          final statsAfter = await _database.getDatabaseStats(userId: userId);

          stopwatch.stop();

          return CacheCleanupResult(
            success: true,
            durationMs: stopwatch.elapsedMilliseconds,
            deletedArticles: deletedArticles,
            deletedMetadata: deletedMetadata,
            spaceReclaimed: optimizationResult?['spaceReclaimed'] ?? 0,
            articlesBefore: statsBefore['total'] ?? 0,
            articlesAfter: statsAfter['total'] ?? 0,
            optimizationPerformed: optimizationResult != null,
            optimizationResult: optimizationResult,
          );
        } catch (e) {
          stopwatch.stop();
          return CacheCleanupResult(
            success: false,
            durationMs: stopwatch.elapsedMilliseconds,
            error: e.toString(),
          );
        }
      },
      metadata: {
        'user_id': userId,
        'force_cleanup': forceCleanup,
        'operation': 'cache_cleanup',
      },
    );
  }

  /// 캐시 통계 가져오기
  Future<CacheStatistics> getCacheStatistics({required String userId}) async {
    final dbStats = await _database.getDatabaseStats(userId: userId);
    final syncStats = await _database.getSyncStatistics();

    return CacheStatistics(
      totalArticles: dbStats['total'] ?? 0,
      freshArticles: dbStats['fresh'] ?? 0,
      bookmarkedArticles: dbStats['bookmarked'] ?? 0,
      articlesLast24Hours: dbStats['fresh'] ?? 0,
      articlesLastWeek: dbStats['total'] ?? 0,
      lastSyncTime: syncStats['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              syncStats['lastSyncTime'] as int,
            )
          : null,
      syncStatus: _determineSyncStatusFromStats(syncStats),
      cacheHitRate: await _calculateCacheHitRate(userId),
    );
  }

  /// 캐시 히트율 계산 (최근 24시간 기준)
  Future<double> _calculateCacheHitRate(String userId) async {
    // 실제 구현에서는 메트릭 컬렉터에서 캐시 히트/미스 데이터를 가져와야 함
    // 여기서는 간단한 예시 구현
    final freshCount =
        (await _database.getDatabaseStats(userId: userId))['fresh'] ?? 0;
    final totalCount =
        (await _database.getDatabaseStats(userId: userId))['total'] ?? 0;

    if (totalCount == 0) return 0.0;
    return freshCount / totalCount;
  }

  /// 타임스탬프 파싱 유틸리티
  int _parseTimestamp(dynamic timestamp) {
    if (timestamp is int) {
      return timestamp;
    } else if (timestamp is String) {
      try {
        return DateTime.parse(timestamp).millisecondsSinceEpoch;
      } catch (e) {
        return DateTime.now().millisecondsSinceEpoch;
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }

  /// 동기화 통계에서 상태 결정
  String _determineSyncStatusFromStats(Map<String, dynamic> syncStats) {
    final statusCounts = syncStats['byStatus'] as Map<String, int>? ?? {};

    if (statusCounts.containsKey('failed') && statusCounts['failed']! > 0) {
      return 'partially_failed';
    } else if (statusCounts.containsKey('syncing') &&
        statusCounts['syncing']! > 0) {
      return 'syncing';
    } else if (statusCounts.containsKey('completed') &&
        statusCounts['completed']! > 0) {
      return 'up_to_date';
    } else {
      return 'pending';
    }
  }
}

/// 캐시 결과 래퍼 클래스
class CacheResult<T> {
  final T data;
  final String status;
  final bool isStale;
  final bool shouldRevalidate;
  final String cacheKey;
  final DateTime? lastUpdated;

  const CacheResult({
    required this.data,
    required this.status,
    required this.isStale,
    required this.shouldRevalidate,
    required this.cacheKey,
    this.lastUpdated,
  });

  bool get isFresh => status == ApiCacheManager._cacheStatusFresh;
  bool get isExpired => status == ApiCacheManager._cacheStatusExpired;
}

/// 캐시 전략 열거형
enum CacheStrategy {
  /// 네트워크 우선, 캐시 백업
  networkFirst,

  /// 캐시 우선, 네트워크 백업
  cacheFirst,

  /// 캐시만 사용 (오프라인)
  cacheOnly,

  /// 캐시와 네트워크 동시 요청
  staleWhileRevalidate,
}

/// 캐시 정리 결과
class CacheCleanupResult {
  final bool success;
  final int durationMs;
  final int deletedArticles;
  final int deletedMetadata;
  final int spaceReclaimed;
  final int articlesBefore;
  final int articlesAfter;
  final bool optimizationPerformed;
  final Map<String, dynamic>? optimizationResult;
  final String? error;

  const CacheCleanupResult({
    required this.success,
    required this.durationMs,
    this.deletedArticles = 0,
    this.deletedMetadata = 0,
    this.spaceReclaimed = 0,
    this.articlesBefore = 0,
    this.articlesAfter = 0,
    this.optimizationPerformed = false,
    this.optimizationResult,
    this.error,
  });

  int get totalSpaceSaved => spaceReclaimed + (articlesBefore - articlesAfter);
  double get cleanupEfficiency => articlesBefore > 0
      ? (articlesBefore - articlesAfter) / articlesBefore
      : 0.0;
}

/// 캐시 통계
class CacheStatistics {
  final int totalArticles;
  final int freshArticles;
  final int bookmarkedArticles;
  final int articlesLast24Hours;
  final int articlesLastWeek;
  final DateTime? lastSyncTime;
  final String syncStatus;
  final double cacheHitRate;

  const CacheStatistics({
    required this.totalArticles,
    required this.freshArticles,
    required this.bookmarkedArticles,
    required this.articlesLast24Hours,
    required this.articlesLastWeek,
    this.lastSyncTime,
    required this.syncStatus,
    required this.cacheHitRate,
  });

  double get freshnessRatio =>
      totalArticles > 0 ? freshArticles / totalArticles : 0.0;
  double get bookmarkRatio =>
      totalArticles > 0 ? bookmarkedArticles / totalArticles : 0.0;
}
