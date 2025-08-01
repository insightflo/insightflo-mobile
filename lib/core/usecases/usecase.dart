import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Base use case interface for all use cases in the application
abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

/// For use cases that don't require parameters
class NoParams {
  const NoParams();
}

/// Generic parameters class for use cases
class Params<T> {
  final T data;
  
  const Params({required this.data});
}

/// Pagination parameters
class PaginationParams {
  final int page;
  final int limit;
  final String? searchQuery;

  const PaginationParams({
    required this.page,
    required this.limit,
    this.searchQuery,
  });
}