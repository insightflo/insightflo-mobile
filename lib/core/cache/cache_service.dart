import 'dart:async';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:insightflo_app/core/database/app_database.dart';
import 'package:insightflo_app/core/monitoring/performance_monitor.dart';
import 'api_cache_manager.dart';

/// API 캐싱을 위한 서비스 추상화 레이어
/// Repository 패턴과 함께 사용하여 데이터 계층에서 캐싱 로직을 분리
abstract class CacheService {
  /// 캐시에서 데이터 가져오기
  Future<CacheResult<T>> getFromCache<T>(String key);

  /// 캐시에 데이터 저장
  Future<void> putInCache<T>(String key, T data, {Duration? ttl});

  /// 캐시 무효화
  Future<void> invalidate(String key);

  /// 캐시 전체 정리
  Future<void> clearCache();

  /// 캐시 통계
  Future<CacheStatistics> getStatistics();
}

/// API-First 아키텍처를 위한 캐시 서비스 구현
class ApiCacheService implements CacheService {
  final ApiCacheManager _cacheManager;
  final String _userId;

  /// 캐시 키 접두사
  static const String _newsKeyPrefix = 'news_';
  static const String _searchKeyPrefix = 'search_';

  ApiCacheService({
    required ApiCacheManager cacheManager,
    required String userId,
  }) : _cacheManager = cacheManager,
       _userId = userId;

  @override
  Future<CacheResult<T>> getFromCache<T>(String key) async {
    final cacheKey = _buildCacheKey(key);

    if (key.startsWith(_newsKeyPrefix)) {
      final result = await _cacheManager.getCachedNews(
        userId: _userId,
        cacheKey: cacheKey,
      );
      return CacheResult<T>(
        data: result.data as T,
        status: result.status,
        isStale: result.isStale,
        shouldRevalidate: result.shouldRevalidate,
        cacheKey: result.cacheKey,
        lastUpdated: result.lastUpdated,
      );
    } else if (key.startsWith(_searchKeyPrefix)) {
      final query = key.substring(_searchKeyPrefix.length);
      final result = await _cacheManager.getCachedSearchResults(
        userId: _userId,
        query: query,
      );
      return CacheResult<T>(
        data: result.data as T,
        status: result.status,
        isStale: result.isStale,
        shouldRevalidate: result.shouldRevalidate,
        cacheKey: result.cacheKey,
        lastUpdated: result.lastUpdated,
      );
    }

    throw UnsupportedError('Cache key type not supported: $key');
  }

  @override
  Future<void> putInCache<T>(String key, T data, {Duration? ttl}) async {
    final cacheKey = _buildCacheKey(key);

    if (key.startsWith(_newsKeyPrefix) && data is List<Map<String, dynamic>>) {
      await _cacheManager.cacheNewsArticles(
        userId: _userId,
        articles: data,
        cacheKey: cacheKey,
        cacheDuration: ttl,
      );
    } else if (key.startsWith(_searchKeyPrefix) &&
        data is List<Map<String, dynamic>>) {
      final query = key.substring(_searchKeyPrefix.length);
      await _cacheManager.cacheSearchResults(
        userId: _userId,
        query: query,
        results: data,
      );
    } else {
      throw UnsupportedError('Cache data type not supported for key: $key');
    }
  }

  @override
  Future<void> invalidate(String key) async {
    final cacheKey = _buildCacheKey(key);
    await _cacheManager.invalidateUserCache(
      userId: _userId,
      cacheKey: cacheKey,
    );
  }

  @override
  Future<void> clearCache() async {
    await _cacheManager.invalidateUserCache(userId: _userId);
  }

  @override
  Future<CacheStatistics> getStatistics() async {
    return await _cacheManager.getCacheStatistics(userId: _userId);
  }

  /// 캐시 키 생성
  String _buildCacheKey(String key) {
    return '${_userId}_$key';
  }

  /// 캐시 정리 수행
  Future<CacheCleanupResult> performCleanup({bool force = false}) async {
    return await _cacheManager.performCacheCleanup(
      userId: _userId,
      forceCleanup: force,
    );
  }

  /// 네트워크 상태 기반 캐시 전략 결정
  Future<CacheStrategy> getCacheStrategy() async {
    return await _cacheManager.determineCacheStrategy();
  }
}

/// 캐시 서비스 팩토리
class CacheServiceFactory {
  static ApiCacheService create({
    required AppDatabase database,
    required String userId,
    Connectivity? connectivity,
    MetricCollector? metricsCollector,
  }) {
    final effectiveConnectivity = connectivity ?? Connectivity();
    final effectiveMetricsCollector =
        metricsCollector ?? MetricCollector.instance;

    final cacheManager = ApiCacheManager(
      database: database,
      connectivity: effectiveConnectivity,
      metricsCollector: effectiveMetricsCollector,
    );

    return ApiCacheService(cacheManager: cacheManager, userId: userId);
  }
}

/// 캐시 정책 구성
class CachePolicy {
  final Duration defaultTtl;
  final Duration searchTtl;
  final Duration newsTtl;
  final Duration staleWhileRevalidateWindow;
  final int maxCacheSize;
  final bool enableOfflineMode;

  const CachePolicy({
    this.defaultTtl = const Duration(hours: 1),
    this.searchTtl = const Duration(minutes: 15),
    this.newsTtl = const Duration(minutes: 30),
    this.staleWhileRevalidateWindow = const Duration(hours: 2),
    this.maxCacheSize = 1000,
    this.enableOfflineMode = true,
  });

  /// 기본 정책
  static const CachePolicy defaultPolicy = CachePolicy();

  /// 공격적 캐싱 정책 (데이터 절약 모드)
  static const CachePolicy aggressive = CachePolicy(
    defaultTtl: Duration(hours: 6),
    searchTtl: Duration(hours: 1),
    newsTtl: Duration(hours: 2),
    staleWhileRevalidateWindow: Duration(hours: 12),
    maxCacheSize: 2000,
    enableOfflineMode: true,
  );

  /// 보수적 캐싱 정책 (실시간 데이터 우선)
  static const CachePolicy conservative = CachePolicy(
    defaultTtl: Duration(minutes: 15),
    searchTtl: Duration(minutes: 5),
    newsTtl: Duration(minutes: 10),
    staleWhileRevalidateWindow: Duration(minutes: 30),
    maxCacheSize: 500,
    enableOfflineMode: false,
  );
}

/// 캐시 이벤트 리스너
abstract class CacheEventListener {
  void onCacheHit(String key, dynamic data);
  void onCacheMiss(String key);
  void onCacheInvalidation(String key);
  void onCacheCleanup(CacheCleanupResult result);
}

/// 기본 캐시 이벤트 리스너 (로깅용)
class DefaultCacheEventListener implements CacheEventListener {
  @override
  void onCacheHit(String key, dynamic data) {
    developer.log('Cache Hit: $key', name: 'CacheService');
  }

  @override
  void onCacheMiss(String key) {
    developer.log('Cache Miss: $key', name: 'CacheService');
  }

  @override
  void onCacheInvalidation(String key) {
    developer.log('Cache Invalidated: $key', name: 'CacheService');
  }

  @override
  void onCacheCleanup(CacheCleanupResult result) {
    developer.log(
      'Cache Cleanup: ${result.success ? 'Success' : 'Failed'} '
      '- Deleted ${result.deletedArticles} articles, '
      'Reclaimed ${result.spaceReclaimed} space',
      name: 'CacheService',
    );
  }
}
