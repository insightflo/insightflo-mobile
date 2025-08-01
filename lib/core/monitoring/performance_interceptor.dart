/// Performance Interceptor for Dio HTTP Client
/// 
/// Dio Interceptor를 통한 API 요청/응답 시간 측정 및 성능 메트릭 수집
/// - 모든 HTTP 요청의 응답시간 자동 측정
/// - 엔드포인트별 성공률 및 에러율 추적
/// - 요청/응답 크기 모니터링
/// - 네트워크 지연시간 분석
/// - 메모리 효율적인 통계 수집
/// 
/// 사용법:
import 'dart:developer' as developer;
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(PerformanceInterceptor.instance);
/// ```

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'models/metrics.dart';

// ============================================================================
// 성능 통계 데이터 클래스
// ============================================================================

/// 엔드포인트별 성능 통계
class EndpointStats {
  final String endpoint;
  final String method;
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  final List<Duration> responseTimes = [];
  final Map<int, int> statusCodeCounts = {};
  DateTime lastRequestTime = DateTime.now();
  
  // 최근 응답시간 저장 (메모리 효율성을 위해 최대 100개)
  static const int maxResponseTimeSamples = 100;
  
  EndpointStats({
    required this.endpoint,
    required this.method,
  });
  
  /// 요청 결과 추가
  void addRequest({
    required Duration responseTime,
    required int statusCode,
    required bool isSuccess,
  }) {
    totalRequests++;
    lastRequestTime = DateTime.now();
    
    if (isSuccess) {
      successfulRequests++;
    } else {
      failedRequests++;
    }
    
    // 응답시간 저장 (순환 버퍼 방식)
    if (responseTimes.length >= maxResponseTimeSamples) {
      responseTimes.removeAt(0);
    }
    responseTimes.add(responseTime);
    
    // 상태코드 카운트
    statusCodeCounts[statusCode] = (statusCodeCounts[statusCode] ?? 0) + 1;
  }
  
  /// 성공률 계산
  double get successRate => totalRequests > 0 
      ? (successfulRequests / totalRequests) * 100.0 
      : 0.0;
  
  /// 에러율 계산
  double get errorRate => totalRequests > 0 
      ? (failedRequests / totalRequests) * 100.0 
      : 0.0;
  
  /// 평균 응답시간
  Duration get averageResponseTime {
    if (responseTimes.isEmpty) return Duration.zero;
    final totalMs = responseTimes
        .map((duration) => duration.inMilliseconds)
        .reduce((a, b) => a + b);
    return Duration(milliseconds: totalMs ~/ responseTimes.length);
  }
  
  /// 중앙값 응답시간
  Duration get medianResponseTime {
    if (responseTimes.isEmpty) return Duration.zero;
    final sorted = List<Duration>.from(responseTimes)
      ..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      final ms1 = sorted[middle - 1].inMilliseconds;
      final ms2 = sorted[middle].inMilliseconds;
      return Duration(milliseconds: (ms1 + ms2) ~/ 2);
    } else {
      return sorted[middle];
    }
  }
  
  /// 95퍼센타일 응답시간
  Duration get p95ResponseTime {
    if (responseTimes.isEmpty) return Duration.zero;
    final sorted = List<Duration>.from(responseTimes)
      ..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));
    final index = (sorted.length * 0.95).ceil() - 1;
    return sorted[math.max(0, index)];
  }
  
  /// 최근 1분간 RPS (Requests Per Second)
  double get recentRPS {
    final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
    if (lastRequestTime.isBefore(oneMinuteAgo)) return 0.0;
    
    // 간단한 근사치 계산 (실제로는 더 정확한 시간 윈도우 필요)
    final recentDuration = DateTime.now().difference(lastRequestTime);
    if (recentDuration.inSeconds == 0) return 0.0;
    return totalRequests / recentDuration.inSeconds;
  }
  
  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'method': method,
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'successRate': successRate,
      'errorRate': errorRate,
      'averageResponseTimeMs': averageResponseTime.inMilliseconds,
      'medianResponseTimeMs': medianResponseTime.inMilliseconds,
      'p95ResponseTimeMs': p95ResponseTime.inMilliseconds,
      'statusCodeCounts': statusCodeCounts,
      'lastRequestTime': lastRequestTime.toIso8601String(),
      'recentRPS': recentRPS,
    };
  }
}

