import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../entities/keyword_entity.dart';
import '../repositories/keyword_repository.dart';

class UpdateKeyword implements UseCase<KeywordEntity, KeywordEntity> {
  final KeywordRepository repository;

  UpdateKeyword(this.repository);

  @override
  Future<Either<Failure, KeywordEntity>> call(KeywordEntity keyword) async {
    return await repository.updateKeyword(keyword);
  }
}