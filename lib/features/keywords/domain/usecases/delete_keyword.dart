import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../repositories/keyword_repository.dart';

class DeleteKeyword implements UseCase<void, String> {
  final KeywordRepository repository;

  DeleteKeyword(this.repository);

  @override
  Future<Either<Failure, void>> call(String keywordId) async {
    return await repository.deleteKeyword(keywordId);
  }
}