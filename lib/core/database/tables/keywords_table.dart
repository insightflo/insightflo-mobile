import 'package:drift/drift.dart';

/// Keywords table for local keyword management in guest mode
/// Uses local_user as the default user_id for guest mode
@DataClassName('KeywordsTableData')
class KeywordsTable extends Table {
  /// Primary key for the keyword
  TextColumn get id => text()();

  /// User ID - uses 'local_user' for guest mode
  TextColumn get userId => text().named('user_id')();

  /// The keyword text
  TextColumn get keyword => text()();

  /// Weight/priority of the keyword (0.0 to 1.0)
  RealColumn get weight => real().withDefault(const Constant(1.0))();

  /// Optional category for the keyword
  TextColumn get category => text().nullable()();

  /// When the keyword was created
  IntColumn get createdAt => integer().named('created_at')();

  /// When the keyword was last updated
  IntColumn get updatedAt => integer().named('updated_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // Ensure user can't have duplicate keywords
    'UNIQUE(user_id, keyword)',
    // Weight should be between 0.0 and 1.0
    'CHECK (weight >= 0.0 AND weight <= 1.0)',
  ];
}

/// Indexes for optimized keyword queries
class KeywordsTableIndexes {
  /// Index for user-based queries
  static const String userIdIndex = '''
    CREATE INDEX IF NOT EXISTS idx_keywords_user_id 
    ON keywords_table (user_id)
  ''';

  /// Index for keyword search
  static const String keywordIndex = '''
    CREATE INDEX IF NOT EXISTS idx_keywords_keyword 
    ON keywords_table (keyword)
  ''';

  /// Compound index for user + keyword queries
  static const String userKeywordIndex = '''
    CREATE INDEX IF NOT EXISTS idx_keywords_user_keyword 
    ON keywords_table (user_id, keyword)
  ''';

  /// Index for weight-based sorting
  static const String weightIndex = '''
    CREATE INDEX IF NOT EXISTS idx_keywords_weight 
    ON keywords_table (user_id, weight DESC)
  ''';
}