import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 라우팅 유틸리티 클래스
/// 
/// 라우트 관련 편의 메서드와 헬퍼 함수들을 제공
class RouteUtils {
  /// 현재 라우트 정보 가져오기
  static GoRouterState getCurrentRoute(BuildContext context) {
    return GoRouterState.of(context);
  }

  /// 현재 경로 확인
  static String getCurrentPath(BuildContext context) {
    return getCurrentRoute(context).uri.path;
  }

  /// 현재 전체 URI 가져오기
  static Uri getCurrentUri(BuildContext context) {
    return getCurrentRoute(context).uri;
  }

  /// 쿼리 파라미터 가져오기
  static String? getQueryParameter(BuildContext context, String key) {
    return getCurrentRoute(context).uri.queryParameters[key];
  }

  /// 모든 쿼리 파라미터 가져오기
  static Map<String, String> getAllQueryParameters(BuildContext context) {
    return getCurrentRoute(context).uri.queryParameters;
  }

  /// 경로 파라미터 가져오기
  static String? getPathParameter(BuildContext context, String key) {
    return getCurrentRoute(context).pathParameters[key];
  }

  /// 모든 경로 파라미터 가져오기
  static Map<String, String> getAllPathParameters(BuildContext context) {
    return getCurrentRoute(context).pathParameters;
  }

  /// 메인 탭인지 확인
  static bool isMainTab(String path) {
    const mainTabs = ['/home', '/categories', '/bookmarks', '/profile'];
    return mainTabs.contains(path) || path == '/';
  }

  /// 탭 인덱스 가져오기
  static int getTabIndex(String path) {
    switch (path) {
      case '/home':
      case '/':
        return 0;
      case '/categories':
        return 1;
      case '/bookmarks':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0;
    }
  }

  /// 경로에서 탭 경로 추출
  static String getTabPath(String path) {
    if (path.startsWith('/home')) return '/home';
    if (path.startsWith('/categories')) return '/categories';
    if (path.startsWith('/bookmarks')) return '/bookmarks';
    if (path.startsWith('/profile')) return '/profile';
    return '/home';
  }

  /// 현재 경로가 특정 경로의 하위 경로인지 확인
  static bool isSubRouteOf(BuildContext context, String parentPath) {
    final currentPath = getCurrentPath(context);
    return currentPath.startsWith(parentPath) && currentPath != parentPath;
  }

  /// 브레드크럼 경로 생성
  static List<String> getBreadcrumbPaths(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final breadcrumbs = <String>[];
    
    String currentPath = '';
    for (final segment in segments) {
      currentPath += '/$segment';
      breadcrumbs.add(currentPath);
    }
    
    return breadcrumbs;
  }

  /// 경로 깊이 계산
  static int getPathDepth(String path) {
    return path.split('/').where((s) => s.isNotEmpty).length;
  }

  /// 상위 경로 가져오기
  static String? getParentPath(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;
    
    segments.removeLast();
    return segments.isEmpty ? '/' : '/${segments.join('/')}';
  }

  /// 안전한 네비게이션 (존재하지 않는 경로 처리)
  static void safeGo(BuildContext context, String path) {
    try {
      context.go(path);
    } catch (e) {
      debugPrint('Navigation error: $e');
      // 기본 경로로 폴백
      context.go('/home');
    }
  }

  /// 안전한 푸시 네비게이션
  static void safePush(BuildContext context, String path) {
    try {
      context.push(path);
    } catch (e) {
      debugPrint('Navigation push error: $e');
      // go로 폴백
      safeGo(context, path);
    }
  }

  /// 조건부 네비게이션
  static void goIf(BuildContext context, String path, bool condition) {
    if (condition) {
      safeGo(context, path);
    }
  }

  /// 뒤로 가기 가능 여부 확인
  static bool canGoBack(BuildContext context) {
    return GoRouter.of(context).canPop();
  }

