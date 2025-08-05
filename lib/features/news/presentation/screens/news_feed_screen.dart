import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:insightflo_app/features/news/presentation/providers/news_provider.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/features/news/presentation/widgets/search_bar_widget.dart';
import 'package:insightflo_app/features/news/presentation/widgets/news_list_view.dart';
import 'package:insightflo_app/features/news/presentation/pages/api_test_page.dart';

/// Main news feed screen with search and personalized news
class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen>
    with AutomaticKeepAliveClientMixin {
  String _currentSearchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialNews();
    });
  }

  void _loadInitialNews() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;
    
    if (userId != null) {
      final newsProvider = context.read<NewsProvider>();
      newsProvider.getPersonalizedNewsForUser(userId, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userId = authProvider.currentUser?.id ?? 'guest';
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar with search
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: colorScheme.surface,
            elevation: 0,
            actions: [
              // Debug menu for API testing
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'api_test') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ApiTestPage(),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'api_test',
                    child: Row(
                      children: [
                        Icon(Icons.api),
                        SizedBox(width: 8),
                        Text('Test API Connection'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.3),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
              title: const Text(
                'News Feed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
          ),
          
          // Search bar
          SliverToBoxAdapter(
            child: SearchBarWidget(
              userId: userId,
              hintText: 'Search financial news, companies, keywords...',
              onSearchChanged: (query) {
                setState(() {
                  _currentSearchQuery = query;
                });
              },
            ),
          ),
          
          // Search results or status indicator
          if (_currentSearchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Searching for "$_currentSearchQuery"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Consumer<NewsProvider>(
                      builder: (context, newsProvider, _) {
                        return Text(
                          '${newsProvider.articles.length} results',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          
          // News list
          SliverFillRemaining(
            child: NewsListView(
              userId: userId,
              enablePullToRefresh: true,
              enableInfiniteScroll: true,
              emptyWidget: _buildEmptyStateWidget(userId),
            ),
          ),
        ],
      ),
      
      // Floating action button for manual refresh
      floatingActionButton: Consumer<NewsProvider>(
        builder: (context, newsProvider, _) {
          if (newsProvider.isLoading) {
            return const SizedBox.shrink();
          }
          
          return FloatingActionButton.extended(
            onPressed: () async {
              if (_currentSearchQuery.isNotEmpty) {
                await newsProvider.searchNewsArticles(_currentSearchQuery, refresh: true);
              } else {
                await newsProvider.getPersonalizedNewsForUser(userId, refresh: true);
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
          );
        },
      ),
    ); // End Scaffold
      },
    ); // End Consumer
  } // End build method

  Widget _buildEmptyStateWidget(String userId) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                _currentSearchQuery.isNotEmpty 
                    ? Icons.search_off
                    : Icons.article_outlined,
                size: 60,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _currentSearchQuery.isNotEmpty
                  ? 'No results found'
                  : 'Welcome to InsightFlo',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _currentSearchQuery.isNotEmpty
                  ? 'Try searching for different keywords or check your spelling.'
                  : 'Your personalized financial news feed will appear here.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Action buttons
            if (_currentSearchQuery.isNotEmpty) ...[
              ElevatedButton.icon(
                onPressed: () {
                  // Clear search and show personalized news
                  setState(() {
                    _currentSearchQuery = '';
                  });
                  final newsProvider = context.read<NewsProvider>();
                  newsProvider.getPersonalizedNewsForUser(userId, refresh: true);
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Search'),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadInitialNews,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Load News'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Navigate to settings/preferences
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Preferences screen coming soon!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Preferences'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}