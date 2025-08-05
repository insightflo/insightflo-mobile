import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:insightflo_app/features/news/presentation/screens/news_home_screen.dart';
import 'package:insightflo_app/features/news/presentation/screens/news_detail_screen.dart';
import 'package:insightflo_app/features/news/presentation/screens/search_screen.dart';
import 'package:insightflo_app/features/news/presentation/screens/bookmarks_screen.dart';
import 'package:insightflo_app/features/news/presentation/screens/categories_screen.dart';
import 'package:insightflo_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:insightflo_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:insightflo_app/features/keywords/presentation/screens/keyword_management_screen.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/core/presentation/screens/main_wrapper_screen.dart';
import 'package:insightflo_app/core/presentation/screens/simple_splash_screen.dart';
import 'package:insightflo_app/core/presentation/screens/onboarding_screen.dart';
import 'package:insightflo_app/core/presentation/screens/error_screen.dart';
import 'route_transitions.dart' as transitions;
import 'package:insightflo_app/features/news/domain/entities/news_entity.dart';

/// go_router 기반 앱 라우터 구성
///
/// 기능:
/// - 딥링크 지원 및 URL 기반 네비게이션
/// - 중첩 라우팅 (탭 네비게이션, 바텀 네비게이션)
/// - 커스텀 페이지 전환 애니메이션
/// - 인증 상태 기반 라우트 가드
/// - 에러 처리 및 리다이렉션
/// - 브라우저 히스토리 지원
class AppRouter {
  /// 인증 상태 제공자
  final AuthProvider _authProvider;

  AppRouter(this._authProvider);

  /// 라우터 인스턴스 생성
  late final GoRouter router = GoRouter(
    // 라우터 설정
    debugLogDiagnostics: true,
    initialLocation: '/splash',

    // 전역 리다이렉션 로직
    redirect: (context, state) => _handleGlobalRedirect(context, state),

    // 리다이렉션 제한 (무한 루프 방지)
    redirectLimit: 10,

    // 라우트 정의
    routes: [
      _buildSplashRoute(),
      _buildOnboardingRoute(),
      _buildMainShellRoute(),
      _buildNewsDetailRoute(),
      _buildSearchRoute(),
      _buildSettingsRoute(),
      _buildKeywordManagementRoute(),
      _buildErrorRoute(),
    ],

    // 에러 처리
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error.toString(),
      onRetry: () => context.go('/'),
    ),

