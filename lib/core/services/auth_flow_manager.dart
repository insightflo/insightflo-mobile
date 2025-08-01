import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'deep_link_service.dart';

/// Authentication flow manager that orchestrates authentication flows
/// 
/// This service manages the overall authentication experience including:
/// - App startup authentication state restoration
/// - Deep link handling for auth flows
/// - Session recovery and token refresh
/// - Cross-platform auth state synchronization
/// 
/// It acts as a coordinator between the AuthProvider, DeepLinkService,
/// and other authentication-related services.
class AuthFlowManager {
  final AuthProvider _authProvider;
  final DeepLinkService _deepLinkService;
  
  // Stream subscriptions
  StreamSubscription<EmailVerificationLink>? _emailVerificationSubscription;
  StreamSubscription<PasswordResetLink>? _passwordResetSubscription;
  StreamSubscription<SocialAuthLink>? _socialAuthSubscription;
  
  // State management
  bool _isInitialized = false;
  bool _isRestoringSession = false;
  
  /// Constructor requires AuthProvider and DeepLinkService
  AuthFlowManager({
    required AuthProvider authProvider,
    required DeepLinkService deepLinkService,
  }) : _authProvider = authProvider,
       _deepLinkService = deepLinkService;

  /// Initialize the authentication flow manager
  /// 
  /// This should be called during app startup, after dependency injection
  /// but before showing the main UI.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize deep link service
      await _deepLinkService.initialize();
      
      // Set up deep link listeners
      _setupDeepLinkListeners();
      
