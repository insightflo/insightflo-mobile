/// Vercel Analytics Adapter
/// 
/// Flutter 앱에서 Vercel Analytics로 커스텀 이벤트를 전송하는 어댑터
/// - 배치 큐를 통한 효율적인 이벤트 전송
/// - 네트워크 실패 시 지수 백오프 재시도
/// - 메모리 효율적인 이벤트 버퍼링
/// - 사용자 프라이버시 보호
/// 
/// 사용법:
/// ```dart
/// final analytics = VercelAnalyticsAdapter.instance;
/// await analytics.initialize(projectId: 'your-project-id');
/// 
/// // 커스텀 이벤트 전송
/// analytics.trackEvent('user_login', {'method': 'google'});
/// 
/// // 성능 메트릭 전송
/// analytics.trackPerformance('api_response', {'duration': 120});
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/metrics.dart';

// ============================================================================
// 이벤트 데이터 모델
// ============================================================================

/// Vercel Analytics로 전송될 이벤트
class AnalyticsEvent {
  final String name;
  final Map<String, dynamic> properties;
  final DateTime timestamp;
  final String? userId;
  final String? sessionId;
  final EventType type;
  
  const AnalyticsEvent({
    required this.name,
    required this.properties,
    required this.timestamp,
    this.userId,
    this.sessionId,
    this.type = EventType.custom,
  });
  
  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'properties': properties,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'sessionId': sessionId,
      'type': type.value,
    };
  }
  
  /// JSON에서 역직렬화
  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      name: json['name'],
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'],
      sessionId: json['sessionId'],
      type: EventType.values.firstWhere(
        (type) => type.value == json['type'],
        orElse: () => EventType.custom,
      ),
    );
  }
  
  @override
  String toString() {
    return 'AnalyticsEvent(name: $name, type: ${type.value}, timestamp: $timestamp)';
  }
}

/// 이벤트 타입 열거형
enum EventType {
  custom('custom'),
  performance('performance'),
  error('error'),
  navigation('navigation'),
  user('user');
  
  const EventType(this.value);
  final String value;
}

// ============================================================================
// 배치 전송 관리
// ============================================================================

/// 이벤트 배치 처리를 위한 큐 매니저
class BatchQueue {
  final List<AnalyticsEvent> _events = [];
  final int maxBatchSize;
  final Duration batchInterval;
  final int maxQueueSize;
  
  Timer? _batchTimer;
  
  BatchQueue({
    this.maxBatchSize = 50,
    this.batchInterval = const Duration(minutes: 2),
    this.maxQueueSize = 1000,
  });
  
  /// 이벤트 추가
  void addEvent(AnalyticsEvent event) {
    // 큐 크기 제한 (메모리 보호)
    if (_events.length >= maxQueueSize) {
      // FIFO 방식으로 오래된 이벤트 제거
      _events.removeRange(0, maxQueueSize ~/ 4);
    }
    
    _events.add(event);
    
    // 배치 크기에 도달하면 즉시 전송
    if (_events.length >= maxBatchSize) {
      _triggerBatch();
    } else {
      _scheduleBatch();
    }
  }
  
  /// 배치 전송 예약
  void _scheduleBatch() {
    _batchTimer?.cancel();
    _batchTimer = Timer(batchInterval, _triggerBatch);
  }
  
  /// 배치 전송 실행
  void _triggerBatch() {
    _batchTimer?.cancel();
    if (_events.isNotEmpty) {
      _onBatchReady?.call(List.from(_events));
      _events.clear();
    }
  }
  
  /// 강제 배치 전송
  void flush() {
    _triggerBatch();
  }
  
  /// 남은 이벤트 수
  int get pendingEventCount => _events.length;
  
  /// 배치 준비 콜백
  Function(List<AnalyticsEvent>)? _onBatchReady;
  
  void setOnBatchReady(Function(List<AnalyticsEvent>) callback) {
    _onBatchReady = callback;
  }
  
  /// 리소스 정리
  void dispose() {
    _batchTimer?.cancel();
    _events.clear();
  }
}

// ============================================================================
// 재시도 매니저
// ============================================================================

/// 네트워크 실패 시 재시도 처리
class RetryManager {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(minutes: 5);
  