// ============================================================================
// Dio Performance Interceptor
// ============================================================================

/// Dio를 위한 성능 모니터링 인터셉터
/// 
/// 모든 HTTP 요청의 성능 지표를 자동으로 수집하고 분석합니다.
/// 메모리 효율적인 통계 수집과 실시간 성능 분석을 제공합니다.
class PerformanceInterceptor extends Interceptor {
  static final PerformanceInterceptor _instance = PerformanceInterceptor._internal();
  static PerformanceInterceptor get instance => _instance;
  
  PerformanceInterceptor._internal();
  
  // 엔드포인트별 통계 저장소 (LRU 캐시 방식)
  final LinkedHashMap<String, EndpointStats> _endpointStats = LinkedHashMap();
  
  // 최대 엔드포인트 추적 수 (메모리 제한)
  static const int maxEndpoints = 500;
  
  // 성능 메트릭 수집 콜백
  final List<Function(APIMetric)> _metricCallbacks = [];
  
  // 설정 옵션
  bool _isEnabled = true;
  bool _logSlowRequests = true;
  Duration _slowRequestThreshold = const Duration(seconds: 2);
  bool _collectDetailedStats = true;
  
  /// 메트릭 수집 콜백 등록
  void addMetricCallback(Function(APIMetric) callback) {
    _metricCallbacks.add(callback);
  }
  
  /// 메트릭 수집 콜백 제거
  void removeMetricCallback(Function(APIMetric) callback) {
    _metricCallbacks.remove(callback);
  }
  
