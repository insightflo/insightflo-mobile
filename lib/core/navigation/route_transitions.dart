import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 페이지 전환 애니메이션 타입
enum PageTransitionType {
  /// 페이드 전환 (투명도 변화)
  fade,

  /// 오른쪽에서 슬라이드
  slideRight,

  /// 왼쪽에서 슬라이드
  slideLeft,

  /// 아래에서 슬라이드 업
  slideUp,

  /// 위에서 슬라이드 다운
  slideDown,

  /// 스케일 전환 (크기 변화)
  scale,

  /// 회전 전환
  rotation,

  /// 커스텀 슬라이드 (더 부드러운 전환)
  customSlide,

  /// Material 스타일 전환
  material,

  /// Cupertino 스타일 전환
  cupertino,
}

/// 커스텀 전환 페이지
///
/// 다양한 페이지 전환 애니메이션을 지원하는 커스텀 페이지 클래스
///
/// 사용 예시:
/// ```dart
/// GoRoute(
///   path: '/detail',
///   pageBuilder: (context, state) => CustomTransitionPage(
///     key: state.pageKey,
///     child: DetailScreen(),
///     transitionType: PageTransitionType.slideUp,
///   ),
/// )
/// ```
class CustomTransitionPage<T> extends Page<T> {
  /// 표시할 위젯
  final Widget child;

  /// 전환 타입
  final PageTransitionType transitionType;

  /// 전환 지속 시간
  final Duration duration;

  /// 역전환 지속 시간
  final Duration reverseDuration;

  /// 커스텀 커브
  final Curve curve;

  /// 역전환 커브
  final Curve reverseCurve;

  const CustomTransitionPage({
    required super.key,
    required this.child,
    this.transitionType = PageTransitionType.slideRight,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOut,
    this.reverseCurve = Curves.easeInOut,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _buildTransitionByType(
          context,
          animation,
          secondaryAnimation,
          child,
          transitionType,
          curve,
          reverseCurve,
        );
      },
      transitionDuration: duration,
      reverseTransitionDuration: reverseDuration,
    );
  }

  /// 전환 타입에 따른 애니메이션 빌더
  static Widget _buildTransitionByType(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    PageTransitionType type,
    Curve curve,
    Curve reverseCurve,
  ) {
    switch (type) {
      case PageTransitionType.fade:
        return FadeTransition(
          opacity: animation.drive(CurveTween(curve: curve)),
          child: child,
        );

      case PageTransitionType.slideRight:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: curve)),
          ),
          child: child,
        );

      case PageTransitionType.slideLeft:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: curve)),
          ),
          child: child,
        );

      case PageTransitionType.slideUp:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: curve)),
          ),
          child: child,
        );

      case PageTransitionType.slideDown:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: curve)),
          ),
          child: child,
        );

      case PageTransitionType.scale:
        return ScaleTransition(
          scale: animation.drive(
            Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)),
          ),
          child: child,
        );

      case PageTransitionType.rotation:
        return RotationTransition(
          turns: animation.drive(
            Tween<double>(
              begin: 0.25,
              end: 1.0,
            ).chain(CurveTween(curve: curve)),
          ),
          child: FadeTransition(opacity: animation, child: child),
        );

      case PageTransitionType.customSlide:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
          ),
          child: FadeTransition(
            opacity: animation.drive(
              Tween<double>(
                begin: 0.5,
                end: 1.0,
              ).chain(CurveTween(curve: Curves.easeIn)),
            ),
            child: child,
          ),
        );

      case PageTransitionType.material:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
          ),
          child: child,
        );

      case PageTransitionType.cupertino:
        return SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.linearToEaseOut)),
          ),
          child: child,
        );
    }
  }
}

/// 전환 없는 페이지 (탭 전환용)
class NoTransitionPage<T> extends Page<T> {
  /// 표시할 위젯
  final Widget child;

