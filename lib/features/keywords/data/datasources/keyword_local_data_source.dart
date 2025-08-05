import 'package:drift/drift.dart';
import 'package:insightflo_app/core/database/app_database.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/features/keywords/data/models/keyword_model.dart';
import 'package:insightflo_app/core/utils/logger.dart';

abstract class KeywordLocalDataSource {
  Future<List<KeywordModel>> getKeywords(String userId);
  Future<KeywordModel> createKeyword(KeywordModel keyword);
  Future<KeywordModel> updateKeyword(KeywordModel keyword);
  Future<void> deleteKeyword(String keywordId, String userId);
  Future<List<String>> searchKeywordSuggestions(String userId, String query);
}

class KeywordLocalDataSourceImpl implements KeywordLocalDataSource {
  final AppDatabase database;

  KeywordLocalDataSourceImpl({required this.database});

  @override
  Future<List<KeywordModel>> getKeywords(String userId) async {
    try {
      AppLogger.info('KeywordLocalDataSource: Getting keywords for user: $userId');
      
      // Use generated Drift code
      final results = await (database.select(database.keywordsTable)
            ..where((tbl) => tbl.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.weight)])
            ..limit(50))
          .get();
      
      final keywords = results.map((row) {
        return KeywordModel(
          id: row.id,
          userId: row.userId,
          keyword: row.keyword,
          weight: row.weight,
          category: row.category,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        );
      }).toList();
      
      AppLogger.info('KeywordLocalDataSource: Found ${keywords.length} keywords');
      return keywords;
    } on Exception catch (e) {
      AppLogger.error('KeywordLocalDataSource: Failed to get keywords', e.toString());
      throw CacheException(message: 'Failed to get keywords from local storage: ${e.toString()}');
    }
  }

  @override
  Future<KeywordModel> createKeyword(KeywordModel keyword) async {
    try {
      AppLogger.info('KeywordLocalDataSource: Creating keyword: ${keyword.keyword}');
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Use generated Drift code
      final companion = KeywordsTableCompanion.insert(
        id: keyword.id,
        userId: keyword.userId,
        keyword: keyword.keyword,
        weight: Value(keyword.weight),
        category: keyword.category != null ? Value(keyword.category) : const Value.absent(),
        createdAt: now,
        updatedAt: Value(now),
      );
      
      await database.into(database.keywordsTable).insert(companion);
      
      final result = KeywordModel(
        id: keyword.id,
        userId: keyword.userId,
        keyword: keyword.keyword,
        weight: keyword.weight,
        category: keyword.category,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
      
      AppLogger.info('KeywordLocalDataSource: Successfully created keyword: ${result.keyword}');
      return result;
    } on Exception catch (e) {
      AppLogger.error('KeywordLocalDataSource: Failed to create keyword', e.toString());
      throw CacheException(message: 'Failed to create keyword in local storage: ${e.toString()}');
    }
  }

  @override
  Future<KeywordModel> updateKeyword(KeywordModel keyword) async {
    try {
      AppLogger.info('KeywordLocalDataSource: Updating keyword: ${keyword.id}');
      
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Use generated Drift code
      final companion = KeywordsTableCompanion(
        keyword: Value(keyword.keyword),
        weight: Value(keyword.weight),
        category: keyword.category != null ? Value(keyword.category) : const Value.absent(),
        updatedAt: Value(now),
      );
      
      final result = await (database.update(database.keywordsTable)
            ..where((tbl) => tbl.id.equals(keyword.id) & tbl.userId.equals(keyword.userId)))
          .write(companion);
      
      if (result == 0) {
        throw CacheException(message: 'Keyword not found or update failed');
      }
      
      AppLogger.info('KeywordLocalDataSource: Successfully updated keyword: ${keyword.keyword}');
      return keyword;
    } on Exception catch (e) {
      AppLogger.error('KeywordLocalDataSource: Failed to update keyword', e.toString());
      throw CacheException(message: 'Failed to update keyword in local storage: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteKeyword(String keywordId, String userId) async {
    try {
      AppLogger.info('KeywordLocalDataSource: Deleting keyword: $keywordId');
      
      // Use generated Drift code
      final result = await (database.delete(database.keywordsTable)
            ..where((tbl) => tbl.id.equals(keywordId) & tbl.userId.equals(userId)))
          .go();
      
      if (result == 0) {
        throw CacheException(message: 'Keyword not found or delete failed');
      }
      
      AppLogger.info('KeywordLocalDataSource: Successfully deleted keyword: $keywordId');
    } on Exception catch (e) {
      AppLogger.error('KeywordLocalDataSource: Failed to delete keyword', e.toString());
      throw CacheException(message: 'Failed to delete keyword from local storage: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> searchKeywordSuggestions(String userId, String query) async {
    try {
      AppLogger.info('KeywordLocalDataSource: Searching keyword suggestions for: $query');
      
      final searchPattern = '%$query%';
      
      // Use generated Drift code
      final results = await (database.select(database.keywordsTable)
            ..where((tbl) => tbl.userId.equals(userId) & tbl.keyword.like(searchPattern))
            ..orderBy([(t) => OrderingTerm.desc(t.weight)])
            ..limit(10))
          .get();
      
      final suggestions = results.map((row) => row.keyword).toList();
      
      AppLogger.info('KeywordLocalDataSource: Found ${suggestions.length} keyword suggestions');
      return suggestions;
    } on Exception catch (e) {
      AppLogger.error('KeywordLocalDataSource: Failed to search keyword suggestions', e.toString());
      throw CacheException(message: 'Failed to search keyword suggestions in local storage: ${e.toString()}');
    }
  }
}