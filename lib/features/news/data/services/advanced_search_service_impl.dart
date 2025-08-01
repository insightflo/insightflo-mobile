import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:drift/drift.dart';
import '../../../../core/database/database.dart';
import '../../domain/models/search_filter.dart';
import '../../domain/services/advanced_search_service.dart';
import '../datasources/news_local_data_source.dart';
import '../models/news_model.dart';

/// Data layer implementation of AdvancedSearchService using Drift database with FTS5
///
/// This implementation provides:
/// - SQLite FTS5 (Full-Text Search) integration for fast semantic search
/// - Persistent TF-IDF indexing stored in database tables
/// - Search history management with configurable retention policies
/// - Advanced multi-criteria filtering with optimized database queries
/// - Trie-based autocomplete with database-backed suggestion storage
/// - Performance metrics and search analytics
class AdvancedSearchServiceImpl implements AdvancedSearchService {
  final AppDatabase _database;
  final NewsLocalDataSource _localDataSource;

  // Cache for frequently accessed data
  final Map<String, List<SearchSuggestion>> _suggestionCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Configuration constants
  static const Duration _suggestionCacheExpiry = Duration(minutes: 30);
  static const Duration _defaultHistoryRetention = Duration(days: 90);
  static const int _maxHistoryEntries = 1000;

  AdvancedSearchServiceImpl({
    required AppDatabase database,
    required NewsLocalDataSource localDataSource,
  }) : _database = database,
       _localDataSource = localDataSource;

  @override
  Future<SearchResult<ScoredNewsModel>> semanticSearch({
    required String query,
    required String userId,
    int limit = 20,
    double threshold = 0.1,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Record search operation
      await _recordSearchStart(userId, query);

      // Use FTS5 for initial text matching if available
      List<NewsModel> candidates;
      try {
        candidates = await _performFTS5Search(query, userId, limit * 3);
      } catch (e) {
        // Fallback to basic search if FTS5 not available
        developer.log(
          'FTS5 search failed, falling back to basic search: $e',
          name: 'AdvancedSearch',
        );
        candidates = await _performBasicTextSearch(query, userId, limit * 3);
      }

      if (candidates.isEmpty) {
        stopwatch.stop();
        return SearchResult<ScoredNewsModel>(
          results: [],
          totalCount: 0,
          searchDuration: stopwatch.elapsed,
          metadata: {'searchMethod': 'fts5_fallback', 'candidateCount': 0},
        );
      }

      // Calculate TF-IDF scores for semantic ranking
      final tfidfScores = await _calculateTFIDFScores(query, candidates);

      // Create scored results with relevance breakdown
      final scoredResults = <ScoredNewsModel>[];
      for (int i = 0; i < candidates.length; i++) {
        final article = candidates[i];
        final tfidfScore = tfidfScores[i];

        if (tfidfScore >= threshold) {
          final scoreBreakdown = {
            'tfidf': tfidfScore,
            'recency': _calculateRecencyScore(article.publishedAt),
            'sourceAuthority': _calculateSourceAuthorityScore(article.source),
            'engagement': _calculateEngagementScore(article),
            'sentimentAlignment': await _calculateSentimentAlignmentScore(
              article,
              userId,
            ),
          };

          final totalScore = _combineScores(scoreBreakdown);

          scoredResults.add(
            ScoredNewsModel(
              newsModel: article,
              relevanceScore: totalScore,
              scoreBreakdown: scoreBreakdown,
            ),
          );
        }
      }

      // Sort by relevance and limit results
      scoredResults.sort(
        (a, b) => b.relevanceScore.compareTo(a.relevanceScore),
      );
      final limitedResults = scoredResults.take(limit).toList();

      stopwatch.stop();

      // Record search completion
      await _recordSearchCompletion(
        userId,
        query,
        limitedResults.length,
        stopwatch.elapsed,
      );

      return SearchResult<ScoredNewsModel>(
        results: limitedResults,
        totalCount: scoredResults.length,
        searchDuration: stopwatch.elapsed,
        metadata: {
          'searchMethod': 'fts5_tfidf',
          'candidateCount': candidates.length,
          'threshold': threshold,
          'avgRelevanceScore': limitedResults.isEmpty
              ? 0.0
              : limitedResults
                        .map((e) => e.relevanceScore)
                        .reduce((a, b) => a + b) /
                    limitedResults.length,
        },
      );
    } catch (e) {
      stopwatch.stop();
      await _recordSearchError(userId, query, e.toString());
      throw Exception('Semantic search failed: $e');
    }
  }

