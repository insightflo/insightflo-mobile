import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';

/// 라우트 가드 타입
enum GuardType {
  /// 인증이 필요한 라우트
  authenticated,
  
  /// 인증되지 않은 사용자만 접근 가능한 라우트
  unauthenticated,
  
  /// 온보딩이 완료된 사용자만 접근 가능
  onboarded,
  
  /// 관리자 권한이 필요한 라우트
  admin,
  
  /// 프리미엄 사용자만 접근 가능한 라우트
  premium,
  
  /// 커스텀 조건
  custom,
}

/// 라우트 가드 결과
enum GuardResult {
  /// 접근 허용
  allow,
  
  /// 접근 거부 및 리다이렉션
  redirect,
  
  /// 접근 거부 및 에러 표시
  deny,
}

/// 라우트 가드 응답
class GuardResponse {
  final GuardResult result;
  final String? redirectPath;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const GuardResponse({
    required this.result,
    this.redirectPath,
    this.errorMessage,
    this.metadata,
  });

  /// 허용 응답
  static const GuardResponse allow = GuardResponse(result: GuardResult.allow);

  /// 리다이렉션 응답
  static GuardResponse redirect(String path) => GuardResponse(
        result: GuardResult.redirect,
        redirectPath: path,
      );

  /// 거부 응답
  static GuardResponse deny(String message) => GuardResponse(
        result: GuardResult.deny,
        errorMessage: message,
      );
}

/// 라우트 가드 인터페이스
abstract class RouteGuard {
  /// 가드 이름
  String get name;

  /// 가드 검사 실행
  Future<GuardResponse> check(BuildContext context, GoRouterState state);

  /// 가드 우선순위 (낮을수록 먼저 실행)
  int get priority => 0;
}

/// 인증 가드
class AuthenticationGuard implements RouteGuard {
  final AuthProvider _authProvider;

  AuthenticationGuard(this._authProvider);

  @override
  String get name => 'Authentication';

  @override
  int get priority => 1;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    if (_authProvider.isAuthenticated) {
      return GuardResponse.allow;
    }

    // 로그인이 필요한 메시지와 함께 온보딩으로 리다이렉션
    return GuardResponse.redirect('/onboarding');
  }
}

/// 온보딩 가드
class OnboardingGuard implements RouteGuard {
  final AuthProvider _authProvider;

  OnboardingGuard(this._authProvider);

  @override
  String get name => 'Onboarding';

  @override
  int get priority => 0; // 가장 높은 우선순위

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    if (_authProvider.isOnboarded) {
      return GuardResponse.allow;
    }

    return GuardResponse.redirect('/onboarding');
  }
}

/// 관리자 권한 가드
class AdminGuard implements RouteGuard {
  final AuthProvider _authProvider;

  AdminGuard(this._authProvider);

  @override
  String get name => 'Admin';

  @override
  int get priority => 2;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    if (!_authProvider.isAuthenticated) {
      return GuardResponse.redirect('/onboarding');
    }

    if (_authProvider.currentUser?.isAdmin == true) {
      return GuardResponse.allow;
    }

    return GuardResponse.deny('관리자 권한이 필요합니다.');
  }
}

/// 프리미엄 사용자 가드
class PremiumGuard implements RouteGuard {
  final AuthProvider _authProvider;

  PremiumGuard(this._authProvider);

  @override
  String get name => 'Premium';

  @override
  int get priority => 3;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    if (!_authProvider.isAuthenticated) {
      return GuardResponse.redirect('/onboarding');
    }

    if (_authProvider.currentUser?.isPremium == true) {
      return GuardResponse.allow;
    }

    return GuardResponse.redirect('/premium-upgrade');
  }
}

/// 게스트 전용 가드 (로그인하지 않은 사용자만)
class GuestOnlyGuard implements RouteGuard {
  final AuthProvider _authProvider;

  GuestOnlyGuard(this._authProvider);

  @override
  String get name => 'GuestOnly';

  @override
  int get priority => 1;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    if (!_authProvider.isAuthenticated) {
      return GuardResponse.allow;
    }