    // 네비게이션 변경 리스너
    observers: [NavigationObserver()],
  );

  /// 전역 리다이렉션 핸들러
  String? _handleGlobalRedirect(BuildContext context, GoRouterState state) {
    final currentLocation = state.uri.toString();
    
    // 스택 트레이스 출력
    debugPrint('🚦 ===== REDIRECT CHECK START =====');
    debugPrint('🚦 Location: $currentLocation');
    debugPrint('🚦 Stack trace:');
    debugPrintStack(maxFrames: 10);
    
    // 키워드 화면이면 어떤 경우에도 리다이렉트하지 않음
    if (currentLocation.startsWith('/keywords')) {
      debugPrint('🚦 KEYWORDS SCREEN DETECTED - SKIP ALL REDIRECTS');
      debugPrint('🚦 ===== REDIRECT CHECK END =====');
      return null;
    }
    
    debugPrint('🚦 Auth State:');
    debugPrint('   - isLoading: ${_authProvider.isLoading}');
    debugPrint('   - isInitialized: ${_authProvider.isInitialized}');
    debugPrint('   - isAuthenticated: ${_authProvider.isAuthenticated}');
    debugPrint('   - isOnboarded: ${_authProvider.isOnboarded}');

    // 온보딩 화면 처리
    if (currentLocation == '/onboarding') {
      debugPrint('   → Allowing onboarding screen');
      return null;
    }

    // 메인 앱 화면들 허용
    final mainAppPaths = ['/home', '/categories', '/bookmarks', '/profile', '/search', '/settings'];
    if (mainAppPaths.any((path) => currentLocation.startsWith(path))) {
      debugPrint('   → Allowing main app screen');
      return null;
    }

    // 스플래시 화면 처리 - 초기화가 완료되었다면 홈으로 이동
    if (currentLocation.startsWith('/splash')) {
      if (_authProvider.isInitialized) {
        if (_authProvider.isOnboarded) {
          debugPrint('   → Splash screen: redirecting to home (initialized and onboarded)');
          debugPrint('🚦 ===== REDIRECT CHECK END (redirecting to /home) =====');
          return '/home';
        } else {
          debugPrint('   → Splash screen: redirecting to onboarding (not onboarded)');
          debugPrint('🚦 ===== REDIRECT CHECK END (redirecting to /onboarding) =====');
          return '/onboarding';
        }
      } else {
        debugPrint('   → Allowing splash screen (not initialized yet)');
        debugPrint('🚦 ===== REDIRECT CHECK END (no redirect) =====');
        return null;
      }
    }

    // 초기화가 완료되지 않은 경우에만 스플래시로 리다이렉트
    if (!_authProvider.isInitialized) {
      debugPrint('   → Redirecting to splash (not initialized)');
      return '/splash';
    }

    final isAuthenticated = _authProvider.isAuthenticated;
    final isOnboarded = _authProvider.isOnboarded;

    // 온보딩이 완료되지 않은 경우
    if (!isOnboarded) {
      debugPrint('   → Redirecting to onboarding (not onboarded)');
      return '/onboarding';
    }

    // 인증이 필요한 라우트 체크
    if (_requiresAuthentication(currentLocation) && !isAuthenticated) {
      debugPrint('   → Redirecting to onboarding (auth required)');
      return '/onboarding';
    }

    debugPrint('   → No redirect needed');
    debugPrint('🚦 ===== REDIRECT CHECK END (no redirect) =====');
    return null;
  }

  bool _requiresAuthentication(String location) {
    final protectedRoutes = ['/bookmarks', '/profile', '/settings/sync'];

    return protectedRoutes.any((route) => location.startsWith(route));
  }

  /// 스플래시 화면 라우트
  GoRoute _buildSplashRoute() {
    return GoRoute(
      path: '/splash',
      name: 'splash',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey, 
        child: const SimpleSplashScreen(),
      ),
    );
  }

  /// 온보딩 화면 라우트
  GoRoute _buildOnboardingRoute() {
    return GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const OnboardingScreen()),
    );
  }

  /// 메인 ShellRoute (BottomNavigationBar를 포함한 중첩 라우팅)
  ShellRoute _buildMainShellRoute() {
    return ShellRoute(
      builder: (context, state, child) {
        return MainWrapperScreen(child: child);
      },
      routes: [
        // 홈 탭 라우트들
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => transitions.NoTransitionPage(
            key: state.pageKey,
            child: const NewsHomeScreen(),
          ),
        ),

        // 카테고리 탭
        GoRoute(
          path: '/categories',
          name: 'categories',
          pageBuilder: (context, state) => transitions.NoTransitionPage(
            key: state.pageKey,
            child: const CategoriesScreen(),
          ),
          routes: [
            // 카테고리별 뉴스 목록
            GoRoute(
              path: ':categoryId',
              name: 'category-news',
              pageBuilder: (context, state) {
                // final categoryId = state.pathParameters['categoryId']!;
                return MaterialPage(
                  key: state.pageKey,
                  child: const NewsHomeScreen(),
                );
              },
            ),
          ],
        ),

        // 북마크 탭
        GoRoute(
          path: '/bookmarks',
          name: 'bookmarks',
          pageBuilder: (context, state) => transitions.NoTransitionPage(
            key: state.pageKey,
            child: const BookmarksScreen(),
          ),
        ),

        // 프로필 탭
        GoRoute(
          path: '/profile',
          name: 'profile',
          pageBuilder: (context, state) => transitions.NoTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),

      ],
    );
  }

  /// 뉴스 상세 화면 라우트
  GoRoute _buildNewsDetailRoute() {
    return GoRoute(
      path: '/news-detail',
      name: 'news-detail',
      pageBuilder: (context, state) {
        // extra에서 NewsEntity 객체를 안전하게 추출합니다.
        final article = state.extra as NewsEntity?;

        // article이 null이면 에러 페이지를 표시합니다.
        if (article == null) {
          return transitions.CustomTransitionPage(
            key: state.pageKey,
            child: Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('기사 정보를 불러올 수 없습니다.')),
            ),
            transitionType: transitions.PageTransitionType.fade,
          );
        }

        // TransitionFactory에서 권장하는 slideUp 효과를 사용합니다.
        return transitions.CustomTransitionPage(
          key: state.pageKey,
          child: NewsDetailScreen(article: article),
          transitionType: transitions.PageTransitionType.slideUp,
        );
      },
    );
  }

  /// 검색 화면 라우트
  GoRoute _buildSearchRoute() {
    return GoRoute(
      path: '/search',
      name: 'search',
      pageBuilder: (context, state) {
        // final query = state.uri.queryParameters['q'];

        return MaterialPage(key: state.pageKey, child: const SearchScreen());
      },
    );
  }

  /// 설정 화면 라우트
  GoRoute _buildSettingsRoute() {
    return GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) =>
          MaterialPage(key: state.pageKey, child: const SettingsScreen()),
      routes: [
        // 프로필 설정
        GoRoute(
          path: 'profile',
          name: 'settings-profile',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const ProfileSettingsScreen(),
          ),
        ),

        // 동기화 설정
        GoRoute(
          path: 'sync',
          name: 'settings-sync',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const SyncSettingsScreen(),
          ),
        ),

        // 오프라인 기사 관리
        GoRoute(
          path: 'offline-articles',
          name: 'offline-articles',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const OfflineArticlesScreen(),
          ),
        ),

        // 자동 다운로드 설정
        GoRoute(
          path: 'auto-download',
          name: 'auto-download',
          pageBuilder: (context, state) => MaterialPage(
            key: state.pageKey,
            child: const AutoDownloadSettingsScreen(),
          ),
        ),
      ],
    );
  }

  /// 키워드 관리 화면 라우트 (독립적)
  GoRoute _buildKeywordManagementRoute() {
    return GoRoute(
      path: '/keywords',
      name: 'keywords',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const KeywordManagementScreen(),
      ),
    );
  }

  /// 에러 화면 라우트
  GoRoute _buildErrorRoute() {
    return GoRoute(
      path: '/error',
      name: 'error',
      pageBuilder: (context, state) {
        final error = state.extra as String? ?? 'Unknown error';

        return MaterialPage(
          key: state.pageKey,
          child: ErrorScreen(error: error, onRetry: () => context.go('/')),
        );
      },
    );
  }
}

