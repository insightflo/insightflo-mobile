/// 성능 메트릭 모델 클래스들
/// 
/// 기본 Metric 클래스와 특화된 DatabaseMetric, APIMetric, UIMetric을 제공합니다.
/// 실시간 성능 모니터링과 데이터 수집을 위한 구조화된 모델을 제공합니다.
/// 
/// 사용법:
/// ```dart
/// // 데이터베이스 메트릭 생성
/// final dbMetric = DatabaseMetric(
///   queryType: QueryType.select,
///   tableName: 'users',
///   duration: Duration(milliseconds: 45),
///   recordCount: 150,
/// );
/// 
/// // API 메트릭 생성
/// final apiMetric = APIMetric(
///   endpoint: '/api/users',
///   method: HttpMethod.get,
///   statusCode: 200,
///   responseTime: Duration(milliseconds: 120),
/// );
/// 
/// // UI 메트릭 생성
/// final uiMetric = UIMetric(
///   metricType: UIMetricType.fps,
///   value: 58.5,
///   widgetName: 'NewsListView',
/// );
/// ```


// ============================================================================
// 기본 열거형 및 상수
// ============================================================================

/// 메트릭 카테고리 열거형
enum MetricCategory {
  database('database'),
  api('api'),
  ui('ui'),
  memory('memory'),
  storage('storage'),
  network('network');

  const MetricCategory(this.value);
  final String value;
}

/// 메트릭 우선순위 레벨
enum MetricPriority {
  low(1),
  medium(2),
  high(3),
  critical(4);

  const MetricPriority(this.level);
  final int level;
}

/// 데이터베이스 쿼리 유형
enum QueryType {
  select('SELECT'),
  insert('INSERT'),
  update('UPDATE'),
  delete('DELETE'),
  create('CREATE'),
  drop('DROP'),
  alter('ALTER'),
  other('OTHER');

  const QueryType(this.sql);
  final String sql;

  static QueryType fromString(String query) {
    final normalized = query.trim().toUpperCase();
    for (final type in QueryType.values) {
      if (normalized.startsWith(type.sql)) {
        return type;
      }
    }
    return QueryType.other;
  }
}

/// HTTP 메서드 열거형
enum HttpMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE'),
  patch('PATCH'),
  head('HEAD'),
  options('OPTIONS');

  const HttpMethod(this.value);
  final String value;

  static HttpMethod fromString(String method) {
    final normalized = method.toUpperCase();
    for (final httpMethod in HttpMethod.values) {
      if (httpMethod.value == normalized) {
        return httpMethod;
      }
    }
    return HttpMethod.get;
  }
}

/// UI 메트릭 유형
enum UIMetricType {
  fps('fps', 'fps'),
  buildTime('build_time', 'ms'),
  frameTime('frame_time', 'ms'),
  scrollPerformance('scroll_performance', 'ms'),
  memoryUsage('memory_usage', 'MB'),
  widgetCount('widget_count', 'count'),
  layoutTime('layout_time', 'ms'),
  paintTime('paint_time', 'ms');

  const UIMetricType(this.key, this.unit);
  final String key;
  final String unit;
}

// ============================================================================
// 기본 Metric 클래스
// ============================================================================

/// 모든 성능 메트릭의 기본 클래스
/// 
/// 메트릭의 공통 속성과 메서드를 정의합니다.
/// 각 특화된 메트릭 클래스는 이 클래스를 상속받아 구현됩니다.
abstract class Metric {
  /// 메트릭 고유 식별자
  final String id;
  
  /// 메트릭 이름
  final String name;
  
  /// 메트릭 카테고리
  final MetricCategory category;
  
  /// 메트릭 값
  final double value;
  
  /// 측정 단위
  final String unit;
  
  /// 메트릭 우선순위
  final MetricPriority priority;
  
  /// 생성 시간
  final DateTime timestamp;
  
  /// 추가 메타데이터
  final Map<String, dynamic> metadata;
  
