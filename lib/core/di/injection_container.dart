import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
// Removed Supabase import - using API-First architecture

// Core
import 'package:insightflo_app/core/database/database.dart';
import 'package:insightflo_app/core/utils/network_info.dart';
import 'package:insightflo_app/core/services/deep_link_service.dart';
import 'package:insightflo_app/core/services/auth_flow_manager.dart';
import 'package:insightflo_app/core/services/api_auth_service.dart';
import 'package:insightflo_app/core/monitoring/performance_monitor.dart';
// import 'package:insightflo_app/core/cache/cache_service.dart'; // CacheService는 database.dart에서 이미 export됨

// Features - News
import 'package:insightflo_app/features/news/data/datasources/news_remote_data_source.dart';
import 'package:insightflo_app/features/news/data/datasources/news_local_data_source.dart';
import 'package:insightflo_app/features/news/data/repositories/news_repository_impl.dart';
import 'package:insightflo_app/features/news/domain/repositories/news_repository.dart';
import 'package:insightflo_app/features/news/domain/usecases/get_personalized_news.dart';
import 'package:insightflo_app/features/news/domain/usecases/search_news.dart';
import 'package:insightflo_app/features/news/domain/usecases/bookmark_article.dart';
import 'package:insightflo_app/features/news/presentation/providers/news_provider.dart';

// Features - Auth
import 'package:insightflo_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:insightflo_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:insightflo_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:insightflo_app/features/auth/domain/usecases/usecases.dart';
import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';

// Features - Keywords
import 'package:insightflo_app/features/keywords/data/datasources/keyword_local_data_source.dart';
import 'package:insightflo_app/features/keywords/data/repositories/keyword_repository_impl.dart';
import 'package:insightflo_app/features/keywords/domain/repositories/keyword_repository.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/get_keywords.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/create_keyword.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/update_keyword.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/delete_keyword.dart';
import 'package:insightflo_app/features/keywords/domain/usecases/search_keyword_suggestions.dart';
import 'package:insightflo_app/features/keywords/presentation/providers/keyword_provider.dart';

/// Service locator instance
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> init() async {
  //! Features - Auth
  await _initAuth();

  //! Features - News
  await _initNews();

  //! Features - Keywords
  await _initKeywords();

  //! Core
  await _initCore();

  //! External
  await _initExternal();
}

/// Initialize Auth feature dependencies
Future<void> _initAuth() async {
  // Providers
  sl.registerFactory(
    () => AuthProvider(
      signInUseCase: sl(),
      signUpUseCase: sl(),
      signOutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      resetPasswordUseCase: sl(),
      signInWithGoogleUseCase: sl(),
      signInWithAppleUseCase: sl(),
      verifyEmailUseCase: sl(),
      // sendEmailVerificationUseCase는 구현되지 않았으므로 제거
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => SignInUseCase(sl()));
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => SignOutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => SignInWithGoogleUseCase(sl()));
  sl.registerLazySingleton(() => SignInWithAppleUseCase(sl()));
  sl.registerLazySingleton(() => VerifyEmailUseCase(sl()));

  // Repository - Updated to API-First architecture
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), secureStorage: sl()),
  );

  // Data sources - Updated to API-First architecture
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );
}

/// Initialize News feature dependencies
Future<void> _initNews() async {
  // Providers
  sl.registerFactory(
    () => NewsProvider(
      getPersonalizedNews: sl(),
      searchNews: sl(),
      bookmarkArticle: sl(),
      localDataSource: sl(),
      authProvider: sl(),
      keywordProvider: sl(),
      authService: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetPersonalizedNews(sl()));
  sl.registerLazySingleton(() => SearchNews(sl()));
  sl.registerLazySingleton(() => BookmarkArticle(sl()));

  // Repository - Updated to include cache service
  sl.registerLazySingleton<NewsRepository>(
    () => NewsRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
      networkInfo: sl(),
      cacheService: sl(),
    ),
  );

  // Data sources - Updated to API-First architecture
  sl.registerLazySingleton<NewsRemoteDataSource>(
    () => NewsRemoteDataSourceImpl(),
  );

  sl.registerLazySingleton<NewsLocalDataSource>(
    () => NewsLocalDataSourceImpl(database: sl()),
  );
}

/// Initialize Keywords feature dependencies
Future<void> _initKeywords() async {
  // Providers
  sl.registerFactory(
    () => KeywordProvider(
      getKeywords: sl(),
      createKeyword: sl(),
      updateKeyword: sl(),
      deleteKeyword: sl(),
      searchKeywordSuggestions: sl(),
      authProvider: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetKeywords(sl()));
  sl.registerLazySingleton(() => CreateKeyword(sl()));
  sl.registerLazySingleton(() => UpdateKeyword(sl()));
  sl.registerLazySingleton(() => DeleteKeyword(sl()));
  sl.registerLazySingleton(() => SearchKeywordSuggestions(sl()));

  // Repository
  sl.registerLazySingleton<KeywordRepository>(
    () => KeywordRepositoryImpl(
      localDataSource: sl(),
    ),
  );

  // Data sources
  sl.registerLazySingleton<KeywordLocalDataSource>(
    () => KeywordLocalDataSourceImpl(
      database: sl(),
    ),
  );
}

/// Initialize Core dependencies
Future<void> _initCore() async {
  // Task 8.11: Performance monitoring (singleton instance)
  sl.registerLazySingleton<MetricCollector>(() => MetricCollector.instance);

  // Database
  sl.registerLazySingleton<AppDatabase>(() => AppDatabase());

  // Cache service - API-First architecture caching system
  sl.registerLazySingleton<CacheService>(
    () => CacheServiceFactory.create(
      database: sl(),
      userId: 'default_user', // TODO: 실제 사용자 ID 사용
      connectivity: sl(),
      metricsCollector: sl(),
    ),
  );

  // Network info
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  // Deep link service
  sl.registerLazySingleton<DeepLinkService>(() => DeepLinkService());

  // HTTP Client
  sl.registerLazySingleton<http.Client>(() => http.Client());

  // API Auth service
  sl.registerLazySingleton<ApiAuthService>(() => ApiAuthService(
    httpClient: sl(),
  ));

  // Auth flow manager (will be initialized after AuthProvider)
  sl.registerLazySingleton<AuthFlowManager>(
    () => AuthFlowManager(
      authProvider: sl(),
      deepLinkService: sl(),
    ),
  );
}

/// Initialize External dependencies
Future<void> _initExternal() async {
  // Removed Supabase client registration - using API-First architecture

  // Secure storage
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );

  // Connectivity
  sl.registerLazySingleton(() => Connectivity());
}

/// Clean up dependencies (useful for testing or app restart)
Future<void> reset() async {
  await sl.reset();
}
