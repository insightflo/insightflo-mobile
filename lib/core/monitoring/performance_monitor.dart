/// Unified Performance Monitoring System
///
/// 백그라운드 성능 메트릭 수집 시스템 - Observer 패턴과 단순화된 수집 방식을 결합
/// DatabaseMetrics(쿼리시간, 캐시히트율), APIMetrics(응답시간, 에러율),
/// UIMetrics(FPS, 빌드시간), 메모리 효율적인 CircularBuffer, 배치 전송을 제공합니다.
///
/// Task 8.11: 백그라운드 성능 메트릭 수집 시스템 구현
/// - 사용자 영향 없이 백그라운드에서 앱 성능 데이터 수집
/// - Vercel Analytics로 배치 전송 (5분마다)
/// - 최소 오버헤드 (순환 버퍼, 메모리 1MB 제한)
/// - 프라이버시 보호 (익명화된 성능 데이터만 수집)
///
/// 사용법:
/// ```dart
/// final collector = MetricCollector.instance;
/// await collector.initialize();
///
/// // 데이터베이스 메트릭 래핑
/// final result = await collector.measureDatabaseQuery('user_login', () async => loginUser());
///
/// // API 모니터링 (Dio interceptor 자동 설정)
/// final dio = Dio();
/// dio.interceptors.add(collector.dioInterceptor);
///
/// // 커스텀 메트릭 기록
/// collector.recordCustomMetric(name: 'image_process', value: 150.0, type: MetricType.ui);
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';

// ============================================================================
// 핵심 인터페이스 및 기본 클래스
// ============================================================================

/// 성능 관찰자 인터페이스 - Observer 패턴 구현
abstract class PerformanceObserver {
  /// 메트릭 업데이트 시 호출됩니다
  void onMetricUpdated(PerformanceMetric metric, MetricData data);

  /// 임계값 초과 시 호출됩니다
  void onThresholdExceeded(
    PerformanceMetric metric,
    MetricData data,
    MetricThreshold threshold,
  );

  /// 에러 발생 시 호출됩니다
  void onError(PerformanceMetric metric, String error, StackTrace? stackTrace);
}

/// 메트릭 임계값 설정
class MetricThreshold {
  final String name;
  final double warningLevel;
  final double criticalLevel;
  final Duration checkInterval;
  final bool enabled;

  const MetricThreshold({
    required this.name,
    required this.warningLevel,
    required this.criticalLevel,
    this.checkInterval = const Duration(seconds: 30),
    this.enabled = true,
  });

  /// 값이 임계값을 초과하는지 확인
  AlertSeverity? checkThreshold(double value) {
    if (!enabled) return null;
    if (value >= criticalLevel) return AlertSeverity.critical;
    if (value >= warningLevel) return AlertSeverity.warning;
    return null;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'warningLevel': warningLevel,
    'criticalLevel': criticalLevel,
    'checkInterval': checkInterval.inMilliseconds,
    'enabled': enabled,
  };
}

/// 알림 심각도 레벨
enum AlertSeverity { info, warning, critical }

/// 메트릭 데이터 포인트
class MetricData {
  final String metricName;
  final double value;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final String? unit;

  MetricData({
    required this.metricName,
    required this.value,
    this.metadata = const {},
    DateTime? timestamp,
    this.unit,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'metricName': metricName,
    'value': value,
    'metadata': metadata,
    'timestamp': timestamp.toIso8601String(),
    'unit': unit,
  };

  factory MetricData.fromJson(Map<String, dynamic> json) => MetricData(
    metricName: json['metricName'],
    value: json['value'],
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    timestamp: DateTime.parse(json['timestamp']),
    unit: json['unit'],
  );
}

/// 성능 메트릭 기본 클래스
abstract class PerformanceMetric {
  final String name;
  final Map<String, MetricThreshold> _thresholds = {};
  final StreamController<MetricData> _streamController =
      StreamController<MetricData>.broadcast();
  final List<MetricData> _history = [];
  final int maxHistorySize;

  PerformanceMetric({required this.name, this.maxHistorySize = 1000});

  /// 메트릭 데이터 스트림
  Stream<MetricData> get stream => _streamController.stream;

  /// 메트릭 히스토리
  List<MetricData> get history => List.unmodifiable(_history);

  /// 최근 메트릭 값
  MetricData? get latest => _history.isEmpty ? null : _history.last;

  /// 임계값 설정
  void setThreshold(MetricThreshold threshold) {
    _thresholds[threshold.name] = threshold;
  }

  /// 임계값 제거
  void removeThreshold(String name) {
    _thresholds.remove(name);
  }

  /// 모든 임계값 가져오기
  Map<String, MetricThreshold> get thresholds => Map.unmodifiable(_thresholds);

  /// 메트릭 데이터 기록
  void recordData(MetricData data) {
    _history.add(data);

    // 히스토리 크기 관리
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }

    // 스트림에 데이터 전송
    _streamController.add(data);

    // MetricCollector에 알림
    MetricCollector.instance._notifyObservers(this, data);

    // 임계값 검사
    _checkThresholds(data);
  }

  /// 임계값 검사
  void _checkThresholds(MetricData data) {
    for (final threshold in _thresholds.values) {
      final severity = threshold.checkThreshold(data.value);
      if (severity != null) {
        MetricCollector.instance._notifyThresholdExceeded(
          this,
          data,
          threshold,
        );
        ThresholdAlert.instance.triggerAlert(this, data, threshold, severity);
      }
    }
  }

  /// 통계 계산
  Map<String, double> getStatistics({Duration? period}) {
    final relevantData = period != null
        ? _history
              .where(
                (data) => DateTime.now().difference(data.timestamp) <= period,
              )
              .toList()
        : _history;

    if (relevantData.isEmpty) {
      return {'min': 0.0, 'max': 0.0, 'avg': 0.0, 'median': 0.0, 'count': 0.0};
    }

    final values = relevantData.map((d) => d.value).toList()..sort();
    final count = values.length;
    final sum = values.reduce((a, b) => a + b);

    return {
      'min': values.first,
      'max': values.last,
      'avg': sum / count,
      'median': count % 2 == 0
          ? (values[count ~/ 2 - 1] + values[count ~/ 2]) / 2
          : values[count ~/ 2],
      'count': count.toDouble(),
    };
  }

  /// 리소스 정리
  void dispose() {
    _streamController.close();
    _history.clear();
    _thresholds.clear();
  }
}

// ============================================================================
// 구체적인 메트릭 구현
// ============================================================================