  /// 지수 백오프로 재시도 실행
  static Future<T> withRetry<T>(
    Future<T> Function() operation, {
    bool Function(Exception)? shouldRetry,
  }) async {
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        attempts++;
        
        // 재시도 가능한 오류인지 확인
        if (shouldRetry != null && !shouldRetry(lastException)) {
          throw lastException;
        }
        
        // 최대 재시도 횟수 도달
        if (attempts >= maxRetries) {
          throw lastException;
        }
        
        // 지수 백오프 지연
        final delay = _calculateDelay(attempts);
        await Future.delayed(delay);
      }
    }
    
    throw lastException!;
  }
  
  /// 지연 시간 계산 (지수 백오프 + 지터)
  static Duration _calculateDelay(int attempt) {
    final exponentialDelay = baseDelay * math.pow(2, attempt - 1);
    final jitter = Duration(
      milliseconds: math.Random().nextInt(1000),
    );
    
    final totalDelay = exponentialDelay + jitter;
    return totalDelay > maxDelay ? maxDelay : totalDelay;
  }
  
  /// 재시도 가능한 오류인지 판단
  static bool isRetryableError(Exception error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    
    // HTTP 상태코드 기반 판단
    final errorMessage = error.toString().toLowerCase();
    if (errorMessage.contains('500') || // Internal Server Error
        errorMessage.contains('502') || // Bad Gateway
        errorMessage.contains('503') || // Service Unavailable
        errorMessage.contains('504')) { // Gateway Timeout
      return true;
    }
    
    return false;
  }
}

// ============================================================================
// 메인 Analytics 어댑터
// ============================================================================

/// Vercel Analytics 연동을 위한 메인 어댑터 클래스
class VercelAnalyticsAdapter {
  static final VercelAnalyticsAdapter _instance = VercelAnalyticsAdapter._internal();
  static VercelAnalyticsAdapter get instance => _instance;
  
  VercelAnalyticsAdapter._internal();
  
  // 설정
  String? _projectId;
  String? _apiKey;
  String _baseUrl = 'https://vercel-analytics.com/api';
  
  // 상태 관리
  bool _isInitialized = false;
  bool _isEnabled = true;
  String? _sessionId;
  String? _userId;
  
  // 배치 처리
  late final BatchQueue _batchQueue;
  
  // HTTP 클라이언트
  late final http.Client _httpClient;
  
  // 네트워크 연결 상태
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = true;
  
  // 통계
  int _eventsSent = 0;
  int _eventsFailedToSend = 0;
  DateTime? _lastSuccessfulSend;
  
  /// Analytics 초기화
  Future<void> initialize({
    required String projectId,
    String? apiKey,
    String? baseUrl,
    bool enableAutoTracking = true,
    int maxBatchSize = 50,
    Duration batchInterval = const Duration(minutes: 2),
  }) async {
    if (_isInitialized) return;
    
    _projectId = projectId;
    _apiKey = apiKey;
    if (baseUrl != null) _baseUrl = baseUrl;
    
    // HTTP 클라이언트 설정
    _httpClient = http.Client();
    
    // 세션 ID 생성
    _sessionId = _generateSessionId();
    
    // 배치 큐 설정
    _batchQueue = BatchQueue(
      maxBatchSize: maxBatchSize,
      batchInterval: batchInterval,
    );
    _batchQueue.setOnBatchReady(_sendBatch);
    
    // 네트워크 상태 모니터링
    await _initializeConnectivity();
    
    _isInitialized = true;
    
    // 초기화 완료 이벤트
    if (enableAutoTracking) {
      trackEvent('analytics_initialized', {
        'project_id': projectId,
        'session_id': _sessionId,
        'platform': Platform.operatingSystem,
      });
    }
  }
  
  /// 네트워크 연결 상태 초기화
  Future<void> _initializeConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isConnected = !results.contains(ConnectivityResult.none);
      
