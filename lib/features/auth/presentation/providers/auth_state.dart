/// Enumeration representing the different authentication states of the application
/// 
/// This enum provides a clear, type-safe way to represent the current authentication
/// status and enables reactive UI updates based on authentication state changes.
enum AuthState {
  /// Initial state when the app starts and auth status hasn't been determined yet
  /// 
  /// This state is typically shown during app startup while checking if the user
  /// has a valid session or stored authentication tokens.
  initial,

  /// Loading state when authentication operations are in progress
  /// 
  /// This state is active during sign-in, sign-up, sign-out, or any other
  /// authentication operation that requires network communication or processing.
  loading,

  /// User is successfully authenticated and has a valid session
  /// 
  /// This state indicates that the user has successfully signed in and has
  /// access to authenticated features of the application.
  authenticated,

  /// User is not authenticated or session has expired
  /// 
  /// This state indicates that the user needs to sign in to access protected
  /// features. It can occur after sign-out, session expiration, or failed authentication.
  unauthenticated,

  /// An error occurred during authentication operations
  /// 
  /// This state indicates that an authentication operation failed due to
  /// network issues, invalid credentials, server errors, or other exceptions.
  /// The specific error details are typically stored separately in the provider.
  error,
}

/// Extension methods for AuthState to provide utility functions
extension AuthStateExtension on AuthState {
  /// Returns true if the current state is loading
  bool get isLoading => this == AuthState.loading;

  /// Returns true if the user is authenticated
  bool get isAuthenticated => this == AuthState.authenticated;

  /// Returns true if the user is not authenticated
  bool get isUnauthenticated => this == AuthState.unauthenticated;

  /// Returns true if there's an authentication error
  bool get hasError => this == AuthState.error;

  /// Returns true if the state is initial (not yet determined)
  bool get isInitial => this == AuthState.initial;

  /// Returns a human-readable description of the current state
  String get description {
    switch (this) {
      case AuthState.initial:
        return 'Checking authentication status...';
      case AuthState.loading:
        return 'Processing authentication...';
      case AuthState.authenticated:
        return 'User is authenticated';
      case AuthState.unauthenticated:
        return 'User is not authenticated';
      case AuthState.error:
        return 'Authentication error occurred';
    }
  }

  /// Returns true if the UI should show loading indicators
  bool get shouldShowLoading => isLoading || isInitial;

  /// Returns true if the UI should allow authentication attempts
  bool get canAuthenticate => isUnauthenticated || hasError;

  /// Returns true if the user can access protected features
  bool get hasAccess => isAuthenticated;
}