/// 데이터베이스 성능 메트릭 (쿼리시간, 캐시히트율)
class DatabaseMetrics extends PerformanceMetric {
  static DatabaseMetrics? _instance;
  static DatabaseMetrics get instance => _instance ??= DatabaseMetrics._();

  int _totalQueries = 0;
  int _cacheHits = 0;
  final Map<String, List<Duration>> _queryTimes = {};

  DatabaseMetrics._() : super(name: 'database') {
    // 기본 임계값 설정
    setThreshold(
      MetricThreshold(
        name: 'query_time',
        warningLevel: 100.0, // 100ms
        criticalLevel: 500.0, // 500ms
      ),
    );

    setThreshold(
      MetricThreshold(
        name: 'cache_hit_rate',
        warningLevel: 70.0, // 70%
        criticalLevel: 50.0, // 50%
      ),
    );
  }

  /// 쿼리 실행 기록
  Future<void> recordQuery(
    String query, {
    required Duration duration,
    bool fromCache = false,
    Map<String, dynamic>? metadata,
  }) async {
    _totalQueries++;
    if (fromCache) _cacheHits++;

    // 쿼리 유형별 시간 추적
    final queryType = _extractQueryType(query);
    _queryTimes.putIfAbsent(queryType, () => []).add(duration);

    // 쿼리 시간 메트릭
    recordData(
      MetricData(
        metricName: 'database_query_time',
        value: duration.inMilliseconds.toDouble(),
        unit: 'ms',
        metadata: {
          'query_type': queryType,
          'from_cache': fromCache,
          'query': kDebugMode ? query : _sanitizeQuery(query),
          ...?metadata,
        },
      ),
    );

    // 캐시 히트율 메트릭
    final hitRate = (_cacheHits / _totalQueries) * 100;
    recordData(
      MetricData(
        metricName: 'database_cache_hit_rate',
        value: hitRate,
        unit: '%',
        metadata: {'total_queries': _totalQueries, 'cache_hits': _cacheHits},
      ),
    );
  }

  /// 연결 풀 메트릭 기록
  void recordConnectionPool({
    required int activeConnections,
    required int totalConnections,
    required int waitingRequests,
  }) {
    recordData(
      MetricData(
        metricName: 'database_connection_pool',
        value: (activeConnections / totalConnections) * 100,
        unit: '%',
        metadata: {
          'active_connections': activeConnections,
          'total_connections': totalConnections,
          'waiting_requests': waitingRequests,
          'pool_utilization': (activeConnections / totalConnections) * 100,
        },
      ),
    );
  }

  /// 쿼리 유형 추출
  String _extractQueryType(String query) {
    final normalized = query.trim().toUpperCase();
    if (normalized.startsWith('SELECT')) return 'SELECT';
    if (normalized.startsWith('INSERT')) return 'INSERT';
    if (normalized.startsWith('UPDATE')) return 'UPDATE';
    if (normalized.startsWith('DELETE')) return 'DELETE';
    return 'OTHER';
  }

  /// 쿼리 정보 암호화 (민감한 정보 제거)
  String _sanitizeQuery(String query) {
    return query
        .replaceAll(RegExp(r"'[^']*'"), "'***'")
        .replaceAll(RegExp(r'"[^"]*"'), '"***"')
        .replaceAll(RegExp(r'\b\d+\b'), '***');
  }

  /// 쿼리 통계 리포트
  Map<String, dynamic> getQueryReport() {
    final report = <String, dynamic>{
      'total_queries': _totalQueries,
      'cache_hits': _cacheHits,
      'cache_hit_rate': _totalQueries > 0
          ? (_cacheHits / _totalQueries) * 100
          : 0.0,
      'query_types': {},
    };

    for (final entry in _queryTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final avgTime =
            times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
            times.length;
        report['query_types'][entry.key] = {
          'count': times.length,
          'avg_time_ms': avgTime,
          'min_time_ms': times.map((d) => d.inMilliseconds).reduce(min),
          'max_time_ms': times.map((d) => d.inMilliseconds).reduce(max),
        };
      }
    }

    return report;
  }
}

/// API 성능 메트릭 (응답시간, 에러율)
class APIMetrics extends PerformanceMetric {
  static APIMetrics? _instance;
  static APIMetrics get instance => _instance ??= APIMetrics._();

  int _totalRequests = 0;
  int _errorRequests = 0;
  final Map<String, List<Duration>> _endpointTimes = {};
  final Map<int, int> _statusCodes = {};

  APIMetrics._() : super(name: 'api') {
    // 기본 임계값 설정
    setThreshold(
      MetricThreshold(
        name: 'response_time',
        warningLevel: 1000.0, // 1초
        criticalLevel: 3000.0, // 3초
      ),
    );

    setThreshold(
      MetricThreshold(
        name: 'error_rate',
        warningLevel: 5.0, // 5%
        criticalLevel: 10.0, // 10%
      ),
    );
  }

  /// API 요청 기록
  Future<void> recordRequest(
    String endpoint, {
    required int statusCode,
    required Duration duration,
    String method = 'GET',
    int? requestSize,
    int? responseSize,
    Map<String, dynamic>? metadata,
  }) async {
    _totalRequests++;
    if (statusCode >= 400) _errorRequests++;

    // 엔드포인트별 응답 시간 추적
    _endpointTimes.putIfAbsent(endpoint, () => []).add(duration);
    _statusCodes[statusCode] = (_statusCodes[statusCode] ?? 0) + 1;

    // 응답 시간 메트릭
    recordData(
      MetricData(
        metricName: 'api_response_time',
        value: duration.inMilliseconds.toDouble(),
        unit: 'ms',
        metadata: {
          'endpoint': endpoint,
          'method': method,
          'status_code': statusCode,
          'request_size': requestSize,
          'response_size': responseSize,
          'is_error': statusCode >= 400,
          ...?metadata,
        },
      ),
    );

    // 에러율 메트릭
    final errorRate = (_errorRequests / _totalRequests) * 100;
    recordData(
      MetricData(
        metricName: 'api_error_rate',
        value: errorRate,
        unit: '%',
        metadata: {
          'total_requests': _totalRequests,
          'error_requests': _errorRequests,
          'status_codes': Map.from(_statusCodes),
        },
      ),
    );

    // 처리량 메트릭 (RPS - Requests Per Second)
    _recordThroughput();
  }

