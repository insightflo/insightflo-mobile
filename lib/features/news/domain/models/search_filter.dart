/// Advanced search filter model for comprehensive news filtering and search configuration
/// Supports complex multi-criteria filtering with date ranges, sentiment analysis,
/// keyword matching, source filtering, and relevance scoring
class SearchFilter {
  /// Text query for semantic search across title, summary, and content
  final String? query;
  
  /// List of specific news sources to include in results
  /// Example: ['Reuters', 'BBC', 'CNN']
  final List<String>? sources;
  
  /// Date range filter for article publication dates
  final DateRange? dateRange;
  
  /// Sentiment-based filtering configuration
  final SentimentFilter? sentiments;
  
  /// Keyword-based filtering with exact and fuzzy matching
  final KeywordFilter? keywords;
  
  /// Minimum relevance score threshold (0.0-1.0)
  /// Articles below this score will be filtered out
  final double? minRelevanceScore;
  
  /// Maximum relevance score threshold (0.0-1.0)
  /// Articles above this score will be filtered out (rare use case)
  final double? maxRelevanceScore;
  
  /// Filter by bookmark status
  /// true: only bookmarked articles, false: only non-bookmarked, null: all
  final bool? isBookmarked;
  
  /// Maximum number of results to return
  final int limit;
  
  /// Number of results to skip (for pagination)
  final int offset;
  
  /// Sorting criteria for search results
  final SortBy sortBy;
  
  /// Sort order (ascending or descending)
  final SortOrder sortOrder;
  
  /// Language filter for multilingual content
  final List<String>? languages;
  
  /// Content type filter (article, video, podcast, etc.)
  final List<ContentType>? contentTypes;
  
  /// Reading time filter in minutes
  final ReadingTimeRange? readingTime;

  const SearchFilter({
    this.query,
    this.sources,
    this.dateRange,
    this.sentiments,
    this.keywords,
    this.minRelevanceScore,
    this.maxRelevanceScore,
    this.isBookmarked,
    this.limit = 20,
    this.offset = 0,
    this.sortBy = SortBy.publishedAt,
    this.sortOrder = SortOrder.descending,
    this.languages,
    this.contentTypes,
    this.readingTime,
  });

  /// Creates a copy of this filter with modified values
  SearchFilter copyWith({
    String? query,
    List<String>? sources,
    DateRange? dateRange,
    SentimentFilter? sentiments,
    KeywordFilter? keywords,
    double? minRelevanceScore,
    double? maxRelevanceScore,
    bool? isBookmarked,
    int? limit,
    int? offset,
    SortBy? sortBy,
    SortOrder? sortOrder,
    List<String>? languages,
    List<ContentType>? contentTypes,
    ReadingTimeRange? readingTime,
  }) {
    return SearchFilter(
      query: query ?? this.query,
      sources: sources ?? this.sources,
      dateRange: dateRange ?? this.dateRange,
      sentiments: sentiments ?? this.sentiments,
      keywords: keywords ?? this.keywords,
      minRelevanceScore: minRelevanceScore ?? this.minRelevanceScore,
      maxRelevanceScore: maxRelevanceScore ?? this.maxRelevanceScore,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      languages: languages ?? this.languages,
      contentTypes: contentTypes ?? this.contentTypes,
      readingTime: readingTime ?? this.readingTime,
    );
  }

  /// Converts filter to JSON for storage and transmission
  Map<String, dynamic> toJson() => {
    'query': query,
    'sources': sources,
    'dateRange': dateRange?.toJson(),
    'sentiments': sentiments?.toJson(),
    'keywords': keywords?.toJson(),
    'minRelevanceScore': minRelevanceScore,
    'maxRelevanceScore': maxRelevanceScore,
    'isBookmarked': isBookmarked,
    'limit': limit,
    'offset': offset,
    'sortBy': sortBy.name,
    'sortOrder': sortOrder.name,
    'languages': languages,
    'contentTypes': contentTypes?.map((e) => e.name).toList(),
    'readingTime': readingTime?.toJson(),
  };

