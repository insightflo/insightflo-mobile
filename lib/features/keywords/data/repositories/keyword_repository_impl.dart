import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/exceptions.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/features/keywords/domain/entities/keyword_entity.dart';
import 'package:insightflo_app/features/keywords/domain/repositories/keyword_repository.dart';
import 'package:insightflo_app/features/keywords/data/datasources/keyword_local_data_source.dart';
import 'package:insightflo_app/features/keywords/data/models/keyword_model.dart';

class KeywordRepositoryImpl implements KeywordRepository {
  final KeywordLocalDataSource localDataSource;

  KeywordRepositoryImpl({
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, List<KeywordEntity>>> getKeywords(
    String userId,
  ) async {
    try {
      final keywords = await localDataSource.getKeywords(userId);
      return Right(keywords);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, KeywordEntity>> createKeyword(
    KeywordEntity keyword,
  ) async {
    try {
      final keywordModel = KeywordModel.fromEntity(keyword);
      final createdKeyword = await localDataSource.createKeyword(keywordModel);
      return Right(createdKeyword);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, KeywordEntity>> updateKeyword(
    KeywordEntity keyword,
  ) async {
    try {
      final keywordModel = KeywordModel.fromEntity(keyword);
      final updatedKeyword = await localDataSource.updateKeyword(keywordModel);
      return Right(updatedKeyword);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteKeyword(String keywordId) async {
    try {
      // Note: We need userId for local deletion, but the interface doesn't provide it
      // For now, we'll assume we can get it from context or modify the interface later
      await localDataSource.deleteKeyword(keywordId, 'local_user');
      return const Right(null);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error occurred'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> searchKeywordSuggestions(
    String query,
  ) async {
    try {
      final suggestions = await localDataSource.searchKeywordSuggestions(
        'local_user',
        query,
      );
      return Right(suggestions);
    } on CacheException catch (e) {
      return Left(CacheFailure(message: e.message));
    } catch (e) {
      return Left(CacheFailure(message: 'Unexpected error occurred'));
    }
  }
}
