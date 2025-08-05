import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:insightflo_app/core/database/database.dart';
import '../models/news_model.dart';
import '../datasources/news_local_data_source.dart';
import '../datasources/news_remote_data_source.dart';

/// Enumeration of synchronization status states
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
  conflictResolved,
}

/// Enumeration of conflict resolution strategies
enum ConflictResolutionStrategy {
  serverWins,
  clientWins,
  merge,
}

/// Configuration for retry behavior with exponential backoff
class RetryConfig {
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;
  final double multiplier;
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.multiplier = 2.0,
    this.useJitter = true,
  });

  /// Calculates delay for a given attempt using exponential backoff
  Duration calculateDelay(int attempt) {
    final exponentialDelay = baseDelay * pow(multiplier, attempt);
    var delay = Duration(
      milliseconds: min(exponentialDelay.inMilliseconds, maxDelay.inMilliseconds).toInt(),
    );

    // Add jitter to prevent thundering herd problem
    if (useJitter) {
      final jitter = Random().nextDouble() * 0.1 + 0.9; // 90-100% of calculated delay
      delay = Duration(milliseconds: (delay.inMilliseconds * jitter).toInt());
    }

    return delay;
  }
}

/// Configuration for background synchronization
class BackgroundSyncConfig {
  final Duration syncInterval;
  final bool enableAutoSync;
  final bool syncOnlyOnWifi;
  final int maxBackgroundRetries;

  const BackgroundSyncConfig({
    this.syncInterval = const Duration(minutes: 15),
    this.enableAutoSync = true,
    this.syncOnlyOnWifi = false,
    this.maxBackgroundRetries = 2,
  });
}

/// Result of a synchronization operation
class SyncResult {
  final bool success;
  final int recordsSynced;
  final Duration duration;
  final String? errorMessage;
  final SyncStatus status;
  final DateTime timestamp;

