import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../entities/keyword_entity.dart';
import '../repositories/keyword_repository.dart';

class GetKeywords implements UseCase<List<KeywordEntity>, String> {
  final KeywordRepository repository;

  GetKeywords(this.repository);

  @override
  Future<Either<Failure, List<KeywordEntity>>> call(String userId) async {
    return await repository.getKeywords(userId);
  }
}