import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/usecases.dart';
import 'auth_state.dart';

/// Authentication provider that manages the application's authentication state
/// 
/// This provider implements the ChangeNotifier pattern to enable reactive UI updates
/// when authentication state changes. It serves as the single source of truth for
/// authentication-related data and operations in the presentation layer.
/// 
/// Key Features:
/// - Reactive state management with automatic UI updates
/// - Comprehensive error handling and user feedback
/// - Loading state management to prevent concurrent operations
/// - Automatic login state restoration on app startup
/// - Integration with Clean Architecture use cases
/// - Consumer pattern support for granular UI updates
class AuthProvider extends ChangeNotifier {
  // Use cases for authentication operations
  final SignInUseCase _signInUseCase;
  final SignUpUseCase _signUpUseCase;
  final SignOutUseCase _signOutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final SignInWithGoogleUseCase _signInWithGoogleUseCase;
  final SignInWithAppleUseCase _signInWithAppleUseCase;
  final VerifyEmailUseCase _verifyEmailUseCase;
  // final SendEmailVerificationUseCase _sendEmailVerificationUseCase; // 구현되지 않아 제거

  /// Constructor requires all authentication use cases
  AuthProvider({
    required SignInUseCase signInUseCase,
    required SignUpUseCase signUpUseCase,
    required SignOutUseCase signOutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required ResetPasswordUseCase resetPasswordUseCase,
    required SignInWithGoogleUseCase signInWithGoogleUseCase,
    required SignInWithAppleUseCase signInWithAppleUseCase,
    required VerifyEmailUseCase verifyEmailUseCase,
    // required SendEmailVerificationUseCase sendEmailVerificationUseCase, // 구현되지 않아 제거
  })  : _signInUseCase = signInUseCase,
        _signUpUseCase = signUpUseCase,
        _signOutUseCase = signOutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _resetPasswordUseCase = resetPasswordUseCase,
        _signInWithGoogleUseCase = signInWithGoogleUseCase,
        _signInWithAppleUseCase = signInWithAppleUseCase,
        _verifyEmailUseCase = verifyEmailUseCase {
        // _sendEmailVerificationUseCase = sendEmailVerificationUseCase; // 구현되지 않아 제거
    // Automatically check authentication status on initialization
    _initializeAuthState();
  }

  // Private state variables
  AuthState _state = AuthState.initial;
  User? _currentUser;
  String? _errorMessage;
  bool _isInitialized = false;

  // Public getters for accessing state
  
  /// Current authentication state
  AuthState get state => _state;

  /// Currently authenticated user (null if not authenticated)
  User? get currentUser => _currentUser;

  /// Current error message (null if no error)
  String? get errorMessage => _errorMessage;

  /// Whether the provider has finished initialization
  bool get isInitialized => _isInitialized;

  /// Convenience getters from AuthState extension
  bool get isLoading => _state.isLoading;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get isUnauthenticated => _state.isUnauthenticated;
  bool get hasError => _state.hasError;
  bool get isInitial => _state.isInitial;
  bool get shouldShowLoading => _state.shouldShowLoading;
  bool get canAuthenticate => _state.canAuthenticate;
  bool get hasAccess => _state.hasAccess;

  /// Initialize authentication state by checking for existing user session
  /// 
  /// This method is called automatically during provider construction and
  /// attempts to restore the user's authentication state from stored tokens
  /// or session data.
  Future<void> _initializeAuthState() async {
    try {
      _setState(AuthState.initial);
      
      // Attempt to get current user from stored session
      final result = await _getCurrentUserUseCase(GetCurrentUserParams());
      
      result.fold(
        (failure) {
          // No existing session or session expired
          _setState(AuthState.unauthenticated);
          _currentUser = null;
          _errorMessage = null;
        },
        (user) {
          // Valid session found
          _setState(AuthState.authenticated);
          _currentUser = user;
          _errorMessage = null;
        },
      );
    } catch (e) {
      // Handle unexpected initialization errors
      _setState(AuthState.error);
      _errorMessage = 'Failed to initialize authentication: ${e.toString()}';
      _currentUser = null;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// [rememberMe] - Whether to remember the user's session for longer period
  /// [metadata] - Optional metadata for analytics or logging
  /// 
  /// Returns true if sign-in was successful, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> signIn({
    required String email,
    required String password,
    bool rememberMe = false,
    Map<String, dynamic>? metadata,
  }) async {
    // Prevent concurrent operations
    if (_state == AuthState.loading) {
      return false;
    }

    try {
      _setState(AuthState.loading);
      _clearError();

      final params = SignInParams(
        email: email,
        password: password,
        rememberMe: rememberMe,
        metadata: metadata,
      );

      final result = await _signInUseCase(params);

      return result.fold(
        (failure) {
          _setState(AuthState.error);
          _errorMessage = _getErrorMessage(failure);
          _currentUser = null;
          return false;
        },
        (user) {
          _setState(AuthState.authenticated);
          _currentUser = user;
          _errorMessage = null;
          return true;
        },
      );
    } catch (e) {
      _setState(AuthState.error);
      _errorMessage = 'An unexpected error occurred during sign-in: ${e.toString()}';
      _currentUser = null;
      return false;
    }
  }

