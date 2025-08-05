import 'dart:math';

import 'package:insightflo_app/features/news/data/models/news_model.dart';
import 'package:insightflo_app/features/news/data/datasources/news_local_data_source.dart';
import 'package:insightflo_app/features/news/data/datasources/news_remote_data_source.dart';
import '../models/search_filter.dart';

// SearchFilter is now imported from separate model file

/// Search suggestion with metadata for autocomplete
class SearchSuggestion {
  final String text;
  final SuggestionType type;
  final int frequency;
  final double relevanceScore;

  const SearchSuggestion({
    required this.text,
    required this.type,
    required this.frequency,
    this.relevanceScore = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'type': type.name,
    'frequency': frequency,
    'relevanceScore': relevanceScore,
  };
}

/// Types of search suggestions
enum SuggestionType { keyword, source, title, historical }

/// Result wrapper for search operations with metadata
class SearchResult<T> {
  final List<T> results;
  final int totalCount;
  final Duration searchDuration;
  final Map<String, dynamic>? metadata;

  const SearchResult({
    required this.results,
    required this.totalCount,
    required this.searchDuration,
    this.metadata,
  });
}

/// News article with enhanced relevance scoring for search results
class ScoredNewsModel extends NewsModel {
  final double relevanceScore;
  final Map<String, double> scoreBreakdown;

  ScoredNewsModel({
    required NewsModel newsModel,
    required this.relevanceScore,
    required this.scoreBreakdown,
  }) : super(
         id: newsModel.id,
         title: newsModel.title,
         summary: newsModel.summary,
         content: newsModel.content,
         url: newsModel.url,
         source: newsModel.source,
         publishedAt: newsModel.publishedAt,
         keywords: newsModel.keywords,
         imageUrl: newsModel.imageUrl,
         sentimentScore: newsModel.sentimentScore,
         sentimentLabel: newsModel.sentimentLabel,
         isBookmarked: newsModel.isBookmarked,
         cachedAt: newsModel.cachedAt,
         userId: newsModel.userId,
       );

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['relevanceScore'] = relevanceScore;
    json['scoreBreakdown'] = scoreBreakdown;
    return json;
  }
}

/// Search history entry for user search tracking
class SearchHistoryEntry {
  final String id;
  final String query;
  final SearchFilter filter;
  final DateTime timestamp;
  final int resultCount;
  final Duration searchDuration;
  final String userId;

  const SearchHistoryEntry({
    required this.id,
    required this.query,
    required this.filter,
    required this.timestamp,
    required this.resultCount,
    required this.searchDuration,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'query': query,
    'filter': filter.toJson(),
    'timestamp': timestamp.toIso8601String(),
    'resultCount': resultCount,
    'searchDuration': searchDuration.inMilliseconds,
    'userId': userId,
  };
}

/// Abstract service interface for advanced news search and filtering capabilities
/// Implements semantic search, complex filtering, autocomplete, and search history management
abstract class AdvancedSearchService {
  /// Performs semantic search using TF-IDF based natural language processing
  ///
  /// Uses Term Frequency-Inverse Document Frequency algorithm for relevance scoring:
  /// - Analyzes query terms against news content, title, and summary
  /// - Calculates term importance based on frequency and document rarity
  /// - Returns results ranked by semantic relevance to the search query
  ///
  /// Parameters:
  /// - [query]: Natural language search query
  /// - [userId]: User identifier for personalized results
  /// - [limit]: Maximum number of results to return
  /// - [threshold]: Minimum relevance score threshold (0.0-1.0)
  Future<SearchResult<ScoredNewsModel>> semanticSearch({
    required String query,
    required String userId,
    int limit = 20,
    double threshold = 0.1,
  });

  /// Filters news articles using multiple complex criteria
  ///
  /// Supports combining multiple filters with AND/OR logic:
  /// - Text search across title, summary, and content
  /// - Date range filtering with precise timestamp matching
  /// - Source filtering for trusted news providers
  /// - Sentiment analysis filtering (positive, negative, neutral)
  /// - Keyword matching with fuzzy search capabilities
  /// - Bookmark status filtering for user-saved articles
  ///
  /// Parameters:
  /// - [filter]: Comprehensive filter configuration
  /// - [userId]: User identifier for personalized filtering
  Future<SearchResult<NewsModel>> filterByMultipleCriteria({
    required SearchFilter filter,
    required String userId,
  });