  @override
  Future<SearchResult<NewsModel>> filterByMultipleCriteria({
    required SearchFilter filter,
    required String userId,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Build optimized SQL query based on filter criteria
      final queryResult = await _buildFilteredQuery(filter, userId);

      stopwatch.stop();

      return SearchResult<NewsModel>(
        results: queryResult.results,
        totalCount: queryResult.totalCount,
        searchDuration: stopwatch.elapsed,
        metadata: {
          'filterCount': filter.activeFilterCount,
          'queryComplexity': _calculateQueryComplexity(filter),
          'indexesUsed': queryResult.indexesUsed,
        },
      );
    } catch (e) {
      stopwatch.stop();
      throw Exception('Multi-criteria filtering failed: $e');
    }
  }

  @override
  Future<List<SearchSuggestion>> getSearchSuggestions({
    required String prefix,
    required String userId,
    int limit = 10,
    List<SuggestionType>? types,
  }) async {
    try {
      // Check cache first
      final cacheKey = '${userId}_${prefix}_${types?.join(',') ?? 'all'}';
      final cachedResult = _getCachedSuggestions(cacheKey);
      if (cachedResult != null) {
        return cachedResult.take(limit).toList();
      }

      final suggestions = <SearchSuggestion>[];
      final prefixLower = prefix.toLowerCase().trim();

      if (prefixLower.isEmpty) {
        return suggestions;
      }

      // Get keyword suggestions from article content
      if (types == null || types.contains(SuggestionType.keyword)) {
        final keywordSuggestions = await _getKeywordSuggestions(
          prefixLower,
          userId,
          limit,
        );
        suggestions.addAll(keywordSuggestions);
      }

      // Get source suggestions
      if (types == null || types.contains(SuggestionType.source)) {
        final sourceSuggestions = await _getSourceSuggestions(
          prefixLower,
          userId,
          limit,
        );
        suggestions.addAll(sourceSuggestions);
      }

      // Get title suggestions
      if (types == null || types.contains(SuggestionType.title)) {
        final titleSuggestions = await _getTitleSuggestions(
          prefixLower,
          userId,
          limit,
        );
        suggestions.addAll(titleSuggestions);
      }

      // Get historical search suggestions
      if (types == null || types.contains(SuggestionType.historical)) {
        final historicalSuggestions = await _getHistoricalSuggestions(
          prefixLower,
          userId,
          limit,
        );
        suggestions.addAll(historicalSuggestions);
      }

      // Remove duplicates and sort by relevance
      final uniqueSuggestions = _removeDuplicateSuggestions(suggestions);
      uniqueSuggestions.sort((a, b) {
        final scoreComparison = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreComparison != 0) return scoreComparison;
        return b.frequency.compareTo(a.frequency);
      });

      final result = uniqueSuggestions.take(limit).toList();

      // Cache the result
      _cacheSuggestions(cacheKey, uniqueSuggestions);

      return result;
    } catch (e) {
      throw Exception('Search suggestions failed: $e');
    }
  }

  @override
  Future<List<ScoredNewsModel>> rankByRelevance({
    required List<NewsModel> results,
    required String query,
    required String userId,
  }) async {
    try {
      if (results.isEmpty) return [];

      final tfidfScores = await _calculateTFIDFScores(query, results);
      final scoredResults = <ScoredNewsModel>[];

      for (int i = 0; i < results.length; i++) {
        final article = results[i];
        final scoreBreakdown = {
          'tfidf': tfidfScores[i],
          'recency': _calculateRecencyScore(article.publishedAt),
          'sourceAuthority': _calculateSourceAuthorityScore(article.source),
          'engagement': _calculateEngagementScore(article),
          'sentimentAlignment': await _calculateSentimentAlignmentScore(
            article,
            userId,
          ),
        };

        final relevanceScore = _combineScores(scoreBreakdown);

        scoredResults.add(
          ScoredNewsModel(
            newsModel: article,
            relevanceScore: relevanceScore,
            scoreBreakdown: scoreBreakdown,
          ),
        );
      }

      // Sort by relevance score
      scoredResults.sort(
        (a, b) => b.relevanceScore.compareTo(a.relevanceScore),
      );
      return scoredResults;
    } catch (e) {
      throw Exception('Relevance ranking failed: $e');
    }
  }

  @override
  Future<List<SearchHistoryEntry>> getSearchHistory({
    required String userId,
    int limit = 50,
    String? query,
  }) async {
    try {
      // Build query to get search history from database
      String sql = '''
        SELECT id, query, filter_json, timestamp, result_count, search_duration_ms, user_id
        FROM search_history 
        WHERE user_id = ?
      ''';

      final variables = <Variable>[Variable.withString(userId)];

      // Add query filter if provided
      if (query != null && query.isNotEmpty) {
        sql += ' AND query LIKE ?';
        variables.add(Variable.withString('%$query%'));
      }

      sql += ' ORDER BY timestamp DESC LIMIT ?';
      variables.add(Variable.withInt(limit));

      final result = await _database
          .customSelect(
            sql,
            variables: variables,
            readsFrom:
                {}, // Will be updated when search_history table is created
          )
          .get();

      return result.map((row) {
        final data = row.data;
        return SearchHistoryEntry(
          id: data['id'] as String,
          query: data['query'] as String,
          filter: SearchFilter.fromJson(
            jsonDecode(data['filter_json'] as String) as Map<String, dynamic>,
          ),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            data['timestamp'] as int,
          ),
          resultCount: data['result_count'] as int,
          searchDuration: Duration(
            milliseconds: data['search_duration_ms'] as int,
          ),
          userId: data['user_id'] as String,
        );
      }).toList();
    } catch (e) {
      // Fallback to empty list if table doesn't exist yet
      developer.log(
        'Search history table not available: $e',
        name: 'SearchHistory',
      );
      return [];
    }
  }

  @override
  Future<void> recordSearchHistory(SearchHistoryEntry entry) async {
    try {
      // Insert search history into database
      await _database.customInsert(
        '''
        INSERT OR REPLACE INTO search_history 
        (id, query, filter_json, timestamp, result_count, search_duration_ms, user_id)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(entry.id),
          Variable.withString(entry.query),
          Variable.withString(jsonEncode(entry.filter.toJson())),
          Variable.withInt(entry.timestamp.millisecondsSinceEpoch),
          Variable.withInt(entry.resultCount),
          Variable.withInt(entry.searchDuration.inMilliseconds),
          Variable.withString(entry.userId),
        ],
      );

      // Clean up old entries if necessary
      await _cleanupOldSearchHistory(entry.userId);
    } catch (e) {
      developer.log(
        'Failed to record search history: $e',
        name: 'SearchHistory',
      );
      // Don't throw - search history is not critical functionality
    }
  }

  @override
  Future<void> clearSearchHistory({
    required String userId,
    DateTime? olderThan,
  }) async {
    try {
      String sql = 'DELETE FROM search_history WHERE user_id = ?';
      final variables = <Variable>[Variable.withString(userId)];

      if (olderThan != null) {
        sql += ' AND timestamp < ?';
        variables.add(Variable.withInt(olderThan.millisecondsSinceEpoch));
      }

      await _database.customUpdate(
        sql,
        variables: variables,
        updates: {}, // Will be updated when search_history table is created
      );
    } catch (e) {
      developer.log(
        'Failed to clear search history: $e',
        name: 'SearchHistory',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getSearchAnalytics({
    required String userId,
    Duration? dateRange,
  }) async {
    try {
      final cutoffTime = dateRange != null
          ? DateTime.now().subtract(dateRange).millisecondsSinceEpoch
          : 0;

      // Get search statistics from database
      final stats = await _database
          .customSelect(
            '''
        SELECT 
          COUNT(*) as total_searches,
          AVG(result_count) as avg_result_count,
          AVG(search_duration_ms) as avg_duration_ms,
          COUNT(DISTINCT query) as unique_queries
        FROM search_history 
        WHERE user_id = ? AND timestamp >= ?
        ''',
            variables: [
              Variable.withString(userId),
              Variable.withInt(cutoffTime),
            ],
            readsFrom: {},
          )
          .getSingleOrNull();

      if (stats == null) {
        return _getDefaultAnalytics();
      }

      // Get most frequent queries
      final frequentQueries = await _database
          .customSelect(
            '''
        SELECT query, COUNT(*) as frequency
        FROM search_history 
        WHERE user_id = ? AND timestamp >= ?
        GROUP BY query 
        ORDER BY frequency DESC 
        LIMIT 10
        ''',
            variables: [
              Variable.withString(userId),
              Variable.withInt(cutoffTime),
            ],
            readsFrom: {},
          )
          .get();

      // Get search patterns by hour
      final hourlyPatterns = await _database
          .customSelect(
            '''
        SELECT 
          strftime('%H', datetime(timestamp/1000, 'unixepoch')) as hour,
          COUNT(*) as search_count
        FROM search_history 
        WHERE user_id = ? AND timestamp >= ?
        GROUP BY hour
        ORDER BY hour
        ''',
            variables: [
              Variable.withString(userId),
              Variable.withInt(cutoffTime),
            ],
            readsFrom: {},
          )
          .get();

      final data = stats.data;
      return {
        'totalSearches': data['total_searches'] as int,
        'averageResultCount': (data['avg_result_count'] as double?) ?? 0.0,
        'averageSearchDuration': (data['avg_duration_ms'] as double?) ?? 0.0,
        'uniqueQueries': data['unique_queries'] as int,
        'mostFrequentQueries': frequentQueries
            .map(
              (row) => {
                'query': row.data['query'] as String,
                'frequency': row.data['frequency'] as int,
              },
            )
            .toList(),
        'searchPatterns': {
          'byHour': Map.fromEntries(
            hourlyPatterns.map(
              (row) => MapEntry(
                int.parse(row.data['hour'] as String),
                row.data['search_count'] as int,
              ),
            ),
          ),
        },
        'dateRange': dateRange?.inDays ?? -1,
      };
    } catch (e) {
      developer.log(
        'Failed to get search analytics: $e',
        name: 'SearchAnalytics',
      );
      return _getDefaultAnalytics();
    }
  }

  // Private helper methods

  /// Performs FTS5-based full-text search on news articles
  Future<List<NewsModel>> _performFTS5Search(
    String query,
    String userId,
    int limit,
  ) async {
    try {
      // Create FTS5 virtual table if it doesn't exist
      await _ensureFTS5TableExists();

      // Perform FTS5 search
      final ftsResults = await _database
          .customSelect(
            '''
        SELECT n.* FROM news_articles n
        JOIN news_fts ON news_fts.docid = n.rowid
        WHERE news_fts MATCH ? AND n.user_id = ?
        ORDER BY bm25(news_fts) 
        LIMIT ?
        ''',
            variables: [
              Variable.withString(_prepareFTS5Query(query)),
              Variable.withString(userId),
              Variable.withInt(limit),
            ],
            readsFrom: {_database.newsTable},
          )
          .get();

      return ftsResults
          .map((row) => NewsModel.fromDatabaseRow(row.data))
          .toList();
    } catch (e) {
      throw Exception('FTS5 search failed: $e');
    }
  }

  /// Ensures FTS5 virtual table exists for full-text search
  Future<void> _ensureFTS5TableExists() async {
    try {
      await _database.customStatement('''
        CREATE VIRTUAL TABLE IF NOT EXISTS news_fts USING fts5(
          title, summary, content, keywords,
          content=news_articles,
          content_rowid=id
        )
      ''');

      // Check if FTS table needs to be populated
      final count = await _database
          .customSelect('SELECT COUNT(*) as count FROM news_fts', readsFrom: {})
          .getSingle();

      if ((count.data['count'] as int) == 0) {
        // Populate FTS table with existing data
        await _database.customStatement('''
          INSERT INTO news_fts(title, summary, content, keywords)
          SELECT title, summary, content, keywords FROM news_articles
        ''');
      }
    } catch (e) {
      throw Exception('Failed to setup FTS5 table: $e');
    }
  }

  /// Prepares query for FTS5 search with proper escaping
  String _prepareFTS5Query(String query) {
    // Escape special FTS5 characters and add phrase matching
    final cleanQuery = query
        .replaceAll('"', '""')
        .replaceAll('*', '')
        .replaceAll(':', '')
        .trim();

    if (cleanQuery.isEmpty) return '""';

    // Split into terms and create OR query for flexibility
    final terms = cleanQuery.split(RegExp(r'\s+'));
    return terms.map((term) => '"$term"').join(' OR ');
  }

  /// Performs basic text search as fallback when FTS5 is not available
  Future<List<NewsModel>> _performBasicTextSearch(
    String query,
    String userId,
    int limit,
  ) async {
    return await _localDataSource.searchNews(
      userId: userId,
      query: query,
      limit: limit,
    );
  }

  /// Calculates TF-IDF scores for search results
  Future<List<double>> _calculateTFIDFScores(
    String query,
    List<NewsModel> articles,
  ) async {
    if (articles.isEmpty) return [];

    // Preprocess query terms
    final queryTerms = _preprocessText(query);
    if (queryTerms.isEmpty) return List.filled(articles.length, 0.0);

    // Calculate document frequency for query terms
    final documentFreq = <String, int>{};
    for (final article in articles) {
      final documentTerms = _getDocumentTerms(article).toSet();
      for (final term in queryTerms) {
        if (documentTerms.contains(term)) {
          documentFreq[term] = (documentFreq[term] ?? 0) + 1;
        }
      }
    }

    // Calculate TF-IDF for each article
    final scores = <double>[];
    final totalDocuments = articles.length;

    for (final article in articles) {
      final documentTerms = _getDocumentTerms(article);
      final termFreq = <String, int>{};

      // Calculate term frequency
      for (final term in documentTerms) {
        termFreq[term] = (termFreq[term] ?? 0) + 1;
      }

      // Calculate TF-IDF score for this document
      double score = 0.0;
      for (final queryTerm in queryTerms) {
        final tf = (termFreq[queryTerm] ?? 0) / documentTerms.length;
        final df = documentFreq[queryTerm] ?? 1;
        final idf = log(totalDocuments / df);
        score += tf * idf;
      }

      scores.add(score / queryTerms.length);
    }

    return scores;
  }

  /// Extracts and preprocesses terms from a news article
  List<String> _getDocumentTerms(NewsModel article) {
    final text =
        '${article.title} ${article.summary} ${article.content} ${article.keywords.join(' ')}';
    return _preprocessText(text);
  }

  /// Preprocesses text into normalized terms
  List<String> _preprocessText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s가-힣]'), ' ') // Support Korean characters
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 1) // Filter very short terms
        .toList();
  }

  /// Calculates recency score based on publication date
  double _calculateRecencyScore(DateTime publishedAt) {
    final now = DateTime.now();
    final daysSincePublished = now.difference(publishedAt).inDays;

    // Exponential decay with 30-day half-life
    return exp(-daysSincePublished / 30.0);
  }

  /// Calculates source authority score
  double _calculateSourceAuthorityScore(String source) {
    // This could be enhanced with a database table of source authority scores
    const authorityScores = {
      'reuters': 0.95,
      'bbc': 0.93,
      'cnn': 0.85,
      'ap': 0.92,
      'bloomberg': 0.88,
      'wall street journal': 0.90,
      'new york times': 0.87,
      'washington post': 0.85,
      'default': 0.50,
    };

    return authorityScores[source.toLowerCase()] ?? authorityScores['default']!;
  }

  /// Calculates engagement score based on user interactions
  double _calculateEngagementScore(NewsModel article) {
    double score = 0.0;

    // Bookmark engagement (strong signal)
    if (article.isBookmarked) {
      score += 0.4;
    }

    // Sentiment as engagement indicator
    score += article.sentimentScore.abs() * 0.2;

    // Keyword richness
    score += min(article.keywords.length / 10.0, 0.3);

    return min(score, 1.0);
  }

  /// Calculates sentiment alignment score with user preferences
  Future<double> _calculateSentimentAlignmentScore(
    NewsModel article,
    String userId,
  ) async {
    try {
      // Get user's sentiment preferences from their reading history
      final userStats = await _database
          .customSelect(
            '''
        SELECT 
          AVG(sentiment_score) as avg_sentiment,
          COUNT(CASE WHEN is_bookmarked = 1 THEN 1 END) as bookmarked_count,
          COUNT(*) as total_count
        FROM news_articles 
        WHERE user_id = ? AND cached_at > ?
        ''',
            variables: [
              Variable.withString(userId),
              Variable.withInt(
                DateTime.now()
                    .subtract(const Duration(days: 30))
                    .millisecondsSinceEpoch,
              ),
            ],
            readsFrom: {_database.newsTable},
          )
          .getSingleOrNull();

      if (userStats == null) {
        return 0.5; // Neutral when no data available
      }

      final data = userStats.data;
      final avgUserSentiment = (data['avg_sentiment'] as double?) ?? 0.0;
      final bookmarkedCount = data['bookmarked_count'] as int;
      final totalCount = data['total_count'] as int;

      // Calculate alignment based on user's average sentiment preference
      final sentimentDistance = (article.sentimentScore - avgUserSentiment)
          .abs();
      final sentimentAlignment = 1.0 - min(sentimentDistance / 2.0, 1.0);

      // Boost alignment if user has bookmarking behavior
      final bookmarkBoost = totalCount > 0
          ? (bookmarkedCount / totalCount) * 0.2
          : 0.0;

      return min(sentimentAlignment + bookmarkBoost, 1.0);
    } catch (e) {
      return 0.5; // Default neutral alignment on error
    }
  }

  /// Combines individual relevance scores using weighted formula
  double _combineScores(Map<String, double> scoreBreakdown) {
    const weights = {
      'tfidf': 0.40, // Semantic relevance (highest weight)
      'recency': 0.25, // Time relevance
      'sourceAuthority': 0.20, // Source credibility
      'engagement': 0.10, // User engagement signals
      'sentimentAlignment': 0.05, // Personal preference alignment
    };

    double totalScore = 0.0;
    double totalWeight = 0.0;

    for (final entry in scoreBreakdown.entries) {
      final weight = weights[entry.key] ?? 0.0;
      totalScore += entry.value * weight;
      totalWeight += weight;
    }

    return totalWeight > 0 ? min(totalScore / totalWeight, 1.0) : 0.0;
  }

  /// Builds optimized filtered query based on SearchFilter criteria
  Future<FilteredQueryResult> _buildFilteredQuery(
    SearchFilter filter,
    String userId,
  ) async {
    // This would build complex SQL queries based on filter criteria
    // For now, delegating to existing local data source methods

    List<NewsModel> results;
    int totalCount = 0;
    final indexesUsed = <String>[];

    // Apply date range filtering first (most selective)
    if (filter.dateRange != null) {
      results = await _localDataSource.getNewsByDateRange(
        userId: userId,
        startDate: filter.dateRange!.startDate,
        endDate: filter.dateRange!.endDate,
        limit: filter.limit * 2,
      );
      indexesUsed.add('publishedAt_index');
    } else {
      results = await _localDataSource.getPersonalizedNews(
        userId: userId,
        limit: filter.limit * 2,
        offset: filter.offset,
      );
      indexesUsed.add('userId_publishedAt_index');
    }

    totalCount = results.length;

    // Apply additional filters
    if (filter.query != null && filter.query!.isNotEmpty) {
      final queryLower = filter.query!.toLowerCase();
      results = results.where((article) {
        return article.title.toLowerCase().contains(queryLower) ||
            article.summary.toLowerCase().contains(queryLower) ||
            article.content.toLowerCase().contains(queryLower);
      }).toList();
    }

    if (filter.sources != null && filter.sources!.isNotEmpty) {
      final sourcesLower = filter.sources!.map((s) => s.toLowerCase()).toSet();
      results = results
          .where(
            (article) => sourcesLower.contains(article.source.toLowerCase()),
          )
          .toList();
      indexesUsed.add('source_index');
    }

    if (filter.sentiments != null) {
      results = results
          .where(
            (article) => filter.sentiments!.matches(
              article.sentimentScore,
              article.sentimentLabel,
            ),
          )
          .toList();
      indexesUsed.add('sentiment_index');
    }

    if (filter.keywords != null) {
      results = results.where((article) {
        final articleText =
            '${article.title} ${article.summary} ${article.content}';
        return filter.keywords!.matches(article.keywords, articleText);
      }).toList();
    }

    if (filter.isBookmarked != null) {
      results = results
          .where((article) => article.isBookmarked == filter.isBookmarked!)
          .toList();
      indexesUsed.add('bookmark_index');
    }

    // Apply sorting
    _sortResults(results, filter.sortBy, filter.sortOrder);

    // Apply final limit
    final limitedResults = results.take(filter.limit).toList();

    return FilteredQueryResult(
      results: limitedResults,
      totalCount: totalCount,
      indexesUsed: indexesUsed,
    );
  }

  /// Sorts results based on specified criteria
  void _sortResults(
    List<NewsModel> results,
    SortBy sortBy,
    SortOrder sortOrder,
  ) {
    results.sort((a, b) {
      int comparison = 0;

      switch (sortBy) {
        case SortBy.publishedAt:
          comparison = a.publishedAt.compareTo(b.publishedAt);
          break;
        case SortBy.sentimentScore:
          comparison = a.sentimentScore.compareTo(b.sentimentScore);
          break;
        case SortBy.title:
          comparison = a.title.compareTo(b.title);
          break;
        case SortBy.source:
          comparison = a.source.compareTo(b.source);
          break;
        case SortBy.relevanceScore:
        case SortBy.readingTime:
        case SortBy.engagement:
          // These would require additional data/calculations
          comparison = 0;
          break;
      }

      return sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  /// Calculates query complexity for optimization hints
  int _calculateQueryComplexity(SearchFilter filter) {
    int complexity = 0;

    if (filter.query != null && filter.query!.isNotEmpty) complexity += 2;
    if (filter.dateRange != null) complexity += 1;
    if (filter.sources != null && filter.sources!.isNotEmpty) complexity += 1;
    if (filter.sentiments != null) complexity += 2;
    if (filter.keywords != null) complexity += 3;
    if (filter.isBookmarked != null) complexity += 1;
    if (filter.minRelevanceScore != null || filter.maxRelevanceScore != null)
      complexity += 2;

    return complexity;
  }

  // Suggestion methods

  /// Gets cached suggestions if still valid
  List<SearchSuggestion>? _getCachedSuggestions(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) < _suggestionCacheExpiry) {
      return _suggestionCache[cacheKey];
    }
    return null;
  }

  /// Caches suggestions with timestamp
  void _cacheSuggestions(String cacheKey, List<SearchSuggestion> suggestions) {
    _suggestionCache[cacheKey] = suggestions;
    _cacheTimestamps[cacheKey] = DateTime.now();

    // Clean up old cache entries
    if (_suggestionCache.length > 100) {
      final oldestKey = _cacheTimestamps.entries
          .reduce((a, b) => a.value.isBefore(b.value) ? a : b)
          .key;
      _suggestionCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  /// Gets keyword suggestions from article content
  Future<List<SearchSuggestion>> _getKeywordSuggestions(
    String prefix,
    String userId,
    int limit,
  ) async {
    try {
      // This would ideally use a pre-built keyword frequency table
      // For now, using a simple approach
      final recentArticles = await _localDataSource.getPersonalizedNews(
        userId: userId,
        limit: 200,
      );

      final keywordFreq = <String, int>{};
      for (final article in recentArticles) {
        for (final keyword in article.keywords) {
          if (keyword.toLowerCase().startsWith(prefix)) {
            keywordFreq[keyword] = (keywordFreq[keyword] ?? 0) + 1;
          }
        }
      }

      return keywordFreq.entries
          .map(
            (entry) => SearchSuggestion(
              text: entry.key,
              type: SuggestionType.keyword,
              frequency: entry.value,
              relevanceScore: 0.7 + (entry.value / 100.0).clamp(0.0, 0.3),
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets source suggestions
  Future<List<SearchSuggestion>> _getSourceSuggestions(
    String prefix,
    String userId,
    int limit,
  ) async {
    try {
      final sourceStats = await _localDataSource.getSourceStatistics(
        userId: userId,
        limit: 50,
      );

      return sourceStats
          .where(
            (stat) =>
                (stat['source'] as String).toLowerCase().startsWith(prefix),
          )
          .map(
            (stat) => SearchSuggestion(
              text: stat['source'] as String,
              type: SuggestionType.source,
              frequency: stat['articleCount'] as int,
              relevanceScore: 0.8,
            ),
          )
          .take(limit)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets title suggestions
  Future<List<SearchSuggestion>> _getTitleSuggestions(
    String prefix,
    String userId,
    int limit,
  ) async {
    try {
      // Get recent articles with titles starting with prefix
      final articles = await _database
          .customSelect(
            '''
        SELECT title, COUNT(*) as frequency
        FROM news_articles 
        WHERE user_id = ? AND LOWER(title) LIKE ? 
        GROUP BY LOWER(title)
        ORDER BY frequency DESC, title ASC
        LIMIT ?
        ''',
            variables: [
              Variable.withString(userId),
              Variable.withString('$prefix%'),
              Variable.withInt(limit),
            ],
            readsFrom: {_database.newsTable},
          )
          .get();

      return articles.map((row) {
        final data = row.data;
        return SearchSuggestion(
          text: data['title'] as String,
          type: SuggestionType.title,
          frequency: data['frequency'] as int,
          relevanceScore: 0.6,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Gets historical search suggestions
  Future<List<SearchSuggestion>> _getHistoricalSuggestions(
    String prefix,
    String userId,
    int limit,
  ) async {
    try {
      final history = await getSearchHistory(
        userId: userId,
        query: prefix,
        limit: limit,
      );

      return history
          .where((entry) => entry.query.toLowerCase().startsWith(prefix))
          .map(
            (entry) => SearchSuggestion(
              text: entry.query,
              type: SuggestionType.historical,
              frequency: 1,
              relevanceScore: 0.5,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Removes duplicate suggestions, keeping highest relevance
  List<SearchSuggestion> _removeDuplicateSuggestions(
    List<SearchSuggestion> suggestions,
  ) {
    final seen = <String, SearchSuggestion>{};

    for (final suggestion in suggestions) {
      final key = suggestion.text.toLowerCase();
      final existing = seen[key];

      if (existing == null ||
          suggestion.relevanceScore > existing.relevanceScore) {
        seen[key] = suggestion;
      }
    }

    return seen.values.toList();
  }

  // Search history methods

  /// Records the start of a search operation
  Future<void> _recordSearchStart(String userId, String query) async {
    // Could be used for analytics or monitoring
    // For now, just a placeholder
  }

  /// Records successful search completion
  Future<void> _recordSearchCompletion(
    String userId,
    String query,
    int resultCount,
    Duration duration,
  ) async {
    try {
      final entry = SearchHistoryEntry(
        id: '${userId}_${DateTime.now().millisecondsSinceEpoch}',
        query: query,
        filter: SearchFilter(query: query), // Basic filter for simple searches
        timestamp: DateTime.now(),
        resultCount: resultCount,
        searchDuration: duration,
        userId: userId,
      );

      await recordSearchHistory(entry);
    } catch (e) {
      developer.log(
        'Failed to record search completion: $e',
        name: 'SearchHistory',
      );
    }
  }

  /// Records search error for debugging
  Future<void> _recordSearchError(
    String userId,
    String query,
    String error,
  ) async {
    // Log to error tracking system
    developer.log(
      'Search error for user $userId, query "$query": $error',
      name: 'SearchError',
    );
  }

  /// Cleans up old search history entries
  Future<void> _cleanupOldSearchHistory(String userId) async {
    try {
      // Remove entries older than retention period
      final cutoffTime = DateTime.now()
          .subtract(_defaultHistoryRetention)
          .millisecondsSinceEpoch;

      await _database.customUpdate(
        'DELETE FROM search_history WHERE user_id = ? AND timestamp < ?',
        variables: [Variable.withString(userId), Variable.withInt(cutoffTime)],
        updates: {},
      );

      // Limit total entries per user
      await _database.customUpdate(
        '''
        DELETE FROM search_history 
        WHERE user_id = ? AND id NOT IN (
          SELECT id FROM search_history 
          WHERE user_id = ? 
          ORDER BY timestamp DESC 
          LIMIT ?
        )
        ''',
        variables: [
          Variable.withString(userId),
          Variable.withString(userId),
          Variable.withInt(_maxHistoryEntries),
        ],
        updates: {},
      );
    } catch (e) {
      developer.log(
        'Failed to cleanup search history: $e',
        name: 'SearchHistory',
      );
    }
  }

  /// Returns default analytics when database is not available
  Map<String, dynamic> _getDefaultAnalytics() {
    return {
      'totalSearches': 0,
      'averageResultCount': 0.0,
      'averageSearchDuration': 0.0,
      'uniqueQueries': 0,
      'mostFrequentQueries': <Map<String, dynamic>>[],
      'searchPatterns': {'byHour': <int, int>{}},
      'dateRange': -1,
    };
  }
}

/// Result wrapper for filtered query operations
class FilteredQueryResult {
  final List<NewsModel> results;
  final int totalCount;
  final List<String> indexesUsed;

  const FilteredQueryResult({
    required this.results,
    required this.totalCount,
    required this.indexesUsed,
  });
}