  /// 인터셉터 활성화/비활성화
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }
  
  /// 느린 요청 로깅 설정
  void configureSlowRequestLogging({
    required bool enabled,
    Duration threshold = const Duration(seconds: 2),
  }) {
    _logSlowRequests = enabled;
    _slowRequestThreshold = threshold;
  }
  
  /// 세부 통계 수집 설정
  void setDetailedStatsCollection(bool enabled) {
    _collectDetailedStats = enabled;
  }
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isEnabled) {
      handler.next(options);
      return;
    }
    
    // 요청 시작 시간 기록
    options.extra['_request_start_time'] = DateTime.now();
    
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_isEnabled) {
      handler.next(response);
      return;
    }
    
    _handleResponse(response, isError: false);
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_isEnabled) {
      handler.next(err);
      return;
    }
    
    _handleResponse(err.response, isError: true, error: err);
    handler.next(err);
  }
  
  /// 응답 처리 (성공/실패 공통)
  void _handleResponse(Response? response, {
    required bool isError,
    DioException? error,
  }) {
    final startTime = response?.requestOptions.extra['_request_start_time'] as DateTime?;
    if (startTime == null) return;
    
    final endTime = DateTime.now();
    final responseTime = endTime.difference(startTime);
    
    final options = response?.requestOptions ?? error?.requestOptions;
    if (options == null) return;
    
    // 엔드포인트 식별자 생성
    final endpoint = _normalizeEndpoint(options.path);
    final method = options.method;
    final endpointKey = '$method $endpoint';
    
    // 응답 정보 수집
    final statusCode = response?.statusCode ?? error?.response?.statusCode ?? 0;
    final requestSize = _calculateRequestSize(options);
    final responseSize = _calculateResponseSize(response);
    final isSuccess = !isError && statusCode >= 200 && statusCode < 400;
    
    // APIMetric 생성
    final apiMetric = APIMetric.httpRequest(
      endpoint: endpoint,
      method: HttpMethod.fromString(method),
      statusCode: statusCode,
      responseTime: responseTime,
      requestSize: requestSize,
      responseSize: responseSize,
      priority: _calculatePriority(responseTime, isSuccess),
      metadata: {
        'user_agent': options.headers['User-Agent'],
        'content_type': options.headers['Content-Type'],
        'network_type': _getNetworkType(),
        'cache_control': response?.headers['Cache-Control']?.first,
        'server': response?.headers['Server']?.first,
        'error_type': error?.type.toString(),
        'error_message': error?.message,
      },
    );
    
    // 메트릭 콜백 호출
    for (final callback in _metricCallbacks) {
      try {
        callback(apiMetric);
      } catch (e) {
        // 콜백 오류는 무시 (메트릭 수집이 앱에 영향주지 않도록)
      }
    }
    
    // 세부 통계 수집
    if (_collectDetailedStats) {
      _updateEndpointStats(endpointKey, endpoint, method, responseTime, statusCode, isSuccess);
    }
    
    // 느린 요청 로깅
    if (_logSlowRequests && responseTime > _slowRequestThreshold) {
      _logSlowRequest(endpoint, method, responseTime, statusCode);
    }
  }
  
  /// 엔드포인트 통계 업데이트
  void _updateEndpointStats(
    String endpointKey,
    String endpoint,
    String method,
    Duration responseTime,
    int statusCode,
    bool isSuccess,
  ) {
    // LRU 캐시 방식으로 메모리 관리
    if (_endpointStats.containsKey(endpointKey)) {
      // 기존 항목을 맨 뒤로 이동 (최근 사용됨)
      final stats = _endpointStats.remove(endpointKey)!;
      _endpointStats[endpointKey] = stats;
    } else {
      // 새 항목 추가
      if (_endpointStats.length >= maxEndpoints) {
        // 가장 오래된 항목 제거
        _endpointStats.remove(_endpointStats.keys.first);
      }
      _endpointStats[endpointKey] = EndpointStats(
        endpoint: endpoint,
        method: method,
      );
    }
    
    _endpointStats[endpointKey]!.addRequest(
      responseTime: responseTime,
      statusCode: statusCode,
      isSuccess: isSuccess,
    );
  }
  
  /// 엔드포인트 경로 정규화 (동적 파라미터 제거)
  String _normalizeEndpoint(String path) {
    return path
        // UUID 패턴 제거
        .replaceAll(RegExp(r'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'), '/{uuid}')
        // 숫자 ID 패턴 제거  
        .replaceAll(RegExp(r'/\d+'), '/{id}')
        // 쿼리 파라미터 제거
        .split('?').first;
  }
  
  /// 요청 크기 계산
  int? _calculateRequestSize(RequestOptions options) {
    try {
      if (options.data == null) return null;
      
      if (options.data is String) {
        return (options.data as String).length;
      } else if (options.data is List<int>) {
        return (options.data as List<int>).length;
      } else if (options.data is Map) {
        // JSON 크기 추정
        return options.data.toString().length;
      }
    } catch (e) {
      // 크기 계산 실패시 무시
    }
    return null;
  }
  
  /// 응답 크기 계산
  int? _calculateResponseSize(Response? response) {
    try {
      if (response?.data == null) return null;
      
      if (response!.data is String) {
        return (response.data as String).length;
      } else if (response.data is List<int>) {
        return (response.data as List<int>).length;
      } else if (response.data is Map || response.data is List) {
        // JSON 크기 추정
        return response.data.toString().length;
      }
    } catch (e) {
      // 크기 계산 실패시 무시
    }
    return null;
  }
  
  /// 요청 우선순위 계산
  MetricPriority _calculatePriority(Duration responseTime, bool isSuccess) {
    if (!isSuccess) return MetricPriority.high;
    if (responseTime.inSeconds > 5) return MetricPriority.high;
    if (responseTime.inSeconds > 2) return MetricPriority.medium;
    return MetricPriority.low;
  }
  
  /// 네트워크 타입 확인 (단순 구현)
  String _getNetworkType() {
    // 실제 구현에서는 connectivity_plus 패키지 사용
    return 'unknown';
  }
  
  /// 느린 요청 로깅
  void _logSlowRequest(String endpoint, String method, Duration responseTime, int statusCode) {
    developer.log('SLOW REQUEST: $method $endpoint - ${responseTime.inMilliseconds}ms (Status: $statusCode)', name: 'SlowRequest');
  }
  
  // ============================================================================
  // 공개 API - 통계 조회
  // ============================================================================
  
  /// 모든 엔드포인트 통계 조회
  Map<String, EndpointStats> getAllEndpointStats() {
    return Map.unmodifiable(_endpointStats);
  }
  
  /// 특정 엔드포인트 통계 조회
  EndpointStats? getEndpointStats(String method, String endpoint) {
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    return _endpointStats['$method $normalizedEndpoint'];
  }
  
  /// 전체 API 성능 요약
  Map<String, dynamic> getPerformanceSummary() {
    if (_endpointStats.isEmpty) {
      return {
        'totalEndpoints': 0,
        'totalRequests': 0,
        'overallSuccessRate': 0.0,
        'overallErrorRate': 0.0,
        'averageResponseTimeMs': 0,
        'slowestEndpoints': <Map<String, dynamic>>[],
        'errorProneEndpoints': <Map<String, dynamic>>[],
      };
    }
    
    int totalRequests = 0;
    int totalSuccessful = 0;
    int totalFailed = 0;
    final List<Duration> allResponseTimes = [];
    
    for (final stats in _endpointStats.values) {
      totalRequests += stats.totalRequests;
      totalSuccessful += stats.successfulRequests;
      totalFailed += stats.failedRequests;
      allResponseTimes.addAll(stats.responseTimes);
    }
    
    final overallSuccessRate = totalRequests > 0 
        ? (totalSuccessful / totalRequests) * 100.0 
        : 0.0;
    
    final overallErrorRate = totalRequests > 0 
        ? (totalFailed / totalRequests) * 100.0 
        : 0.0;
    
    final averageResponseTime = allResponseTimes.isNotEmpty
        ? allResponseTimes
            .map((d) => d.inMilliseconds)
            .reduce((a, b) => a + b) ~/ allResponseTimes.length
        : 0;
    
    // 가장 느린 엔드포인트 TOP 5
    final slowestEndpoints = _endpointStats.entries
        .map((entry) => {
          'endpoint': entry.key,
          'averageResponseTimeMs': entry.value.averageResponseTime.inMilliseconds,
          'requestCount': entry.value.totalRequests,
        })
        .toList()
      ..sort((a, b) => (b['averageResponseTimeMs'] as int)
          .compareTo(a['averageResponseTimeMs'] as int))
      ..take(5);
    
    // 에러율이 높은 엔드포인트 TOP 5
    final errorProneEndpoints = _endpointStats.entries
        .where((entry) => entry.value.errorRate > 0)
        .map((entry) => {
          'endpoint': entry.key,
          'errorRate': entry.value.errorRate,
          'requestCount': entry.value.totalRequests,
        })
        .toList()
      ..sort((a, b) => (b['errorRate'] as double)
          .compareTo(a['errorRate'] as double))
      ..take(5);
    
    return {
      'totalEndpoints': _endpointStats.length,
      'totalRequests': totalRequests,
      'overallSuccessRate': overallSuccessRate,
      'overallErrorRate': overallErrorRate,
      'averageResponseTimeMs': averageResponseTime,
      'slowestEndpoints': slowestEndpoints.toList(),
      'errorProneEndpoints': errorProneEndpoints.toList(),
      'generatedAt': DateTime.now().toIso8601String(),
    };
  }
  
  /// 상위 N개 느린 엔드포인트 조회
  List<EndpointStats> getSlowingEndpoints({int limit = 10}) {
    return _endpointStats.values
        .where((stats) => stats.totalRequests > 0)
        .toList()
      ..sort((a, b) => b.averageResponseTime.inMilliseconds
          .compareTo(a.averageResponseTime.inMilliseconds))
      ..take(limit);
  }
  
  /// 에러율이 높은 엔드포인트 조회
  List<EndpointStats> getErrorProneEndpoints({
    int limit = 10,
    double minErrorRate = 5.0,
  }) {
    return _endpointStats.values
        .where((stats) => stats.errorRate >= minErrorRate)
        .toList()
      ..sort((a, b) => b.errorRate.compareTo(a.errorRate))
      ..take(limit);
  }
  
  /// 통계 초기화
  void clearStats() {
    _endpointStats.clear();
  }
  
  /// 특정 엔드포인트 통계 초기화
  void clearEndpointStats(String method, String endpoint) {
    final normalizedEndpoint = _normalizeEndpoint(endpoint);
    _endpointStats.remove('$method $normalizedEndpoint');
  }
  
  /// JSON으로 모든 통계 내보내기
  Map<String, dynamic> exportStatsToJson() {
    return {
      'endpointStats': _endpointStats.map(
        (key, stats) => MapEntry(key, stats.toJson()),
      ),
      'summary': getPerformanceSummary(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }
}

// ============================================================================
// 확장 헬퍼 클래스
// ============================================================================

/// Dio 인스턴스에 성능 모니터링을 쉽게 추가하기 위한 확장
extension DioPerformanceExtension on Dio {
  /// 성능 모니터링 인터셉터 추가
  void addPerformanceMonitoring({
    bool logSlowRequests = true,
    Duration slowRequestThreshold = const Duration(seconds: 2),
    bool collectDetailedStats = true,
  }) {
    final interceptor = PerformanceInterceptor.instance;
    interceptor.configureSlowRequestLogging(
      enabled: logSlowRequests,
      threshold: slowRequestThreshold,
    );
    interceptor.setDetailedStatsCollection(collectDetailedStats);
    
    // 이미 추가되었는지 확인
    final hasInterceptor = interceptors.any(
      (interceptor) => interceptor is PerformanceInterceptor,
    );
    
    if (!hasInterceptor) {
      interceptors.add(interceptor);
    }
  }
  
  /// 성능 통계 조회
  Map<String, dynamic> getPerformanceStats() {
    return PerformanceInterceptor.instance.getPerformanceSummary();
  }
  
  /// 성능 모니터링 활성화/비활성화
  void setPerformanceMonitoringEnabled(bool enabled) {
    PerformanceInterceptor.instance.setEnabled(enabled);
  }
}

// ============================================================================
// 사용 예시
// ============================================================================

/// 사용 예시를 보여주는 클래스
class PerformanceInterceptorExample {
  static void demonstrateUsage() {
    final dio = Dio();
    
    // 1. 기본 사용법
    dio.addPerformanceMonitoring();
    
    // 2. 세부 설정
    dio.addPerformanceMonitoring(
      logSlowRequests: true,
      slowRequestThreshold: const Duration(seconds: 1),
      collectDetailedStats: true,
    );
    
    // 3. 메트릭 수집 콜백 등록
    PerformanceInterceptor.instance.addMetricCallback((metric) {
      developer.log('API Metric: ${metric.endpoint} - ${metric.responseTime.inMilliseconds}ms', name: 'APIMetric');
      
      // 외부 모니터링 시스템으로 전송
      // sendMetricToMonitoringSystem(metric);
    });
    
    // 4. 실시간 통계 조회
    Timer.periodic(const Duration(minutes: 5), (timer) {
      final stats = dio.getPerformanceStats();
      developer.log('API Performance Summary: $stats', name: 'APIPerformance');
    });
  }
}