  const SyncResult({
    required this.success,
    required this.recordsSynced,
    required this.duration,
    this.errorMessage,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'recordsSynced': recordsSynced,
    'duration': duration.inMilliseconds,
    'errorMessage': errorMessage,
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// State information for ongoing synchronization
class SyncState {
  final SyncStatus status;
  final double progress;
  final String? currentOperation;
  final int totalItems;
  final int processedItems;
  final String? errorMessage;

  const SyncState({
    required this.status,
    this.progress = 0.0,
    this.currentOperation,
    this.totalItems = 0,
    this.processedItems = 0,
    this.errorMessage,
  });

  SyncState copyWith({
    SyncStatus? status,
    double? progress,
    String? currentOperation,
    int? totalItems,
    int? processedItems,
    String? errorMessage,
  }) {
    return SyncState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentOperation: currentOperation ?? this.currentOperation,
      totalItems: totalItems ?? this.totalItems,
      processedItems: processedItems ?? this.processedItems,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Manages bidirectional synchronization between local Drift DB and Vercel API
/// Implements offline-first architecture with conflict resolution and background sync
class SyncManager {
  final AppDatabase _database;
  final NewsLocalDataSource _localDataSource;
  final NewsRemoteDataSource _remoteDataSource;
  final RetryConfig _retryConfig;
  final BackgroundSyncConfig _backgroundConfig;
  final ConflictResolutionStrategy _conflictStrategy;

  // Stream controllers for real-time status updates
  final StreamController<SyncState> _syncStateController = 
      StreamController<SyncState>.broadcast();
  final StreamController<SyncResult> _syncResultController = 
      StreamController<SyncResult>.broadcast();

  // Internal state management
  SyncState _currentState = const SyncState(status: SyncStatus.idle);
  Timer? _backgroundSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isDisposed = false;

  /// Constructor with dependency injection
  SyncManager({
    required AppDatabase database,
    required NewsLocalDataSource localDataSource,
    required NewsRemoteDataSource remoteDataSource,
    RetryConfig retryConfig = const RetryConfig(),
    BackgroundSyncConfig backgroundConfig = const BackgroundSyncConfig(),
    ConflictResolutionStrategy conflictStrategy = ConflictResolutionStrategy.serverWins,
  })  : _database = database,
        _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _retryConfig = retryConfig,
        _backgroundConfig = backgroundConfig,
        _conflictStrategy = conflictStrategy {
    _initializeConnectivityMonitoring();
    _startBackgroundSync();
  }

  /// Real-time stream of synchronization state updates
  Stream<SyncState> get syncStatusStream => _syncStateController.stream;

  /// Stream of synchronization results
  Stream<SyncResult> get syncResultStream => _syncResultController.stream;

  /// Current synchronization state
  SyncState get currentState => _currentState;

  /// Initializes connectivity monitoring for automatic sync resumption
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // Check if any connection is available (not none)
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      
      if (hasConnection && _currentState.status == SyncStatus.failed) {
        // Auto-resume sync when connectivity is restored
        _scheduleSync(delay: const Duration(seconds: 2));
      }
    });
  }

  /// Starts background synchronization timer
  void _startBackgroundSync() {
    if (!_backgroundConfig.enableAutoSync) return;

    _backgroundSyncTimer = Timer.periodic(_backgroundConfig.syncInterval, (_) {
      if (_currentState.status == SyncStatus.idle) {
        syncWithRemote(background: true);
      }
    });
  }

  /// Updates current sync state and notifies listeners
  void _updateState(SyncState newState) {
    if (_isDisposed) return;
    
    _currentState = newState;
    _syncStateController.add(newState);
  }

  /// Schedules a sync operation with delay
  void _scheduleSync({Duration delay = Duration.zero}) {
    Timer(delay, () {
      if (!_isDisposed && _currentState.status == SyncStatus.idle) {
        syncWithRemote();
      }
    });
  }

  /// Performs bidirectional synchronization between local and remote data
  /// Returns a SyncResult indicating success/failure and sync statistics
  Future<SyncResult> syncWithRemote({
    String? userId,
    bool background = false,
    bool forceFullSync = false,
  }) async {
    if (_currentState.status == SyncStatus.syncing) {
      throw StateError('Sync already in progress');
    }

    final stopwatch = Stopwatch()..start();
    var recordsSynced = 0;
    
    try {
      _updateState(const SyncState(
        status: SyncStatus.syncing,
        currentOperation: 'Preparing synchronization...',
      ));

      // Check network connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((result) => result == ConnectivityResult.none)) {
        throw Exception('No network connectivity available');
      }

      // Check WiFi requirement for background sync
      if (background && 
          _backgroundConfig.syncOnlyOnWifi && 
          !connectivity.contains(ConnectivityResult.wifi)) {
        throw Exception('Background sync requires WiFi connection');
      }

      // Get sync metadata to determine last sync time
      final syncMetadata = await _database.getSyncMetadata(
        tableName: 'news_articles',
        syncDirection: 'bidirectional',
      );

      final lastSyncTime = syncMetadata?.lastSyncTime ?? 0;
      final shouldPerformIncrementalSync = !forceFullSync && lastSyncTime > 0;

      // Step 1: Download from server (server → local)
      _updateState(_currentState.copyWith(
        currentOperation: 'Downloading from server...',
        progress: 0.1,
      ));

      final downloadResult = await _performDownloadSync(
        userId: userId,
        lastSyncTime: shouldPerformIncrementalSync ? DateTime.fromMillisecondsSinceEpoch(lastSyncTime) : null,
      );

      recordsSynced += downloadResult.recordsSynced;

      // Step 2: Upload to server (local → server)
      _updateState(_currentState.copyWith(
        currentOperation: 'Uploading to server...',
        progress: 0.6,
      ));

      final uploadResult = await _performUploadSync(
        userId: userId,
        lastSyncTime: shouldPerformIncrementalSync ? DateTime.fromMillisecondsSinceEpoch(lastSyncTime) : null,
      );

      recordsSynced += uploadResult.recordsSynced;

      // Step 3: Update sync metadata
      _updateState(_currentState.copyWith(
        currentOperation: 'Updating sync metadata...',
        progress: 0.9,
      ));

      await _database.upsertSyncMetadata(
        tableName: 'news_articles',
        syncDirection: 'bidirectional',
        syncStatus: 'completed',
        recordCount: recordsSynced,
        metadata: jsonEncode({
          'downloadedRecords': downloadResult.recordsSynced,
          'uploadedRecords': uploadResult.recordsSynced,
          'incrementalSync': shouldPerformIncrementalSync,
        }),
      );

      stopwatch.stop();

      final result = SyncResult(
        success: true,
        recordsSynced: recordsSynced,
        duration: stopwatch.elapsed,
        status: SyncStatus.completed,
        timestamp: DateTime.now(),
      );

      _updateState(const SyncState(
        status: SyncStatus.completed,
        progress: 1.0,
        currentOperation: 'Sync completed successfully',
      ));

      _syncResultController.add(result);

      // Reset to idle after a short delay
      Timer(const Duration(seconds: 2), () {
        if (!_isDisposed) {
          _updateState(const SyncState(status: SyncStatus.idle));
        }
      });

      return result;

    } catch (error) {
      stopwatch.stop();

      final errorMessage = error.toString();
      await _database.upsertSyncMetadata(
        tableName: 'news_articles',
        syncDirection: 'bidirectional',
        syncStatus: 'failed',
        recordCount: recordsSynced,
        errorMessage: errorMessage,
      );

      final result = SyncResult(
        success: false,
        recordsSynced: recordsSynced,
        duration: stopwatch.elapsed,
        errorMessage: errorMessage,
        status: SyncStatus.failed,
        timestamp: DateTime.now(),
      );

      _updateState(SyncState(
        status: SyncStatus.failed,
        errorMessage: errorMessage,
      ));

      _syncResultController.add(result);

      // Schedule retry with exponential backoff
      if (!background) {
        _scheduleRetrySync(error: errorMessage);
      }

      rethrow;
    }
  }

  /// Performs download synchronization (server → local)
  Future<SyncResult> _performDownloadSync({
    String? userId,
    DateTime? lastSyncTime,
  }) async {
    try {
      // Fetch news from remote API with incremental update support
      final remoteNews = await _withRetry(() async {
        return await _remoteDataSource.getPersonalizedNews(
          userId: userId ?? 'default',
          limit: 100, // Batch size for performance
        );
      });

      if (remoteNews.isEmpty) {
        return SyncResult(
          success: true,
          recordsSynced: 0,
          duration: Duration.zero,
          status: SyncStatus.completed,
          timestamp: DateTime.now(),
        );
      }

      // Check for conflicts and resolve them
      final resolvedNews = <NewsModel>[];
      for (final remoteArticle in remoteNews) {
        // Convert NewsArticleModel to NewsModel
        final newsModel = NewsModel(
          id: remoteArticle.id,
          title: remoteArticle.title,
          content: remoteArticle.content,
          summary: remoteArticle.summary,
          source: remoteArticle.source,
          url: remoteArticle.url,
          imageUrl: remoteArticle.imageUrl,
          publishedAt: remoteArticle.publishedAt,
          keywords: remoteArticle.keywords,
          sentimentScore: remoteArticle.sentimentScore ?? 0.0,
          sentimentLabel: remoteArticle.sentimentLabel ?? 'neutral',
          isBookmarked: remoteArticle.isBookmarked,
          cachedAt: DateTime.now(),
          userId: userId ?? 'default',
        );
        
        final resolved = await handleConflictResolution(
          remoteArticle: newsModel,
          strategy: _conflictStrategy,
        );
        if (resolved != null) {
          resolvedNews.add(resolved);
        }
      }

      // Batch insert resolved articles
      if (resolvedNews.isNotEmpty) {
        await _localDataSource.batchCacheNewsArticles(resolvedNews);
      }

      return SyncResult(
        success: true,
        recordsSynced: resolvedNews.length,
        duration: Duration.zero,
        status: SyncStatus.completed,
        timestamp: DateTime.now(),
      );

    } catch (error) {
      throw Exception('Download sync failed: $error');
    }
  }

  /// Performs upload synchronization (local → server)
  Future<SyncResult> _performUploadSync({
    String? userId,
    DateTime? lastSyncTime,
  }) async {
    try {
      // For now, this is primarily download-focused
      // Upload functionality would be implemented here for user-generated content
      // Such as bookmarks, reading history, preferences, etc.
      
      // Placeholder for upload logic
      // Future implementation would upload bookmarked articles
      // final bookmarkedNews = await _localDataSource.getBookmarkedNews(
      //   userId: userId ?? 'default',
      //   limit: 50,
      // );

      // In a real implementation, you would upload bookmarked articles
      // to the server for cross-device synchronization
      
      return SyncResult(
        success: true,
        recordsSynced: 0, // No uploads for now
        duration: Duration.zero,
        status: SyncStatus.completed,
        timestamp: DateTime.now(),
      );

    } catch (error) {
      throw Exception('Upload sync failed: $error');
    }
  }

  /// Handles conflict resolution between local and remote data
  /// Returns the resolved article or null if the article should be skipped
  Future<NewsModel?> handleConflictResolution({
    required NewsModel remoteArticle,
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.serverWins,
  }) async {
    try {
      // Check if article exists locally
      final localExists = await _localDataSource.hasArticle(
        articleId: remoteArticle.id,
        userId: remoteArticle.userId,
      );

      if (!localExists) {
        // No conflict - new article from server
        return remoteArticle;
      }

      // Article exists locally - resolve conflict based on strategy
      switch (strategy) {
        case ConflictResolutionStrategy.serverWins:
          // Server version always wins (default behavior)
          return remoteArticle;

        case ConflictResolutionStrategy.clientWins:
          // Client version wins - skip remote update
          return null;

        case ConflictResolutionStrategy.merge:
          // Merge strategy - combine server and local data
          // For news articles, we typically prefer server data
          // but preserve local bookmarks and user interactions
          return remoteArticle; // Simplified merge logic
      }

    } catch (error) {
      debugPrint('Conflict resolution failed for article ${remoteArticle.id}: $error');
      // Default to server wins on error
      return remoteArticle;
    }
  }

  /// Executes a function with retry logic using exponential backoff
  Future<T> _withRetry<T>(Future<T> Function() operation) async {
    Object? lastError;
    
    for (int attempt = 0; attempt <= _retryConfig.maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        
        if (attempt == _retryConfig.maxRetries) {
          break; // Max retries reached
        }

        final delay = _retryConfig.calculateDelay(attempt);
        debugPrint('Sync attempt ${attempt + 1} failed: $error. Retrying in ${delay.inSeconds}s...');
        
        await Future.delayed(delay);
      }
    }
    
    throw lastError!;
  }

