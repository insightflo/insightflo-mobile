import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/news_card.dart';
import '../../domain/entities/news_entity.dart';

/// 북마크 화면 - Material 3 디자인
/// 
/// 기능:
/// - 북마크된 기사 목록 표시
/// - 실시간 검색 필터링
/// - 스와이프 삭제 (Dismissible)
/// - Pull-to-refresh
/// - 빈 상태 및 에러 처리
/// - NewsCard 위젯 재사용
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen>
    with AutomaticKeepAliveClientMixin {
  
  // 검색 관련
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // 필터된 북마크 리스트
  List<NewsEntity> _filteredBookmarks = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    // 북마크 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBookmarks();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadBookmarks() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    
    if (userId != null) {
      final newsProvider = context.read<NewsProvider>();
      newsProvider.loadBookmarkedArticles(userId);
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  List<NewsEntity> _getFilteredBookmarks(List<NewsEntity> bookmarks) {
    if (_searchQuery.isEmpty) {
      return bookmarks;
    }
    
    return bookmarks.where((article) {
      return article.title.toLowerCase().contains(_searchQuery) ||
             article.summary.toLowerCase().contains(_searchQuery) ||
             article.source.toLowerCase().contains(_searchQuery) ||
             article.keywords.any((keyword) => 
                 keyword.toLowerCase().contains(_searchQuery));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer2<NewsProvider, AuthProvider>(
      builder: (context, newsProvider, authProvider, _) {
        final userId = authProvider.currentUser?.id ?? 'guest';
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        
        _filteredBookmarks = _getFilteredBookmarks(newsProvider.bookmarkedArticles);

        return Scaffold(
          backgroundColor: colorScheme.surface,
          
          // 앱바
          appBar: AppBar(
            title: const Text(
              '북마크',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: colorScheme.surface,
            elevation: 0,
            actions: [
              // 검색 결과 카운트
              if (_searchQuery.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(
                      '${_filteredBookmarks.length}개',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          
          body: Column(
            children: [
              // 검색 필드
              _buildSearchField(theme, colorScheme),
              
              // 북마크 리스트
              Expanded(
                child: _buildBookmarksList(
                  newsProvider, 
                  userId, 
                  theme, 
                  colorScheme,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 검색 필드 구성
  Widget _buildSearchField(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '북마크 검색 (제목, 요약, 키워드...)',
          hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
        style: theme.textTheme.bodyLarge,
      ),
    );
  }

  /// 북마크 리스트 구성
  Widget _buildBookmarksList(
    NewsProvider newsProvider,
    String userId,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    // 로딩 상태
    if (newsProvider.isLoading && newsProvider.bookmarkedArticles.isEmpty) {
      return _buildLoadingWidget();
    }
    
    // 에러 상태
    if (newsProvider.error != null && newsProvider.bookmarkedArticles.isEmpty) {
      return _buildErrorWidget(newsProvider.error!, theme, colorScheme);
    }
    
    // 빈 상태 (검색 결과 없음 포함)
    if (_filteredBookmarks.isEmpty) {
      return _buildEmptyWidget(theme, colorScheme);
    }
    
    // 북마크 리스트
    return RefreshIndicator(
      onRefresh: () async {
        _loadBookmarks();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredBookmarks.length,
        itemBuilder: (context, index) {
          final article = _filteredBookmarks[index];
          
          return Dismissible(
            key: Key('bookmark_${article.id}'),
            direction: DismissDirection.endToStart,
            background: _buildDismissBackground(colorScheme),
            confirmDismiss: (direction) async {
              return await _showDeleteConfirmDialog(
                context, 
                article.title,
                theme,
                colorScheme,
              );
            },
            onDismissed: (direction) async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await newsProvider.removeBookmarkFromArticle(userId, article.id);
              
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('${article.title} 북마크가 삭제되었습니다'),
                  duration: const Duration(seconds: 2),
                  action: SnackBarAction(
                    label: '취소',
                    onPressed: () async {
                      // 북마크 복구
                      await newsProvider.bookmarkNewsArticle(userId, article.id);
                    },
                  ),
                ),
              );
            },
            child: NewsCard(
              article: article,
              userId: userId,
              onTap: () {
                // TODO: 뉴스 상세 페이지로 이동
                _showNewsDetail(article);
              },
            ),
          );
        },
      ),
    );
  }

  /// 로딩 위젯
  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            '북마크를 불러오는 중...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 에러 위젯
  Widget _buildErrorWidget(String error, ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '북마크를 불러올 수 없습니다',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadBookmarks,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  /// 빈 상태 위젯
  Widget _buildEmptyWidget(ThemeData theme, ColorScheme colorScheme) {
    final isSearching = _searchQuery.isNotEmpty;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                isSearching ? Icons.search_off : Icons.bookmark_border,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching 
                  ? '검색 결과가 없습니다'
                  : '아직 북마크한 기사가 없습니다',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isSearching
                  ? '다른 키워드로 검색해보거나 검색어를 확인해보세요.'
                  : '관심 있는 기사를 북마크하여 나중에 쉽게 찾아보세요.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            if (isSearching) ...[
              FilledButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear),
                label: const Text('검색 지우기'),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () {
                  // 홈 화면으로 이동하여 뉴스 탐색
                  DefaultTabController.of(context).animateTo(0);
                },
                icon: const Icon(Icons.explore),
                label: const Text('뉴스 탐색하기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Dismissible 배경 위젯
  Widget _buildDismissBackground(ColorScheme colorScheme) {
    return Container(
      alignment: Alignment.centerRight,
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_outline,
              color: colorScheme.onErrorContainer,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              '삭제',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 삭제 확인 다이얼로그
  Future<bool?> _showDeleteConfirmDialog(
    BuildContext context,
    String articleTitle,
    ThemeData theme,
    ColorScheme colorScheme,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('북마크 삭제'),
        content: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '"',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: articleTitle.length > 50 
                    ? '${articleTitle.substring(0, 50)}...'
                    : articleTitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: '"\n북마크를 삭제하시겠습니까?',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 뉴스 상세 표시 (임시)
  void _showNewsDetail(NewsEntity article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(article.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '출처: ${article.source}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(article.summary),
              const SizedBox(height: 16),
              if (article.keywords.isNotEmpty) ...[
                const Text(
                  '키워드:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: article.keywords.map((keyword) {
                    return Chip(
                      label: Text(keyword),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          if (article.url.isNotEmpty)
            FilledButton(
              onPressed: () {
                // TODO: 웹뷰나 외부 브라우저로 원문 보기
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('원문 보기 기능은 준비 중입니다'),
                  ),
                );
              },
              child: const Text('원문 보기'),
            ),
        ],
      ),
    );
  }
}