/// 네비게이션 관찰자
class NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logNavigation('PUSH', route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logNavigation('POP', route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logNavigation('REMOVE', route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logNavigation('REPLACE', newRoute, oldRoute);
    }
  }

  void _logNavigation(
    String action,
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    debugPrint(
      '🧭 Navigation $action: ${route.settings.name ?? 'Unknown'} '
      '${previousRoute != null ? 'from ${previousRoute.settings.name ?? 'Unknown'}' : ''}',
    );
    
    // 스플래시 화면 네비게이션일 경우 스택 트레이스 출력
    if (route.settings.name == 'splash' || route.settings.name?.contains('splash') == true) {
      debugPrint('🚨 SPLASH NAVIGATION DETECTED - Stack trace:');
      debugPrintStack(maxFrames: 15);
    }
  }
}

/// 라우터 확장 메서드들
extension AppRouterExtension on GoRouter {
  /// 뉴스 상세로 이동 (딥링크 지원)
  void goToNewsDetail(String articleId, {bool fromSearch = false}) {
    go('/news/$articleId${fromSearch ? '?fromSearch=true' : ''}');
  }

  /// 검색 화면으로 이동
  void goToSearch({String? query}) {
    go('/search${query != null ? '?q=${Uri.encodeComponent(query)}' : ''}');
  }

