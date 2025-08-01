import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../features/news/presentation/providers/theme_provider.dart';
import '../../navigation/route_utils.dart';

/// 메인 애플리케이션 래퍼 화면 - ShellRoute 호환
///
/// 기능:
/// - 바텀 네비게이션 바 관리
/// - ShellRoute child 위젯 표시
/// - 동적 앱바 및 플로팅 액션 버튼
/// - 키보드 감지 및 UI 조정
/// - 백 버튼 처리
class MainWrapperScreen extends StatefulWidget {
  /// ShellRoute에서 전달받는 child widget
  final Widget child;

  const MainWrapperScreen({super.key, required this.child});

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen>
    with TickerProviderStateMixin {
  // 탭 관련
  int _currentIndex = 0;

  // 애니메이션 관련
  late AnimationController _fabAnimationController;
  late AnimationController _bottomNavAnimationController;
  late Animation<double> _fabAnimation;
  late Animation<Offset> _bottomNavAnimation;

  // UI 상태
  final bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();

    // 현재 라우트에 따른 초기 탭 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTabFromRoute();
    });
  }

  void _initializeControllers() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bottomNavAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _setupAnimations() {
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    _bottomNavAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _bottomNavAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    // 초기 애니메이션 시작
    _fabAnimationController.forward();
    _bottomNavAnimationController.forward();
  }

  void _updateTabFromRoute() {
    if (!mounted) return; // Widget이 마운트되지 않은 경우 리턴

    final path = RouteUtils.getCurrentPath(context);
    final newIndex = RouteUtils.getTabIndex(path);

    if (newIndex != _currentIndex && mounted) {
      setState(() {
        _currentIndex = newIndex;
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _bottomNavAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      extendBody: true,
    );
  }

  /// 메인 바디 구성 - ShellRoute child 표시
  Widget _buildBody() {
    return Column(
      children: [
        _buildAppBar(),
        Expanded(
          child: widget.child, // ShellRoute에서 전달받은 child 위젯 표시
        ),
      ],
    );
  }

  /// 동적 앱바 구성
  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: SafeArea(bottom: false, child: _buildTabSpecificAppBar()),
    );
  }

  /// 탭별 앱바 구성
  Widget _buildTabSpecificAppBar() {
    switch (_currentIndex) {
      case 0: // 홈
        return _buildHomeAppBar();
      case 1: // 카테고리
        return _buildCategoriesAppBar();
      case 2: // 북마크
        return _buildBookmarksAppBar();
      case 3: // 프로필
        return _buildProfileAppBar();
      default:
        return _buildDefaultAppBar();
    }
  }

  Widget _buildHomeAppBar() {
    return AppBar(
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', height: 32, width: 32),
          const SizedBox(width: 8),
          const Text(
            'InsightFlo',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => context.go('/search'),
          tooltip: '검색',
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: _showNotifications,
          tooltip: '알림',
        ),
      ],
    );
  }

  Widget _buildCategoriesAppBar() {
    return AppBar(
      title: const Text('카테고리'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune),
          onPressed: _showCategoryFilter,
          tooltip: '필터',
        ),
      ],
    );
  }

  Widget _buildBookmarksAppBar() {
    return AppBar(
      title: const Text('북마크'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.sort),
          onPressed: _showBookmarkSort,
          tooltip: '정렬',
        ),
        PopupMenuButton<String>(
          onSelected: _handleBookmarkAction,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'select_all', child: Text('모두 선택')),
            const PopupMenuItem(value: 'delete_selected', child: Text('선택 삭제')),
            const PopupMenuItem(value: 'export', child: Text('내보내기')),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileAppBar() {
    return AppBar(
      title: const Text('프로필'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.go('/settings'),
          tooltip: '설정',
        ),
      ],
    );
  }

  Widget _buildDefaultAppBar() {
    return AppBar(
      title: const Text('InsightFlo'),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }

  /// 바텀 네비게이션 바 구성
  Widget _buildBottomNavigationBar() {
    return SlideTransition(
      position: _bottomNavAnimation,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.1),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onTabTapped,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                backgroundColor: Theme.of(context).colorScheme.surface,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: '홈',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.category_outlined),
                    activeIcon: Icon(Icons.category),
                    label: '카테고리',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bookmark_border),
                    activeIcon: Icon(Icons.bookmark),
                    label: '북마크',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: '프로필',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 플로팅 액션 버튼 구성
  Widget? _buildFloatingActionButton() {
    if (!_showFab) return null;

    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton(
        onPressed: _onFabPressed,
        tooltip: _getFabTooltip(),
        child: Icon(_getFabIcon()),
      ),
    );
  }

  IconData _getFabIcon() {
    switch (_currentIndex) {
      case 0: // 홈
        return Icons.search;
      case 1: // 카테고리
        return Icons.add;
      case 2: // 북마크
        return Icons.folder_open;
      case 3: // 프로필
        return Icons.edit;
      default:
        return Icons.add;
    }
  }

  String _getFabTooltip() {
    switch (_currentIndex) {
      case 0:
        return '검색';
      case 1:
        return '카테고리 추가';
      case 2:
        return '폴더 관리';
      case 3:
        return '프로필 편집';
      default:
        return '추가';
    }
  }

  // 이벤트 핸들러들

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // 같은 탭을 다시 누르면 스크롤 맨 위로
      _scrollToTop();
      return;
    }

    setState(() {
      _currentIndex = index;
    });

    // 해당 탭의 라우트로 이동
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/categories');
        break;
      case 2:
        context.go('/bookmarks');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  void _onFabPressed() {
    switch (_currentIndex) {
      case 0: // 홈 - 검색
        _showSearch();
        break;
      case 1: // 카테고리 - 카테고리 추가
        _showAddCategory();
        break;
      case 2: // 북마크 - 폴더 관리
        _showFolderManagement();
        break;
      case 3: // 프로필 - 프로필 편집
        _showProfileEdit();
        break;
    }
  }

  void _scrollToTop() {
    // 현재 탭의 스크롤을 맨 위로 (실제 구현에서는 각 탭의 컨트롤러 필요)
    debugPrint('스크롤 맨 위로');
  }

  void _showSearch() {
    // 검색 화면으로 이동
    context.push('/search');
  }

  void _showAddCategory() {
    showDialog(
      context: context,
      builder: (context) => const AddCategoryDialog(),
    );
  }

  void _showFolderManagement() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const FolderManagementSheet(),
    );
  }

  void _showProfileEdit() {
    context.go('/settings/profile');
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const NotificationsSheet(),
    );
  }

  void _showCategoryFilter() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const CategoryFilterSheet(),
    );
  }

  void _showBookmarkSort() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const BookmarkSortSheet(),
    );
  }

  void _handleBookmarkAction(String action) {
    switch (action) {
      case 'select_all':
        debugPrint('모든 북마크 선택');
        break;
      case 'delete_selected':
        debugPrint('선택된 북마크 삭제');
        break;
      case 'export':
        debugPrint('북마크 내보내기');
        break;
    }
  }
}

// 임시 위젯들 (실제 구현에서는 별도 파일로)

class VoiceSearchBottomSheet extends StatelessWidget {
  const VoiceSearchBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '음성으로 검색하세요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.mic, size: 80),
          const SizedBox(height: 20),
          const Text('마이크 버튼을 눌러 말해보세요'),
        ],
      ),
    );
  }
}

class AddCategoryDialog extends StatelessWidget {
  const AddCategoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('카테고리 추가'),
      content: const TextField(
        decoration: InputDecoration(hintText: '카테고리 이름을 입력하세요'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('추가'),
        ),
      ],
    );
  }
}

class FolderManagementSheet extends StatelessWidget {
  const FolderManagementSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Text(
            '폴더 관리',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          // 폴더 목록 구현
        ],
      ),
    );
  }
}

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Text(
            '알림',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          // 알림 목록 구현
        ],
      ),
    );
  }
}

class CategoryFilterSheet extends StatelessWidget {
  const CategoryFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Text(
            '카테고리 필터',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          // 필터 옵션 구현
        ],
      ),
    );
  }
}

class BookmarkSortSheet extends StatelessWidget {
  const BookmarkSortSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Text(
            '북마크 정렬',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          // 정렬 옵션 구현
        ],
      ),
    );
  }
}