  const NoTransitionPage({
    required super.key,
    required this.child,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

/// 고급 전환 효과들
class AdvancedTransitions {
  // 성능 최적화를 위한 Matrix4 객체 재사용
  static final Matrix4 _identityMatrix = Matrix4.identity()
    ..setEntry(3, 2, 0.001);

  /// 더블 슬라이드 전환 (이전 페이지도 함께 슬라이드)
  static Widget doubleSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
      ),
      child: SlideTransition(
        position: secondaryAnimation.drive(
          Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.3, 0.0),
          ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
        ),
        child: child,
      ),
    );
  }

  /// 3D 플립 전환 (Matrix4 객체 재사용으로 성능 최적화)
  static Widget flipTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 애니메이션 값에 따라 Y축을 기준으로 회전합니다.
        // Matrix4.copy를 사용하여 매번 새로운 객체 생성을 방지하고 성능을 최적화합니다.
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.copy(_identityMatrix)
            ..rotateY(animation.value * 3.14159),
          child: child,
        );
      },
      child: child,
    );
  }

  /// 확대/축소 슬라이드 전환
  static Widget scaleSlideTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      ),
      child: ScaleTransition(
        scale: animation.drive(
          Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );
  }

  /// 회전 + 페이드 전환
  static Widget rotationFadeTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: RotationTransition(
        turns: animation.drive(
          Tween<double>(
            begin: 0.1,
            end: 0.0,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
        ),
        child: child,
      ),
    );
  }

  /// 시차 효과 전환
  static Widget parallaxTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Stack(
      children: [
        SlideTransition(
          position: secondaryAnimation.drive(
            Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.3, 0.0),
            ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
          ),
          child: child, // 이전 페이지
        ),
        SlideTransition(
          position: animation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.fastOutSlowIn)),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// 전환 효과 팩토리
class TransitionFactory {
  /// 플랫폼별 기본 전환 가져오기
  static PageTransitionType getDefaultTransition(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
        return PageTransitionType.cupertino;
      case TargetPlatform.android:
        return PageTransitionType.material;
      default:
        return PageTransitionType.slideRight;
    }
  }

  /// 화면 타입별 전환 권장사항
  static PageTransitionType getRecommendedTransition(String routeName) {
    switch (routeName) {
      case 'splash':
      case 'onboarding':
        return PageTransitionType.fade;

      case 'news-detail':
      case 'search':
        return PageTransitionType.slideUp;

      case 'settings':
      case 'profile':
        return PageTransitionType.slideRight;

      case 'modal':
      case 'dialog':
        return PageTransitionType.scale;

      default:
        return PageTransitionType.slideRight;
    }
  }

  /// 커스텀 전환 빌더
  static RouteTransitionsBuilder createCustomTransition({
    required PageTransitionType type,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return (context, animation, secondaryAnimation, child) {
      return CustomTransitionPage._buildTransitionByType(
        context,
        animation,
        secondaryAnimation,
        child,
        type,
        curve,
        curve,
      );
    };
  }
}

/// 전환 설정 클래스
class TransitionConfig {
  final PageTransitionType type;
  final Duration duration;
  final Duration reverseDuration;
  final Curve curve;
  final Curve reverseCurve;
  final bool maintainState;
  final bool opaque;

  const TransitionConfig({
    this.type = PageTransitionType.slideRight,
    this.duration = const Duration(milliseconds: 300),
    this.reverseDuration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOut,
    this.reverseCurve = Curves.easeInOut,
    this.maintainState = true,
    this.opaque = true,
  });

  /// 빠른 전환 설정
  static const TransitionConfig fast = TransitionConfig(
    duration: Duration(milliseconds: 200),
    reverseDuration: Duration(milliseconds: 150),
    curve: Curves.easeOut,
  );

  /// 느린 전환 설정
  static const TransitionConfig slow = TransitionConfig(
    duration: Duration(milliseconds: 500),
    reverseDuration: Duration(milliseconds: 400),
    curve: Curves.easeInOutCubic,
  );

  /// iOS 스타일 설정
  static const TransitionConfig ios = TransitionConfig(
    type: PageTransitionType.cupertino,
    duration: Duration(milliseconds: 300),
    curve: Curves.linearToEaseOut,
  );

  /// Material 스타일 설정
  static const TransitionConfig material = TransitionConfig(
    type: PageTransitionType.material,
    duration: Duration(milliseconds: 300),
    curve: Curves.fastOutSlowIn,
  );
}