  /// 안전한 뒤로 가기 (루트에서는 홈으로)
  static void safeGoBack(BuildContext context, {String fallbackPath = '/home'}) {
    if (canGoBack(context)) {
      context.pop();
    } else {
      safeGo(context, fallbackPath);
    }
  }

  /// 특정 경로까지 뒤로 가기
  static void popUntil(BuildContext context, String targetPath) {
    while (canGoBack(context) && getCurrentPath(context) != targetPath) {
      context.pop();
    }
  }

  /// 현재 경로가 인증이 필요한지 확인
  static bool requiresAuthentication(String path) {
    const authRequiredPaths = [
      '/bookmarks',
      '/profile',
      '/settings',
    ];
    
    return authRequiredPaths.any((p) => path.startsWith(p));
  }

  /// 현재 경로가 프리미엄 기능인지 확인
  static bool isPremiumFeature(String path) {
    const premiumPaths = [
      '/premium',
      '/advanced-search',
      '/export',
    ];
    
    return premiumPaths.any((p) => path.startsWith(p));
  }

  /// URL에서 기사 ID 추출
  static String? extractArticleId(String path) {
    final match = RegExp(r'/news/([^/]+)').firstMatch(path);
    return match?.group(1);
  }

  /// URL에서 카테고리 ID 추출
  static String? extractCategoryId(String path) {
    final match = RegExp(r'/categories/([^/]+)').firstMatch(path);
    return match?.group(1);
  }

  /// 검색 쿼리 URL 생성
  static String buildSearchUrl(String query, {Map<String, String>? filters}) {
    final uri = Uri(
      path: '/search',
      queryParameters: {
        'q': query,
        if (filters != null) ...filters,
      },
    );
    return uri.toString();
  }

  /// 뉴스 상세 URL 생성
  static String buildNewsDetailUrl(String articleId, {bool fromSearch = false}) {
    final uri = Uri(
      path: '/news/$articleId',
      queryParameters: fromSearch ? {'fromSearch': 'true'} : null,
    );
    return uri.toString();
  }

  /// 카테고리 뉴스 URL 생성
  static String buildCategoryNewsUrl(String categoryId) {
    return '/categories/$categoryId';
  }

  /// 쿼리 파라미터 업데이트
  static String updateQueryParameter(
    String currentUrl,
    String key,
    String value,
  ) {
    final uri = Uri.parse(currentUrl);
    final newParams = Map<String, String>.from(uri.queryParameters);
    newParams[key] = value;
    
    return uri.replace(queryParameters: newParams).toString();
  }

  /// 쿼리 파라미터 제거
  static String removeQueryParameter(String currentUrl, String key) {
    final uri = Uri.parse(currentUrl);
    final newParams = Map<String, String>.from(uri.queryParameters);
    newParams.remove(key);
    
    return uri.replace(queryParameters: newParams.isEmpty ? null : newParams).toString();
  }

  /// 경로 정규화
  static String normalizePath(String path) {
    // 연속된 슬래시 제거
    path = path.replaceAll(RegExp(r'/+'), '/');
    
    // 마지막 슬래시 제거 (루트 경로 제외)
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    
    // 빈 경로는 루트로
    if (path.isEmpty) {
      path = '/';
    }
    
    return path;
  }

