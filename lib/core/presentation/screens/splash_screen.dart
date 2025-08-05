import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/features/news/presentation/providers/theme_provider.dart';

/// 스플래시 화면
/// 
/// 기능:
/// - 앱 로딩 및 초기화
/// - 로고 애니메이션
/// - 인증 상태 확인
/// - 자동 라우팅
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  
  // 애니메이션 컨트롤러들
  late final AnimationController _logoController;
  late final AnimationController _progressController;
  late final AnimationController _fadeController;
  
  // 애니메이션들
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _progressValue;
  late final Animation<double> _fadeOpacity;
  
  // 로딩 상태
  double _progress = 0.0;
  String _loadingText = '앱을 시작하고 있습니다...';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startInitialization();
  }

  void _initializeAnimations() {
    // 로고 애니메이션 (0.8초)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _logoScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));
    
    _logoOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));
    
    // 프로그레스 애니메이션 (2초)
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _progressValue = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    // 페이드아웃 애니메이션 (0.5초)
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    // 애니메이션 리스너
    _progressController.addListener(() {
      if (mounted) {
        setState(() {
          _progress = _progressValue.value;
        });
      }
    });
  }

  Future<void> _startInitialization() async {
    // 로고 애니메이션 시작
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 프로그레스 애니메이션 시작
    _progressController.forward();
    
    // 실제 초기화 작업들
    await _performInitializationSteps();
    
    // 초기화 완료 후 네비게이션
    await _navigateToNextScreen();
  }

  Future<void> _performInitializationSteps() async {
    final steps = [
      ('테마 설정을 로드하고 있습니다...', _initializeTheme),
      ('사용자 정보를 확인하고 있습니다...', _checkAuthentication),
      ('캐시 데이터를 로드하고 있습니다...', _loadCacheData),
      ('네트워크 연결을 확인하고 있습니다...', _checkNetworkConnection),
      ('준비 완료!', _finalizeInitialization),
    ];
    
    for (int i = 0; i < steps.length; i++) {
      if (!mounted) return; // 위젯이 dispose된 경우 중단
      
      final (message, task) = steps[i];
      
      if (mounted) {
        setState(() {
          _loadingText = message;
        });
      }
      
      await task();
      
      // 각 단계별 최소 대기 시간
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  Future<void> _initializeTheme() async {
    if (!mounted) return;
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.initialize();
  }

  Future<void> _checkAuthentication() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkAuthenticationStatus();
  }

  Future<void> _loadCacheData() async {
    // 캐시 데이터 로드 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _checkNetworkConnection() async {
    // 네트워크 연결 확인 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 200));
  }

  Future<void> _finalizeInitialization() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _navigateToNextScreen() async {
    // 페이드아웃 애니메이션 시작
    _fadeController.forward();
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;
    
    final authProvider = context.read<AuthProvider>();
    
    // 인증 상태에 따른 라우팅
    if (!authProvider.isOnboarded) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeOpacity,
        child: _buildSplashContent(),
      ),
    );
  }

  Widget _buildSplashContent() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildLogoSection(),
          ),
          Expanded(
            flex: 1,
            child: _buildProgressSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 로고 애니메이션
          AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return Transform.scale(
                scale: _logoScale.value,
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primaryContainer,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.newspaper,
                      size: 60,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // 앱 이름
          FadeTransition(
            opacity: _logoOpacity,
            child: Text(
              'InsightFlo',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 태그라인
          FadeTransition(
            opacity: _logoOpacity,
            child: Text(
              '스마트한 뉴스 경험',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 프로그레스 바
          Container(
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 로딩 텍스트
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _loadingText,
              key: ValueKey(_loadingText),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 버전 정보
          Text(
            'v1.0.0',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// 스플래시 화면 변형 - 최소한의 로딩
class MinimalSplashScreen extends StatefulWidget {
  const MinimalSplashScreen({super.key});

  @override
  State<MinimalSplashScreen> createState() => _MinimalSplashScreenState();
}

class _MinimalSplashScreenState extends State<MinimalSplashScreen>
    with SingleTickerProviderStateMixin {
  
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat(reverse: true);
    
    // 2초 후 자동 네비게이션
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        final authProvider = context.read<AuthProvider>();
        
        if (!authProvider.isOnboarded) {
          context.go('/onboarding');
        } else {
          context.go('/home');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.newspaper,
                  size: 40,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}