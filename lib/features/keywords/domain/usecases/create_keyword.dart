import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../entities/keyword_entity.dart';
import '../repositories/keyword_repository.dart';

class CreateKeyword implements UseCase<KeywordEntity, KeywordEntity> {
  final KeywordRepository repository;

  CreateKeyword(this.repository);

  @override
  Future<Either<Failure, KeywordEntity>> call(KeywordEntity keyword) async {
    return await repository.createKeyword(keyword);
  }
}