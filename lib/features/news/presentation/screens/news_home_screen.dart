import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/news_provider.dart';
import '../../domain/entities/news_entity.dart';

/// InsightFlo 뉴스 홈 화면 - 개인화된 뉴스 피드
class NewsHomeScreen extends StatefulWidget {
  const NewsHomeScreen({super.key});

  @override
  State<NewsHomeScreen> createState() => _NewsHomeScreenState();
}

class _NewsHomeScreenState extends State<NewsHomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // 뉴스 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Anonymous user ID 사용
      context.read<NewsProvider>().getPersonalizedNewsForUser(
        'anonymous',
        refresh: false,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 스크롤 리스너. 스크롤이 맨 아래에 도달하면 추가 데이터를 로드합니다.
  void _onScroll() {
    if (_isBottom) {
      final provider = context.read<NewsProvider>();
      // 이미 로딩 중이면 중복 요청을 방지합니다.
      if (!provider.isLoading && !provider.isLoadingMore) {
        provider.loadMoreNews('anonymous');
      }
    }
  }

  /// 스크롤이 맨 아래 근처에 있는지 확인합니다.
  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    // 90% 지점에서 로드를 시작하여 사용자 경험을 개선합니다.
    return currentScroll >= (maxScroll * 0.9);
  }

  /// 당겨서 새로고침 핸들러
  Future<void> _handleRefresh() async {
    // 위젯이 여전히 마운트된 상태인지 확인하여 안정성을 높입니다.
    if (mounted) {
      await context.read<NewsProvider>().refreshNews('anonymous');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // _buildHeader(), // 헤더를 나중에 다시 활성화할 수 있도록 주석 처리
            _buildPersonalizedFeed(),
          ],
        ),
      ),
    );
  }

  // /// 헤더 섹션
  // Widget _buildHeader() {
  //   return SliverToBoxAdapter(
  //     child: Container(
  //       padding: const EdgeInsets.all(20),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(
  //             '📰 InsightFlo',
  //             style: Theme.of(context).textTheme.headlineMedium?.copyWith(
  //               fontWeight: FontWeight.bold,
  //               color: Theme.of(context).colorScheme.primary,
  //             ),
  //           ),
  //           const SizedBox(height: 8),
  //           Text(
  //             '개인화된 뉴스와 인사이트를 만나보세요',
  //             style: Theme.of(context).textTheme.bodyLarge?.copyWith(
  //               color: Theme.of(context).colorScheme.onSurfaceVariant,
  //             ),
  //           ),
  //           // const SizedBox(height: 16),
  //           // _buildQuickActions(),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  /// 빠른 액션 버튼들
  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionCard(
          icon: Icons.article,
          label: '최신',
          color: Colors.orange,
          onTap: () => _refreshNews(),
        ),
        _buildActionCard(
          icon: Icons.analytics,
          label: '분석',
          color: Colors.blue,
          onTap: () => _showAnalytics(),
        ),
        _buildActionCard(
          icon: Icons.bookmark,
          label: '북마크',
          color: Colors.green,
          onTap: () => _goToBookmarks(),
        ),
        _buildActionCard(
          icon: Icons.search,
          label: '검색',
          color: Colors.purple,
          onTap: () => _goToSearch(),
        ),
      ],
    );
  }

  /// 액션 카드
  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 개인화된 뉴스 피드
  Widget _buildPersonalizedFeed() {
    return Consumer<NewsProvider>(
      builder: (context, newsProvider, child) {
        // 초기 로딩 상태
        if (newsProvider.isLoading && newsProvider.articles.isEmpty) {
          return SliverToBoxAdapter(child: _buildLoadingCard());
        }

        // 초기 에러 상태
        if (newsProvider.error != null && newsProvider.articles.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildErrorCard(newsProvider.error!),
          );
        }

        // 기사가 없는 경우
        if (newsProvider.articles.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyCard());
        }

        // 기사 목록 + 추가 로딩 인디케이터
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // 리스트의 마지막 아이템이고, 추가 로딩 중일 때 인디케이터를 표시
              if (index == newsProvider.articles.length) {
                return _buildLoadingMoreIndicator();
              }
              // 뉴스 카드 표시
              return _buildNewsCard(newsProvider.articles[index]);
            },
            // 기사 수 + 추가 로딩 중이면 1 추가
            childCount:
                newsProvider.articles.length +
                (newsProvider.isLoadingMore ? 1 : 0),
          ),
        );
      },
    );
  }

  /// 뉴스 카드 (실제 뉴스 엔티티 사용)
  Widget _buildNewsCard(NewsEntity article) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showArticleDetail(article),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                  child:
                      article.imageUrl != null && article.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            article.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.article,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.article,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title.isNotEmpty ? article.title : '제목 없음',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.summary.isNotEmpty ? article.summary : '요약 없음',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.source,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.source.isNotEmpty
                                ? article.source
                                : '출처 없음',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Spacer(),
                          if (article.sentimentScore != 0.0)
                            _buildSentimentIndicator(article.sentimentScore),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 감정 분석 표시
  Widget _buildSentimentIndicator(double score) {
    IconData icon;
    Color color;

    if (score > 0.1) {
      icon = Icons.sentiment_satisfied;
      color = Colors.green;
    } else if (score < -0.1) {
      icon = Icons.sentiment_dissatisfied;
      color = Colors.red;
    } else {
      icon = Icons.sentiment_neutral;
      color = Colors.orange;
    }

    return Icon(icon, size: 16, color: color);
  }

  /// 로딩 카드
  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('뉴스를 불러오는 중...'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 에러 카드
  Widget _buildErrorCard(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                '뉴스를 불러올 수 없습니다',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  context.read<NewsProvider>().getPersonalizedNewsForUser(
                    'anonymous',
                    refresh: true,
                  );
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 빈 카드
  Widget _buildEmptyCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.article_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '아직 뉴스가 없습니다',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('새로운 뉴스가 업데이트되면 여기에 표시됩니다.'),
            ],
          ),
        ),
      ),
    );
  }

  /// 추가 로딩 인디케이터
  Widget _buildLoadingMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20.0),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // 액션 메서드들
  void _showArticleDetail(NewsEntity article) {
    // go_router를 사용하여 기사 상세 화면으로 이동하고, article 객체를 전달합니다.
    context.push('/news-detail', extra: article);
  }

  void _refreshNews() {
    // RefreshIndicator와 동일한 새로고침 메서드를 호출하여 일관성을 유지합니다.
    context.read<NewsProvider>().refreshNews('anonymous');
  }

  void _showAnalytics() {
    // TODO: go_router로 분석 화면 라우트 구현 필요
    context.push('/analytics');
  }

  void _goToBookmarks() {
    context.push('/bookmarks');
  }

  void _goToSearch() {
    context.push('/search');
  }
}
