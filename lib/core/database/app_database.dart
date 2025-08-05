import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/news_table.dart';
import 'tables/sync_metadata_table.dart';
import 'tables/keywords_table.dart';
import 'package:insightflo_app/core/constants/app_constants.dart';
import 'package:insightflo_app/core/monitoring/performance_monitor.dart';

// Include generated code
part 'app_database.g.dart';

/// Main application database using Drift ORM
/// Manages news articles and user data with Clean Architecture principles
@DriftDatabase(tables: [NewsTable, SyncMetadataTable, KeywordsTable])
class AppDatabase extends _$AppDatabase {
  /// Database instance
  AppDatabase() : super(_openConnection());

  /// Task 8.11: Performance metrics collector instance
  MetricCollector get _metricsCollector => MetricCollector.instance;

  /// Current database schema version
  @override
  int get schemaVersion => 4;

  /// Database migration strategy
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      // Called when the database is first created
      onCreate: (Migrator m) async {
        await m.createAll();

        // Create custom indexes for performance optimization
        await customStatement(NewsTableIndexes.freshArticlesIndex);
        await customStatement(NewsTableIndexes.searchIndex);
        await customStatement(NewsTableIndexes.positiveSentimentIndex);
        await customStatement(NewsTableIndexes.negativeSentimentIndex);

        // Create sync metadata indexes
        await customStatement(SyncMetadataTableIndexes.tableNameIndex);
        await customStatement(SyncMetadataTableIndexes.syncStatusIndex);
        await customStatement(SyncMetadataTableIndexes.lastSyncTimeIndex);
        await customStatement(SyncMetadataTableIndexes.tableNameDirectionIndex);

        // Create keywords indexes
        await customStatement(KeywordsTableIndexes.userIdIndex);
        await customStatement(KeywordsTableIndexes.keywordIndex);
        await customStatement(KeywordsTableIndexes.userKeywordIndex);
        await customStatement(KeywordsTableIndexes.weightIndex);
      },

      // Called when upgrading from an older schema version
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2: Add sync_metadata table
        if (from < 2) {
          // Create the sync_metadata table
          await m.createTable(syncMetadataTable);

          // Create sync metadata indexes
          await customStatement(SyncMetadataTableIndexes.tableNameIndex);
          await customStatement(SyncMetadataTableIndexes.syncStatusIndex);
          await customStatement(SyncMetadataTableIndexes.lastSyncTimeIndex);
          await customStatement(
            SyncMetadataTableIndexes.tableNameDirectionIndex,
          );

          // Initialize sync metadata for existing news table
          final now = DateTime.now().millisecondsSinceEpoch;
          await into(syncMetadataTable).insert(
            SyncMetadataTableCompanion.insert(
              id: 'news_articles_download',
              syncTableName: 'news_articles',
              lastSyncTime: now,
              syncStatus: 'pending',
              recordCount: 0,
              syncDirection: 'download',
              createdAt: now,
              updatedAt: now,
              errorMessage: const Value(null),
              metadata: const Value(null),
            ),
          );
        }

        // Migration from version 2 to 3: Fix sync_metadata table constraints
        if (from < 3) {
          // Drop and recreate sync_metadata table with fixed constraints
          await m.deleteTable('sync_metadata');
          await m.createTable(syncMetadataTable);

          // Recreate sync metadata indexes
          await customStatement(SyncMetadataTableIndexes.tableNameIndex);
          await customStatement(SyncMetadataTableIndexes.syncStatusIndex);
          await customStatement(SyncMetadataTableIndexes.lastSyncTimeIndex);
          await customStatement(
            SyncMetadataTableIndexes.tableNameDirectionIndex,
          );

          // Re-initialize sync metadata for existing news table
          final now = DateTime.now().millisecondsSinceEpoch;
          await into(syncMetadataTable).insert(
            SyncMetadataTableCompanion.insert(
              id: 'news_articles_download',
              syncTableName: 'news_articles',
              lastSyncTime: now,
              syncStatus: 'pending',
              recordCount: 0,
              syncDirection: 'download',
              createdAt: now,
              updatedAt: now,
              errorMessage: const Value(null),
              metadata: const Value(null),
            ),
          );
        }

