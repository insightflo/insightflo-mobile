// Basic Flutter widget test for InsightFlo app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:insightflo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:insightflo_app/features/news/presentation/providers/news_provider.dart';

// Generate mocks for providers
@GenerateMocks([
  AuthProvider,
  NewsProvider,
])
import 'widget_test.mocks.dart';

void main() {
  group('Widget Tests', () {
    late MockAuthProvider mockAuthProvider;
    late MockNewsProvider mockNewsProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
      mockNewsProvider = MockNewsProvider();

      // Setup default mock behaviors
      when(mockAuthProvider.isAuthenticated).thenReturn(false);
      when(mockAuthProvider.currentUser).thenReturn(null);
      when(mockAuthProvider.isLoading).thenReturn(false);
      when(mockAuthProvider.errorMessage).thenReturn(null);

      when(mockNewsProvider.isLoading).thenReturn(false);
      when(mockNewsProvider.articles).thenReturn([]);
      when(mockNewsProvider.error).thenReturn(null);
    });

    testWidgets('Simple widget test with providers', (WidgetTester tester) async {
      // Build a simple widget with mocked providers
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<NewsProvider>.value(value: mockNewsProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('InsightFlo')),
              body: const Center(child: Text('Test App')),
            ),
          ),
        ),
      );

      // Should show basic app content
      expect(find.text('InsightFlo'), findsOneWidget);
      expect(find.text('Test App'), findsOneWidget);
    });

    testWidgets('AuthProvider state is accessible', (WidgetTester tester) async {
      // Setup authenticated state
      when(mockAuthProvider.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
            ChangeNotifierProvider<NewsProvider>.value(value: mockNewsProvider),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final authProvider = Provider.of<AuthProvider>(context);
                return Scaffold(
                  body: Text(authProvider.isAuthenticated ? 'Authenticated' : 'Not Authenticated'),
                );
              },
            ),
          ),
        ),
      );

      // Verify that the auth state is accessible
      expect(find.text('Authenticated'), findsOneWidget);
    });

    group('Provider Error Handling', () {
      testWidgets('AuthProvider error messages are accessible', 
          (WidgetTester tester) async {
        // Setup error state
        when(mockAuthProvider.errorMessage).thenReturn('Authentication failed');

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
              ChangeNotifierProvider<NewsProvider>.value(value: mockNewsProvider),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  final authProvider = Provider.of<AuthProvider>(context);
                  return Scaffold(
                    body: Text(authProvider.errorMessage ?? 'No error'),
                  );
                },
              ),
            ),
          ),
        );

        // Should display the error message
        expect(find.text('Authentication failed'), findsOneWidget);
      });

      testWidgets('NewsProvider error messages are accessible', 
          (WidgetTester tester) async {
        // Setup error state
        when(mockNewsProvider.error).thenReturn('Failed to load news');

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
              ChangeNotifierProvider<NewsProvider>.value(value: mockNewsProvider),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  final newsProvider = Provider.of<NewsProvider>(context);
                  return Scaffold(
                    body: Text(newsProvider.error ?? 'No error'),
                  );
                },
              ),
            ),
          ),
        );

        // Should display the error message
        expect(find.text('Failed to load news'), findsOneWidget);
      });
    });
  });
}