    // 이미 로그인된 사용자는 홈으로 리다이렉션
    return GuardResponse.redirect('/home');
  }
}

/// 디바이스 상태 가드
class DeviceStateGuard implements RouteGuard {
  @override
  String get name => 'DeviceState';

  @override
  int get priority => 10;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    // 네트워크 연결 상태 확인
    final hasConnection = await _checkNetworkConnection();
    
    if (!hasConnection && _requiresNetwork(state.uri.path)) {
      return GuardResponse.redirect('/offline');
    }

    // 저장공간 확인
    final hasEnoughStorage = await _checkStorageSpace();
    
    if (!hasEnoughStorage && _requiresStorage(state.uri.path)) {
      return GuardResponse.deny('저장공간이 부족합니다.');
    }

    return GuardResponse.allow;
  }

  Future<bool> _checkNetworkConnection() async {
    // 실제 구현에서는 connectivity_plus 패키지 사용
    return true; // 임시로 true 반환
  }

  Future<bool> _checkStorageSpace() async {
    // 실제 구현에서는 저장공간 확인 로직
    return true; // 임시로 true 반환
  }

  bool _requiresNetwork(String path) {
    final networkRequiredPaths = [
      '/search',
      '/sync',
      '/premium-upgrade',
    ];
    
    return networkRequiredPaths.any((p) => path.startsWith(p));
  }

  bool _requiresStorage(String path) {
    final storageRequiredPaths = [
      '/offline-articles',
      '/downloads',
    ];
    
    return storageRequiredPaths.any((p) => path.startsWith(p));
  }
}

/// 시간 기반 가드
class TimeBasedGuard implements RouteGuard {
  final DateTime? startTime;
  final DateTime? endTime;
  final List<int>? allowedWeekdays; // 1(월) ~ 7(일)

  TimeBasedGuard({
    this.startTime,
    this.endTime,
    this.allowedWeekdays,
  });

  @override
  String get name => 'TimeBased';

  @override
  int get priority => 5;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) async {
    final now = DateTime.now();

    // 시간 범위 확인
    if (startTime != null && endTime != null) {
      final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
      final start = TimeOfDay(hour: startTime!.hour, minute: startTime!.minute);
      final end = TimeOfDay(hour: endTime!.hour, minute: endTime!.minute);

      if (!_isTimeInRange(currentTime, start, end)) {
        return GuardResponse.deny('현재 시간에는 접근할 수 없습니다.');
      }
    }

    // 요일 확인
    if (allowedWeekdays != null && !allowedWeekdays!.contains(now.weekday)) {
      return GuardResponse.deny('오늘은 접근할 수 없습니다.');
    }

    return GuardResponse.allow;
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // 같은 날 범위
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // 자정을 넘나드는 범위
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }
}

/// 커스텀 조건 가드
class CustomConditionGuard implements RouteGuard {
  final String _name;
  final Future<GuardResponse> Function(BuildContext, GoRouterState) _condition;
  final int _priority;

  CustomConditionGuard({
    required String name,
    required Future<GuardResponse> Function(BuildContext, GoRouterState) condition,
    int priority = 5,
  })  : _name = name,
        _condition = condition,
        _priority = priority;

  @override
  String get name => _name;

  @override
  int get priority => _priority;

  @override
  Future<GuardResponse> check(BuildContext context, GoRouterState state) {
    return _condition(context, state);
  }
}

/// 가드 매니저 - 여러 가드를 관리하고 실행
class GuardManager {
  final List<RouteGuard> _guards = [];

  /// 가드 추가
  void addGuard(RouteGuard guard) {
    _guards.add(guard);
    _sortGuards();
  }

  /// 가드 제거
  void removeGuard(String name) {
    _guards.removeWhere((guard) => guard.name == name);
  }

  /// 모든 가드 실행
  Future<GuardResponse> checkAll(BuildContext context, GoRouterState state) async {
    for (final guard in _guards) {
      try {
        final response = await guard.check(context, state);
        
        if (response.result != GuardResult.allow) {
          debugPrint('🛡️ Guard ${guard.name} blocked access to ${state.uri.path}');
          return response;
        }
      } catch (e) {
        debugPrint('🛡️ Guard ${guard.name} failed: $e');
        return GuardResponse.deny('인증 확인 중 오류가 발생했습니다.');
      }
    }

    return GuardResponse.allow;
  }