        // Migration from version 3 to 4: Add keywords table
        if (from < 4) {
          // Create the keywords table
          await m.createTable(keywordsTable);

          // Create keywords indexes
          await customStatement(KeywordsTableIndexes.userIdIndex);
          await customStatement(KeywordsTableIndexes.keywordIndex);
          await customStatement(KeywordsTableIndexes.userKeywordIndex);
          await customStatement(KeywordsTableIndexes.weightIndex);
        }
      },

      // Called before opening the database
      beforeOpen: (details) async {
        // Enable foreign key constraints
        await customStatement('PRAGMA foreign_keys = ON');

        // Configure SQLite for better performance
        await customStatement('PRAGMA journal_mode = WAL');
        await customStatement('PRAGMA synchronous = NORMAL');
        await customStatement('PRAGMA cache_size = 10000');
        await customStatement('PRAGMA temp_store = MEMORY');

        // Set a reasonable busy timeout
        await customStatement('PRAGMA busy_timeout = 30000');
      },
    );
  }

  // News article queries with performance optimization

  /// Gets personalized news for a specific user
  /// Optimized with compound index (userId, publishedAt)
  /// Task 8.11: Enhanced with performance monitoring
  Future<List<NewsTableData>> getPersonalizedNews({
    required String userId,
    int limit = AppConstants.defaultPageSize,
    int offset = 0,
  }) async {
    return await _metricsCollector.measureDatabaseQuery(
      'get_personalized_news',
      () async {
        return await (select(newsTable)
              ..where((tbl) => tbl.userId.equals(userId))
              ..orderBy([
                (t) => OrderingTerm.desc(t.publishedAt),
                (t) => OrderingTerm.desc(t.sentimentScore),
              ])
              ..limit(limit, offset: offset))
            .get();
      },
      metadata: {
        'user_id': userId,
        'limit': limit,
        'offset': offset,
        'query_type': 'personalized_news',
      },
    );
  }

  /// Gets fresh articles (cached within 24 hours)
  /// Uses partial index for better performance
  /// Task 8.11: Enhanced with performance monitoring
  Future<List<NewsTableData>> getFreshNews({
    required String userId,
    int limit = AppConstants.defaultPageSize,
  }) async {
    return await _metricsCollector.measureDatabaseQuery(
      'get_fresh_news',
      () async {
        final twentyFourHoursAgo = DateTime.now()
            .subtract(const Duration(hours: 24))
            .millisecondsSinceEpoch;

        return await (select(newsTable)
              ..where(
                (tbl) =>
                    tbl.userId.equals(userId) &
                    tbl.cachedAt.isBiggerThanValue(twentyFourHoursAgo),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
              ..limit(limit))
            .get();
      },
      metadata: {
        'user_id': userId,
        'limit': limit,
        'query_type': 'fresh_news',
        'cache_window_hours': 24,
      },
    );
  }

  /// Searches news articles by title and content
  /// Task 8.11: Enhanced with performance monitoring
  Future<List<NewsTableData>> searchNews({
    required String userId,
    required String query,
    int limit = AppConstants.defaultPageSize,
  }) async {
    return await _metricsCollector.measureDatabaseQuery(
      'search_news',
      () async {
        final searchPattern = '%$query%';

        return await (select(newsTable)
              ..where(
                (tbl) =>
                    tbl.userId.equals(userId) &
                    (tbl.title.like(searchPattern) |
                        tbl.summary.like(searchPattern) |
                        tbl.keywords.like(searchPattern)),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.publishedAt),
                (t) => OrderingTerm.desc(t.sentimentScore),
              ])
              ..limit(limit))
            .get();
      },
      metadata: {
        'user_id': userId,
        'search_query': query,
        'search_pattern': '%$query%',
        'limit': limit,
        'query_type': 'search_news',
      },
    );
  }

  /// Gets bookmarked articles for a user
  /// Uses compound index (userId, isBookmarked)
  Future<List<NewsTableData>> getBookmarkedNews({
    required String userId,
    int limit = AppConstants.defaultPageSize,
  }) async {
    return await (select(newsTable)
          ..where(
            (tbl) => tbl.userId.equals(userId) & tbl.isBookmarked.equals(1),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..limit(limit))
        .get();
  }

  /// Gets articles by sentiment
  /// Uses sentiment-specific partial indexes
  Future<List<NewsTableData>> getNewsBySentiment({
    required String userId,
    required double minSentiment,
    required double maxSentiment,
    int limit = AppConstants.defaultPageSize,
  }) async {
    return await (select(newsTable)
          ..where(
            (tbl) =>
                tbl.userId.equals(userId) &
                tbl.sentimentScore.isBetweenValues(minSentiment, maxSentiment),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..limit(limit))
        .get();
  }

  /// Inserts or updates a news article
  Future<void> insertOrUpdateNews(NewsTableCompanion article) async {
    await into(newsTable).insertOnConflictUpdate(article);
  }

  /// Batch inserts news articles for better performance
  /// Task 8.11: Enhanced with performance monitoring
  Future<void> batchInsertNews(List<NewsTableCompanion> articles) async {
    await _metricsCollector.measureDatabaseQuery(
      'batch_insert_news',
      () async {
        await batch((batch) {
          for (final article in articles) {
            batch.insert(newsTable, article, mode: InsertMode.insertOrReplace);
          }
        });
      },
      metadata: {
        'article_count': articles.length,
        'query_type': 'batch_insert',
        'operation': 'insertOrReplace',
      },
    );
  }

  /// Updates bookmark status for an article
  Future<bool> updateBookmarkStatus({
    required String articleId,
    required String userId,
    required bool isBookmarked,
  }) async {
    final result =
        await (update(newsTable)..where(
              (tbl) => tbl.id.equals(articleId) & tbl.userId.equals(userId),
            ))
            .write(
              NewsTableCompanion(isBookmarked: Value(isBookmarked ? 1 : 0)),
            );

    return result > 0;
  }

  /// Gets database statistics for monitoring
  Future<Map<String, int>> getDatabaseStats({required String userId}) async {
    final totalCount = await customSelect(
      'SELECT COUNT(*) as count FROM news_articles WHERE user_id = ?',
      variables: [Variable.withString(userId)],
      readsFrom: {newsTable},
    ).getSingle();

    final bookmarkedCount = await customSelect(
      'SELECT COUNT(*) as count FROM news_articles WHERE user_id = ? AND is_bookmarked = 1',
      variables: [Variable.withString(userId)],
      readsFrom: {newsTable},
    ).getSingle();

    final freshCount = await customSelect(
      'SELECT COUNT(*) as count FROM news_articles WHERE user_id = ? AND cached_at > ?',
      variables: [
        Variable.withString(userId),
        Variable.withInt(
          DateTime.now()
              .subtract(const Duration(hours: 24))
              .millisecondsSinceEpoch,
        ),
      ],
      readsFrom: {newsTable},
    ).getSingle();

    return {
      'total': totalCount.data['count'] as int,
      'bookmarked': bookmarkedCount.data['count'] as int,
      'fresh': freshCount.data['count'] as int,
    };
  }

  // Advanced queries for performance optimization

  /// Gets news articles within a specific date range
  /// Optimized with publishedAt index
  Future<List<NewsTableData>> getNewsByDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = AppConstants.defaultPageSize,
  }) async {
    final startTimestamp = startDate.millisecondsSinceEpoch;
    final endTimestamp = endDate.millisecondsSinceEpoch;

    return await (select(newsTable)
          ..where(
            (tbl) =>
                tbl.userId.equals(userId) &
                tbl.publishedAt.isBetweenValues(startTimestamp, endTimestamp),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.publishedAt)])
          ..limit(limit))
        .get();
  }

  /// Gets top news articles by sentiment label with highest scores
  /// Uses sentiment-specific indexes for optimal performance
  Future<List<NewsTableData>> getTopNewsBySentiment({
    required String userId,
    required String sentimentLabel,
    int limit = AppConstants.defaultPageSize,
  }) async {
    return await (select(newsTable)
          ..where(
            (tbl) =>
                tbl.userId.equals(userId) &
                tbl.sentimentLabel.equals(sentimentLabel),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.sentimentScore),
            (t) => OrderingTerm.desc(t.publishedAt),
          ])
          ..limit(limit))
        .get();
  }

  /// Gets comprehensive statistics by news source
  /// Returns source name, article count, and average sentiment
  Future<List<Map<String, dynamic>>> getSourceStatistics({
    required String userId,
    int limit = 50,
  }) async {
    final result = await customSelect(
      '''
      SELECT 
        source,
        COUNT(*) as article_count,
        AVG(sentiment_score) as avg_sentiment,
        COUNT(CASE WHEN is_bookmarked = 1 THEN 1 END) as bookmarked_count,
        MAX(published_at) as latest_article_date
      FROM news_articles 
      WHERE user_id = ? 
      GROUP BY source 
      ORDER BY article_count DESC, avg_sentiment DESC
      LIMIT ?
      ''',
      variables: [Variable.withString(userId), Variable.withInt(limit)],
      readsFrom: {newsTable},
    ).get();

    return result
        .map(
          (row) => {
            'source': row.data['source'] as String,
            'articleCount': row.data['article_count'] as int,
            'avgSentiment': (row.data['avg_sentiment'] as double?) ?? 0.0,
            'bookmarkedCount': row.data['bookmarked_count'] as int,
            'latestArticleDate': row.data['latest_article_date'] as int,
          },
        )
        .toList();
  }

  // Batch operations for high-performance data manipulation

  /// Batch updates sentiment scores for multiple articles
  /// Uses transaction for atomicity and better performance
  Future<int> batchUpdateSentiment({
    required String userId,
    required Map<String, double> sentimentUpdates,
  }) async {
    if (sentimentUpdates.isEmpty) return 0;

    return await transaction(() async {
      int updatedCount = 0;

      // Process updates in batches of 100 for optimal performance
      final entries = sentimentUpdates.entries.toList();
      const batchSize = 100;

      for (int i = 0; i < entries.length; i += batchSize) {
        final batchEnd = (i + batchSize < entries.length)
            ? i + batchSize
            : entries.length;
        final batch = entries.sublist(i, batchEnd);

        await this.batch((batchWriter) {
          for (final entry in batch) {
            final articleId = entry.key;
            final sentimentScore = entry.value;

            // Determine sentiment label based on score
            String sentimentLabel;
            if (sentimentScore >= 0.1) {
              sentimentLabel = 'positive';
            } else if (sentimentScore <= -0.1) {
              sentimentLabel = 'negative';
            } else {
              sentimentLabel = 'neutral';
            }

            batchWriter.update(
              newsTable,
              NewsTableCompanion(
                sentimentScore: Value(sentimentScore),
                sentimentLabel: Value(sentimentLabel),
              ),
              where: (tbl) =>
                  tbl.id.equals(articleId) & tbl.userId.equals(userId),
            );
          }
        });

        updatedCount += batch.length;
      }

      return updatedCount;
    });
  }

  /// Enhanced cleanup with 7-day retention policy
  /// Keeps articles from last 7 days + up to 1000 most recent articles
  Future<int> cleanupOldArticles({
    required String userId,
    int keepCount = 1000,
    int retentionDays = 7,
  }) async {
    return await transaction(() async {
      // Calculate 7-day cutoff timestamp
      final sevenDaysAgo = DateTime.now()
          .subtract(Duration(days: retentionDays))
          .millisecondsSinceEpoch;

      // First, get articles to keep (either within 7 days OR in top 1000 recent)
      final articlesToKeep = await customSelect(
        '''
        SELECT id FROM (
          SELECT id, cached_at, published_at,
                 ROW_NUMBER() OVER (ORDER BY published_at DESC) as rn
          FROM news_articles 
          WHERE user_id = ?
        ) ranked
        WHERE cached_at > ? OR rn <= ?
        ''',
        variables: [
          Variable.withString(userId),
          Variable.withInt(sevenDaysAgo),
          Variable.withInt(keepCount),
        ],
        readsFrom: {newsTable},
      ).get();

      if (articlesToKeep.isEmpty) return 0;

      // Extract IDs to keep
      final idsToKeep = articlesToKeep
          .map((row) => row.data['id'] as String)
          .toList();

      // Delete articles not in the keep list
      final placeholders = List.filled(idsToKeep.length, '?').join(',');
      final deleteCount = await customUpdate(
        'DELETE FROM news_articles WHERE user_id = ? AND id NOT IN ($placeholders)',
        variables: [
          Variable.withString(userId),
          ...idsToKeep.map((id) => Variable.withString(id)),
        ],
        updates: {newsTable},
      );

      return deleteCount;
    });
  }

  /// Performs database optimization including VACUUM and index maintenance
  /// Should be called periodically to maintain optimal performance
  /// Task 8.11: Enhanced with performance monitoring
  Future<Map<String, dynamic>> optimizeDatabase() async {
    return await _metricsCollector.measureDatabaseQuery(
      'optimize_database',
      () async {
        final stopwatch = Stopwatch()..start();

        try {
          // Get database size before optimization
          final sizeBefore = await customSelect(
            'PRAGMA page_count',
            readsFrom: {},
          ).getSingle();

          // Run VACUUM to reclaim space and defragment
          await customStatement('VACUUM');

          // Update table statistics for query optimizer
          await customStatement('ANALYZE');

          // Reindex all indexes for optimal performance
          await customStatement('REINDEX');

          // Get database size after optimization
          final sizeAfter = await customSelect(
            'PRAGMA page_count',
            readsFrom: {},
          ).getSingle();

          stopwatch.stop();

          final pagesBefore = sizeBefore.data['page_count'] as int;
          final pagesAfter = sizeAfter.data['page_count'] as int;
          final spaceReclaimed = pagesBefore - pagesAfter;

          return {
            'success': true,
            'durationMs': stopwatch.elapsedMilliseconds,
            'pagesBefore': pagesBefore,
            'pagesAfter': pagesAfter,
            'spaceReclaimed': spaceReclaimed,
            'compressionRatio': pagesBefore > 0
                ? (spaceReclaimed / pagesBefore)
                : 0.0,
          };
        } catch (e) {
          stopwatch.stop();
          return {
            'success': false,
            'error': e.toString(),
            'durationMs': stopwatch.elapsedMilliseconds,
          };
        }
      },
      metadata: {
        'query_type': 'optimize_database',
        'operations': ['VACUUM', 'ANALYZE', 'REINDEX'],
      },
    );
  }

  // Sync metadata management methods

  /// Gets sync metadata for a specific table and direction
  Future<SyncMetadataData?> getSyncMetadata({
    required String tableName,
    required String syncDirection,
  }) async {
    final id = '${tableName}_$syncDirection';
    return await (select(syncMetadataTable)
          ..where((tbl) => tbl.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Gets all sync metadata records for a table
  Future<List<SyncMetadataData>> getAllSyncMetadataForTable({
    required String tableName,
  }) async {
    return await (select(syncMetadataTable)
          ..where((tbl) => tbl.syncTableName.equals(tableName))
          ..orderBy([(t) => OrderingTerm.desc(t.lastSyncTime)]))
        .get();
  }

  /// Gets sync metadata records by status
  Future<List<SyncMetadataData>> getSyncMetadataByStatus({
    required String status,
  }) async {
    return await (select(syncMetadataTable)
          ..where((tbl) => tbl.syncStatus.equals(status))
          ..orderBy([(t) => OrderingTerm.asc(t.lastSyncTime)]))
        .get();
  }

  /// Updates or inserts sync metadata
  Future<void> upsertSyncMetadata({
    required String tableName,
    required String syncDirection,
    required String syncStatus,
    required int recordCount,
    String? errorMessage,
    String? metadata,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '${tableName}_$syncDirection';

    await into(syncMetadataTable).insertOnConflictUpdate(
      SyncMetadataTableCompanion.insert(
        id: id,
        syncTableName: tableName,
        lastSyncTime: now,
        syncStatus: syncStatus,
        recordCount: recordCount,
        syncDirection: syncDirection,
        createdAt: now,
        updatedAt: now,
        errorMessage: Value(errorMessage),
        metadata: Value(metadata),
      ),
    );
  }

  /// Updates sync status for a specific sync metadata record
  Future<bool> updateSyncStatus({
    required String tableName,
    required String syncDirection,
    required String syncStatus,
    String? errorMessage,
  }) async {
    final id = '${tableName}_$syncDirection';
    final now = DateTime.now().millisecondsSinceEpoch;

    final result =
        await (update(
          syncMetadataTable,
        )..where((tbl) => tbl.id.equals(id))).write(
          SyncMetadataTableCompanion(
            syncStatus: Value(syncStatus),
            updatedAt: Value(now),
            errorMessage: Value(errorMessage),
          ),
        );

    return result > 0;
  }

  /// Gets stale sync metadata (older than specified duration)
  Future<List<SyncMetadataData>> getStaleSyncMetadata({
    required Duration maxAge,
  }) async {
    final cutoffTime = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

    return await (select(syncMetadataTable)
          ..where((tbl) => tbl.lastSyncTime.isSmallerThanValue(cutoffTime))
          ..orderBy([(t) => OrderingTerm.asc(t.lastSyncTime)]))
        .get();
  }

  /// Gets sync statistics for all tables
  Future<Map<String, dynamic>> getSyncStatistics() async {
    final allMetadata = await select(syncMetadataTable).get();

    final stats = <String, dynamic>{
      'totalTables': <String>{}.length,
      'byStatus': <String, int>{},
      'totalRecords': 0,
      'lastSyncTime': 0,
      'failedSyncs': <Map<String, dynamic>>[],
    };

    final tableNames = <String>{};
    int totalRecords = 0;
    int latestSyncTime = 0;
    final statusCounts = <String, int>{};
    final failedSyncs = <Map<String, dynamic>>[];

    for (final metadata in allMetadata) {
      tableNames.add(metadata.syncTableName);
      totalRecords += metadata.recordCount;

      if (metadata.lastSyncTime > latestSyncTime) {
        latestSyncTime = metadata.lastSyncTime;
      }

      statusCounts[metadata.syncStatus] =
          (statusCounts[metadata.syncStatus] ?? 0) + 1;

      if (metadata.syncStatus == 'failed' && metadata.errorMessage != null) {
        failedSyncs.add({
          'tableName': metadata.syncTableName,
          'syncDirection': metadata.syncDirection,
          'errorMessage': metadata.errorMessage,
          'lastSyncTime': metadata.lastSyncTime,
        });
      }
    }

    stats['totalTables'] = tableNames.length;
    stats['byStatus'] = statusCounts;
    stats['totalRecords'] = totalRecords;
    stats['lastSyncTime'] = latestSyncTime;
    stats['failedSyncs'] = failedSyncs;

    return stats;
  }

  /// Cleans up old sync metadata records
  Future<int> cleanupSyncMetadata({required Duration retentionPeriod}) async {
    final cutoffTime = DateTime.now()
        .subtract(retentionPeriod)
        .millisecondsSinceEpoch;

    return await (delete(syncMetadataTable)..where(
          (tbl) =>
              tbl.updatedAt.isSmallerThanValue(cutoffTime) &
              tbl.syncStatus.isNotValue('syncing'),
        )) // Don't delete active syncs
        .go();
  }

  // Keywords management methods

  /// Gets all keywords for a user
  Future<List<KeywordsTableData>> getKeywords({
    required String userId,
    int limit = 50,
  }) async {
    return await (select(keywordsTable)
          ..where((tbl) => tbl.userId.equals(userId))
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(limit))
        .get();
  }

  /// Creates a new keyword
  Future<KeywordsTableData> createKeyword({
    required String id,
    required String userId,
    required String keyword,
    required double weight,
    String? category,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final companion = KeywordsTableCompanion.insert(
      id: id,
      userId: userId,
      keyword: keyword,
      weight: Value(weight),
      category: category != null ? Value(category) : const Value.absent(),
      createdAt: now,
      updatedAt: Value(now),
    );
    
    await into(keywordsTable).insert(companion);
    
    // Return the created keyword
    return await (select(keywordsTable)..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  /// Updates an existing keyword
  Future<bool> updateKeyword({
    required String id,
    required String userId,
    String? keyword,
    double? weight,
    String? category,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    
    final companion = KeywordsTableCompanion(
      keyword: keyword != null ? Value(keyword) : const Value.absent(),
      weight: weight != null ? Value(weight) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      updatedAt: Value(now),
    );
    
    final result = await (update(keywordsTable)
          ..where((tbl) => tbl.id.equals(id) & tbl.userId.equals(userId)))
        .write(companion);
    
    return result > 0;
  }

  /// Deletes a keyword
  Future<bool> deleteKeyword({
    required String keywordId,
    required String userId,
  }) async {
    final result = await (delete(keywordsTable)
          ..where((tbl) => tbl.id.equals(keywordId) & tbl.userId.equals(userId)))
        .go();
    
    return result > 0;
  }

  /// Searches for keyword suggestions (returns existing keywords matching query)
  Future<List<String>> searchKeywordSuggestions({
    required String userId,
    required String query,
    int limit = 10,
  }) async {
    final searchPattern = '%$query%';
    
    final results = await (select(keywordsTable)
          ..where((tbl) => tbl.userId.equals(userId) & tbl.keyword.like(searchPattern))
          ..orderBy([(t) => OrderingTerm.desc(t.weight)])
          ..limit(limit))
        .get();
    
    return results.map((row) => row.keyword).toList();
  }
}

/// Database connection configuration
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Make sure SQLite3 is initialized for mobile platforms
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Use sqlite3_flutter_libs for better performance
    // Removed sqlite3.tempDirectory as it's not needed

    // Get the application documents directory
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'insightflo_app.db'));

    return NativeDatabase.createInBackground(
      file,
      logStatements: false, // Set to true for debugging
    );
  });
}

/// Global database instance
/// Use dependency injection in production
final database = AppDatabase();
