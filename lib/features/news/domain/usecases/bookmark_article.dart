import 'package:dartz/dartz.dart';
import 'package:insightflo_app/core/errors/failures.dart';
import 'package:insightflo_app/core/usecases/usecase.dart';
import '../repositories/news_repository.dart';

/// Use case for bookmarking news articles
class BookmarkArticle implements UseCase<void, BookmarkArticleParams> {
  final NewsRepository repository;

  BookmarkArticle(this.repository);

  @override
  Future<Either<Failure, void>> call(BookmarkArticleParams params) async {
    return await repository.bookmarkArticle(
      userId: params.userId,
      articleId: params.articleId,
    );
  }
}

class BookmarkArticleParams {
  final String userId;
  final String articleId;

  const BookmarkArticleParams({
    required this.userId,
    required this.articleId,
  });
}