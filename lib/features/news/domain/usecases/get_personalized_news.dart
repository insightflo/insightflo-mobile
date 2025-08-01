import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/news_article.dart';
import '../repositories/news_repository.dart';

/// Use case for getting personalized news articles
class GetPersonalizedNews implements UseCase<List<NewsArticle>, GetPersonalizedNewsParams> {
  final NewsRepository repository;

  GetPersonalizedNews(this.repository);

  @override
  Future<Either<Failure, List<NewsArticle>>> call(GetPersonalizedNewsParams params) async {
    return await repository.getPersonalizedNews(
      userId: params.userId,
      page: params.page,
      limit: params.limit,
    );
  }
}

class GetPersonalizedNewsParams {
  final String userId;
  final int page;
  final int limit;

  const GetPersonalizedNewsParams({
    required this.userId,
    this.page = 1,
    this.limit = 20,
  });
}