      // 연결 상태 변경 감지
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (List<ConnectivityResult> results) {
          final wasConnected = _isConnected;
          _isConnected = !results.contains(ConnectivityResult.none);
          
          // 연결이 복구되면 대기 중인 배치 전송
          if (!wasConnected && _isConnected) {
            _batchQueue.flush();
          }
        },
      );
    } catch (e) {
      // 연결 상태 확인 실패시 기본값 유지
      _isConnected = true;
    }
  }
  
  /// 커스텀 이벤트 추적
  void trackEvent(String eventName, [Map<String, dynamic>? properties]) {
    if (!_isInitialized || !_isEnabled) return;
    
    final event = AnalyticsEvent(
      name: eventName,
      properties: {
        ...?properties,
        'platform': Platform.operatingSystem,
        'app_version': '1.0.0', // 실제 앱 버전으로 교체
        'user_agent': _getUserAgent(),
      },
      timestamp: DateTime.now(),
      userId: _userId,
      sessionId: _sessionId,
      type: EventType.custom,
    );
    
    _batchQueue.addEvent(event);
  }
  
  /// 성능 메트릭 전송
  void trackPerformance(String metricName, Map<String, dynamic> metrics) {
    if (!_isInitialized || !_isEnabled) return;
    
    final event = AnalyticsEvent(
      name: 'performance_metric',
      properties: {
        'metric_name': metricName,
        'metrics': metrics,
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      },
      timestamp: DateTime.now(),
      userId: _userId,
      sessionId: _sessionId,
      type: EventType.performance,
    );
    
    _batchQueue.addEvent(event);
  }
  
  /// API 메트릭 전송 (APIMetric 객체 기반)
  void trackAPIMetric(APIMetric metric) {
    trackPerformance('api_request', {
      'endpoint': metric.endpoint,
      'method': metric.method.value,
      'status_code': metric.statusCode,
      'response_time_ms': metric.responseTime.inMilliseconds,
      'is_success': metric.isSuccess,
      'request_size': metric.requestSize,
      'response_size': metric.responseSize,
    });
  }
  
  /// UI 메트릭 전송 (UIMetric 객체 기반)
  void trackUIMetric(UIMetric metric) {
    trackPerformance('ui_performance', {
      'metric_type': metric.metricType.key,
      'value': metric.value,
      'unit': metric.unit,
      'widget_name': metric.widgetName,
      'screen_name': metric.screenName,
      'is_healthy': metric.isHealthy,
    });
  }
  
  /// 데이터베이스 메트릭 전송 (DatabaseMetric 객체 기반)
  void trackDatabaseMetric(DatabaseMetric metric) {
    trackPerformance('database_query', {
      'query_type': metric.queryType.sql,
      'duration_ms': metric.duration.inMilliseconds,
      'table_name': metric.tableName,
      'record_count': metric.recordCount,
      'from_cache': metric.fromCache,
      'used_index': metric.usedIndex,
    });
  }
  
  /// 에러 이벤트 추적
  void trackError(String error, {
    String? stackTrace,
    Map<String, dynamic>? context,
  }) {
    if (!_isInitialized || !_isEnabled) return;
    
    final event = AnalyticsEvent(
      name: 'error_occurred',
      properties: {
        'error_message': error,
        'stack_trace': stackTrace,
        'context': context ?? {},
        'session_id': _sessionId,
      },
      timestamp: DateTime.now(),
      userId: _userId,
      sessionId: _sessionId,
      type: EventType.error,
    );
    
    _batchQueue.addEvent(event);
  }
  
  /// 페이지/화면 전환 추적
  void trackNavigation(String screenName, {
    String? previousScreen,
    Map<String, dynamic>? parameters,
  }) {
    trackEvent('screen_view', {
      'screen_name': screenName,
      'previous_screen': previousScreen,
      'parameters': parameters ?? {},
    });
  }
  
  /// 사용자 ID 설정
  void setUserId(String? userId) {
    _userId = userId;
  }
  
  /// 사용자 속성 설정
  void setUserProperties(Map<String, dynamic> properties) {
    trackEvent('user_properties_updated', {
      'user_properties': properties,
    });
  }
  
  /// Analytics 활성화/비활성화
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    
    if (!enabled) {
      // 비활성화 시 대기 중인 이벤트 삭제
      _batchQueue.dispose();
    }
  }
  
  /// 즉시 배치 전송
  Future<void> flush() async {
    if (!_isInitialized || !_isEnabled) return;
    _batchQueue.flush();
  }
  
  /// 배치 이벤트 전송
  Future<void> _sendBatch(List<AnalyticsEvent> events) async {
    if (!_isConnected || events.isEmpty) return;
    
    try {
      await RetryManager.withRetry(
        () => _performBatchSend(events),
        shouldRetry: RetryManager.isRetryableError,
      );
      
      _eventsSent += events.length;
      _lastSuccessfulSend = DateTime.now();
      
    } catch (e) {
      _eventsFailedToSend += events.length;
      
      // 중요 이벤트는 나중에 재시도하기 위해 다시 큐에 추가
      final criticalEvents = events.where(
        (event) => event.type == EventType.error || 
                   event.name == 'crash_report'
      ).toList();
      
      for (final event in criticalEvents) {
        _batchQueue.addEvent(event);
      }
      
      developer.log('Failed to send batch: $e', name: 'Analytics');
    }
  }
  
  /// 실제 HTTP 전송 수행
  Future<void> _performBatchSend(List<AnalyticsEvent> events) async {
    final payload = {
      'project_id': _projectId,
      'events': events.map((e) => e.toJson()).toList(),
      'sent_at': DateTime.now().toIso8601String(),
    };
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': _getUserAgent(),
    };
    
    if (_apiKey != null) {
      headers['Authorization'] = 'Bearer $_apiKey';
    }
    
    final response = await _httpClient.post(
      Uri.parse('$_baseUrl/events'),
      headers: headers,
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 30));
    
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'HTTP ${response.statusCode}: ${response.reasonPhrase}',
      );
    }
  }
  
  /// 세션 ID 생성
  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(999999);
    return '${timestamp}_$random';
  }
  
  /// User Agent 문자열 생성
  String _getUserAgent() {
    return 'InsightFlo-Mobile/1.0.0 (${Platform.operatingSystem}; ${Platform.operatingSystemVersion})';
  }
  
  /// Analytics 통계 조회
  Map<String, dynamic> getStats() {
    return {
      'is_initialized': _isInitialized,
      'is_enabled': _isEnabled,
      'is_connected': _isConnected,
      'events_sent': _eventsSent,
      'events_failed': _eventsFailedToSend,
      'pending_events': _batchQueue.pendingEventCount,
      'last_successful_send': _lastSuccessfulSend?.toIso8601String(),
      'session_id': _sessionId,
      'user_id': _userId,
    };
  }
  
  /// 리소스 정리
  void dispose() {
    _connectivitySubscription?.cancel();
    _batchQueue.dispose();
    _httpClient.close();
    _isInitialized = false;
  }
}