      // Restore authentication session
      await _restoreAuthenticationSession();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('AuthFlowManager: Initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthFlowManager: Failed to initialize: $e');
      }
      rethrow;
    }
  }

  /// Set up listeners for deep link events
  void _setupDeepLinkListeners() {
    // Email verification links
    _emailVerificationSubscription = 
        _deepLinkService.emailVerificationLinks.listen(
      _handleEmailVerificationLink,
      onError: (error) {
        if (kDebugMode) {
          print('AuthFlowManager: Email verification link error: $error');
        }
      },
    );

    // Password reset links
    _passwordResetSubscription = 
        _deepLinkService.passwordResetLinks.listen(
      _handlePasswordResetLink,
      onError: (error) {
        if (kDebugMode) {
          print('AuthFlowManager: Password reset link error: $error');
        }
      },
    );

    // Social auth callback links
    _socialAuthSubscription = 
        _deepLinkService.socialAuthLinks.listen(
      _handleSocialAuthLink,
      onError: (error) {
        if (kDebugMode) {
          print('AuthFlowManager: Social auth link error: $error');
        }
      },
    );
  }

  /// Restore authentication session on app startup
  /// 
  /// This method attempts to restore the user's authentication state
  /// from stored tokens, refresh tokens if needed, and validate
  /// the current session.
  Future<void> _restoreAuthenticationSession() async {
    if (_isRestoringSession) return;

    _isRestoringSession = true;
    
    try {
      if (kDebugMode) {
        print('AuthFlowManager: Starting session restoration');
      }

      // The AuthProvider automatically checks for existing session
      // during its initialization, so we just need to wait for it
      // to complete and check the result
      
      // Wait a short time for AuthProvider to complete initialization
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Check authentication status
      final isAuthenticated = await _authProvider.checkAuthStatus();
      
      if (kDebugMode) {
        print('AuthFlowManager: Session restoration completed. '
              'Authenticated: $isAuthenticated');
      }
      
      if (isAuthenticated) {
        await _performPostAuthenticationTasks();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthFlowManager: Session restoration failed: $e');
      }
      // Don't rethrow - app should still work without restored session
    } finally {
      _isRestoringSession = false;
    }
  }

  /// Perform tasks after successful authentication
  Future<void> _performPostAuthenticationTasks() async {
    try {
      // Refresh user data to ensure it's up to date
      await _authProvider.refreshUser();
      
      // Check if email verification is needed
      if (_authProvider.currentUser != null && 
          !_authProvider.currentUser!.isEmailVerified) {
        if (kDebugMode) {
          print('AuthFlowManager: Email verification needed');
        }
        // Could trigger email re-send or show verification prompt
      }
      
      if (kDebugMode) {
        print('AuthFlowManager: Post-authentication tasks completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthFlowManager: Post-authentication tasks failed: $e');
      }
    }
  }

  /// Handle email verification deep link
  Future<void> _handleEmailVerificationLink(EmailVerificationLink link) async {
    try {
      if (kDebugMode) {
        print('AuthFlowManager: Handling email verification link');
      }

      final success = await _authProvider.verifyEmail(token: link.token);
      
      if (success) {
        if (kDebugMode) {
          print('AuthFlowManager: Email verification successful');
        }
        // Could show success message or navigate to success screen
      } else {
        if (kDebugMode) {
          print('AuthFlowManager: Email verification failed: ${_authProvider.errorMessage}');
        }
        // Could show error message or navigate to error screen
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthFlowManager: Email verification error: $e');
      }
    }
  }

  /// Handle password reset deep link
  Future<void> _handlePasswordResetLink(PasswordResetLink link) async {
    try {
      if (kDebugMode) {
        print('AuthFlowManager: Handling password reset link');
      }

      // For password reset, we typically navigate to a password reset screen
      // where the user can enter their new password along with the token
      
      // This would be handled by navigation service or app router
      // For now, we just log the event
      if (kDebugMode) {
        print('AuthFlowManager: Password reset token received: ${link.token}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthFlowManager: Password reset error: $e');
      }
    }
  }

  /// Handle social auth callback deep link
  Future<void> _handleSocialAuthLink(SocialAuthLink link) async {
    try {
      if (kDebugMode) {
        print('AuthFlowManager: Handling social auth link');
      }

      if (link.hasError) {
        if (kDebugMode) {
          print('AuthFlowManager: Social auth error: ${link.error}');
        }
        // Could show error message
        return;
      }

      if (link.isSuccess) {
        // The actual authentication should have been handled by the
        // social login flow, so we just need to refresh the auth state
        await _authProvider.checkAuthStatus();
        
        if (kDebugMode) {
          print('AuthFlowManager: Social auth callback processed successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthFlowManager: Social auth callback error: $e');
      }
    }
  }

  /// Manually trigger session restoration
  /// 
  /// This can be called when the app resumes from background
  /// or when network connectivity is restored.
  Future<void> restoreSession() async {
    if (!_isInitialized) {
      await initialize();
      return;
    }

    await _restoreAuthenticationSession();
  }

  /// Check if user needs email verification
  bool get needsEmailVerification {
    return _authProvider.isAuthenticated && 
           _authProvider.currentUser != null &&
           !_authProvider.currentUser!.isEmailVerified;
  }

  /// Get current authentication state
  bool get isAuthenticated => _authProvider.isAuthenticated;

  /// Get current user
  get currentUser => _authProvider.currentUser;

  /// Whether the manager is initialized
  bool get isInitialized => _isInitialized;

  /// Whether session restoration is in progress
  bool get isRestoringSession => _isRestoringSession;

  /// Dispose of resources
  void dispose() {
    _emailVerificationSubscription?.cancel();
    _passwordResetSubscription?.cancel();
    _socialAuthSubscription?.cancel();
    _deepLinkService.dispose();
  }
}

/// Extension for authentication flow utilities
extension AuthFlowUtilities on AuthFlowManager {
  /// Handle app resume from background
  Future<void> handleAppResume() async {
    if (_isInitialized && !_isRestoringSession) {
      await _restoreAuthenticationSession();
    }
  }

  /// Handle network connectivity restored
  Future<void> handleNetworkRestored() async {
    if (_isInitialized && _authProvider.isAuthenticated) {
      await _authProvider.refreshUser();
    }
  }

  /// Clear all authentication data
  Future<void> clearAuthenticationData() async {
    await _authProvider.signOut();
  }
}