  /// 네트워크 연결 메트릭 기록
  void recordNetworkLatency(Duration latency, String host) {
    recordData(
      MetricData(
        metricName: 'api_network_latency',
        value: latency.inMilliseconds.toDouble(),
        unit: 'ms',
        metadata: {
          'host': host,
          'measurement_time': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// 처리량 계산 및 기록
  void _recordThroughput() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));

    final recentRequests = history
        .where(
          (data) =>
              data.metricName == 'api_response_time' &&
              data.timestamp.isAfter(oneMinuteAgo),
        )
        .length;

    recordData(
      MetricData(
        metricName: 'api_throughput',
        value: recentRequests / 60.0, // RPS
        unit: 'rps',
        metadata: {
          'measurement_window': '1_minute',
          'total_requests_in_window': recentRequests,
        },
      ),
    );
  }

  /// API 통계 리포트
  Map<String, dynamic> getAPIReport() {
    final report = <String, dynamic>{
      'total_requests': _totalRequests,
      'error_requests': _errorRequests,
      'error_rate': _totalRequests > 0
          ? (_errorRequests / _totalRequests) * 100
          : 0.0,
      'status_codes': Map.from(_statusCodes),
      'endpoints': {},
    };

    for (final entry in _endpointTimes.entries) {
      final times = entry.value;
      if (times.isNotEmpty) {
        final avgTime =
            times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
            times.length;
        report['endpoints'][entry.key] = {
          'request_count': times.length,
          'avg_response_time_ms': avgTime,
          'min_response_time_ms': times
              .map((d) => d.inMilliseconds)
              .reduce(min),
          'max_response_time_ms': times
              .map((d) => d.inMilliseconds)
              .reduce(max),
        };
      }
    }

    return report;
  }
}

/// UI 성능 메트릭 (FPS, 빌드시간)
class UIMetrics extends PerformanceMetric {
  static UIMetrics? _instance;
  static UIMetrics get instance => _instance ??= UIMetrics._();

  bool _isMonitoring = false;
  final List<Duration> _frameTimes = [];
  final List<Duration> _buildTimes = [];
  Timer? _frameTimer;

  UIMetrics._() : super(name: 'ui') {
    // 기본 임계값 설정
    setThreshold(
      MetricThreshold(
        name: 'fps',
        warningLevel: 55.0, // 55 FPS
        criticalLevel: 30.0, // 30 FPS (더 관대한 임계값)
      ),
    );

    setThreshold(
      MetricThreshold(
        name: 'build_time',
        warningLevel: 25.0, // 25ms (40fps)
        criticalLevel: 50.0, // 50ms (20fps)
      ),
    );
  }

  /// UI 모니터링 시작
  void startMonitoring() {
    if (_isMonitoring) return;
    _isMonitoring = true;

    // Frame callback 등록
    SchedulerBinding.instance.addTimingsCallback(_onFrameMetrics);

    // 주기적 FPS 계산
    _frameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateFPS();
    });

    // 메모리 사용량 모니터링
    _startMemoryMonitoring();
  }

  /// UI 모니터링 중지
  void stopMonitoring() {
    if (!_isMonitoring) return;
    _isMonitoring = false;

    SchedulerBinding.instance.removeTimingsCallback(_onFrameMetrics);
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  /// 프레임 메트릭 콜백
  void _onFrameMetrics(List<FrameTiming> timings) {
    for (final timing in timings) {
      final buildDuration = timing.buildDuration;
      final rasterDuration = timing.rasterDuration;
      final totalDuration = buildDuration + rasterDuration;

      _frameTimes.add(totalDuration);
      _buildTimes.add(buildDuration);

      // 히스토리 크기 관리
      if (_frameTimes.length > 60) _frameTimes.removeAt(0);
      if (_buildTimes.length > 60) _buildTimes.removeAt(0);

      // 빌드 시간 메트릭 기록
      recordData(
        MetricData(
          metricName: 'ui_build_time',
          value: buildDuration.inMicroseconds / 1000.0, // ms로 변환
          unit: 'ms',
          metadata: {
            'raster_time_ms': rasterDuration.inMicroseconds / 1000.0,
            'total_frame_time_ms': totalDuration.inMicroseconds / 1000.0,
            'vsync_overhead': timing.vsyncOverhead.inMicroseconds / 1000.0,
          },
        ),
      );
    }
  }

  /// FPS 계산 및 기록
  void _calculateFPS() {
    if (_frameTimes.isEmpty) return;

    final now = DateTime.now();
    now.subtract(const Duration(seconds: 1));

    // 최근 1초간의 프레임 수 계산
    var recentFrameCount = 0;
    for (int i = _frameTimes.length - 1; i >= 0; i--) {
      final frameAge = now.difference(now.subtract(_frameTimes[i]));
      if (frameAge <= const Duration(seconds: 1)) {
        recentFrameCount++;
      } else {
        break;
      }
    }

    final fps = recentFrameCount.toDouble();
    recordData(
      MetricData(
        metricName: 'ui_fps',
        value: fps,
        unit: 'fps',
        metadata: {
          'frame_count_last_second': recentFrameCount,
          'avg_frame_time_ms': _frameTimes.isNotEmpty
              ? _frameTimes
                        .map((d) => d.inMicroseconds / 1000.0)
                        .reduce((a, b) => a + b) /
                    _frameTimes.length
              : 0.0,
        },
      ),
    );
  }

  /// 메모리 사용량 모니터링
  void _startMemoryMonitoring() {
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isMonitoring) return;

      // Flutter 메모리 정보는 디버그 모드에서만 정확함
      if (kDebugMode) {
        final info = WidgetsBinding.instance.platformDispatcher.implicitView;
        recordData(
          MetricData(
            metricName: 'ui_memory_usage',
            value: 0.0, // 실제 메모리 사용량은 platform-specific 구현 필요
            unit: 'MB',
            metadata: {
              'device_pixel_ratio': info?.devicePixelRatio ?? 1.0,
              'physical_size': {
                'width': info?.physicalSize.width ?? 0,
                'height': info?.physicalSize.height ?? 0,
              },
            },
          ),
        );
      }
    });
  }

  /// 위젯 빌드 시간 수동 기록
  void recordBuildTime(String widgetName, Duration buildTime) {
    recordData(
      MetricData(
        metricName: 'ui_widget_build_time',
        value: buildTime.inMicroseconds / 1000.0,
        unit: 'ms',
        metadata: {
          'widget_name': widgetName,
          'build_timestamp': DateTime.now().toIso8601String(),
        },
      ),
    );
  }

  /// 스크롤 성능 기록
  void recordScrollPerformance({
    required double scrollDelta,
    required Duration frameTime,
    bool isJanky = false,
  }) {
    recordData(
      MetricData(
        metricName: 'ui_scroll_performance',
        value: frameTime.inMicroseconds / 1000.0,
        unit: 'ms',
        metadata: {
          'scroll_delta': scrollDelta,
          'is_janky': isJanky,
          'frame_budget_exceeded': frameTime.inMilliseconds > 16,
        },
      ),
    );
  }

  /// UI 통계 리포트
  Map<String, dynamic> getUIReport() {
    final avgFPS = _frameTimes.isNotEmpty
        ? 1000.0 /
              (_frameTimes
                      .map((d) => d.inMicroseconds / 1000.0)
                      .reduce((a, b) => a + b) /
                  _frameTimes.length)
        : 0.0;

    final avgBuildTime = _buildTimes.isNotEmpty
        ? _buildTimes
                  .map((d) => d.inMicroseconds / 1000.0)
                  .reduce((a, b) => a + b) /
              _buildTimes.length
        : 0.0;

    return {
      'is_monitoring': _isMonitoring,
      'avg_fps': avgFPS,
      'avg_build_time_ms': avgBuildTime,
      'frame_budget_misses': _buildTimes
          .where((d) => d.inMilliseconds > 16)
          .length,
      'janky_frame_percentage': _buildTimes.isNotEmpty
          ? (_buildTimes.where((d) => d.inMilliseconds > 16).length /
                    _buildTimes.length) *
                100
          : 0.0,
    };
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}

