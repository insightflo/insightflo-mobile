import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import 'news_card.dart';

/// Custom widget for displaying a scrollable list of news articles
class NewsListView extends StatefulWidget {
  final String userId;
  final bool enablePullToRefresh;
  final bool enableInfiniteScroll;
  final Widget? emptyWidget;
  final Widget? errorWidget;

  const NewsListView({
    super.key,
    required this.userId,
    this.enablePullToRefresh = true,
    this.enableInfiniteScroll = true,
    this.emptyWidget,
    this.errorWidget,
  });

  @override
  State<NewsListView> createState() => _NewsListViewState();
}

class _NewsListViewState extends State<NewsListView> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    if (widget.enableInfiniteScroll) {
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when 200px from bottom
      final newsProvider = context.read<NewsProvider>();
      if (!newsProvider.isLoadingMore && newsProvider.hasMoreData) {
        newsProvider.loadMoreNews(widget.userId);
      }
    }
  }

  Future<void> _onRefresh() async {
    final newsProvider = context.read<NewsProvider>();
    await newsProvider.refreshNews(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsProvider>(
      builder: (context, newsProvider, child) {
        // Error state
        if (newsProvider.error != null && newsProvider.articles.isEmpty) {
          return widget.errorWidget ?? _buildErrorWidget(newsProvider.error!);
        }

        // Loading state (initial load)
        if (newsProvider.isLoading && newsProvider.articles.isEmpty) {
          return _buildLoadingWidget();
        }

        // Empty state
        if (newsProvider.articles.isEmpty) {
          return widget.emptyWidget ?? _buildEmptyWidget();
        }

        // Success state with data
        Widget listView = ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: newsProvider.articles.length + 
                     (newsProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Show loading indicator at bottom when loading more
            if (index == newsProvider.articles.length) {
              return _buildLoadMoreWidget();
            }

            final article = newsProvider.articles[index];
            return NewsCard(
              article: article,
              userId: widget.userId,
              onTap: () {
                // TODO: Navigate to article detail screen
                _showArticleDetail(context, article);
              },
            );
          },
        );

        // Wrap with RefreshIndicator if pull-to-refresh is enabled
        if (widget.enablePullToRefresh) {
          listView = RefreshIndicator(
            onRefresh: _onRefresh,
            child: listView,
          );
        }

        return listView;
      },
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading news...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final newsProvider = context.read<NewsProvider>();
                newsProvider.refreshNews(widget.userId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No news found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or check back later for new articles.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                final newsProvider = context.read<NewsProvider>();
                newsProvider.refreshNews(widget.userId);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreWidget() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showArticleDetail(BuildContext context, article) {
    // TODO: Implement navigation to article detail screen
    // For now, show a simple dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          article.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Source: ${article.source}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(article.summary),
              const SizedBox(height: 16),
              if (article.keywords.isNotEmpty) ...[
                Text(
                  'Keywords:',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: article.keywords.map((keyword) {
                    return Chip(
                      label: Text(keyword),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Open article URL in browser
              Navigator.of(context).pop();
            },
            child: const Text('Read Full Article'),
          ),
        ],
      ),
    );
  }
}