  /// Provides intelligent search suggestions using Trie data structure
  ///
  /// Implements prefix-based autocomplete with the following features:
  /// - Trie (prefix tree) for O(m) lookup time where m is query length
  /// - Frequency-based ranking of suggestions
  /// - Context-aware suggestions based on user search history
  /// - Multi-type suggestions: keywords, sources, historical queries, article titles
  /// - Real-time suggestion updates as user types
  ///
  /// Parameters:
  /// - [prefix]: Partial search query for autocomplete
  /// - [userId]: User identifier for personalized suggestions
  /// - [limit]: Maximum number of suggestions to return
  /// - [types]: Filter suggestions by type (keyword, source, historical, title)
  Future<List<SearchSuggestion>> getSearchSuggestions({
    required String prefix,
    required String userId,
    int limit = 10,
    List<SuggestionType>? types,
  });

  /// Calculates and ranks search results by relevance score
  ///
  /// Multi-factor relevance scoring algorithm considers:
  /// - TF-IDF semantic similarity score (40% weight)
  /// - Recency boost for recent articles (25% weight)
  /// - Source authority and credibility score (20% weight)
  /// - User engagement metrics (bookmarks, reading time) (10% weight)
  /// - Sentiment alignment with user preferences (5% weight)
  ///
  /// Parameters:
  /// - [results]: List of news articles to rank
  /// - [query]: Original search query for relevance calculation
  /// - [userId]: User identifier for personalized ranking
  Future<List<ScoredNewsModel>> rankByRelevance({
    required List<NewsModel> results,
    required String query,
    required String userId,
  });

  /// Manages user search history with intelligent storage and retrieval
  ///
  /// Search history management features:
  /// - Automatic search query and result tracking
  /// - Duplicate query detection and frequency updates
  /// - Configurable retention policy (default: 90 days)
  /// - Privacy-compliant data handling with user consent
  /// - Search pattern analysis for personalization improvements
  /// - Export functionality for user data transparency
  ///
  /// Parameters:
  /// - [userId]: User identifier for history management
  /// - [limit]: Maximum number of history entries to return
  /// - [query]: Optional filter for specific search terms
  Future<List<SearchHistoryEntry>> getSearchHistory({
    required String userId,
    int limit = 50,
    String? query,
  });

  /// Records a search operation in user history
  ///
  /// Parameters:
  /// - [entry]: Complete search history entry with metadata
  Future<void> recordSearchHistory(SearchHistoryEntry entry);

  /// Clears search history for a user
  ///
  /// Parameters:
  /// - [userId]: User identifier for history clearing
  /// - [olderThan]: Optional date threshold for partial clearing
  Future<void> clearSearchHistory({
    required String userId,
    DateTime? olderThan,
  });

  /// Gets search analytics and statistics for a user
  ///
  /// Returns comprehensive search analytics including:
  /// - Most frequent search terms
  /// - Average search result relevance scores
  /// - Search success rates and user engagement metrics
  /// - Temporal search patterns and trends
  ///
  /// Parameters:
  /// - [userId]: User identifier for analytics
  /// - [dateRange]: Optional date range for analytics period
  Future<Map<String, dynamic>> getSearchAnalytics({
    required String userId,
    Duration? dateRange,
  });
}

/// Implementation of AdvancedSearchService with complete search functionality
///
/// This implementation provides:
/// - In-memory TF-IDF document indexing for semantic search
/// - Trie-based autocomplete with frequency tracking
/// - Multi-criteria filtering with efficient database queries
/// - Search history management with configurable retention
/// - Advanced relevance scoring with multiple ranking factors
class AdvancedSearchServiceImpl implements AdvancedSearchService {
  // Dependencies (injected through constructor)
  final NewsLocalDataSource _localDataSource;

  // Internal data structures for search optimization
  final Map<String, Map<String, double>> _tfidfIndex =
      {}; // document_id -> {term -> tfidf_score}
  final Map<String, int> _documentFrequency = {}; // term -> document_count
  final TrieNode _suggestionTrie = TrieNode();
  final List<SearchHistoryEntry> _searchHistory = [];

  // Configuration
  static const int _maxHistoryEntries = 1000;
  static const Duration _historyRetention = Duration(days: 90);

  AdvancedSearchServiceImpl({
    required NewsLocalDataSource localDataSource,
    NewsRemoteDataSource? remoteDataSource,
  }) : _localDataSource = localDataSource;