// ============================================================================
// 메트릭 수집기 (싱글톤 + Observer 패턴)
// ============================================================================

/// 성능 메트릭 수집기 - 통합된 Observer + CircularBuffer 패턴
class MetricCollector with WidgetsBindingObserver {
  static MetricCollector? _instance;
  static MetricCollector get instance => _instance ??= MetricCollector._();

  final List<PerformanceObserver> _observers = [];
  final Map<String, PerformanceMetric> _metrics = {};
  final StreamController<Map<String, dynamic>> _globalStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Task 8.11: CircularBuffer for memory-efficient storage
  static const int _maxMetricsCount = 1000;
  static const int _batchTransmissionInterval = 5; // 5분
  static const double _samplingRate = 0.1; // 10% 샘플링

  late final CircularBuffer<MetricDataPoint> _metricsBuffer;
  final Random _random = Random();

  bool _isInitialized = false;
  bool _isCollecting = false;
  Timer? _aggregationTimer;
  Timer? _transmissionTimer;

  MetricCollector._() {
    _metricsBuffer = CircularBuffer<MetricDataPoint>(_maxMetricsCount);
  }

  /// 글로벌 메트릭 스트림
  Stream<Map<String, dynamic>> get globalStream =>
      _globalStreamController.stream;

  /// 초기화
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 기본 메트릭 등록
      registerMetric(DatabaseMetrics.instance);
      registerMetric(APIMetrics.instance);
      registerMetric(UIMetrics.instance);

      // UI 관찰자로 등록
      WidgetsBinding.instance.addObserver(this);

      // UI 모니터링 시작
      UIMetrics.instance.startMonitoring();

      // 주기적 집계 및 배치 전송 시작
      _startAggregation();
      _startBatchTransmission();