  /// Creates SearchFilter from JSON data
  factory SearchFilter.fromJson(Map<String, dynamic> json) {
    return SearchFilter(
      query: json['query'] as String?,
      sources: (json['sources'] as List<dynamic>?)?.cast<String>(),
      dateRange: json['dateRange'] != null 
          ? DateRange.fromJson(json['dateRange'] as Map<String, dynamic>)
          : null,
      sentiments: json['sentiments'] != null
          ? SentimentFilter.fromJson(json['sentiments'] as Map<String, dynamic>)
          : null,
      keywords: json['keywords'] != null
          ? KeywordFilter.fromJson(json['keywords'] as Map<String, dynamic>)
          : null,
      minRelevanceScore: json['minRelevanceScore'] as double?,
      maxRelevanceScore: json['maxRelevanceScore'] as double?,
      isBookmarked: json['isBookmarked'] as bool?,
      limit: json['limit'] as int? ?? 20,
      offset: json['offset'] as int? ?? 0,
      sortBy: SortBy.values.firstWhere(
        (e) => e.name == json['sortBy'],
        orElse: () => SortBy.publishedAt,
      ),
      sortOrder: SortOrder.values.firstWhere(
        (e) => e.name == json['sortOrder'],
        orElse: () => SortOrder.descending,
      ),
      languages: (json['languages'] as List<dynamic>?)?.cast<String>(),
      contentTypes: (json['contentTypes'] as List<dynamic>?)
          ?.map((e) => ContentType.values.firstWhere((ct) => ct.name == e))
          .toList(),
      readingTime: json['readingTime'] != null
          ? ReadingTimeRange.fromJson(json['readingTime'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Checks if the filter has any active criteria
  bool get hasActiveFilters => 
      query?.isNotEmpty == true ||
      sources?.isNotEmpty == true ||
      dateRange != null ||
      sentiments != null ||
      keywords != null ||
      minRelevanceScore != null ||
      maxRelevanceScore != null ||
      isBookmarked != null ||
      languages?.isNotEmpty == true ||
      contentTypes?.isNotEmpty == true ||
      readingTime != null;

  /// Counts the number of active filter criteria
  int get activeFilterCount {
    int count = 0;
    if (query?.isNotEmpty == true) count++;
    if (sources?.isNotEmpty == true) count++;
    if (dateRange != null) count++;
    if (sentiments != null) count++;
    if (keywords != null) count++;
    if (minRelevanceScore != null || maxRelevanceScore != null) count++;
    if (isBookmarked != null) count++;
    if (languages?.isNotEmpty == true) count++;
    if (contentTypes?.isNotEmpty == true) count++;
    if (readingTime != null) count++;
    return count;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilter &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          _listEquals(sources, other.sources) &&
          dateRange == other.dateRange &&
          sentiments == other.sentiments &&
          keywords == other.keywords &&
          minRelevanceScore == other.minRelevanceScore &&
          maxRelevanceScore == other.maxRelevanceScore &&
          isBookmarked == other.isBookmarked &&
          limit == other.limit &&
          offset == other.offset &&
          sortBy == other.sortBy &&
          sortOrder == other.sortOrder &&
          _listEquals(languages, other.languages) &&
          _listEquals(contentTypes, other.contentTypes) &&
          readingTime == other.readingTime;

  @override
  int get hashCode => Object.hash(
        query,
        sources,
        dateRange,
        sentiments,
        keywords,
        minRelevanceScore,
        maxRelevanceScore,
        isBookmarked,
        limit,
        offset,
        sortBy,
        sortOrder,
        languages,
        contentTypes,
        readingTime,
      );

  @override
  String toString() {
    return 'SearchFilter('
        'query: $query, '
        'sources: $sources, '
        'dateRange: $dateRange, '
        'sentiments: $sentiments, '
        'keywords: $keywords, '
        'minRelevanceScore: $minRelevanceScore, '
        'maxRelevanceScore: $maxRelevanceScore, '
        'isBookmarked: $isBookmarked, '
        'limit: $limit, '
        'offset: $offset, '
        'sortBy: $sortBy, '
        'sortOrder: $sortOrder, '
        'languages: $languages, '
        'contentTypes: $contentTypes, '
        'readingTime: $readingTime'
        ')';
  }

  /// Helper method to compare lists for equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Date range filter for article publication dates
class DateRange {
  /// Start date for the range (inclusive)
  final DateTime startDate;
  
  /// End date for the range (inclusive)
  final DateTime endDate;
  
  /// Predefined date range type for quick selection
  final DateRangeType? type;

  const DateRange({
    required this.startDate,
    required this.endDate,
    this.type,
  });

  /// Creates a date range for today
  factory DateRange.today() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateRange(
      startDate: today,
      endDate: today.add(const Duration(days: 1)),
      type: DateRangeType.today,
    );
  }

  /// Creates a date range for the last week
  factory DateRange.lastWeek() {
    final now = DateTime.now();
    return DateRange(
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now,
      type: DateRangeType.lastWeek,
    );
  }

  /// Creates a date range for the last month
  factory DateRange.lastMonth() {
    final now = DateTime.now();
    return DateRange(
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
      type: DateRangeType.lastMonth,
    );
  }

  /// Creates a date range for the last year
  factory DateRange.lastYear() {
    final now = DateTime.now();
    return DateRange(
      startDate: now.subtract(const Duration(days: 365)),
      endDate: now,
      type: DateRangeType.lastYear,
    );
  }

  /// Duration of the date range
  Duration get duration => endDate.difference(startDate);

  /// Checks if a date falls within this range
  bool contains(DateTime date) {
    return date.isAfter(startDate) && date.isBefore(endDate) || 
           date.isAtSameMomentAs(startDate) || 
           date.isAtSameMomentAs(endDate);
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'type': type?.name,
  };

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      type: json['type'] != null
          ? DateRangeType.values.firstWhere((e) => e.name == json['type'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRange &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          type == other.type;

  @override
  int get hashCode => Object.hash(startDate, endDate, type);

  @override
  String toString() => 'DateRange(startDate: $startDate, endDate: $endDate, type: $type)';
}

/// Predefined date range types for quick selection
enum DateRangeType {
  today,
  yesterday,
  lastWeek,
  lastMonth,
  lastQuarter,
  lastYear,
  custom,
}

/// Sentiment-based filtering configuration
class SentimentFilter {
  /// List of sentiment labels to include
  /// Example: ['positive', 'negative', 'neutral']
  final List<String>? labels;
  
  /// Minimum sentiment score threshold (-1.0 to 1.0)
  final double? minScore;
  
  /// Maximum sentiment score threshold (-1.0 to 1.0)
  final double? maxScore;
  
  /// Include articles with positive sentiment (score > 0.1)
  final bool includePositive;
  
  /// Include articles with negative sentiment (score < -0.1)
  final bool includeNegative;
  
  /// Include articles with neutral sentiment (-0.1 <= score <= 0.1)
  final bool includeNeutral;

  const SentimentFilter({
    this.labels,
    this.minScore,
    this.maxScore,
    this.includePositive = true,
    this.includeNegative = true,
    this.includeNeutral = true,
  });

  /// Creates a filter for positive sentiment only
  factory SentimentFilter.positiveOnly() {
    return const SentimentFilter(
      labels: ['positive'],
      minScore: 0.1,
      includePositive: true,
      includeNegative: false,
      includeNeutral: false,
    );
  }

  /// Creates a filter for negative sentiment only
  factory SentimentFilter.negativeOnly() {
    return const SentimentFilter(
      labels: ['negative'],
      maxScore: -0.1,
      includePositive: false,
      includeNegative: true,
      includeNeutral: false,
    );
  }

  /// Creates a filter for neutral sentiment only
  factory SentimentFilter.neutralOnly() {
    return const SentimentFilter(
      labels: ['neutral'],
      minScore: -0.1,
      maxScore: 0.1,
      includePositive: false,
      includeNegative: false,
      includeNeutral: true,
    );
  }

  /// Checks if a sentiment score matches this filter
  bool matches(double sentimentScore, String sentimentLabel) {
    // Check label filter
    if (labels != null && !labels!.contains(sentimentLabel)) {
      return false;
    }

    // Check score range
    if (minScore != null && sentimentScore < minScore!) {
      return false;
    }
    if (maxScore != null && sentimentScore > maxScore!) {
      return false;
    }

    // Check inclusion flags
    if (sentimentScore > 0.1 && !includePositive) return false;
    if (sentimentScore < -0.1 && !includeNegative) return false;
    if (sentimentScore >= -0.1 && sentimentScore <= 0.1 && !includeNeutral) return false;

    return true;
  }

  Map<String, dynamic> toJson() => {
    'labels': labels,
    'minScore': minScore,
    'maxScore': maxScore,
    'includePositive': includePositive,
    'includeNegative': includeNegative,
    'includeNeutral': includeNeutral,
  };

  factory SentimentFilter.fromJson(Map<String, dynamic> json) {
    return SentimentFilter(
      labels: (json['labels'] as List<dynamic>?)?.cast<String>(),
      minScore: json['minScore'] as double?,
      maxScore: json['maxScore'] as double?,
      includePositive: json['includePositive'] as bool? ?? true,
      includeNegative: json['includeNegative'] as bool? ?? true,
      includeNeutral: json['includeNeutral'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SentimentFilter &&
          runtimeType == other.runtimeType &&
          _listEquals(labels, other.labels) &&
          minScore == other.minScore &&
          maxScore == other.maxScore &&
          includePositive == other.includePositive &&
          includeNegative == other.includeNegative &&
          includeNeutral == other.includeNeutral;

  @override
  int get hashCode => Object.hash(
        labels,
        minScore,
        maxScore,
        includePositive,
        includeNegative,
        includeNeutral,
      );

  /// Helper method to compare lists for equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Keyword-based filtering with exact and fuzzy matching
class KeywordFilter {
  /// Exact keywords that must be present in the article
  final List<String>? exactKeywords;
  
  /// Keywords for fuzzy matching (similar words accepted)
  final List<String>? fuzzyKeywords;
  
  /// Keywords that must NOT be present in the article
  final List<String>? excludeKeywords;
  
  /// Minimum number of keywords that must match
  final int? minMatchCount;
  
  /// Matching strategy (AND all keywords vs OR any keyword)
  final KeywordMatchStrategy strategy;
  
  /// Case sensitivity for keyword matching
  final bool caseSensitive;
  
  /// Include keyword variations (stemming)
  final bool includeVariations;

  const KeywordFilter({
    this.exactKeywords,
    this.fuzzyKeywords,
    this.excludeKeywords,
    this.minMatchCount,
    this.strategy = KeywordMatchStrategy.or,
    this.caseSensitive = false,
    this.includeVariations = true,
  });

  /// Checks if an article's keywords match this filter
  bool matches(List<String> articleKeywords, String articleText) {
    int matchCount = 0;

    // Prepare text for matching
    final text = caseSensitive ? articleText : articleText.toLowerCase();
    final keywords = caseSensitive ? articleKeywords : 
        articleKeywords.map((k) => k.toLowerCase()).toList();

    // Check exclude keywords first
    if (excludeKeywords != null) {
      for (final excludeKeyword in excludeKeywords!) {
        final keyword = caseSensitive ? excludeKeyword : excludeKeyword.toLowerCase();
        if (keywords.contains(keyword) || text.contains(keyword)) {
          return false; // Article contains excluded keyword
        }
      }
    }

    // Check exact keywords
    if (exactKeywords != null) {
      for (final exactKeyword in exactKeywords!) {
        final keyword = caseSensitive ? exactKeyword : exactKeyword.toLowerCase();
        if (keywords.contains(keyword) || text.contains(keyword)) {
          matchCount++;
          if (strategy == KeywordMatchStrategy.or) {
            return true; // At least one match found
          }
        } else if (strategy == KeywordMatchStrategy.and) {
          return false; // Required keyword not found
        }
      }
    }

    // Check fuzzy keywords (simplified fuzzy matching)
    if (fuzzyKeywords != null) {
      for (final fuzzyKeyword in fuzzyKeywords!) {
        final keyword = caseSensitive ? fuzzyKeyword : fuzzyKeyword.toLowerCase();
        bool fuzzyMatch = false;
        
        // Check for partial matches in keywords and text
        for (final articleKeyword in keywords) {
          if (articleKeyword.contains(keyword) || keyword.contains(articleKeyword)) {
            fuzzyMatch = true;
            break;
          }
        }
        
        if (!fuzzyMatch && text.contains(keyword)) {
          fuzzyMatch = true;
        }

        if (fuzzyMatch) {
          matchCount++;
          if (strategy == KeywordMatchStrategy.or) {
            return true;
          }
        } else if (strategy == KeywordMatchStrategy.and) {
          return false;
        }
      }
    }

    // Check minimum match count
    if (minMatchCount != null) {
      return matchCount >= minMatchCount!;
    }

    // For AND strategy, all keywords must match
    if (strategy == KeywordMatchStrategy.and) {
      final totalKeywords = (exactKeywords?.length ?? 0) + (fuzzyKeywords?.length ?? 0);
      return matchCount == totalKeywords;
    }

    // For OR strategy, at least one keyword must match
    return matchCount > 0;
  }

  Map<String, dynamic> toJson() => {
    'exactKeywords': exactKeywords,
    'fuzzyKeywords': fuzzyKeywords,
    'excludeKeywords': excludeKeywords,
    'minMatchCount': minMatchCount,
    'strategy': strategy.name,
    'caseSensitive': caseSensitive,
    'includeVariations': includeVariations,
  };

  factory KeywordFilter.fromJson(Map<String, dynamic> json) {
    return KeywordFilter(
      exactKeywords: (json['exactKeywords'] as List<dynamic>?)?.cast<String>(),
      fuzzyKeywords: (json['fuzzyKeywords'] as List<dynamic>?)?.cast<String>(),
      excludeKeywords: (json['excludeKeywords'] as List<dynamic>?)?.cast<String>(),
      minMatchCount: json['minMatchCount'] as int?,
      strategy: KeywordMatchStrategy.values.firstWhere(
        (e) => e.name == json['strategy'],
        orElse: () => KeywordMatchStrategy.or,
      ),
      caseSensitive: json['caseSensitive'] as bool? ?? false,
      includeVariations: json['includeVariations'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeywordFilter &&
          runtimeType == other.runtimeType &&
          _listEquals(exactKeywords, other.exactKeywords) &&
          _listEquals(fuzzyKeywords, other.fuzzyKeywords) &&
          _listEquals(excludeKeywords, other.excludeKeywords) &&
          minMatchCount == other.minMatchCount &&
          strategy == other.strategy &&
          caseSensitive == other.caseSensitive &&
          includeVariations == other.includeVariations;

  @override
  int get hashCode => Object.hash(
        exactKeywords,
        fuzzyKeywords,
        excludeKeywords,
        minMatchCount,
        strategy,
        caseSensitive,
        includeVariations,
      );

  /// Helper method to compare lists for equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Keyword matching strategy
enum KeywordMatchStrategy {
  /// Match if ANY keyword is found
  or,
  
  /// Match only if ALL keywords are found
  and,
}

/// Reading time range filter for articles
class ReadingTimeRange {
  /// Minimum reading time in minutes
  final int minMinutes;
  
  /// Maximum reading time in minutes
  final int maxMinutes;

  const ReadingTimeRange({
    required this.minMinutes,
    required this.maxMinutes,
  });

  /// Quick reads (1-3 minutes)
  factory ReadingTimeRange.quick() {
    return const ReadingTimeRange(minMinutes: 1, maxMinutes: 3);
  }

  /// Medium reads (3-10 minutes)
  factory ReadingTimeRange.medium() {
    return const ReadingTimeRange(minMinutes: 3, maxMinutes: 10);
  }

  /// Long reads (10+ minutes)
  factory ReadingTimeRange.long() {
    return const ReadingTimeRange(minMinutes: 10, maxMinutes: 60);
  }

  /// Checks if a reading time falls within this range
  bool contains(int readingTimeMinutes) {
    return readingTimeMinutes >= minMinutes && readingTimeMinutes <= maxMinutes;
  }

  Map<String, dynamic> toJson() => {
    'minMinutes': minMinutes,
    'maxMinutes': maxMinutes,
  };

  factory ReadingTimeRange.fromJson(Map<String, dynamic> json) {
    return ReadingTimeRange(
      minMinutes: json['minMinutes'] as int,
      maxMinutes: json['maxMinutes'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingTimeRange &&
          runtimeType == other.runtimeType &&
          minMinutes == other.minMinutes &&
          maxMinutes == other.maxMinutes;

  @override
  int get hashCode => Object.hash(minMinutes, maxMinutes);

  @override
  String toString() => 'ReadingTimeRange(minMinutes: $minMinutes, maxMinutes: $maxMinutes)';
}

/// Sort criteria options for search results
enum SortBy {
  /// Sort by publication date
  publishedAt,
  
  /// Sort by sentiment score
  sentimentScore,
  
  /// Sort by relevance score (from search algorithm)
  relevanceScore,
  
  /// Sort alphabetically by title
  title,
  
  /// Sort alphabetically by source
  source,
  
  /// Sort by reading time
  readingTime,
  
  /// Sort by engagement metrics
  engagement,
}

/// Sort order options
enum SortOrder {
  /// Ascending order (A-Z, oldest-newest, lowest-highest)
  ascending,
  
  /// Descending order (Z-A, newest-oldest, highest-lowest)
  descending,
}

/// Content type filter options
enum ContentType {
  /// Standard news articles
  article,
  
  /// Video content
  video,
  
  /// Podcast episodes
  podcast,
  
  /// Photo galleries
  gallery,
  
  /// Live updates/breaking news
  liveUpdate,
  
  /// Opinion pieces
  opinion,
  
  /// Interviews
  interview,
  
  /// Analysis and deep dives
  analysis,
}