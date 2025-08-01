// State management
export 'auth_state.dart';
export 'auth_provider.dart';

/// Exports for authentication presentation layer providers
/// 
/// This file provides a convenient way to import all authentication providers
/// and related presentation layer components in a single import statement.

/// Authentication Providers Overview
/// 
/// This module provides the following providers for authentication state management:
/// 
/// 1. [AuthState] - Enumeration of possible authentication states
///    - initial: App startup, checking authentication status
///    - loading: Authentication operations in progress
///    - authenticated: User successfully authenticated
///    - unauthenticated: User not authenticated or session expired
///    - error: Authentication error occurred
/// 
/// 2. [AuthProvider] - Main authentication state provider
///    - Implements ChangeNotifier for reactive UI updates
///    - Integrates with Clean Architecture use cases
///    - Manages authentication state transitions
///    - Provides comprehensive error handling
///    - Supports automatic login state restoration
/// 
/// Usage Example:
/// ```dart
/// // In main.dart or app.dart
/// MultiProvider(
///   providers: [
///     ChangeNotifierProvider<AuthProvider>(
///       create: (context) => sl<AuthProvider>(),
///     ),
///     // Other providers...
///   ],
///   child: MyApp(),
/// )
/// 
/// // In widgets
/// Consumer<AuthProvider>(
///   builder: (context, authProvider, child) {
///     switch (authProvider.state) {
///       case AuthState.loading:
///         return LoadingWidget();
///       case AuthState.authenticated:
///         return MainAppWidget();
///       case AuthState.unauthenticated:
///         return LoginWidget();
///       case AuthState.error:
///         return ErrorWidget(authProvider.errorMessage);
///       case AuthState.initial:
///         return SplashWidget();
///     }
///   },
/// )
/// 
/// // Selective listening with Selector
/// Selector<AuthProvider, bool>(
///   selector: (context, authProvider) => authProvider.isAuthenticated,
///   builder: (context, isAuthenticated, child) {
///     return isAuthenticated ? HomeScreen() : LoginScreen();
///   },
/// )
/// ```
/// 
/// Key Features:
/// - Reactive state management with ChangeNotifier
/// - Clean Architecture integration with use cases
/// - Comprehensive error handling and user feedback
/// - Loading state management for UI responsiveness
/// - Automatic authentication state restoration
/// - Consumer pattern support for granular UI updates
/// - Extension methods for common UI state checks
/// - Thread-safe state transitions
/// - Proper disposal of resources
/// - Type-safe authentication operations