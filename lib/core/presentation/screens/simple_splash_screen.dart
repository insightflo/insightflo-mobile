import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';

/// 간단한 스플래시 화면
/// 메모리 리크 방지를 위한 최소한의 구현
class SimpleSplashScreen extends StatefulWidget {
  const SimpleSplashScreen({super.key});

  @override
  State<SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends State<SimpleSplashScreen>
    with SingleTickerProviderStateMixin {
  
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat(reverse: true);
    
    // 초기화 및 네비게이션
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    // 최소 스플래시 시간 보장
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;
    
    // AuthProvider 상태 확인
    final authProvider = context.read<AuthProvider>();
    
    // AuthProvider 초기화 대기
    int retryCount = 0;
    while (!authProvider.isInitialized && retryCount < 30) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 100));
      retryCount++;
    }
    
    if (!mounted) return;
    
    // 현재 경로가 키워드 화면이면 자동 네비게이션하지 않음
    final currentLocation = GoRouter.of(context).routeInformationProvider.value.uri.toString();
    if (currentLocation.startsWith('/keywords')) {
      debugPrint('SimpleSplashScreen: Keywords screen detected - NOT navigating away');
      return;
    }
    
    debugPrint('SimpleSplashScreen: Navigating to appropriate screen');
    
    if (!authProvider.isOnboarded) {
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 애니메이션
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
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
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // 앱 이름
            Text(
              'InsightFlo',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // 태그라인
            Text(
              '스마트한 뉴스 경험',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 64),
            
            // 로딩 인디케이터
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}