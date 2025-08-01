import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling deep links and URL schemes
/// 
/// This service manages incoming deep links for email verification,
/// password reset, and other authentication-related flows.
/// It provides a unified interface for handling both custom URL schemes
/// and universal links on iOS/Android.
/// 
/// Supported link types:
/// - Email verification: insightflo://verify-email?token=xxx
/// - Password reset: insightflo://reset-password?token=xxx
/// - Social auth redirects: insightflo://auth/callback?provider=xxx
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('insightflo/deep_links');
  
  // Stream controllers for different link types
  final StreamController<EmailVerificationLink> _emailVerificationController = 
      StreamController<EmailVerificationLink>.broadcast();
  final StreamController<PasswordResetLink> _passwordResetController = 
      StreamController<PasswordResetLink>.broadcast();
  final StreamController<SocialAuthLink> _socialAuthController = 
      StreamController<SocialAuthLink>.broadcast();

  // Singleton instance
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  /// Initialize deep link handling
  /// 
  /// This should be called early in the app lifecycle, typically
  /// in main() or during app initialization.
  Future<void> initialize() async {
    try {
      // Temporarily disable method channel until platform implementation is ready
      if (kDebugMode) {
        print('DeepLinkService: Method channel disabled - skipping platform channel setup');
      }
      // _channel.setMethodCallHandler(_handleMethodCall);
      
      // Check for initial link (app opened via deep link)
      await _checkInitialLink();
      
      if (kDebugMode) {
        print('DeepLinkService: Initialized successfully (mock mode)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('DeepLinkService: Failed to initialize: $e');
      }
    }
  }

  /// Handle method calls from platform channels
  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onDeepLink':
          final String? url = call.arguments as String?;
          if (url != null) {
            await _processDeepLink(url);
          }
          break;
        default:
          throw PlatformException(
            code: 'UNIMPLEMENTED',
            details: 'Method ${call.method} not implemented',
          );
      }
    } catch (e) {
      if (kDebugMode) {
        print('DeepLinkService: Error handling method call: $e');
      }
    }
  }

  /// Check for initial deep link when app is opened
  Future<void> _checkInitialLink() async {
    try {
      // Temporarily disable method channel calls until platform implementation is ready
      if (kDebugMode) {
        print('DeepLinkService: Method channel disabled - platform implementation not ready');
      }
      // final String? initialLink = await _channel.invokeMethod('getInitialLink');
      // if (initialLink != null) {
      //   await _processDeepLink(initialLink);
      // }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('DeepLinkService: Failed to get initial link: ${e.message}');
      }
    }
  }

  /// Process incoming deep link
  Future<void> _processDeepLink(String url) async {
    try {
      final uri = Uri.parse(url);
      
      // Validate scheme
      if (uri.scheme != 'insightflo') {
        if (kDebugMode) {
          print('DeepLinkService: Invalid scheme: ${uri.scheme}');
        }
        return;
      }

      // Route based on path
      switch (uri.host) {
        case 'verify-email':
          await _handleEmailVerification(uri);
          break;
        case 'reset-password':
          await _handlePasswordReset(uri);
          break;
        case 'auth':
          await _handleSocialAuth(uri);
          break;
        default:
          if (kDebugMode) {
            print('DeepLinkService: Unknown host: ${uri.host}');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('DeepLinkService: Error processing deep link: $e');
      }
    }
  }

  /// Handle email verification deep link
  Future<void> _handleEmailVerification(Uri uri) async {
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];
    
    if (token != null) {
      final link = EmailVerificationLink(
        token: token,
        email: email,
        timestamp: DateTime.now(),
      );
      
      _emailVerificationController.add(link);
      
      if (kDebugMode) {
        print('DeepLinkService: Email verification link processed');
      }
    }
  }

  /// Handle password reset deep link
  Future<void> _handlePasswordReset(Uri uri) async {
    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];
    
    if (token != null) {
      final link = PasswordResetLink(
        token: token,
        email: email,
        timestamp: DateTime.now(),
      );
      
      _passwordResetController.add(link);
      
      if (kDebugMode) {
        print('DeepLinkService: Password reset link processed');
      }
    }
  }

  /// Handle social auth callback deep link
  Future<void> _handleSocialAuth(Uri uri) async {
    final provider = uri.queryParameters['provider'];
    final accessToken = uri.queryParameters['access_token'];
    final refreshToken = uri.queryParameters['refresh_token'];
    final error = uri.queryParameters['error'];
    
    final link = SocialAuthLink(
      provider: provider,
      accessToken: accessToken,
      refreshToken: refreshToken,
      error: error,
      timestamp: DateTime.now(),
    );
    
    _socialAuthController.add(link);
    
    if (kDebugMode) {
      print('DeepLinkService: Social auth callback processed');
    }
  }

  /// Stream of email verification links
  Stream<EmailVerificationLink> get emailVerificationLinks => 
      _emailVerificationController.stream;

  /// Stream of password reset links
  Stream<PasswordResetLink> get passwordResetLinks => 
      _passwordResetController.stream;

  /// Stream of social auth links
  Stream<SocialAuthLink> get socialAuthLinks => 
      _socialAuthController.stream;

  /// Test deep link functionality (debug only)
  Future<void> testDeepLink(String url) async {
    if (kDebugMode) {
      await _processDeepLink(url);
    }
  }

  /// Open external URL
  Future<bool> launchExternalUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('DeepLinkService: Failed to launch URL: $e');
      }
      return false;
    }
  }

  /// Dispose of resources
  void dispose() {
    _emailVerificationController.close();
    _passwordResetController.close();
    _socialAuthController.close();
  }
}

/// Email verification deep link data
class EmailVerificationLink {
  final String token;
  final String? email;
  final DateTime timestamp;

  const EmailVerificationLink({
    required this.token,
    this.email,
    required this.timestamp,
  });

  @override
  String toString() => 'EmailVerificationLink(token: $token, email: $email)';
}

/// Password reset deep link data
class PasswordResetLink {
  final String token;
  final String? email;
  final DateTime timestamp;

  const PasswordResetLink({
    required this.token,
    this.email,
    required this.timestamp,
  });

  @override
  String toString() => 'PasswordResetLink(token: $token, email: $email)';
}

/// Social auth callback deep link data
class SocialAuthLink {
  final String? provider;
  final String? accessToken;
  final String? refreshToken;
  final String? error;
  final DateTime timestamp;

  const SocialAuthLink({
    this.provider,
    this.accessToken,
    this.refreshToken,
    this.error,
    required this.timestamp,
  });

  bool get hasError => error != null;
  bool get isSuccess => !hasError && accessToken != null;

  @override
  String toString() => 'SocialAuthLink(provider: $provider, success: $isSuccess)';
}

/// Extension for platform-specific deep link configuration
extension DeepLinkConfiguration on DeepLinkService {
  /// Get Android intent filter configuration
  String get androidConfiguration => '''
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="insightflo" />
</intent-filter>
''';

  /// Get iOS URL schemes configuration
  String get iosConfiguration => '''
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>insightflo.deeplink</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>insightflo</string>
        </array>
    </dict>
</array>
''';
}