// ============================================================================
// 확장 헬퍼
// ============================================================================

/// Metric 객체를 Analytics로 쉽게 전송하기 위한 확장
extension MetricAnalyticsExtension on Metric {
  /// 메트릭을 Analytics 이벤트로 전송
  void sendToAnalytics() {
    final analytics = VercelAnalyticsAdapter.instance;
    
    switch (this) {
      case APIMetric apiMetric:
        analytics.trackAPIMetric(apiMetric);
        break;
      case UIMetric uiMetric:
        analytics.trackUIMetric(uiMetric);
        break;
      case DatabaseMetric dbMetric:
        analytics.trackDatabaseMetric(dbMetric);
        break;
      default:
        analytics.trackPerformance(name, {
          'category': category.value,
          'value': value,
          'unit': unit,
          'is_healthy': isHealthy,
          'metadata': metadata,
        });
    }
  }
}

// ============================================================================
// 사용 예시
// ============================================================================

/// Analytics 사용 예시
class AnalyticsUsageExample {
  static Future<void> demonstrateUsage() async {
    final analytics = VercelAnalyticsAdapter.instance;
    
    // 1. 초기화
    await analytics.initialize(
      projectId: 'insightflo-mobile',
      apiKey: 'your-api-key', // 선택사항
      maxBatchSize: 30,
      batchInterval: const Duration(minutes: 1),
    );
    
    // 2. 사용자 설정
    analytics.setUserId('user123');
    analytics.setUserProperties({
      'subscription_tier': 'premium',
      'signup_date': '2024-01-15',
    });
    
    // 3. 이벤트 추적
    analytics.trackEvent('news_article_read', {
      'article_id': 'article123',
      'category': 'technology',
      'read_duration_seconds': 45,
    });
    
    // 4. 화면 전환 추적
    analytics.trackNavigation('news_feed', 
      previousScreen: 'onboarding',
    );
    
    // 5. 에러 추적
    analytics.trackError('Network timeout', 
      context: {'endpoint': '/api/news'},
    );
    
    // 6. 메트릭 자동 전송 (Performance Interceptor와 연동)
    final apiMetric = APIMetric.httpRequest(
      endpoint: '/api/news',
      method: HttpMethod.get,
      statusCode: 200,
      responseTime: const Duration(milliseconds: 150),
    );
    apiMetric.sendToAnalytics();
    
    // 7. 통계 확인
    developer.log('Analytics Stats: ${analytics.getStats()}', name: 'Analytics');
    
    // 8. 앱 종료 시 정리
    await analytics.flush(); // 남은 이벤트 전송
    analytics.dispose(); // 리소스 정리
  }
}