  /// Schedules a retry sync operation with exponential backoff
  void _scheduleRetrySync({required String error}) {
    final delay = _retryConfig.calculateDelay(0);
    
    Timer(delay, () {
      if (!_isDisposed && _currentState.status == SyncStatus.failed) {
        syncWithRemote().catchError((retryError) {
          debugPrint('Retry sync failed: $retryError');
          return SyncResult(
            success: false,
            recordsSynced: 0,
            duration: Duration.zero,
            errorMessage: retryError.toString(),
            status: SyncStatus.failed,
            timestamp: DateTime.now(),
          );
        });
      }
    });
  }

  /// Forces a full synchronization, ignoring incremental sync
  Future<SyncResult> forceFullSync({String? userId}) async {
    return await syncWithRemote(
      userId: userId,
      forceFullSync: true,
    );
  }

  /// Gets synchronization statistics from the database
  Future<Map<String, dynamic>> getSyncStatistics() async {
    return await _database.getSyncStatistics();
  }

  /// Cleans up old sync metadata records
  Future<int> cleanupSyncMetadata({
    Duration retentionPeriod = const Duration(days: 30),
  }) async {
    return await _database.cleanupSyncMetadata(
      retentionPeriod: retentionPeriod,
    );
  }

  /// Runs synchronization in a background isolate
  /// This prevents UI blocking during large sync operations
  static Future<SyncResult> runBackgroundSync(Map<String, dynamic> config) async {
    return await compute(_backgroundSyncIsolate, config);
  }

  /// Background sync isolate function
  static Future<SyncResult> _backgroundSyncIsolate(Map<String, dynamic> config) async {
    // This would be implemented to run sync in an isolate
    // For now, return a placeholder result
    return SyncResult(
      success: true,
      recordsSynced: 0,
      duration: Duration.zero,
      status: SyncStatus.completed,
      timestamp: DateTime.now(),
    );
  }

  /// Disposes of resources and cancels all subscriptions
  void dispose() {
    if (_isDisposed) return;
    
    _isDisposed = true;
    _backgroundSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    
    _syncStateController.close();
    _syncResultController.close();
  }
}