  /// 카테고리별 뉴스로 이동
  void goToCategoryNews(String categoryId) {
    go('/categories/$categoryId');
  }

  /// 설정 화면으로 이동
  void goToSettings() {
    go('/settings');
  }

  /// 프로필 설정으로 이동
  void goToProfileSettings() {
    go('/settings/profile');
  }

  /// 북마크 화면으로 이동
  void goToBookmarks() {
    go('/bookmarks');
  }

  /// 키워드 관리 화면으로 이동
  void goToKeywordManagement() {
    go('/keywords');
  }

  /// 메인 탭으로 이동 (바텀 네비게이션)
  void goToMainTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        go('/home');
        break;
      case 1:
        go('/categories');
        break;
      case 2:
        go('/bookmarks');
        break;
      case 3:
        go('/profile');
        break;
      default:
        go('/home');
    }
  }

  /// 뒤로 가기가 가능한지 확인
  bool get canGoBack => routerDelegate.canPop();

  /// 안전한 뒤로 가기 (루트에서는 홈으로)
  void safeGoBack(BuildContext context) {
    if (canGoBack) {
      pop();
    } else {
      go('/home');
    }
  }
}

/// 딥링크 유틸리티
class DeepLinkHandler {
  static const String scheme = 'insightflo';
  static const String host = 'app';

  /// 딥링크 URL 생성
  static String createDeepLink(
    String path, [
    Map<String, String>? queryParams,
  ]) {
    final uri = Uri(
      scheme: scheme,
      host: host,
      path: path,
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  /// 뉴스 기사 딥링크 생성
  static String createNewsLink(String articleId) {
    return createDeepLink('/news/$articleId');
  }

  /// 검색 딥링크 생성
  static String createSearchLink(String query) {
    return createDeepLink('/search', {'q': query});
  }

  /// 카테고리 딥링크 생성
  static String createCategoryLink(String categoryId) {
    return createDeepLink('/categories/$categoryId');
  }

  /// 딥링크 파싱
  static Map<String, dynamic>? parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.scheme != scheme || uri.host != host) {
        return null;
      }

      return {'path': uri.path, 'queryParameters': uri.queryParameters};
    } catch (e) {
      debugPrint('딥링크 파싱 실패: $e');
      return null;
    }
  }
}

/// 라우트 유틸리티
class RouteUtils {
  /// 현재 라우트 정보 가져오기
  static GoRouterState getCurrentRoute(BuildContext context) {
    return GoRouterState.of(context);
  }

  /// 현재 경로 확인
  static String getCurrentPath(BuildContext context) {
    return getCurrentRoute(context).uri.path;
  }

  /// 쿼리 파라미터 가져오기
  static String? getQueryParameter(BuildContext context, String key) {
    return getCurrentRoute(context).uri.queryParameters[key];
  }

  /// 경로 파라미터 가져오기
  static String? getPathParameter(BuildContext context, String key) {
    return getCurrentRoute(context).pathParameters[key];
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
}

// 임시 스크린들 (실제 구현에서는 별도 파일로)

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정')),
      body: const Center(child: Text('프로필 설정 화면')),
    );
  }
}

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동기화 설정')),
      body: const Center(child: Text('동기화 설정 화면')),
    );
  }
}

class OfflineArticlesScreen extends StatelessWidget {
  const OfflineArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오프라인 기사')),
      body: const Center(child: Text('오프라인 기사 관리 화면')),
    );
  }
}

class AutoDownloadSettingsScreen extends StatelessWidget {
  const AutoDownloadSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('자동 다운로드 설정')),
      body: const Center(child: Text('자동 다운로드 설정 화면')),
    );
  }
}
