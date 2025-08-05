import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../repositories/keyword_repository.dart';

class SearchKeywordSuggestions implements UseCase<List<String>, String> {
  final KeywordRepository repository;

  SearchKeywordSuggestions(this.repository);

  @override
  Future<Either<Failure, List<String>>> call(String query) async {
    return await repository.searchKeywordSuggestions(query);
  }
}