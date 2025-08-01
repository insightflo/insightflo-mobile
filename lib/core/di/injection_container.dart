import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
// Removed Supabase import - using API-First architecture

// Core
import '../database/database.dart';
import '../utils/network_info.dart';
import '../services/deep_link_service.dart';
import '../services/auth_flow_manager.dart';
import '../services/api_auth_service.dart';
import '../monitoring/performance_monitor.dart';
// import '../cache/cache_service.dart'; // CacheService는 database.dart에서 이미 export됨

// Features - News
import '../../features/news/data/datasources/news_remote_data_source.dart';
import '../../features/news/data/datasources/news_local_data_source.dart';
import '../../features/news/data/repositories/news_repository_impl.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../../features/news/domain/usecases/get_personalized_news.dart';
import '../../features/news/domain/usecases/search_news.dart';
import '../../features/news/domain/usecases/bookmark_article.dart';
import '../../features/news/presentation/providers/news_provider.dart';

// Features - Auth
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/usecases.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Service locator instance
final sl = GetIt.instance;

/// Initialize all dependencies
Future<void> init() async {
  //! Features - Auth
  await _initAuth();

  //! Features - News
  await _initNews();

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
