import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/news_provider.dart';
import '../../domain/entities/news_entity.dart';
import '../../data/datasources/news_local_data_source.dart';

/// 뉴스 검색 화면
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late ScrollController _scrollController;
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  
  String _currentQuery = '';
  List<NewsEntity> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingMore = false;
  String? _searchError;
  int _currentPage = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController = TextEditingController();
    _focusNode = FocusNode();
    
    // 자동 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    // 로컬 검색은 페이지네이션을 지원하지 않으므로 스크롤 로딩 비활성화
    // 향후 API 검색 구현 시 다시 활성화 가능
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    return currentScroll >= (maxScroll * 0.9);
  }

  void _onSearchChanged(String query) {
    setState(() {
      _currentQuery = query;
      if (query.trim().isEmpty) {
        _searchResults.clear();
        _searchError = null;
        _hasMoreData = true;
        _currentPage = 1;
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.trim().isEmpty) {
      _onSearchChanged('');
      return;
    }
    
    setState(() {
      _currentQuery = query.trim();
      _currentPage = 1;
      _hasMoreData = true;
      _searchResults.clear();
    });
    
    _performSearch(query.trim(), refresh: true);
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.unfocus();
    setState(() {
      _currentQuery = '';
      _searchResults.clear();
      _searchError = null;
      _hasMoreData = true;
      _currentPage = 1;
    });
  }

  Future<void> _performSearch(String query, {bool refresh = false}) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = refresh;
      _isLoadingMore = !refresh;
      _searchError = null;
    });

    try {
      final newsProvider = context.read<NewsProvider>();
      
      // 로컬 데이터베이스에서 직접 검색 (NewsProvider의 캐시된 검색 기능 사용)
      final localDataSource = newsProvider.localDataSource;
      final searchResults = await localDataSource.searchNews(
        userId: 'anonymous',
        query: query,
        limit: 20,
      );
      
      if (searchResults != null) {
        final safeResults = searchResults
            .where((result) => result != null)
            .cast<NewsEntity>()
            .toList();
        
        setState(() {
          if (refresh) {
            _searchResults = safeResults;
          } else {
            // 로컬 검색은 페이지네이션을 지원하지 않으므로 더 이상 로드할 데이터가 없음
            _hasMoreData = false;
          }
          // 로컬 검색에서는 페이지네이션이 제한적이므로 hasMoreData를 false로 설정
          _hasMoreData = false;
        });
      } else {
        setState(() {
          if (refresh) {
            _searchResults.clear();
          }
          _hasMoreData = false;
        });
      }
      
    } catch (e) {
      setState(() {
        _searchError = e.toString();
      });
    } finally {
      setState(() {
        _isSearching = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreSearchResults() async {
    if (_currentQuery.isNotEmpty) {
      await _performSearch(_currentQuery, refresh: false);
    }
  }

  void _showArticleDetail(NewsEntity article) {
    context.push('/news-detail', extra: article);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('뉴스 검색'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Column(
        children: [
          // 독립적인 검색 바
          _buildSearchBar(),
          
          // 검색 결과
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  /// 독립적인 검색 바 위젯
  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _focusNode.hasFocus 
              ? colorScheme.primary 
              : colorScheme.outline.withOpacity(0.5),
          width: _focusNode.hasFocus ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Search icon
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Icon(
              Icons.search,
              color: _focusNode.hasFocus 
                  ? colorScheme.primary 
                  : colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
          
          // Search input field
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '뉴스를 검색해보세요...',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 16,
                ),
              ),
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              onChanged: _onSearchChanged,
            ),
          ),
          
          // Clear/Loading indicator
          if (_searchController.text.isNotEmpty || _isSearching)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _isSearching 
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      onPressed: _clearSearch,
                      splashRadius: 16,
                      tooltip: 'Clear search',
                    ),
            ),
        ],
      ),
    );
  }

  /// 검색 콘텐츠
  Widget _buildSearchContent() {
    // 검색어가 없을 때
    if (_currentQuery.isEmpty) {
      return _buildEmptySearchState();
    }

    // 로딩 상태
    if (_isSearching && _searchResults.isEmpty) {
      return _buildLoadingState();
    }

    // 에러 상태
    if (_searchError != null && _searchResults.isEmpty) {
      return _buildErrorState(_searchError!);
    }

    // 결과가 없을 때
    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    // 검색 결과 리스트
    return _buildSearchResults();
  }

  /// 검색어가 없을 때의 상태
  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '뉴스를 검색해보세요',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '키워드를 입력하여 관련 뉴스를 찾아보세요',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 로딩 상태
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('검색 중...'),
        ],
      ),
    );
  }

  /// 에러 상태
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '검색 중 오류가 발생했습니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (_currentQuery.isNotEmpty) {
                _performSearch(_currentQuery, refresh: true);
              }
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 결과가 없을 때의 상태
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '검색 결과가 없습니다',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$_currentQuery"에 대한 뉴스를 찾을 수 없습니다',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 검색 결과 리스트
  Widget _buildSearchResults() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 8),
      itemCount: _searchResults.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 추가 로딩 인디케이터
        if (index == _searchResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final article = _searchResults[index];
        return _buildSearchResultCard(article);
      },
    );
  }

  /// 검색 결과 카드
  Widget _buildSearchResultCard(NewsEntity article) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showArticleDetail(article),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 또는 아이콘
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                  child: article.imageUrl != null && article.imageUrl!.isNotEmpty
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
                const SizedBox(width: 12),
                
                // 텍스트 내용
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title.isNotEmpty ? article.title : '제목 없음',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        article.summary.isNotEmpty ? article.summary : '요약 없음',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.source,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            article.source.isNotEmpty ? article.source : '출처 없음',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            ),
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

    return Icon(icon, size: 14, color: color);
  }
}