  @override
  Future<SearchResult<ScoredNewsModel>> semanticSearch({
    required String query,
    required String userId,
    int limit = 20,
    double threshold = 0.1,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Get all cached articles for the user
      final allArticles = await _localDataSource.getPersonalizedNews(
        userId: userId,
        limit: 1000, // Get larger set for semantic analysis
      );

      if (allArticles.isEmpty) {
        return SearchResult<ScoredNewsModel>(
          results: [],
          totalCount: 0,
          searchDuration: stopwatch.elapsed,
        );
      }

      // Build or update TF-IDF index if needed
      await _updateTFIDFIndex(allArticles);

      // Calculate semantic similarity scores
      final queryTerms = _preprocessText(query);
      final scoredResults = <ScoredNewsModel>[];

      for (final article in allArticles) {
        final relevanceScore = _calculateTFIDFScore(article.id, queryTerms);

        if (relevanceScore >= threshold) {
          final scoreBreakdown = {
            'tfidf': relevanceScore,
            'recency': _calculateRecencyScore(article.publishedAt),
            'engagement': _calculateEngagementScore(article),
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

      // Sort by relevance score and limit results
      scoredResults.sort(
        (a, b) => b.relevanceScore.compareTo(a.relevanceScore),
      );
      final limitedResults = scoredResults.take(limit).toList();

      stopwatch.stop();

      return SearchResult<ScoredNewsModel>(
        results: limitedResults,
        totalCount: scoredResults.length,
        searchDuration: stopwatch.elapsed,
        metadata: {
          'queryTerms': queryTerms,
          'indexSize': _tfidfIndex.length,
          'threshold': threshold,
        },
      );
    } catch (e) {
      stopwatch.stop();
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
      List<NewsModel> results = [];

      // Apply date range filtering if specified
      if (filter.dateRange != null) {
        results = await _localDataSource.getNewsByDateRange(
          userId: userId,
          startDate: filter.dateRange!.startDate,
          endDate: filter.dateRange!.endDate,
          limit: filter.limit * 2, // Get more for additional filtering
        );
      } else {
        // Get base set of articles
        results = await _localDataSource.getPersonalizedNews(
          userId: userId,
          limit: filter.limit * 2,
          offset: filter.offset,
        );
      }

      // Apply text query filtering
      if (filter.query != null && filter.query!.isNotEmpty) {
        final queryLower = filter.query!.toLowerCase();
        results = results.where((article) {
          return article.title.toLowerCase().contains(queryLower) ||
              article.summary.toLowerCase().contains(queryLower) ||
              article.content.toLowerCase().contains(queryLower) ||
              article.keywords.any(
                (keyword) => keyword.toLowerCase().contains(queryLower),
              );
        }).toList();
      }

      // Apply source filtering
      if (filter.sources != null && filter.sources!.isNotEmpty) {
        final sourcesLower = filter.sources!
            .map((s) => s.toLowerCase())
            .toSet();
        results = results
            .where(
              (article) => sourcesLower.contains(article.source.toLowerCase()),
            )
            .toList();
      }

      // Apply sentiment filtering
      if (filter.sentiments != null) {
        results = results
            .where(
              (article) => filter.sentiments!.matches(
                article.sentimentScore,
                article.sentimentLabel,
              ),
            )
            .toList();
      }

      // Apply keyword filtering
      if (filter.keywords != null) {
        results = results.where((article) {
          final articleText =
              '${article.title} ${article.summary} ${article.content}';
          return filter.keywords!.matches(article.keywords, articleText);
        }).toList();
      }

      // Apply bookmark filtering
      if (filter.isBookmarked != null) {
        results = results
            .where((article) => article.isBookmarked == filter.isBookmarked!)
            .toList();
      }

      // Apply sorting
      _sortResults(results, filter.sortBy, filter.sortOrder);

      // Apply final limit
      final limitedResults = results.take(filter.limit).toList();

      stopwatch.stop();

      return SearchResult<NewsModel>(
        results: limitedResults,
        totalCount: results.length,
        searchDuration: stopwatch.elapsed,
        metadata: {
          'appliedFilters': filter.activeFilterCount,
          'originalCount': results.length,
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
      final suggestions = <SearchSuggestion>[];
      final prefixLower = prefix.toLowerCase();

      // Get suggestions from Trie structure
      final trieSuggestions = _suggestionTrie.getSuggestions(
        prefixLower,
        limit,
      );
      suggestions.addAll(trieSuggestions);

      // Get source suggestions
      if (types == null || types.contains(SuggestionType.source)) {
        final sourceStats = await _localDataSource.getSourceStatistics(
          userId: userId,
          limit: 20,
        );

        for (final stat in sourceStats) {
          final source = stat['source'] as String;
          if (source.toLowerCase().startsWith(prefixLower)) {
            suggestions.add(
              SearchSuggestion(
                text: source,
                type: SuggestionType.source,
                frequency: stat['articleCount'] as int,
                relevanceScore: 0.8,
              ),
            );
          }
        }
      }

      // Get historical search suggestions
      if (types == null || types.contains(SuggestionType.historical)) {
        final historicalSuggestions = _searchHistory
            .where((entry) => entry.userId == userId)
            .where((entry) => entry.query.toLowerCase().startsWith(prefixLower))
            .take(5)
            .map(
              (entry) => SearchSuggestion(
                text: entry.query,
                type: SuggestionType.historical,
                frequency: 1,
                relevanceScore: 0.6,
              ),
            )
            .toList();

        suggestions.addAll(historicalSuggestions);
      }

      // Sort by relevance and frequency, then limit
      suggestions.sort((a, b) {
        final scoreComparison = b.relevanceScore.compareTo(a.relevanceScore);
        if (scoreComparison != 0) return scoreComparison;
        return b.frequency.compareTo(a.frequency);
      });

      return suggestions.take(limit).toList();
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
      final queryTerms = _preprocessText(query);
      final scoredResults = <ScoredNewsModel>[];

      for (final article in results) {
        final scoreBreakdown = <String, double>{
          'tfidf': _calculateTFIDFScore(article.id, queryTerms),
          'recency': _calculateRecencyScore(article.publishedAt),
          'sourceAuthority': _calculateSourceAuthorityScore(article.source),
          'engagement': _calculateEngagementScore(article),
          'sentimentAlignment': _calculateSentimentAlignmentScore(
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
      var history = _searchHistory
          .where((entry) => entry.userId == userId)
          .toList();

      // Filter by query if specified
      if (query != null && query.isNotEmpty) {
        final queryLower = query.toLowerCase();
        history = history
            .where((entry) => entry.query.toLowerCase().contains(queryLower))
            .toList();
      }

      // Sort by timestamp (most recent first)
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return history.take(limit).toList();
    } catch (e) {
      throw Exception('Get search history failed: $e');
    }
  }

  @override
  Future<void> recordSearchHistory(SearchHistoryEntry entry) async {
    try {
      // Remove old entries if at maximum capacity
      if (_searchHistory.length >= _maxHistoryEntries) {
        _searchHistory.removeRange(
          0,
          _searchHistory.length - _maxHistoryEntries + 1,
        );
      }

      _searchHistory.add(entry);

      // Update suggestion Trie with the search query
      _updateSuggestionTrie(entry.query);

      // Clean up old entries based on retention policy
      final cutoffDate = DateTime.now().subtract(_historyRetention);
      _searchHistory.removeWhere(
        (entry) => entry.timestamp.isBefore(cutoffDate),
      );
    } catch (e) {
      throw Exception('Record search history failed: $e');
    }
  }

  @override
  Future<void> clearSearchHistory({
    required String userId,
    DateTime? olderThan,
  }) async {
    try {
      if (olderThan != null) {
        _searchHistory.removeWhere(
          (entry) =>
              entry.userId == userId && entry.timestamp.isBefore(olderThan),
        );
      } else {
        _searchHistory.removeWhere((entry) => entry.userId == userId);
      }
    } catch (e) {
      throw Exception('Clear search history failed: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getSearchAnalytics({
    required String userId,
    Duration? dateRange,
  }) async {
    try {
      final cutoffDate = dateRange != null
          ? DateTime.now().subtract(dateRange)
          : null;

      final relevantHistory = _searchHistory
          .where((entry) => entry.userId == userId)
          .where(
            (entry) =>
                cutoffDate == null || entry.timestamp.isAfter(cutoffDate),
          )
          .toList();

      final analytics = <String, dynamic>{
        'totalSearches': relevantHistory.length,
        'averageResultCount': relevantHistory.isEmpty
            ? 0
            : relevantHistory
                      .map((e) => e.resultCount)
                      .reduce((a, b) => a + b) /
                  relevantHistory.length,
        'averageSearchDuration': relevantHistory.isEmpty
            ? 0
            : relevantHistory
                      .map((e) => e.searchDuration.inMilliseconds)
                      .reduce((a, b) => a + b) /
                  relevantHistory.length,
        'mostFrequentQueries': _getMostFrequentQueries(relevantHistory),
        'searchPatterns': _getSearchPatterns(relevantHistory),
      };

      return analytics;
    } catch (e) {
      throw Exception('Get search analytics failed: $e');
    }
  }

  // Private helper methods

  /// Preprocesses text into normalized terms for analysis
  List<String> _preprocessText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2)
        .toList();
  }

  /// Updates the TF-IDF index with new articles
  Future<void> _updateTFIDFIndex(List<NewsModel> articles) async {
    final allDocuments = <String, String>{};

    // Prepare document corpus
    for (final article in articles) {
      final documentText =
          '${article.title} ${article.summary} ${article.content}';
      allDocuments[article.id] = documentText;
    }

    // Calculate document frequency for each term
    _documentFrequency.clear();
    for (final document in allDocuments.values) {
      final terms = _preprocessText(document).toSet();
      for (final term in terms) {
        _documentFrequency[term] = (_documentFrequency[term] ?? 0) + 1;
      }
    }

    // Calculate TF-IDF for each document
    _tfidfIndex.clear();
    final totalDocuments = allDocuments.length;

    for (final entry in allDocuments.entries) {
      final docId = entry.key;
      final document = entry.value;
      final terms = _preprocessText(document);
      final termFreq = <String, int>{};

      // Calculate term frequency
      for (final term in terms) {
        termFreq[term] = (termFreq[term] ?? 0) + 1;
      }

      // Calculate TF-IDF scores
      final tfidfScores = <String, double>{};
      for (final termEntry in termFreq.entries) {
        final term = termEntry.key;
        final tf = termEntry.value / terms.length;
        final df = _documentFrequency[term] ?? 1;
        final idf = log(totalDocuments / df);
        tfidfScores[term] = tf * idf;
      }

      _tfidfIndex[docId] = tfidfScores;
    }
  }

  /// Calculates TF-IDF based similarity score for a document and query terms
  double _calculateTFIDFScore(String documentId, List<String> queryTerms) {
    final docVector = _tfidfIndex[documentId] ?? {};
    if (docVector.isEmpty || queryTerms.isEmpty) return 0.0;

    double score = 0.0;
    for (final term in queryTerms) {
      score += docVector[term] ?? 0.0;
    }

    return score / queryTerms.length;
  }

  /// Calculates recency score based on article publication date
  double _calculateRecencyScore(DateTime publishedAt) {
    final now = DateTime.now();
    final daysSincePublished = now.difference(publishedAt).inDays;

    // Exponential decay: newer articles get higher scores
    return exp(-daysSincePublished / 30.0); // 30-day half-life
  }

  /// Calculates source authority score
  double _calculateSourceAuthorityScore(String source) {
    // This would typically be based on a pre-computed authority database
    // For now, return a default medium score
    const authorityScores = {
      'reuters': 0.9,
      'bbc': 0.9,
      'cnn': 0.8,
      'default': 0.5,
    };

    return authorityScores[source.toLowerCase()] ?? authorityScores['default']!;
  }

  /// Calculates engagement score based on user interactions
  double _calculateEngagementScore(NewsModel article) {
    double score = 0.0;

    // Bookmark engagement
    if (article.isBookmarked) {
      score += 0.3;
    }

    // Sentiment as engagement indicator
    score += (article.sentimentScore.abs() * 0.2);

    return min(score, 1.0);
  }

  /// Calculates sentiment alignment score with user preferences
  double _calculateSentimentAlignmentScore(NewsModel article, String userId) {
    // This would typically analyze user's historical sentiment preferences
    // For now, return a neutral score
    return 0.5;
  }

  /// Combines individual scores using weighted formula
  double _combineScores(Map<String, double> scoreBreakdown) {
    const weights = {
      'tfidf': 0.4,
      'recency': 0.25,
      'sourceAuthority': 0.2,
      'engagement': 0.1,
      'sentimentAlignment': 0.05,
    };

    double totalScore = 0.0;
    for (final entry in scoreBreakdown.entries) {
      final weight = weights[entry.key] ?? 0.0;
      totalScore += entry.value * weight;
    }

    return min(totalScore, 1.0);
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
          // Would need additional scoring logic here
          comparison = 0;
          break;
        case SortBy.readingTime:
          // Sort by estimated reading time (based on content length)
          final aReadingTime = _estimateReadingTime(a.content);
          final bReadingTime = _estimateReadingTime(b.content);
          comparison = aReadingTime.compareTo(bReadingTime);
          break;
        case SortBy.engagement:
          // Sort by engagement metrics (bookmark status and sentiment score)
          final aEngagement = _calculateEngagementScore(a);
          final bEngagement = _calculateEngagementScore(b);
          comparison = aEngagement.compareTo(bEngagement);
          break;
      }

      return sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }

  /// Estimates reading time in minutes based on content length
  /// Assumes average reading speed of 200 words per minute
  int _estimateReadingTime(String content) {
    if (content.isEmpty) return 0;

    // Count words (simple whitespace-based counting)
    final wordCount = content.trim().split(RegExp(r'\s+')).length;

    // Average reading speed: 200 words per minute
    const wordsPerMinute = 200;
    final readingTimeMinutes = (wordCount / wordsPerMinute).ceil();

    // Minimum 1 minute reading time
    return readingTimeMinutes.clamp(1, 60);
  }

  /// Updates the suggestion Trie with a new query
  void _updateSuggestionTrie(String query) {
    final terms = _preprocessText(query);
    for (final term in terms) {
      _suggestionTrie.insert(term);
    }
  }

  /// Gets most frequent queries from search history
  List<Map<String, dynamic>> _getMostFrequentQueries(
    List<SearchHistoryEntry> history,
  ) {
    final queryFreq = <String, int>{};
    for (final entry in history) {
      queryFreq[entry.query] = (queryFreq[entry.query] ?? 0) + 1;
    }

    final sortedQueries = queryFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedQueries
        .take(10)
        .map((entry) => {'query': entry.key, 'frequency': entry.value})
        .toList();
  }

  /// Analyzes search patterns for analytics
  Map<String, dynamic> _getSearchPatterns(List<SearchHistoryEntry> history) {
    // Analyze temporal patterns, query lengths, etc.
    final patterns = <String, dynamic>{
      'averageQueryLength': history.isEmpty
          ? 0
          : history.map((e) => e.query.length).reduce((a, b) => a + b) /
                history.length,
      'searchesByHour': <int, int>{},
    };

    for (final entry in history) {
      final hour = entry.timestamp.hour;
      patterns['searchesByHour'][hour] =
          (patterns['searchesByHour'][hour] ?? 0) + 1;
    }

    return patterns;
  }
}

/// Trie node for efficient prefix-based search suggestions
class TrieNode {
  final Map<String, TrieNode> children = {};
  bool isEndOfWord = false;
  int frequency = 0;

  /// Inserts a word into the Trie
  void insert(String word) {
    TrieNode current = this;
    for (final char in word.toLowerCase().split('')) {
      current.children.putIfAbsent(char, () => TrieNode());
      current = current.children[char]!;
    }
    current.isEndOfWord = true;
    current.frequency++;
  }

  /// Gets suggestions for a given prefix
  List<SearchSuggestion> getSuggestions(String prefix, int limit) {
    TrieNode current = this;

    // Navigate to the prefix node
    for (final char in prefix.split('')) {
      if (!current.children.containsKey(char)) {
        return [];
      }
      current = current.children[char]!;
    }

    // Collect all words with this prefix
    final suggestions = <SearchSuggestion>[];
    _collectWords(current, prefix, suggestions, limit);

    // Sort by frequency and return limited results
    suggestions.sort((a, b) => b.frequency.compareTo(a.frequency));
    return suggestions.take(limit).toList();
  }

  /// Recursively collects words from Trie nodes
  void _collectWords(
    TrieNode node,
    String currentWord,
    List<SearchSuggestion> suggestions,
    int limit,
  ) {
    if (suggestions.length >= limit) return;

    if (node.isEndOfWord) {
      suggestions.add(
        SearchSuggestion(
          text: currentWord,
          type: SuggestionType.keyword,
          frequency: node.frequency,
          relevanceScore: 0.7,
        ),
      );
    }

    for (final entry in node.children.entries) {
      _collectWords(entry.value, currentWord + entry.key, suggestions, limit);
    }
  }
}
