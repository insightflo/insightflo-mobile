import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';

/// 온보딩 화면
/// 
/// 기능:
/// - 앱 소개 및 주요 기능 안내
/// - 페이지 전환 애니메이션
/// - 권한 요청 및 설정
/// - 첫 실행 설정 완료
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'InsightFlo에 오신 것을 환영합니다',
      description: '스마트한 뉴스 경험을 시작하세요.\n개인화된 뉴스 피드와 똑똑한 검색으로\n원하는 정보를 빠르게 찾아보세요.',
      imagePath: 'assets/images/onboarding_1.png',
      icon: Icons.newspaper,
    ),
    OnboardingPage(
      title: '맞춤형 뉴스 추천',
      description: 'AI가 분석한 여러분의 관심사에 맞는\n뉴스를 추천해드립니다.\n더 이상 필요없는 정보에 시간을 낭비하지 마세요.',
      imagePath: 'assets/images/onboarding_2.png',
      icon: Icons.recommend,
    ),
    OnboardingPage(
      title: '똑똑한 검색과 음성 인식',
      description: '고급 검색 필터와 음성 검색으로\n원하는 뉴스를 쉽고 빠르게 찾아보세요.\n감정 분석과 키워드 매칭까지 지원합니다.',
      imagePath: 'assets/images/onboarding_3.png',
      icon: Icons.search,
    ),
    OnboardingPage(
      title: '북마크와 오프라인 읽기',
      description: '중요한 기사는 북마크로 저장하고\n오프라인에서도 언제든지 읽어보세요.\n폴더로 정리하여 체계적으로 관리할 수 있습니다.',
      imagePath: 'assets/images/onboarding_4.png',
      icon: Icons.bookmark,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildPageView(),
            ),
            _buildPageIndicator(),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 로고
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                  ),
                ),
                child: Icon(
                  Icons.newspaper,
                  size: 20,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'InsightFlo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          // 건너뛰기 버튼
          if (_currentPage < _pages.length - 1)
            TextButton(
              onPressed: _completeOnboarding,
              child: const Text('건너뛰기'),
            ),
        ],
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      itemCount: _pages.length,
      itemBuilder: (context, index) {
        return _buildOnboardingPageWidget(_pages[index]);
      },
    );
  }

  Widget _buildOnboardingPageWidget(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 일러스트레이션 또는 아이콘
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                ],
              ),
            ),
            child: Icon(
              page.icon,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          
          const SizedBox(height: 48),
          
          // 제목
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // 설명
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (index) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: index == _currentPage ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: index == _currentPage
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // 이전 버튼
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                child: const Text('이전'),
              ),
            ),
          
          if (_currentPage > 0) const SizedBox(width: 16),
          
          // 다음/시작 버튼
          Expanded(
            flex: _currentPage == 0 ? 1 : 1,
            child: FilledButton(
              onPressed: _currentPage == _pages.length - 1
                  ? _completeOnboarding
                  : _nextPage,
              child: Text(
                _currentPage == _pages.length - 1 ? '시작하기' : '다음',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // 온보딩 완료 상태 저장
    final authProvider = context.read<AuthProvider>();
    await authProvider.completeOnboarding();
    
    // 권한 요청 등 필요한 초기 설정
    await _requestPermissions();
    
    if (mounted) {
      // 메인 화면으로 이동
      context.go('/home');
    }
  }

  Future<void> _requestPermissions() async {
    // 알림 권한 요청
    await _requestNotificationPermission();
    
    // 기타 필요한 권한들 요청
    // await _requestLocationPermission();
    // await _requestStoragePermission();
  }

  Future<void> _requestNotificationPermission() async {
    // 실제 구현에서는 permission_handler 패키지 사용
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림 권한'),
        content: const Text('중요한 뉴스 알림을 받으시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 알림 권한 요청 로직
            },
            child: const Text('허용'),
          ),
        ],
      ),
    );
  }
}

/// 온보딩 페이지 데이터 모델
class OnboardingPage {
  final String title;
  final String description;
  final String imagePath;
  final IconData icon;

  const OnboardingPage({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.icon,
  });
}

/// 권한 요청 온보딩 화면
class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> {
  final Map<String, bool> _permissions = {
    'notifications': false,
    'location': false,
    'storage': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('권한 설정'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '더 나은 경험을 위해\n몇 가지 권한이 필요합니다',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '언제든지 설정에서 변경할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 32),
            
            Expanded(
              child: ListView(
                children: [
                  _buildPermissionTile(
                    icon: Icons.notifications,
                    title: '알림',
                    description: '중요한 뉴스와 업데이트 알림',
                    permission: 'notifications',
                  ),
                  _buildPermissionTile(
                    icon: Icons.location_on,
                    title: '위치',
                    description: '지역 뉴스와 날씨 정보 제공',
                    permission: 'location',
                  ),
                  _buildPermissionTile(
                    icon: Icons.storage,
                    title: '저장소',
                    description: '오프라인 기사 저장 및 캐시',
                    permission: 'storage',
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.go('/home');
                    },
                    child: const Text('나중에 설정'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _requestSelectedPermissions,
                    child: const Text('권한 허용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required String permission,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _permissions[permission] ?? false,
              onChanged: (value) {
                setState(() {
                  _permissions[permission] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestSelectedPermissions() async {
    // 선택된 권한들에 대해 실제 권한 요청
    for (final entry in _permissions.entries) {
      if (entry.value) {
        await _requestPermission(entry.key);
      }
    }
    
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _requestPermission(String permission) async {
    // 실제 구현에서는 permission_handler 패키지 사용
    debugPrint('Requesting permission: $permission');
  }
}