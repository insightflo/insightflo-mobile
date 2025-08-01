import 'package:drift/drift.dart';

/// Sync metadata table for tracking synchronization state between local and remote data
/// Manages synchronization history, status, and metadata for offline-first architecture
@DataClassName('SyncMetadataData')
class SyncMetadataTable extends Table {
  /// Unique identifier for the sync metadata record
  /// Format: 'tableName_syncDirection' (e.g., 'news_articles_download')
  TextColumn get id => text().withLength(min: 1, max: 100)();

  /// Name of the table being synchronized
  /// References the actual database table name (e.g., 'news_articles')
  TextColumn get syncTableName => text().withLength(min: 1, max: 50)();

  @override
  String get tableName => 'sync_metadata';

  /// Timestamp of the last successful synchronization
  /// Stored as milliseconds since epoch for precise tracking
  IntColumn get lastSyncTime => integer()();

  /// Current synchronization status
  /// Values: 'pending', 'syncing', 'completed', 'failed'
  TextColumn get syncStatus => text().withLength(min: 1, max: 20)();

  /// Number of records synchronized in the last operation
  /// Used for progress tracking and statistics
  IntColumn get recordCount => integer()();

  /// Direction of synchronization
  /// Values: 'upload', 'download', 'bidirectional'
  TextColumn get syncDirection => text().withLength(min: 1, max: 20)();

  /// Timestamp when this sync metadata record was created
  IntColumn get createdAt => integer()();

  /// Timestamp when this sync metadata record was last updated
  IntColumn get updatedAt => integer()();

  /// Error message if synchronization failed (nullable)
  TextColumn get errorMessage => text().nullable()();

  /// Additional synchronization metadata as JSON string (nullable)
  /// Can store custom sync parameters, filters, or configuration
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Ensure syncStatus has valid values
    "CHECK (sync_status IN ('pending', 'syncing', 'completed', 'failed'))",
    // Ensure syncDirection has valid values  
    "CHECK (sync_direction IN ('upload', 'download', 'bidirectional'))",
    // Ensure timestamps are positive
    'CHECK (last_sync_time >= 0)',
    'CHECK (created_at >= 0)',
    'CHECK (updated_at >= 0)',
    // Ensure record count is non-negative
    'CHECK (record_count >= 0)',
  ];
}

/// Index creation constants for sync metadata table performance optimization
class SyncMetadataTableIndexes {
  /// Index for fast lookups by table name
  static const String tableNameIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_metadata_table_name 
    ON sync_metadata (sync_table_name)
  ''';

  /// Index for fast lookups by sync status
  static const String syncStatusIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_metadata_sync_status 
    ON sync_metadata (sync_status)
  ''';

  /// Index for fast lookups by last sync time (for finding stale data)
  static const String lastSyncTimeIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_metadata_last_sync_time 
    ON sync_metadata (last_sync_time)
  ''';

  /// Compound index for table name and sync direction queries
  static const String tableNameDirectionIndex = '''
    CREATE INDEX IF NOT EXISTS idx_sync_metadata_table_name_direction 
    ON sync_metadata (sync_table_name, sync_direction)
  ''';
}