  /// 특정 가드만 실행
  Future<GuardResponse> checkGuard(
    String name,
    BuildContext context,
    GoRouterState state,
  ) async {
    final guard = _guards.firstWhere(
      (g) => g.name == name,
      orElse: () => throw ArgumentError('Guard $name not found'),
    );

    return guard.check(context, state);
  }

  /// 우선순위별로 가드 정렬
  void _sortGuards() {
    _guards.sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// 등록된 가드 목록 가져오기
  List<String> get registeredGuards => _guards.map((g) => g.name).toList();

  /// 가드 초기화
  void clear() {
    _guards.clear();
  }
}

/// 라우트별 가드 설정
class RouteGuardConfig {
  static final Map<String, List<String>> _routeGuards = {
    // 인증이 필요한 라우트
    '/bookmarks': ['Onboarding', 'Authentication'],
    '/profile': ['Onboarding', 'Authentication'],
    '/settings/sync': ['Onboarding', 'Authentication'],
    '/settings/profile': ['Onboarding', 'Authentication'],
    
    // 프리미엄 기능
    '/premium-features': ['Onboarding', 'Authentication', 'Premium'],
    '/advanced-search': ['Onboarding', 'Authentication', 'Premium'],
    
    // 관리자 전용
    '/admin': ['Onboarding', 'Authentication', 'Admin'],
    '/admin/users': ['Onboarding', 'Authentication', 'Admin'],
    
    // 게스트 전용 (로그인 시 접근 불가)
    '/onboarding': ['GuestOnly'],
    '/login': ['GuestOnly'],
    
    // 네트워크 필요
    '/search': ['DeviceState'],
    '/sync': ['DeviceState'],
  };

  /// 라우트에 필요한 가드 목록 가져오기
  static List<String> getGuardsForRoute(String path) {
    for (final entry in _routeGuards.entries) {
      if (path.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return [];
  }

  /// 라우트에 가드 추가
  static void addGuardToRoute(String path, String guardName) {
    _routeGuards[path] = [...(_routeGuards[path] ?? []), guardName];
  }

  /// 라우트에서 가드 제거
  static void removeGuardFromRoute(String path, String guardName) {
    _routeGuards[path]?.remove(guardName);
  }
}

/// 가드 팩토리 - 일반적인 가드들을 쉽게 생성
class GuardFactory {
  /// 기본 가드 세트 생성
  static List<RouteGuard> createDefaultGuards(AuthProvider authProvider) {
    return [
      OnboardingGuard(authProvider),
      AuthenticationGuard(authProvider),
      AdminGuard(authProvider),
      PremiumGuard(authProvider),
      GuestOnlyGuard(authProvider),
      DeviceStateGuard(),
    ];
  }

  /// 시간 제한 가드 생성
  static RouteGuard createTimeRestrictedGuard({
    required String name,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    List<int>? allowedWeekdays,
  }) {
    return TimeBasedGuard(
      startTime: startTime != null 
          ? DateTime(2024, 1, 1, startTime.hour, startTime.minute)
          : null,
      endTime: endTime != null
          ? DateTime(2024, 1, 1, endTime.hour, endTime.minute)
          : null,
      allowedWeekdays: allowedWeekdays,
    );
  }

  /// 역할 기반 가드 생성
  static RouteGuard createRoleGuard({
    required String name,
    required List<String> allowedRoles,
    required AuthProvider authProvider,
  }) {
    return CustomConditionGuard(
      name: name,
      condition: (context, state) async {
        if (!authProvider.isAuthenticated) {
          return GuardResponse.redirect('/onboarding');
        }

        final userRoles = authProvider.currentUser?.roles ?? [];
        final hasRequiredRole = allowedRoles.any((role) => userRoles.contains(role));

        if (hasRequiredRole) {
          return GuardResponse.allow;
        }

        return GuardResponse.deny('권한이 부족합니다.');
      },
    );
  }
}