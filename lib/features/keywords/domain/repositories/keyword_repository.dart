import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import '../entities/keyword_entity.dart';

abstract class KeywordRepository {
  Future<Either<Failure, List<KeywordEntity>>> getKeywords(String userId);
  Future<Either<Failure, KeywordEntity>> createKeyword(KeywordEntity keyword);
  Future<Either<Failure, KeywordEntity>> updateKeyword(KeywordEntity keyword);
  Future<Either<Failure, void>> deleteKeyword(String keywordId);
  Future<Either<Failure, List<String>>> searchKeywordSuggestions(String query);
}