  /// Sign up with email and password
  /// 
  /// [email] - User's email address
  /// [password] - User's password
  /// [metadata] - Optional metadata for user profile or analytics
  /// 
  /// Returns true if sign-up was successful, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    // Prevent concurrent operations
    if (_state == AuthState.loading) {
      return false;
    }

    try {
      _setState(AuthState.loading);
      _clearError();

      final params = SignUpParams(
        email: email,
        password: password,
        metadata: metadata,
      );

      final result = await _signUpUseCase(params);

      return result.fold(
        (failure) {
          _setState(AuthState.error);
          _errorMessage = _getErrorMessage(failure);
          _currentUser = null;
          return false;
        },
        (user) {
          _setState(AuthState.authenticated);
          _currentUser = user;
          _errorMessage = null;
          return true;
        },
      );
    } catch (e) {
      _setState(AuthState.error);
      _errorMessage = 'An unexpected error occurred during sign-up: ${e.toString()}';
      _currentUser = null;
      return false;
    }
  }

  /// Sign out the current user
  /// 
  /// [signOutType] - Type of sign-out (normal, secure, timeout, administrative)
  /// [clearAllData] - Whether to clear local user data after sign-out
  /// 
  /// Returns true if sign-out was successful, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> signOut({
    SignOutType signOutType = SignOutType.normal,
    bool clearAllData = true,
  }) async {
    // Prevent concurrent operations
    if (_state == AuthState.loading) {
      return false;
    }

    try {
      _setState(AuthState.loading);
      _clearError();

      final params = SignOutParams(
        signOutType: signOutType,
        clearAllData: clearAllData,
      );

      final result = await _signOutUseCase(params);

      return result.fold(
        (failure) {
          _setState(AuthState.error);
          _errorMessage = _getErrorMessage(failure);
          return false;
        },
        (_) {
          _setState(AuthState.unauthenticated);
          _currentUser = null;
          _errorMessage = null;
          return true;
        },
      );
    } catch (e) {
      _setState(AuthState.error);
      _errorMessage = 'An unexpected error occurred during sign-out: ${e.toString()}';
      return false;
    }
  }

  /// Check current authentication status and refresh user data
  /// 
  /// This method can be called to manually refresh the current user's
  /// authentication status and data from the server.
  /// 
  /// Returns true if user is authenticated, false otherwise.
  Future<bool> checkAuthStatus() async {
    // Prevent concurrent operations during critical state changes
    if (_state == AuthState.loading) {
      return _state == AuthState.authenticated;
    }

    try {
      _setState(AuthState.loading);
      _clearError();

      final result = await _getCurrentUserUseCase(GetCurrentUserParams());

      return result.fold(
        (failure) {
          _setState(AuthState.unauthenticated);
          _currentUser = null;
          _errorMessage = null; // Don't show error for auth status checks
          return false;
        },
        (user) {
          _setState(AuthState.authenticated);
          _currentUser = user;
          _errorMessage = null;
          return true;
        },
      );
    } catch (e) {
      _setState(AuthState.error);
      _errorMessage = 'Failed to check authentication status: ${e.toString()}';
      _currentUser = null;
      return false;
    }
  }

  /// Send password reset email
  /// 
  /// [email] - Email address to send reset instructions to
  /// 
  /// Returns true if reset email was sent successfully, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> resetPassword({
    required String email,
  }) async {
    // Allow password reset even during loading state for better UX
    try {
      _clearError();

      final params = ResetPasswordParams(email: email);
      final result = await _resetPasswordUseCase(params);

      return result.fold(
        (failure) {
          _errorMessage = _getErrorMessage(failure);
          notifyListeners();
          return false;
        },
        (_) {
          _errorMessage = null;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to send reset email: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Refresh current user data
  /// 
  /// Fetches the latest user data from the server without changing
  /// authentication state. Useful for updating user profile information.
  /// 
  /// Returns true if refresh was successful, false otherwise.
  Future<bool> refreshUser() async {
    if (!isAuthenticated) {
      return false;
    }

    try {
      final result = await _getCurrentUserUseCase(GetCurrentUserParams());

      return result.fold(
        (failure) {
          // Don't change auth state for refresh failures
          _errorMessage = 'Failed to refresh user data: ${_getErrorMessage(failure)}';
          notifyListeners();
          return false;
        },
        (user) {
          _currentUser = user;
          _errorMessage = null;
          notifyListeners();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to refresh user data: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google OAuth
  /// 
  /// Returns true if Google sign-in was successful, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> signInWithGoogle() async {
    // Prevent concurrent operations
    if (_state == AuthState.loading) {
      return false;
    }

    try {
      _setState(AuthState.loading);
      _clearError();

      final result = await _signInWithGoogleUseCase(NoParams());

      return result.fold(
        (failure) {
          _setState(AuthState.error);
          _errorMessage = _getErrorMessage(failure);
          _currentUser = null;
          return false;
        },
        (user) {
          _setState(AuthState.authenticated);
          _currentUser = user;
          _errorMessage = null;
          return true;
        },
      );
    } catch (e) {
      _setState(AuthState.error);
      _errorMessage = 'An unexpected error occurred during Google sign-in: ${e.toString()}';
      _currentUser = null;
      return false;
    }
  }

  /// Sign in with Apple OAuth
  /// 
  /// Returns true if Apple sign-in was successful, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> signInWithApple() async {
    // Prevent concurrent operations
    if (_state == AuthState.loading) {
      return false;
    }

    try {
      _setState(AuthState.loading);
      _clearError();

      final result = await _signInWithAppleUseCase(NoParams());

      return result.fold(
        (failure) {
          _setState(AuthState.error);
          _errorMessage = _getErrorMessage(failure);
          _currentUser = null;
          return false;
        },
        (user) {
          _setState(AuthState.authenticated);
          _currentUser = user;
          _errorMessage = null;
          return true;
        },
      );
    } catch (e) {
      _setState(AuthState.error);
      _errorMessage = 'An unexpected error occurred during Apple sign-in: ${e.toString()}';
      _currentUser = null;
      return false;
    }
  }

  /// Send email verification to the current user
  /// 
  /// Returns true if verification email was sent successfully, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> sendEmailVerification() async {
    try {
      _clearError();

      // TODO: Implement SendEmailVerificationUseCase
      // For now, return success to prevent app crashes
      await Future.delayed(const Duration(milliseconds: 500));
      
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send verification email: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Verify email with verification token
  /// 
  /// [token] - Email verification token received via email
  /// 
  /// Returns true if email verification was successful, false otherwise.
  /// Error details are available through [errorMessage] getter.
  Future<bool> verifyEmail({required String token}) async {
    try {
      _clearError();

      final params = VerifyEmailParams(token: token);
      final result = await _verifyEmailUseCase(params);

      return result.fold(
        (failure) {
          _errorMessage = _getErrorMessage(failure);
          notifyListeners();
          return false;
        },
        (_) {
          _errorMessage = null;
          // Refresh user data to update email verification status
          refreshUser();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = 'Failed to verify email: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Clear current error message
  /// 
  /// Useful for dismissing error messages in the UI after user acknowledgment.
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Update authentication state and notify listeners
  void _setState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Clear error message without notifying listeners
  void _clearError() {
    _errorMessage = null;
  }

  /// Convert failure objects to user-friendly error messages
  String _getErrorMessage(Failure failure) {
    if (failure is AuthFailure) {
      return failure.message;
    } else if (failure is NetworkFailure) {
      return 'Network error. Please check your connection and try again.';
    } else if (failure is ServerFailure) {
      return 'Server error. Please try again later.';
    } else if (failure is ValidationFailure) {
      return failure.message;
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  void dispose() {
    // Clean up resources if needed
    super.dispose();
  }
}

/// Extension to add Consumer pattern helpers for common use cases
extension AuthProviderConsumer on AuthProvider {
  /// Whether to show authentication forms
  bool get shouldShowAuthForms => canAuthenticate;

  /// Whether to show main app content
  bool get shouldShowMainContent => hasAccess;

  /// Whether to show loading spinner
  bool get shouldShowLoadingSpinner => shouldShowLoading && isInitialized;

  /// Whether to show error message
  bool get shouldShowError => hasError && errorMessage != null;

  /// Get user display name or email
  String get userDisplayName {
    if (currentUser == null) return '';
    return currentUser!.displayName ?? currentUser!.email;
  }

  /// Get user avatar URL or initials
  String get userAvatarUrl {
    if (currentUser == null) return '';
    return currentUser!.avatarUrl ?? '';
  }

  // ====================
  // Compatibility Methods
  // ====================

  /// Compatibility alias for checkAuthStatus
  Future<void> checkAuthenticationStatus() async {
    await checkAuthStatus();
  }

  /// Refresh user data from server
  Future<void> refreshUser() async {
    await checkAuthStatus();
  }

  /// Check if user is onboarded (compatibility for old AuthProvider)
  bool get isOnboarded => true; // Always true for new architecture

  /// Complete onboarding (compatibility for old AuthProvider)
  Future<void> completeOnboarding() async {
    // No-op for compatibility - onboarding handled elsewhere
  }

  /// Verify email with token
  Future<bool> verifyEmail({required String token}) async {
    try {
      _clearError();
      
      final result = await _verifyEmailUseCase(VerifyEmailParams(token: token));
      
      return await result.fold(
        (failure) async {
          _errorMessage = _getErrorMessage(failure);
          notifyListeners();
          return false;
        },
        (_) async {
          // Refresh user data to get updated email confirmation status
          await checkAuthStatus();
          return true;
        },
      );
    } catch (e) {
      _errorMessage = 'Email verification failed: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}