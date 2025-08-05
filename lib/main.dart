import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Removed Supabase config import - using API-First architecture
import 'core/di/injection_container.dart' as di;
import 'core/services/auth_flow_manager.dart';
import 'core/monitoring/performance_monitor.dart';
import 'features/news/presentation/providers/news_provider.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/news/presentation/providers/theme_provider.dart';
import 'features/keywords/presentation/providers/keyword_provider.dart';
import 'core/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Task 8.11: Initialize performance monitoring first
    final metricsCollector = MetricCollector.instance;
    await metricsCollector.initialize();
    metricsCollector.startCollection();
    
    // Removed Supabase initialization - using API-First architecture
    
    // Initialize dependency injection
    await di.init();
    
    // Initialize authentication flow manager
    final authFlowManager = di.sl<AuthFlowManager>();
    await authFlowManager.initialize();
    
    runApp(const InsightFloApp());
  } catch (e) {
    // Handle initialization errors
    runApp(ErrorApp(error: e.toString()));
  }
}

class InsightFloApp extends StatefulWidget {
  const InsightFloApp({super.key});

  @override
  State<InsightFloApp> createState() => _InsightFloAppState();
}

class _InsightFloAppState extends State<InsightFloApp> {
  @override
  void initState() {
    super.initState();
    
    // 키워드 변경 콜백 설정 - 한 번만 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keywordProvider = di.sl<KeywordProvider>();
      final newsProvider = di.sl<NewsProvider>();
      keywordProvider.setOnKeywordChangedCallback(
        (userId) => newsProvider.refreshNewsOnKeywordChange(userId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => di.sl<AuthProvider>(),
        ),
        ChangeNotifierProvider<NewsProvider>(
          create: (_) => di.sl<NewsProvider>(),
        ),
        ChangeNotifierProvider<KeywordProvider>(
          create: (_) => di.sl<KeywordProvider>(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..initialize(),
        ),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, _) {
          // AppRouter 인스턴스 생성 (AuthProvider와 함께)
          final appRouter = AppRouter(authProvider);
          
          return MaterialApp.router(
            title: 'InsightFlo',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getLightTheme(context),
            darkTheme: themeProvider.getDarkTheme(context),
            themeMode: themeProvider.themeMode,
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }

}

// Error app widget for initialization failures
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InsightFlo - Error',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Initialization Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to initialize InsightFlo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Could implement restart logic here
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