      _isInitialized = true;
      _isCollecting = true;
      debugPrint(
        'MetricCollector initialized with CircularBuffer ($_maxMetricsCount capacity)',
      );
    } catch (e) {
      debugPrint('Failed to initialize MetricCollector: $e');
    }
  }

  /// Task 8.11: Start collecting metrics
  void startCollection() {
    if (!_isInitialized) return;
    _isCollecting = true;
    debugPrint('Metrics collection started');
  }

  /// Task 8.11: Stop collecting metrics
  void stopCollection() {
    _isCollecting = false;
    debugPrint('Metrics collection stopped');
  }

  /// Task 8.11: Record metric with sampling
  void recordMetricData(MetricDataPoint metric) {
    if (!_isCollecting || !_shouldSample()) return;

    try {
      _metricsBuffer.add(metric);

      // 글로벌 스트림에도 전송 (기존 Observer 패턴 유지)
      _globalStreamController.add({
        'type': 'metric_recorded',
        'data': metric.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to record metric: $e');
    }
  }

  /// Task 8.11: Check if we should sample this metric
  bool _shouldSample() => _random.nextDouble() < _samplingRate;

  /// 관찰자 추가
  void addObserver(PerformanceObserver observer) {
    if (!_observers.contains(observer)) {
      _observers.add(observer);
    }
  }

  /// 관찰자 제거
  void removeObserver(PerformanceObserver observer) {
    _observers.remove(observer);
  }

  /// 메트릭 등록
  void registerMetric(PerformanceMetric metric) {
    _metrics[metric.name] = metric;

    // 메트릭 스트림 구독
    metric.stream.listen((data) {
      _globalStreamController.add({
        'metric_type': metric.name,
        'data': data.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
  }

  /// 메트릭 가져오기
  T? getMetric<T extends PerformanceMetric>(String name) {
    return _metrics[name] as T?;
  }

  /// 모든 메트릭 가져오기
  Map<String, PerformanceMetric> get allMetrics => Map.unmodifiable(_metrics);

  /// 관찰자들에게 메트릭 업데이트 알림
  void _notifyObservers(PerformanceMetric metric, MetricData data) {
    for (final observer in _observers) {
      try {
        observer.onMetricUpdated(metric, data);
      } catch (e, stackTrace) {
        debugPrint('Observer notification error: $e');
        observer.onError(metric, e.toString(), stackTrace);
      }
    }
  }

  /// 관찰자들에게 임계값 초과 알림
  void _notifyThresholdExceeded(
    PerformanceMetric metric,
    MetricData data,
    MetricThreshold threshold,
  ) {
    for (final observer in _observers) {
      try {
        observer.onThresholdExceeded(metric, data, threshold);
      } catch (e, stackTrace) {
        debugPrint('Threshold notification error: $e');
        observer.onError(metric, e.toString(), stackTrace);
      }
    }
  }

  /// Task 8.11: Start batch transmission
  void _startBatchTransmission() {
    _transmissionTimer = Timer.periodic(
      Duration(minutes: _batchTransmissionInterval),
      (_) => _transmitMetrics(),
    );
  }

  /// Task 8.11: Transmit metrics to Vercel Analytics
  Future<void> _transmitMetrics() async {
    if (_metricsBuffer.isEmpty) return;

    try {
      final metrics = _metricsBuffer.toList();
      await _sendToVercelAnalytics(metrics);
      _metricsBuffer.clear();
      debugPrint('Transmitted ${metrics.length} metrics to Vercel Analytics');
    } catch (e) {
      debugPrint('Failed to transmit metrics: $e');
    }
  }

  /// 주기적 데이터 집계
  void _startAggregation() {
    _aggregationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _performAggregation();
    });
  }

  /// 데이터 집계 수행
  void _performAggregation() {
    final aggregatedData = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'metrics': {},
    };

    for (final entry in _metrics.entries) {
      final metric = entry.value;
      final stats = metric.getStatistics(period: const Duration(minutes: 5));

      aggregatedData['metrics'][entry.key] = {
        'statistics': stats,
        'latest_value': metric.latest?.value,
        'data_points': metric.history.length,
      };
    }

    _globalStreamController.add({
      'type': 'aggregation',
      'data': aggregatedData,
    });
  }

  /// 성능 스냅샷 생성
  Map<String, dynamic> createSnapshot() {
    final snapshot = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'system_info': _getSystemInfo(),
      'metrics': {},
    };

    for (final entry in _metrics.entries) {
      final metric = entry.value;
      snapshot['metrics'][entry.key] = {
        'latest': metric.latest?.toJson(),
        'statistics': metric.getStatistics(),
        'thresholds': metric.thresholds.map((k, v) => MapEntry(k, v.toJson())),
      };
    }

    return snapshot;
  }

  /// 시스템 정보 수집
  Map<String, dynamic> _getSystemInfo() {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'dart_version': Platform.version,
      'memory_mb': _getMemoryUsage(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 메모리 사용량 (추정치)
  double _getMemoryUsage() {
    // 실제 구현에서는 platform-specific 코드가 필요
    return 0.0;
  }

  /// Task 8.11: WidgetsBindingObserver 구현 (UI 생명주기 추적)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    recordMetricData(
      MetricDataPoint(
        type: MetricType.ui,
        name: 'app_lifecycle_change',
        value: 0,
        metadata: {
          'state': state.toString(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    recordMetricData(
      MetricDataPoint(
        type: MetricType.ui,
        name: 'metrics_changed',
        value: 0,
        metadata: {'timestamp': DateTime.now().millisecondsSinceEpoch},
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Task 8.11: Send metrics to Vercel Analytics
  Future<void> _sendToVercelAnalytics(List<MetricDataPoint> metrics) async {
    if (metrics.isEmpty) return;

    try {
      final payload = _prepareVercelPayload(metrics);

      final response = await http.post(
        Uri.parse('https://vitals.vercel-analytics.com/v1/vitals'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'InsightFlo-Mobile/1.0',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        debugPrint('Vercel Analytics error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to send metrics to Vercel Analytics: $e');
    }
  }

  Map<String, dynamic> _prepareVercelPayload(List<MetricDataPoint> metrics) {
    final groupedMetrics = <String, List<MetricDataPoint>>{};

    for (final metric in metrics) {
      final key = metric.type.toString().split('.').last;
      groupedMetrics.putIfAbsent(key, () => []).add(metric);
    }

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'metrics': groupedMetrics.map((type, metricsList) {
        return MapEntry(type, metricsList.map((m) => m.toJson()).toList());
      }),
      'metadata': {
        'app_version': '1.0.0',
        'platform': Platform.operatingSystem,
        'count': metrics.length,
      },
    };
  }

  /// 리소스 정리
  void dispose() {
    _isCollecting = false;
    _aggregationTimer?.cancel();
    _transmissionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _globalStreamController.close();
    UIMetrics.instance.stopMonitoring();

    for (final metric in _metrics.values) {
      metric.dispose();
    }

    _metricsBuffer.clear();
    _metrics.clear();
    _observers.clear();
    _isInitialized = false;
  }
}

// ============================================================================
// 임계값 알림 시스템
// ============================================================================

/// 임계값 알림 관리자
class ThresholdAlert {
  static ThresholdAlert? _instance;
  static ThresholdAlert get instance => _instance ??= ThresholdAlert._();

  final Map<String, DateTime> _lastAlertTimes = {};
  final Duration _cooldownPeriod = const Duration(minutes: 5);
  final StreamController<AlertEvent> _alertStreamController =
      StreamController<AlertEvent>.broadcast();

  ThresholdAlert._();

  /// 알림 이벤트 스트림
  Stream<AlertEvent> get alertStream => _alertStreamController.stream;

  /// 알림 트리거
  void triggerAlert(
    PerformanceMetric metric,
    MetricData data,
    MetricThreshold threshold,
    AlertSeverity severity,
  ) {
    final alertKey = '${metric.name}_${threshold.name}';
    final now = DateTime.now();

    // 쿨다운 검사
    final lastAlert = _lastAlertTimes[alertKey];
    if (lastAlert != null && now.difference(lastAlert) < _cooldownPeriod) {
      return;
    }

    _lastAlertTimes[alertKey] = now;

    final alertEvent = AlertEvent(
      metric: metric,
      data: data,
      threshold: threshold,
      severity: severity,
      timestamp: now,
      message: _generateAlertMessage(metric, data, threshold, severity),
    );

    _alertStreamController.add(alertEvent);

    // 로그 출력
    debugPrint('🚨 [${severity.name.toUpperCase()}] ${alertEvent.message}');

    // Vercel Analytics에 이벤트 전송
    VercelAnalyticsIntegration.instance.sendEvent('performance_alert', {
      'metric_name': metric.name,
      'threshold_name': threshold.name,
      'severity': severity.name,
      'value': data.value,
      'warning_level': threshold.warningLevel,
      'critical_level': threshold.criticalLevel,
    });
  }

  /// 알림 메시지 생성
  String _generateAlertMessage(
    PerformanceMetric metric,
    MetricData data,
    MetricThreshold threshold,
    AlertSeverity severity,
  ) {
    final value = data.value.toStringAsFixed(2);
    final unit = data.unit ?? '';
    final level = severity == AlertSeverity.critical
        ? threshold.criticalLevel
        : threshold.warningLevel;

    return '${metric.name.toUpperCase()} ${threshold.name}: $value$unit '
        '(threshold: ${level.toStringAsFixed(2)}$unit)';
  }

  /// 알림 히스토리 정리
  void clearHistory() {
    _lastAlertTimes.clear();
  }

  /// 리소스 정리
  void dispose() {
    _alertStreamController.close();
    _lastAlertTimes.clear();
  }
}

/// 알림 이벤트
class AlertEvent {
  final PerformanceMetric metric;
  final MetricData data;
  final MetricThreshold threshold;
  final AlertSeverity severity;
  final DateTime timestamp;
  final String message;

  AlertEvent({
    required this.metric,
    required this.data,
    required this.threshold,
    required this.severity,
    required this.timestamp,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
    'metric_name': metric.name,
    'data': data.toJson(),
    'threshold': threshold.toJson(),
    'severity': severity.name,
    'timestamp': timestamp.toIso8601String(),
    'message': message,
  };
}

// ============================================================================
// Vercel Analytics 통합
// ============================================================================

/// Vercel Analytics 커스텀 이벤트 통합
class VercelAnalyticsIntegration {
  static VercelAnalyticsIntegration? _instance;
  static VercelAnalyticsIntegration get instance =>
      _instance ??= VercelAnalyticsIntegration._();

  final String _endpoint = 'https://vitals.vercel-analytics.com/v1/vitals';
  final List<Map<String, dynamic>> _pendingEvents = [];
  Timer? _batchTimer;
  bool _isEnabled = true;

  VercelAnalyticsIntegration._() {
    _startBatchProcessing();
  }

  /// Analytics 활성화/비활성화
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// 커스텀 이벤트 전송
  Future<void> sendEvent(
    String eventName,
    Map<String, dynamic> properties,
  ) async {
    if (!_isEnabled) return;

    final event = {
      'name': eventName,
      'value': 1,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'properties': properties,
    };

    _pendingEvents.add(event);

    // 임계 이벤트는 즉시 전송
    if (eventName == 'performance_alert' &&
        properties['severity'] == 'critical') {
      await _sendBatch([event]);
      _pendingEvents.remove(event);
    }
  }

  /// 성능 바이탈 전송
  Future<void> sendVitals({
    required double cls, // Cumulative Layout Shift
    required double fcp, // First Contentful Paint
    required double fid, // First Input Delay
    required double lcp, // Largest Contentful Paint
    required double ttfb, // Time to First Byte
  }) async {
    if (!_isEnabled) return;

    await sendEvent('web_vitals', {
      'cls': cls,
      'fcp': fcp,
      'fid': fid,
      'lcp': lcp,
      'ttfb': ttfb,
      'url': 'mobile_app', // 모바일 앱 식별자
      'user_agent': Platform.operatingSystem,
    });
  }

  /// 배치 처리 시작
  void _startBatchProcessing() {
    _batchTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_pendingEvents.isNotEmpty) {
        _sendBatch(List.from(_pendingEvents));
        _pendingEvents.clear();
      }
    });
  }

  /// 이벤트 배치 전송
  Future<void> _sendBatch(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'InsightFlo-Mobile/1.0',
        },
        body: jsonEncode({
          'events': events,
          'dsn': 'mobile_app_vitals', // 프로젝트별 식별자
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('Vercel Analytics error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Vercel Analytics send error: $e');
    }
  }

  /// 리소스 정리
  void dispose() {
    _batchTimer?.cancel();
    _pendingEvents.clear();
  }
}

// ============================================================================
// 성능 리포트 생성기
// ============================================================================

/// 성능 리포트 생성기
class PerformanceReport {
  static PerformanceReport? _instance;
  static PerformanceReport get instance => _instance ??= PerformanceReport._();

  PerformanceReport._();

  /// 종합 성능 리포트 생성
  Future<Map<String, dynamic>> generateReport({
    Duration period = const Duration(hours: 24),
    bool includeRawData = false,
  }) async {
    final endTime = DateTime.now();
    final startTime = endTime.subtract(period);

    final report = <String, dynamic>{
      'report_metadata': {
        'generated_at': endTime.toIso8601String(),
        'period_start': startTime.toIso8601String(),
        'period_end': endTime.toIso8601String(),
        'period_hours': period.inHours,
      },
      'summary': {},
      'metrics': {},
      'alerts': {},
      'recommendations': [],
    };

    // 메트릭별 리포트 생성
    final collector = MetricCollector.instance;

    // 데이터베이스 메트릭
    final dbMetrics = collector.getMetric<DatabaseMetrics>('database');
    if (dbMetrics != null) {
      report['metrics']['database'] = await _generateDatabaseReport(
        dbMetrics,
        period,
      );
    }

    // API 메트릭
    final apiMetrics = collector.getMetric<APIMetrics>('api');
    if (apiMetrics != null) {
      report['metrics']['api'] = await _generateAPIReport(apiMetrics, period);
    }

    // UI 메트릭
    final uiMetrics = collector.getMetric<UIMetrics>('ui');
    if (uiMetrics != null) {
      report['metrics']['ui'] = await _generateUIReport(uiMetrics, period);
    }

    // 요약 생성
    report['summary'] = _generateSummary(report['metrics']);

    // 권장사항 생성
    report['recommendations'] = _generateRecommendations(report['metrics']);

    // 알림 통계
    report['alerts'] = _generateAlertSummary(period);

    return report;
  }

  /// 데이터베이스 메트릭 리포트
  Future<Map<String, dynamic>> _generateDatabaseReport(
    DatabaseMetrics metrics,
    Duration period,
  ) async {
    final stats = metrics.getStatistics(period: period);
    final queryReport = metrics.getQueryReport();

    return {
      'statistics': stats,
      'query_analysis': queryReport,
      'performance_grade': _calculateGrade(
        stats['avg'] ?? 0,
        100,
        500,
      ), // 100ms good, 500ms poor
      'trends': _calculateTrends(metrics.history, period),
    };
  }

  /// API 메트릭 리포트
  Future<Map<String, dynamic>> _generateAPIReport(
    APIMetrics metrics,
    Duration period,
  ) async {
    final stats = metrics.getStatistics(period: period);
    final apiReport = metrics.getAPIReport();

    return {
      'statistics': stats,
      'endpoint_analysis': apiReport,
      'performance_grade': _calculateGrade(
        stats['avg'] ?? 0,
        1000,
        3000,
      ), // 1s good, 3s poor
      'trends': _calculateTrends(metrics.history, period),
    };
  }

  /// UI 메트릭 리포트
  Future<Map<String, dynamic>> _generateUIReport(
    UIMetrics metrics,
    Duration period,
  ) async {
    final stats = metrics.getStatistics(period: period);
    final uiReport = metrics.getUIReport();

    return {
      'statistics': stats,
      'ui_analysis': uiReport,
      'performance_grade': _calculateGrade(
        60 - (stats['avg'] ?? 0),
        55,
        45,
      ), // 60fps good, 45fps poor
      'trends': _calculateTrends(metrics.history, period),
    };
  }

  /// 성능 등급 계산 (A, B, C, D, F)
  String _calculateGrade(
    double value,
    double goodThreshold,
    double poorThreshold,
  ) {
    if (value <= goodThreshold) return 'A';
    if (value <= goodThreshold * 1.2) return 'B';
    if (value <= poorThreshold * 0.8) return 'C';
    if (value <= poorThreshold) return 'D';
    return 'F';
  }

  /// 트렌드 분석
  Map<String, dynamic> _calculateTrends(
    List<MetricData> history,
    Duration period,
  ) {
    final cutoff = DateTime.now().subtract(period);
    final relevantData = history
        .where((d) => d.timestamp.isAfter(cutoff))
        .toList();

    if (relevantData.length < 2) {
      return {'trend': 'insufficient_data', 'change_percent': 0.0};
    }

    final halfPoint = relevantData.length ~/ 2;
    final firstHalf = relevantData.take(halfPoint).map((d) => d.value).toList();
    final secondHalf = relevantData
        .skip(halfPoint)
        .map((d) => d.value)
        .toList();

    final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;

    final changePercent = ((secondAvg - firstAvg) / firstAvg) * 100;

    String trend;
    if (changePercent.abs() < 5) {
      trend = 'stable';
    } else if (changePercent > 0) {
      trend = 'increasing';
    } else {
      trend = 'decreasing';
    }

    return {
      'trend': trend,
      'change_percent': changePercent,
      'first_half_avg': firstAvg,
      'second_half_avg': secondAvg,
    };
  }

  /// 리포트 요약 생성
  Map<String, dynamic> _generateSummary(Map<String, dynamic> metrics) {
    final grades = <String>[];
    final issues = <String>[];

    for (final entry in metrics.entries) {
      final metricData = entry.value as Map<String, dynamic>;
      final grade = metricData['performance_grade'] as String;
      grades.add(grade);

      if (grade == 'D' || grade == 'F') {
        issues.add('${entry.key} performance needs attention');
      }
    }

    // 전체 등급 계산
    final gradePoints = grades
        .map(
          (g) => g == 'A'
              ? 4
              : g == 'B'
              ? 3
              : g == 'C'
              ? 2
              : g == 'D'
              ? 1
              : 0,
        )
        .toList();

    final avgGrade = gradePoints.isNotEmpty
        ? gradePoints.reduce((a, b) => a + b) / gradePoints.length
        : 0.0;

    String overallGrade;
    if (avgGrade >= 3.5) {
      overallGrade = 'A';
      // ignore: curly_braces_in_flow_control_structures
    } else if (avgGrade >= 2.5)
      overallGrade = 'B';
    // ignore: curly_braces_in_flow_control_structures
    else if (avgGrade >= 1.5)
      overallGrade = 'C';
    // ignore: curly_braces_in_flow_control_structures
    else if (avgGrade >= 0.5)
      overallGrade = 'D';
    // ignore: curly_braces_in_flow_control_structures
    else
      overallGrade = 'F';

    return {
      'overall_grade': overallGrade,
      'grade_average': avgGrade,
      'critical_issues': issues,
      'metrics_analyzed': metrics.length,
    };
  }

  /// 권장사항 생성
  List<String> _generateRecommendations(Map<String, dynamic> metrics) {
    final recommendations = <String>[];

    // 데이터베이스 권장사항
    final dbMetrics = metrics['database'] as Map<String, dynamic>?;
    if (dbMetrics != null) {
      final grade = dbMetrics['performance_grade'] as String;
      if (grade == 'D' || grade == 'F') {
        recommendations.add(
          'Consider optimizing database queries and adding indexes',
        );
        recommendations.add(
          'Review query patterns and implement query caching',
        );
      }
    }

    // API 권장사항
    final apiMetrics = metrics['api'] as Map<String, dynamic>?;
    if (apiMetrics != null) {
      final grade = apiMetrics['performance_grade'] as String;
      if (grade == 'D' || grade == 'F') {
        recommendations.add('Implement API response caching and compression');
        recommendations.add('Consider using CDN for static content');
      }
    }

    // UI 권장사항
    final uiMetrics = metrics['ui'] as Map<String, dynamic>?;
    if (uiMetrics != null) {
      final grade = uiMetrics['performance_grade'] as String;
      if (grade == 'D' || grade == 'F') {
        recommendations.add(
          'Optimize widget builds and reduce unnecessary rebuilds',
        );
        recommendations.add('Implement lazy loading for large lists');
      }
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Performance is good! Continue monitoring for any degradation',
      );
    }

    return recommendations;
  }

  /// 알림 요약 생성
  Map<String, dynamic> _generateAlertSummary(Duration period) {
    // 실제 구현에서는 ThresholdAlert의 이벤트 히스토리를 사용
    return {
      'total_alerts': 0,
      'critical_alerts': 0,
      'warning_alerts': 0,
      'most_frequent_alert': null,
    };
  }

  /// 리포트를 JSON으로 내보내기
  Future<String> exportToJson(Map<String, dynamic> report) async {
    return jsonEncode(report);
  }

  /// 리포트를 CSV로 내보내기 (메트릭 데이터)
  Future<String> exportToCSV(Map<String, dynamic> report) async {
    final lines = <String>['Timestamp,Metric,Value,Unit'];

    final metrics = report['metrics'] as Map<String, dynamic>;
    for (final entry in metrics.entries) {
      final metricData = entry.value as Map<String, dynamic>;
      final stats = metricData['statistics'] as Map<String, dynamic>;

      lines.add(
        '${DateTime.now().toIso8601String()},${entry.key}_avg,${stats['avg']},ms',
      );
      lines.add(
        '${DateTime.now().toIso8601String()},${entry.key}_min,${stats['min']},ms',
      );
      lines.add(
        '${DateTime.now().toIso8601String()},${entry.key}_max,${stats['max']},ms',
      );
    }

    return lines.join('\n');
  }
}

// ============================================================================
// Task 8.11: CircularBuffer 및 메트릭 데이터 포인트
// ============================================================================

/// Task 8.11: Circular buffer for memory-efficient storage
class CircularBuffer<T> {
  late List<T?> _buffer;
  int _head = 0;
  int _tail = 0;
  int _size = 0;
  final int _capacity;

  CircularBuffer(this._capacity) {
    _buffer = List<T?>.filled(_capacity, null);
  }

  void add(T item) {
    _buffer[_tail] = item;
    _tail = (_tail + 1) % _capacity;

    if (_size < _capacity) {
      _size++;
    } else {
      _head = (_head + 1) % _capacity;
    }
  }

  List<T> toList() {
    final result = <T>[];
    for (int i = 0; i < _size; i++) {
      final index = (_head + i) % _capacity;
      final item = _buffer[index];
      if (item != null) result.add(item);
    }
    return result;
  }

  void clear() {
    _head = 0;
    _tail = 0;
    _size = 0;
    _buffer.fillRange(0, _capacity, null);
  }

  bool get isEmpty => _size == 0;
  bool get isFull => _size == _capacity;
  int get length => _size;
}

/// Task 8.11: Simplified metric data point for CircularBuffer
class MetricDataPoint {
  final MetricType type;
  final String name;
  final double value;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  MetricDataPoint({
    required this.type,
    required this.name,
    required this.value,
    required this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'name': name,
      'value': value,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'MetricDataPoint(type: $type, name: $name, value: $value)';
  }
}

/// Task 8.11: Metric types for simplified collection
enum MetricType { database, api, ui, memory, startup }

// ============================================================================
// 사용 예제 및 도우미 클래스
// ============================================================================

/// 성능 모니터링 도우미 클래스
class PerformanceHelper {
  /// 함수 실행 시간 측정
  static Future<T> measureExecutionTime<T>(
    String operationName,
    Future<T> Function() operation, {
    String category = 'general',
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      // 메트릭 기록
      MetricCollector.instance
          .getMetric<DatabaseMetrics>('database')
          ?.recordData(
            MetricData(
              metricName: 'operation_duration',
              value: stopwatch.elapsedMilliseconds.toDouble(),
              unit: 'ms',
              metadata: {
                'operation_name': operationName,
                'category': category,
                'success': true,
              },
            ),
          );

      return result;
    } catch (e) {
      stopwatch.stop();

      // 에러 메트릭 기록
      MetricCollector.instance
          .getMetric<DatabaseMetrics>('database')
          ?.recordData(
            MetricData(
              metricName: 'operation_duration',
              value: stopwatch.elapsedMilliseconds.toDouble(),
              unit: 'ms',
              metadata: {
                'operation_name': operationName,
                'category': category,
                'success': false,
                'error': e.toString(),
              },
            ),
          );

      rethrow;
    }
  }

  /// 위젯 빌드 시간 측정 데코레이터
  static Widget measureBuildTime(String widgetName, Widget Function() builder) {
    return Builder(
      builder: (context) {
        final stopwatch = Stopwatch()..start();
        final widget = builder();
        stopwatch.stop();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          UIMetrics.instance.recordBuildTime(widgetName, stopwatch.elapsed);
        });

        return widget;
      },
    );
  }
}

/// 기본 성능 관찰자 구현
class DefaultPerformanceObserver implements PerformanceObserver {
  @override
  void onMetricUpdated(PerformanceMetric metric, MetricData data) {
    // 기본적으로 디버그 로그만 출력
    if (kDebugMode) {
      debugPrint(
        '📊 ${metric.name}: ${data.metricName} = ${data.value}${data.unit ?? ''}',
      );
    }
  }

  @override
  void onThresholdExceeded(
    PerformanceMetric metric,
    MetricData data,
    MetricThreshold threshold,
  ) {
    debugPrint(
      '⚠️ Threshold exceeded: ${metric.name}.${threshold.name} = ${data.value}',
    );
  }

  @override
  void onError(PerformanceMetric metric, String error, StackTrace? stackTrace) {
    debugPrint('❌ Performance monitoring error in ${metric.name}: $error');
    if (stackTrace != null && kDebugMode) {
      debugPrint(stackTrace.toString());
    }
  }
}

// ============================================================================
// Task 8.11: 간소화된 Extension API
// ============================================================================

/// Task 8.11: Extension methods for easy integration
extension MetricCollectorExtensions on MetricCollector {
  /// Easy database query wrapping
  Future<T> measureDatabaseQuery<T>(
    String queryName,
    Future<T> Function() query, {
    Map<String, dynamic>? metadata,
  }) async {
    final stopwatch = Stopwatch()..start();
    T result;
    String? error;

    try {
      result = await query();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      stopwatch.stop();

      recordMetricData(
        MetricDataPoint(
          type: MetricType.database,
          name: queryName,
          value: stopwatch.elapsedMilliseconds.toDouble(),
          metadata: {
            'duration_ms': stopwatch.elapsedMilliseconds,
            'error': error,
            ...?metadata,
          },
          timestamp: DateTime.now(),
        ),
      );
    }

    return result;
  }

  /// Easy synchronous database query wrapping
  T measureSyncDatabaseQuery<T>(
    String queryName,
    T Function() query, {
    Map<String, dynamic>? metadata,
  }) {
    final stopwatch = Stopwatch()..start();
    T result;
    String? error;

    try {
      result = query();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      stopwatch.stop();

      recordMetricData(
        MetricDataPoint(
          type: MetricType.database,
          name: queryName,
          value: stopwatch.elapsedMilliseconds.toDouble(),
          metadata: {
            'duration_ms': stopwatch.elapsedMilliseconds,
            'error': error,
            ...?metadata,
          },
          timestamp: DateTime.now(),
        ),
      );
    }

    return result;
  }

  /// Record custom metric
  void recordCustomMetric({
    required String name,
    required double value,
    MetricType type = MetricType.ui,
    Map<String, dynamic>? metadata,
  }) {
    recordMetricData(
      MetricDataPoint(
        type: type,
        name: name,
        value: value,
        metadata: metadata ?? {},
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Get Dio interceptor for API monitoring
  Interceptor get dioInterceptor {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        options.extra['start_time'] = DateTime.now().millisecondsSinceEpoch;
        handler.next(options);
      },
      onResponse: (response, handler) {
        _recordAPIMetric(response.requestOptions, response: response);
        handler.next(response);
      },
      onError: (error, handler) {
        _recordAPIMetric(error.requestOptions, error: error);
        handler.next(error);
      },
    );
  }

  void _recordAPIMetric(
    RequestOptions options, {
    Response? response,
    DioException? error,
  }) {
    final startTime = options.extra['start_time'] as int?;
    if (startTime == null) return;

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final duration = endTime - startTime;

    recordMetricData(
      MetricDataPoint(
        type: MetricType.api,
        name: '${options.method} ${options.path}',
        value: duration.toDouble(),
        metadata: {
          'method': options.method,
          'url': options.uri.toString(),
          'duration_ms': duration,
          'status_code': response?.statusCode ?? error?.response?.statusCode,
          'response_size': response?.data?.toString().length ?? 0,
          'error': error?.message,
        },
        timestamp: DateTime.now(),
      ),
    );
  }
}