  /// 메트릭이 정상 범위 내에 있는지 여부
  final bool isHealthy;

  Metric({
    required this.id,
    required this.name,
    required this.category,
    required this.value,
    required this.unit,
    this.priority = MetricPriority.medium,
    DateTime? timestamp,
    this.metadata = const {},
    this.isHealthy = true,
  }) : timestamp = timestamp ?? DateTime.now();

  /// 메트릭을 JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.value,
      'value': value,
      'unit': unit,
      'priority': priority.level,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'isHealthy': isHealthy,
      'type': runtimeType.toString(),
    };
  }

  /// JSON에서 메트릭 생성 (팩토리 메서드)
  static Metric fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    
    switch (type) {
      case 'DatabaseMetric':
        return DatabaseMetric.fromJson(json);
      case 'APIMetric':
        return APIMetric.fromJson(json);
      case 'UIMetric':
        return UIMetric.fromJson(json);
      default:
        throw ArgumentError('Unknown metric type: $type');
    }
  }

  /// 메트릭을 문자열로 표현
  @override
  String toString() {
    return '${runtimeType}(id: $id, name: $name, value: $value$unit, timestamp: ${timestamp.toIso8601String()})';
  }

  /// 메트릭 비교 (값 기준)
  int compareTo(Metric other) {
    return value.compareTo(other.value);
  }

  /// 메트릭 값이 임계값을 초과하는지 확인
  bool exceedsThreshold({
    double? warningThreshold,
    double? criticalThreshold,
  }) {
    if (criticalThreshold != null && value >= criticalThreshold) {
      return true;
    }
    if (warningThreshold != null && value >= warningThreshold) {
      return true;
    }
    return false;
  }

  /// 메트릭의 심각도 레벨 계산
  MetricPriority calculateSeverity({
    double? warningThreshold,
    double? criticalThreshold,
  }) {
    if (criticalThreshold != null && value >= criticalThreshold) {
      return MetricPriority.critical;
    }
    if (warningThreshold != null && value >= warningThreshold) {
      return MetricPriority.high;
    }
    return priority;
  }

  /// 메트릭 복사본 생성 (일부 필드 수정 가능)
  Metric copyWith({
    String? id,
    String? name,
    MetricCategory? category,
    double? value,
    String? unit,
    MetricPriority? priority,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    bool? isHealthy,
  });
}

// ============================================================================
// DatabaseMetric - 데이터베이스 성능 메트릭
// ============================================================================

/// 데이터베이스 관련 성능 메트릭 클래스
/// 
/// 쿼리 실행 시간, 캐시 히트율, 연결 풀 상태 등을 추적합니다.
class DatabaseMetric extends Metric {
  /// 쿼리 유형
  final QueryType queryType;
  
  /// 대상 테이블명
  final String? tableName;
  
  /// 쿼리 실행 시간
  final Duration duration;
  
  /// 처리된 레코드 수
  final int? recordCount;
  
  /// 캐시에서 가져온 데이터인지 여부
  final bool fromCache;
  
  /// 실행된 SQL 쿼리 (민감한 정보 제거됨)
  final String? sanitizedQuery;
  
  /// 인덱스 사용 여부
  final bool? usedIndex;
  
  /// 쿼리 비용 점수
  final double? costScore;

  DatabaseMetric({
    required super.id,
    required super.name,
    required this.queryType,
    required this.duration,
    this.tableName,
    this.recordCount,
    this.fromCache = false,
    this.sanitizedQuery,
    this.usedIndex,
    this.costScore,
    super.priority = MetricPriority.medium,
    super.timestamp,
    super.metadata = const {},
  }) : super(
          category: MetricCategory.database,
          value: duration.inMilliseconds.toDouble(),
          unit: 'ms',
          isHealthy: duration.inMilliseconds <= 100, // 100ms 이하면 정상
        );

