import 'package:flutter/material.dart';

/// Resource state wrapper for handling loading, success, and error states
@immutable
abstract class Resource<T> {
  const Resource();
}

/// Loading state
class Loading<T> extends Resource<T> {
  const Loading();
}

/// Success state with data
class Success<T> extends Resource<T> {
  final T data;
  
  const Success(this.data);
}

/// Error state with message
class Error<T> extends Resource<T> {
  final String message;
  final int? statusCode;
  
  const Error(this.message, {this.statusCode});
}

/// Empty state (no data)
class Empty<T> extends Resource<T> {
  const Empty();
}

/// Extension methods for Resource handling
extension ResourceExtension<T> on Resource<T> {
  /// Check if resource is loading
  bool get isLoading => this is Loading<T>;
  
  /// Check if resource has data
  bool get hasData => this is Success<T>;
  
  /// Check if resource has error
  bool get hasError => this is Error<T>;
  
  /// Check if resource is empty
  bool get isEmpty => this is Empty<T>;
  
  /// Get data if available
  T? get data => this is Success<T> ? (this as Success<T>).data : null;
  
  /// Get error message if available
  String? get error => this is Error<T> ? (this as Error<T>).message : null;
  
  /// Transform the data if successful
  Resource<R> map<R>(R Function(T) transform) {
    if (this is Success<T>) {
      try {
        return Success(transform((this as Success<T>).data));
      } catch (e) {
        return Error('Transformation failed: $e');
      }
    } else if (this is Error<T>) {
      return Error((this as Error<T>).message, statusCode: (this as Error<T>).statusCode);
    } else if (this is Loading<T>) {
      return const Loading();
    } else {
      return const Empty();
    }
  }
  
  /// Handle resource states with callbacks
  R when<R>({
    required R Function() loading,
    required R Function(T data) success,
    required R Function(String message) error,
    required R Function() empty,
  }) {
    if (this is Loading<T>) {
      return loading();
    } else if (this is Success<T>) {
      return success((this as Success<T>).data);
    } else if (this is Error<T>) {
      return error((this as Error<T>).message);
    } else {
      return empty();
    }
  }
}

/// Resource builder widget for handling different states
class ResourceBuilder<T> extends StatelessWidget {
  final Resource<T> resource;
  final Widget Function(BuildContext context, T data) onSuccess;
  final Widget Function(BuildContext context)? onLoading;
  final Widget Function(BuildContext context, String error)? onError;
  final Widget Function(BuildContext context)? onEmpty;

  const ResourceBuilder({
    super.key,
    required this.resource,
    required this.onSuccess,
    this.onLoading,
    this.onError,
    this.onEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return resource.when(
      loading: () => onLoading?.call(context) ?? _defaultLoading(context),
      success: (data) => onSuccess(context, data),
      error: (message) => onError?.call(context, message) ?? _defaultError(context, message),
      empty: () => onEmpty?.call(context) ?? _defaultEmpty(context),
    );
  }

  Widget _defaultLoading(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _defaultError(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No data available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for updates',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}