  /// 외부 URL인지 확인
  static bool isExternalUrl(String url) {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// 딥링크 URL 파싱
  static Map<String, dynamic>? parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      
      // 앱 스킴 확인
      if (uri.scheme != 'insightflo') {
        return null;
      }
      
      return {
        'path': uri.path,
        'queryParameters': uri.queryParameters,
        'host': uri.host,
      };
    } catch (e) {
      debugPrint('딥링크 파싱 실패: $e');
      return null;
    }
  }

  /// 경로 매칭 패턴 확인
  static bool matchesPattern(String path, String pattern) {
    // 간단한 와일드카드 패턴 매칭
    final regexPattern = pattern
        .replaceAll('*', '.*')
        .replaceAll('?', '.');
    
    return RegExp('^$regexPattern\$').hasMatch(path);
  }

  /// 라우트 메타데이터 가져오기
  static Map<String, dynamic> getRouteMetadata(String path) {
    // 라우트별 메타데이터 정의
    const routeMetadata = {
      '/home': {
        'title': '홈',
        'icon': Icons.home,
        'showInNavigation': true,
        'requiresAuth': false,
      },
      '/categories': {
        'title': '카테고리',
        'icon': Icons.category,
        'showInNavigation': true,
        'requiresAuth': false,
      },
      '/bookmarks': {
        'title': '북마크',
        'icon': Icons.bookmark,
        'showInNavigation': true,
        'requiresAuth': true,
      },
      '/profile': {
        'title': '프로필',
        'icon': Icons.person,
        'showInNavigation': true,
        'requiresAuth': true,
      },
      '/settings': {
        'title': '설정',
        'icon': Icons.settings,
        'showInNavigation': false,
        'requiresAuth': false,
      },
    };

    return routeMetadata[path] ?? {};
  }

  /// 현재 경로의 제목 가져오기
  static String getRouteTitle(BuildContext context) {
    final path = getCurrentPath(context);
    final metadata = getRouteMetadata(path);
    return metadata['title'] as String? ?? '앱';
  }

  /// 네비게이션 히스토리 관리
  static void clearNavigationHistory(BuildContext context) {
    // 모든 스택을 클리어하고 홈으로 이동
    while (canGoBack(context)) {
      context.pop();
    }
    context.go('/home');
  }

  /// 특정 경로로 리셋 (모든 히스토리 클리어)
  static void resetToPath(BuildContext context, String path) {
    clearNavigationHistory(context);
    safeGo(context, path);
  }

  /// 조건부 리다이렉션
  static void redirectIf(
    BuildContext context,
    bool condition,
    String targetPath,
  ) {
    if (condition) {
      safeGo(context, targetPath);
    }
  }

  /// 네비게이션 상태 로깅
  static void logNavigationState(BuildContext context) {
    final route = getCurrentRoute(context);
    debugPrint('🧭 Navigation State:');
    debugPrint('  Path: ${route.uri.path}');
    debugPrint('  Query: ${route.uri.queryParameters}');
    debugPrint('  Path Params: ${route.pathParameters}');
    debugPrint('  Can Go Back: ${canGoBack(context)}');
  }
}

/// 네비게이션 이벤트 타입
enum NavigationEventType {
  push,
  pop,
  replace,
  redirect,
}

/// 네비게이션 이벤트
class NavigationEvent {
  final NavigationEventType type;
  final String fromPath;
  final String toPath;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  NavigationEvent({
    required this.type,
    required this.fromPath,
    required this.toPath,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() {
    return 'NavigationEvent(${type.name}: $fromPath -> $toPath at $timestamp)';
  }
}

/// 네비게이션 히스토리 매니저
class NavigationHistoryManager {
  static final List<NavigationEvent> _history = [];
  static const int maxHistorySize = 100;

  /// 이벤트 추가
  static void addEvent(NavigationEvent event) {
    _history.add(event);
    
    // 히스토리 크기 제한
    if (_history.length > maxHistorySize) {
      _history.removeAt(0);
    }
    
    debugPrint('📝 ${event.toString()}');
  }

  /// 히스토리 가져오기
  static List<NavigationEvent> getHistory() {
    return List.unmodifiable(_history);
  }

  /// 최근 이벤트 가져오기
  static NavigationEvent? getLastEvent() {
    return _history.isEmpty ? null : _history.last;
  }

  /// 특정 타입의 이벤트 필터링
  static List<NavigationEvent> getEventsByType(NavigationEventType type) {
    return _history.where((event) => event.type == type).toList();
  }

  /// 히스토리 클리어
  static void clearHistory() {
    _history.clear();
  }

  /// 히스토리 통계
  static Map<String, int> getStatistics() {
    final stats = <String, int>{};
    
    for (final event in _history) {
      final key = event.type.name;
      stats[key] = (stats[key] ?? 0) + 1;
    }
    
    return stats;
  }
}