  /// 팩토리 생성자 - 쿼리 실행 메트릭
  factory DatabaseMetric.queryExecution({
    required String queryString,
    required Duration duration,
    String? tableName,
    int? recordCount,
    bool fromCache = false,
    bool? usedIndex,
    double? costScore,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    final queryType = QueryType.fromString(queryString);
    final sanitized = _sanitizeQuery(queryString);
    
    return DatabaseMetric(
      id: 'db_query_${DateTime.now().millisecondsSinceEpoch}',
      name: '${queryType.sql} Query',
      queryType: queryType,
      duration: duration,
      tableName: tableName,
      recordCount: recordCount,
      fromCache: fromCache,
      sanitizedQuery: sanitized,
      usedIndex: usedIndex,
      costScore: costScore,
      priority: priority,
      metadata: {
        'query_type': queryType.sql,
        'from_cache': fromCache,
        'used_index': usedIndex,
        'cost_score': costScore,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 캐시 히트율 메트릭
  factory DatabaseMetric.cacheHitRate({
    required double hitRatePercentage,
    required int totalQueries,
    required int cacheHits,
    MetricPriority priority = MetricPriority.low,
    Map<String, dynamic> metadata = const {},
  }) {
    return DatabaseMetric(
      id: 'db_cache_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Cache Hit Rate',
      queryType: QueryType.other,
      duration: Duration.zero,
      priority: priority,
      metadata: {
        'hit_rate_percentage': hitRatePercentage,
        'total_queries': totalQueries,
        'cache_hits': cacheHits,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 연결 풀 메트릭
  factory DatabaseMetric.connectionPool({
    required int activeConnections,
    required int totalConnections,
    required int waitingRequests,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    final utilizationPercentage = (activeConnections / totalConnections) * 100;
    
    return DatabaseMetric(
      id: 'db_pool_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Connection Pool Utilization',
      queryType: QueryType.other,
      duration: Duration.zero,
      priority: priority,
      metadata: {
        'active_connections': activeConnections,
        'total_connections': totalConnections,
        'waiting_requests': waitingRequests,
        'utilization_percentage': utilizationPercentage,
        ...metadata,
      },
    );
  }

  /// JSON에서 DatabaseMetric 생성
  factory DatabaseMetric.fromJson(Map<String, dynamic> json) {
    return DatabaseMetric(
      id: json['id'],
      name: json['name'],
      queryType: QueryType.values.firstWhere(
        (type) => type.sql == json['metadata']['query_type'],
        orElse: () => QueryType.other,
      ),
      duration: Duration(milliseconds: json['value'].toInt()),
      tableName: json['metadata']['table_name'],
      recordCount: json['metadata']['record_count'],
      fromCache: json['metadata']['from_cache'] ?? false,
      sanitizedQuery: json['metadata']['sanitized_query'],
      usedIndex: json['metadata']['used_index'],
      costScore: json['metadata']['cost_score']?.toDouble(),
      priority: MetricPriority.values.firstWhere(
        (p) => p.level == json['priority'],
        orElse: () => MetricPriority.medium,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  DatabaseMetric copyWith({
    String? id,
    String? name,
    MetricCategory? category,
    double? value,
    String? unit,
    MetricPriority? priority,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    bool? isHealthy,
    QueryType? queryType,
    String? tableName,
    Duration? duration,
    int? recordCount,
    bool? fromCache,
    String? sanitizedQuery,
    bool? usedIndex,
    double? costScore,
  }) {
    return DatabaseMetric(
      id: id ?? this.id,
      name: name ?? this.name,
      queryType: queryType ?? this.queryType,
      duration: duration ?? this.duration,
      tableName: tableName ?? this.tableName,
      recordCount: recordCount ?? this.recordCount,
      fromCache: fromCache ?? this.fromCache,
      sanitizedQuery: sanitizedQuery ?? this.sanitizedQuery,
      usedIndex: usedIndex ?? this.usedIndex,
      costScore: costScore ?? this.costScore,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 쿼리에서 민감한 정보 제거
  static String _sanitizeQuery(String query) {
    return query
        .replaceAll(RegExp(r"'[^']*'"), "'***'")
        .replaceAll(RegExp(r'"[^"]*"'), '"***"')
        .replaceAll(RegExp(r'\b\d+\b'), '***')
        .replaceAll(RegExp(r'VALUES\s*\([^)]+\)', caseSensitive: false), 'VALUES (***)');
  }
}

// ============================================================================
// APIMetric - API 성능 메트릭
// ============================================================================

/// API 및 네트워크 관련 성능 메트릭 클래스
/// 
/// HTTP 요청 응답 시간, 에러율, 처리량 등을 추적합니다.
class APIMetric extends Metric {
  /// API 엔드포인트
  final String endpoint;
  
  /// HTTP 메서드
  final HttpMethod method;
  
  /// HTTP 상태 코드
  final int statusCode;
  
  /// 응답 시간
  final Duration responseTime;
  
  /// 요청 크기 (바이트)
  final int? requestSize;
  
  /// 응답 크기 (바이트)
  final int? responseSize;
  
  /// 요청이 성공했는지 여부
  final bool isSuccess;
  
  /// 네트워크 지연 시간
  final Duration? networkLatency;
  
  /// 사용자 에이전트
  final String? userAgent;
  
  /// API 버전
  final String? apiVersion;

  APIMetric({
    required super.id,
    required super.name,
    required this.endpoint,
    required this.method,
    required this.statusCode,
    required this.responseTime,
    this.requestSize,
    this.responseSize,
    this.networkLatency,
    this.userAgent,
    this.apiVersion,
    super.priority = MetricPriority.medium,
    super.timestamp,
    super.metadata = const {},
  })  : isSuccess = statusCode >= 200 && statusCode < 400,
        super(
          category: MetricCategory.api,
          value: responseTime.inMilliseconds.toDouble(),
          unit: 'ms',
          isHealthy: statusCode >= 200 && statusCode < 400 && responseTime.inMilliseconds <= 1000,
        );

  /// 팩토리 생성자 - HTTP 요청 메트릭
  factory APIMetric.httpRequest({
    required String endpoint,
    required HttpMethod method,
    required int statusCode,
    required Duration responseTime,
    int? requestSize,
    int? responseSize,
    Duration? networkLatency,
    String? userAgent,
    String? apiVersion,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    return APIMetric(
      id: 'api_req_${DateTime.now().millisecondsSinceEpoch}',
      name: '${method.value} $endpoint',
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      responseTime: responseTime,
      requestSize: requestSize,
      responseSize: responseSize,
      networkLatency: networkLatency,
      userAgent: userAgent,
      apiVersion: apiVersion,
      priority: priority,
      metadata: {
        'method': method.value,
        'status_code': statusCode,
        'is_success': statusCode >= 200 && statusCode < 400,
        'request_size': requestSize,
        'response_size': responseSize,
        'network_latency_ms': networkLatency?.inMilliseconds,
        'user_agent': userAgent,
        'api_version': apiVersion,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 에러율 메트릭
  factory APIMetric.errorRate({
    required double errorRatePercentage,
    required int totalRequests,
    required int errorRequests,
    String endpoint = '/all',
    MetricPriority priority = MetricPriority.high,
    Map<String, dynamic> metadata = const {},
  }) {
    return APIMetric(
      id: 'api_error_${DateTime.now().millisecondsSinceEpoch}',
      name: 'API Error Rate',
      endpoint: endpoint,
      method: HttpMethod.get,
      statusCode: errorRatePercentage > 10 ? 500 : 200,
      responseTime: Duration.zero,
      priority: priority,
      metadata: {
        'error_rate_percentage': errorRatePercentage,
        'total_requests': totalRequests,
        'error_requests': errorRequests,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 처리량 메트릭 (RPS - Requests Per Second)
  factory APIMetric.throughput({
    required double requestsPerSecond,
    required Duration measurementWindow,
    String endpoint = '/all',
    MetricPriority priority = MetricPriority.low,
    Map<String, dynamic> metadata = const {},
  }) {
    return APIMetric(
      id: 'api_throughput_${DateTime.now().millisecondsSinceEpoch}',
      name: 'API Throughput',
      endpoint: endpoint,
      method: HttpMethod.get,
      statusCode: 200,
      responseTime: Duration.zero,
      priority: priority,
      metadata: {
        'requests_per_second': requestsPerSecond,
        'measurement_window_seconds': measurementWindow.inSeconds,
        ...metadata,
      },
    );
  }

  /// JSON에서 APIMetric 생성
  factory APIMetric.fromJson(Map<String, dynamic> json) {
    return APIMetric(
      id: json['id'],
      name: json['name'],
      endpoint: json['metadata']['endpoint'] ?? json['endpoint'] ?? '/unknown',
      method: HttpMethod.fromString(json['metadata']['method'] ?? 'GET'),
      statusCode: json['metadata']['status_code'] ?? 200,
      responseTime: Duration(milliseconds: json['value'].toInt()),
      requestSize: json['metadata']['request_size'],
      responseSize: json['metadata']['response_size'],
      networkLatency: json['metadata']['network_latency_ms'] != null
          ? Duration(milliseconds: json['metadata']['network_latency_ms'])
          : null,
      userAgent: json['metadata']['user_agent'],
      apiVersion: json['metadata']['api_version'],
      priority: MetricPriority.values.firstWhere(
        (p) => p.level == json['priority'],
        orElse: () => MetricPriority.medium,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  APIMetric copyWith({
    String? id,
    String? name,
    MetricCategory? category,
    double? value,
    String? unit,
    MetricPriority? priority,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    bool? isHealthy,
    String? endpoint,
    HttpMethod? method,
    int? statusCode,
    Duration? responseTime,
    int? requestSize,
    int? responseSize,
    Duration? networkLatency,
    String? userAgent,
    String? apiVersion,
  }) {
    return APIMetric(
      id: id ?? this.id,
      name: name ?? this.name,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      statusCode: statusCode ?? this.statusCode,
      responseTime: responseTime ?? this.responseTime,
      requestSize: requestSize ?? this.requestSize,
      responseSize: responseSize ?? this.responseSize,
      networkLatency: networkLatency ?? this.networkLatency,
      userAgent: userAgent ?? this.userAgent,
      apiVersion: apiVersion ?? this.apiVersion,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 요청이 느린지 판단 (1초 초과)
  bool get isSlow => responseTime.inMilliseconds > 1000;

  /// 요청이 매우 느린지 판단 (3초 초과)
  bool get isVerySlow => responseTime.inMilliseconds > 3000;

  /// 클라이언트 에러인지 판단 (4xx)
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// 서버 에러인지 판단 (5xx)
  bool get isServerError => statusCode >= 500;
}

// ============================================================================
// UIMetric - UI 성능 메트릭
// ============================================================================

/// UI 및 사용자 인터페이스 성능 메트릭 클래스
/// 
/// FPS, 위젯 빌드 시간, 스크롤 성능, 메모리 사용량 등을 추적합니다.
class UIMetric extends Metric {
  /// UI 메트릭 유형
  final UIMetricType metricType;
  
  /// 관련 위젯 이름
  final String? widgetName;
  
  /// 화면 이름 또는 라우트
  final String? screenName;
  
  /// 프레임 시간 (UI 메트릭에만 해당)
  final Duration? frameTime;
  
  /// 렌더링 시간
  final Duration? renderTime;
  
  /// 레이아웃 시간
  final Duration? layoutTime;
  
  /// 페인트 시간
  final Duration? paintTime;
  
  /// 메모리 사용량 (MB)
  final double? memoryUsageMB;
  
  /// 위젯 트리 깊이
  final int? widgetTreeDepth;
  
  /// 리빌드 발생 여부
  final bool hasRebuild;

  UIMetric({
    required super.id,
    required super.name,
    required this.metricType,
    required super.value,
    this.widgetName,
    this.screenName,
    this.frameTime,
    this.renderTime,
    this.layoutTime,
    this.paintTime,
    this.memoryUsageMB,
    this.widgetTreeDepth,
    this.hasRebuild = false,
    super.priority = MetricPriority.medium,
    super.timestamp,
    super.metadata = const {},
  }) : super(
          category: MetricCategory.ui,
          unit: metricType.unit,
          isHealthy: _calculateHealthy(metricType, value),
        );

  /// 팩토리 생성자 - FPS 메트릭
  factory UIMetric.fps({
    required double fpsValue,
    String? screenName,
    Duration? frameTime,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    return UIMetric(
      id: 'ui_fps_${DateTime.now().millisecondsSinceEpoch}',
      name: 'FPS Measurement',
      metricType: UIMetricType.fps,
      value: fpsValue,
      screenName: screenName,
      frameTime: frameTime,
      priority: priority,
      metadata: {
        'screen_name': screenName,
        'frame_time_ms': frameTime?.inMilliseconds,
        'is_smooth': fpsValue >= 55.0,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 위젯 빌드 시간 메트릭
  factory UIMetric.buildTime({
    required String widgetName,
    required Duration buildDuration,
    String? screenName,
    int? widgetTreeDepth,
    bool hasRebuild = false,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    return UIMetric(
      id: 'ui_build_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Widget Build Time',
      metricType: UIMetricType.buildTime,
      value: buildDuration.inMicroseconds / 1000.0, // ms로 변환
      widgetName: widgetName,
      screenName: screenName,
      widgetTreeDepth: widgetTreeDepth,
      hasRebuild: hasRebuild,
      priority: priority,
      metadata: {
        'widget_name': widgetName,
        'screen_name': screenName,
        'widget_tree_depth': widgetTreeDepth,
        'has_rebuild': hasRebuild,
        'exceeds_frame_budget': buildDuration.inMilliseconds > 16,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 스크롤 성능 메트릭
  factory UIMetric.scrollPerformance({
    required Duration scrollFrameTime,
    required double scrollDelta,
    String? widgetName,
    String? screenName,
    bool isJanky = false,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    return UIMetric(
      id: 'ui_scroll_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Scroll Performance',
      metricType: UIMetricType.scrollPerformance,
      value: scrollFrameTime.inMicroseconds / 1000.0, // ms로 변환
      widgetName: widgetName,
      screenName: screenName,
      frameTime: scrollFrameTime,
      priority: priority,
      metadata: {
        'scroll_delta': scrollDelta,
        'is_janky': isJanky,
        'frame_budget_exceeded': scrollFrameTime.inMilliseconds > 16,
        'widget_name': widgetName,
        'screen_name': screenName,
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 메모리 사용량 메트릭
  factory UIMetric.memoryUsage({
    required double memoryMB,
    String? screenName,
    int? widgetCount,
    MetricPriority priority = MetricPriority.low,
    Map<String, dynamic> metadata = const {},
  }) {
    return UIMetric(
      id: 'ui_memory_${DateTime.now().millisecondsSinceEpoch}',
      name: 'UI Memory Usage',
      metricType: UIMetricType.memoryUsage,
      value: memoryMB,
      screenName: screenName,
      memoryUsageMB: memoryMB,
      priority: priority,
      metadata: {
        'screen_name': screenName,
        'widget_count': widgetCount,
        'memory_pressure': memoryMB > 100.0 ? 'high' : memoryMB > 50.0 ? 'medium' : 'low',
        ...metadata,
      },
    );
  }

  /// 팩토리 생성자 - 렌더링 성능 메트릭
  factory UIMetric.renderingPerformance({
    required Duration totalRenderTime,
    Duration? layoutTime,
    Duration? paintTime,
    String? widgetName,
    String? screenName,
    MetricPriority priority = MetricPriority.medium,
    Map<String, dynamic> metadata = const {},
  }) {
    return UIMetric(
      id: 'ui_render_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Rendering Performance',
      metricType: UIMetricType.frameTime,
      value: totalRenderTime.inMicroseconds / 1000.0, // ms로 변환
      widgetName: widgetName,
      screenName: screenName,
      renderTime: totalRenderTime,
      layoutTime: layoutTime,
      paintTime: paintTime,
      priority: priority,
      metadata: {
        'layout_time_ms': layoutTime?.inMicroseconds != null 
            ? layoutTime!.inMicroseconds / 1000.0 
            : null,
        'paint_time_ms': paintTime?.inMicroseconds != null 
            ? paintTime!.inMicroseconds / 1000.0 
            : null,
        'widget_name': widgetName,
        'screen_name': screenName,
        ...metadata,
      },
    );
  }

  /// JSON에서 UIMetric 생성
  factory UIMetric.fromJson(Map<String, dynamic> json) {
    final metricTypeKey = json['metadata']['metric_type'] ?? json['metricType'];
    final metricType = UIMetricType.values.firstWhere(
      (type) => type.key == metricTypeKey,
      orElse: () => UIMetricType.buildTime,
    );

    return UIMetric(
      id: json['id'],
      name: json['name'],
      metricType: metricType,
      value: json['value'].toDouble(),
      widgetName: json['metadata']['widget_name'],
      screenName: json['metadata']['screen_name'],
      frameTime: json['metadata']['frame_time_ms'] != null
          ? Duration(milliseconds: json['metadata']['frame_time_ms'].toInt())
          : null,
      renderTime: json['metadata']['render_time_ms'] != null
          ? Duration(milliseconds: json['metadata']['render_time_ms'].toInt())
          : null,
      layoutTime: json['metadata']['layout_time_ms'] != null
          ? Duration(milliseconds: json['metadata']['layout_time_ms'].toInt())
          : null,
      paintTime: json['metadata']['paint_time_ms'] != null
          ? Duration(milliseconds: json['metadata']['paint_time_ms'].toInt())
          : null,
      memoryUsageMB: json['metadata']['memory_usage_mb']?.toDouble(),
      widgetTreeDepth: json['metadata']['widget_tree_depth'],
      hasRebuild: json['metadata']['has_rebuild'] ?? false,
      priority: MetricPriority.values.firstWhere(
        (p) => p.level == json['priority'],
        orElse: () => MetricPriority.medium,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  @override
  UIMetric copyWith({
    String? id,
    String? name,
    MetricCategory? category,
    double? value,
    String? unit,
    MetricPriority? priority,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    bool? isHealthy,
    UIMetricType? metricType,
    String? widgetName,
    String? screenName,
    Duration? frameTime,
    Duration? renderTime,
    Duration? layoutTime,
    Duration? paintTime,
    double? memoryUsageMB,
    int? widgetTreeDepth,
    bool? hasRebuild,
  }) {
    return UIMetric(
      id: id ?? this.id,
      name: name ?? this.name,
      metricType: metricType ?? this.metricType,
      value: value ?? this.value,
      widgetName: widgetName ?? this.widgetName,
      screenName: screenName ?? this.screenName,
      frameTime: frameTime ?? this.frameTime,
      renderTime: renderTime ?? this.renderTime,
      layoutTime: layoutTime ?? this.layoutTime,
      paintTime: paintTime ?? this.paintTime,
      memoryUsageMB: memoryUsageMB ?? this.memoryUsageMB,
      widgetTreeDepth: widgetTreeDepth ?? this.widgetTreeDepth,
      hasRebuild: hasRebuild ?? this.hasRebuild,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// 메트릭 유형별 건강 상태 계산
  static bool _calculateHealthy(UIMetricType type, double value) {
    switch (type) {
      case UIMetricType.fps:
        return value >= 55.0; // 55 FPS 이상이면 정상
      case UIMetricType.buildTime:
      case UIMetricType.frameTime:
        return value <= 16.0; // 16ms 이하면 정상 (60fps 기준)
      case UIMetricType.scrollPerformance:
        return value <= 16.0; // 16ms 이하면 정상 스크롤
      case UIMetricType.memoryUsage:
        return value <= 100.0; // 100MB 이하면 정상
      case UIMetricType.layoutTime:
      case UIMetricType.paintTime:
        return value <= 8.0; // 8ms 이하면 정상
      case UIMetricType.widgetCount:
        return value <= 1000; // 1000개 이하면 정상
    }
  }

  /// 프레임 예산(16ms)을 초과했는지 확인
  bool get exceedsFrameBudget {
    switch (metricType) {
      case UIMetricType.buildTime:
      case UIMetricType.frameTime:
      case UIMetricType.scrollPerformance:
        return value > 16.0;
      default:
        return false;
    }
  }

  /// 부드러운 애니메이션을 위한 성능 확인 (60fps 기준)
  bool get isSmoothPerformance {
    switch (metricType) {
      case UIMetricType.fps:
        return value >= 58.0;
      case UIMetricType.buildTime:
      case UIMetricType.frameTime:
        return value <= 16.67; // 60fps = 16.67ms per frame
      default:
        return isHealthy;
    }
  }
}

// ============================================================================
// 유틸리티 함수들
// ============================================================================

/// 메트릭 컬렉션을 위한 헬퍼 클래스
class MetricUtils {
  /// 메트릭 리스트를 JSON 배열로 변환
  static List<Map<String, dynamic>> metricsToJson(List<Metric> metrics) {
    return metrics.map((metric) => metric.toJson()).toList();
  }

  /// JSON 배열을 메트릭 리스트로 변환
  static List<Metric> metricsFromJson(List<dynamic> jsonList) {
    return jsonList
        .cast<Map<String, dynamic>>()
        .map((json) => Metric.fromJson(json))
        .toList();
  }

  /// 메트릭 리스트를 카테고리별로 그룹화
  static Map<MetricCategory, List<Metric>> groupByCategory(List<Metric> metrics) {
    final grouped = <MetricCategory, List<Metric>>{};
    
    for (final metric in metrics) {
      grouped.putIfAbsent(metric.category, () => []).add(metric);
    }
    
    return grouped;
  }

  /// 메트릭 리스트를 우선순위별로 정렬
  static List<Metric> sortByPriority(List<Metric> metrics) {
    final sorted = List<Metric>.from(metrics);
    sorted.sort((a, b) => b.priority.level.compareTo(a.priority.level));
    return sorted;
  }

  /// 건강하지 않은 메트릭만 필터링
  static List<Metric> filterUnhealthy(List<Metric> metrics) {
    return metrics.where((metric) => !metric.isHealthy).toList();
  }

  /// 특정 시간 범위의 메트릭만 필터링
  static List<Metric> filterByTimeRange(
    List<Metric> metrics,
    DateTime startTime,
    DateTime endTime,
  ) {
    return metrics.where((metric) =>
        metric.timestamp.isAfter(startTime) &&
        metric.timestamp.isBefore(endTime)).toList();
  }

  /// 메트릭 통계 계산
  static Map<String, double> calculateStatistics(List<Metric> metrics) {
    if (metrics.isEmpty) {
      return {
        'count': 0.0,
        'min': 0.0,
        'max': 0.0,
        'average': 0.0,
        'median': 0.0,
      };
    }

    final values = metrics.map((m) => m.value).toList()..sort();
    final count = values.length;
    final sum = values.reduce((a, b) => a + b);

    return {
      'count': count.toDouble(),
      'min': values.first,
      'max': values.last,
      'average': sum / count,
      'median': count % 2 == 0
          ? (values[count ~/ 2 - 1] + values[count ~/ 2]) / 2
          : values[count ~/ 2],
    };
  }
}