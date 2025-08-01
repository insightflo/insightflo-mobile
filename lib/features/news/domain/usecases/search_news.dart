import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

/// Use case for searching news articles
class SearchNews implements UseCase<List<NewsArticle>, SearchNewsParams> {
  final NewsRepository repository;

  SearchNews(this.repository);

  @override
  Future<Either<Failure, List<NewsArticle>>> call(SearchNewsParams params) async {
    return await repository.searchNews(
      query: params.query,
      page: params.page,
      limit: params.limit,
    );
  }
}

class SearchNewsParams {
  final String query;
  final int page;
  final int limit;

  const SearchNewsParams({
    required this.query,
    this.page = 1,
    this.limit = 20,
  });
}