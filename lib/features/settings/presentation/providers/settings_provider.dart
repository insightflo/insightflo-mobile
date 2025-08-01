import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings provider for managing app-wide settings
/// 
/// Features:
/// - Notification settings management
/// - Biometric authentication settings
/// - News refresh interval configuration
/// - Cache size limit management
/// - Analytics settings
/// - Settings import/export functionality
/// - Cache statistics and management
class SettingsProvider extends ChangeNotifier {
  final SharedPreferences sharedPreferences;

  // Private fields
  bool _notificationsEnabled = true;
  bool _biometricAuthEnabled = false;
  String _newsRefreshInterval = '30';
  int _cacheSizeLimit = 100;
  bool _analyticsEnabled = true;

  // Storage keys
  static const String _notificationsKey = 'notifications_enabled';
  static const String _biometricAuthKey = 'biometric_auth_enabled';
  static const String _newsRefreshKey = 'news_refresh_interval';
  static const String _cacheSizeLimitKey = 'cache_size_limit';
  static const String _analyticsKey = 'analytics_enabled';

  SettingsProvider({required this.sharedPreferences}) {
    _loadSettings();
  }

  // Getters
  bool get notificationsEnabled => _notificationsEnabled;
  bool get biometricAuthEnabled => _biometricAuthEnabled;
  String get newsRefreshInterval => _newsRefreshInterval;
  int get cacheSizeLimit => _cacheSizeLimit;
  bool get analyticsEnabled => _analyticsEnabled;

  /// Load settings from SharedPreferences
  void _loadSettings() {
    _notificationsEnabled = sharedPreferences.getBool(_notificationsKey) ?? true;
    _biometricAuthEnabled = sharedPreferences.getBool(_biometricAuthKey) ?? false;
    _newsRefreshInterval = sharedPreferences.getString(_newsRefreshKey) ?? '30';
    _cacheSizeLimit = sharedPreferences.getInt(_cacheSizeLimitKey) ?? 100;
    _analyticsEnabled = sharedPreferences.getBool(_analyticsKey) ?? true;
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;

    _notificationsEnabled = enabled;
    await sharedPreferences.setBool(_notificationsKey, enabled);
    notifyListeners();
  }

  /// Set biometric authentication enabled/disabled
  Future<void> setBiometricAuthEnabled(bool enabled) async {
    if (_biometricAuthEnabled == enabled) return;

    _biometricAuthEnabled = enabled;
    await sharedPreferences.setBool(_biometricAuthKey, enabled);
    notifyListeners();
  }

  /// Set news refresh interval
  Future<void> setNewsRefreshInterval(String interval) async {
    if (_newsRefreshInterval == interval) return;

    _newsRefreshInterval = interval;
    await sharedPreferences.setString(_newsRefreshKey, interval);
    notifyListeners();
  }

  /// Set cache size limit with validation
  Future<void> setCacheSizeLimit(int limit) async {
    // Clamp to valid range (50MB - 1000MB)
    final clampedLimit = limit.clamp(50, 1000);
    
    if (_cacheSizeLimit == clampedLimit) return;

    _cacheSizeLimit = clampedLimit;
    await sharedPreferences.setInt(_cacheSizeLimitKey, clampedLimit);
    notifyListeners();
  }

  /// Set analytics enabled/disabled
  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (_analyticsEnabled == enabled) return;

    _analyticsEnabled = enabled;
    await sharedPreferences.setBool(_analyticsKey, enabled);
    notifyListeners();
  }

  /// Clear cache data
  Future<bool> clearCache() async {
    try {
      final newsCleared = await sharedPreferences.remove('cached_news');
      final imagesCleared = await sharedPreferences.remove('cached_images');
      return newsCleared && imagesCleared;
    } catch (e) {
      return false;
    }
  }

  /// Reset all settings to default values
  Future<void> resetToDefaults() async {
    _notificationsEnabled = true;
    _biometricAuthEnabled = false;
    _newsRefreshInterval = '30';
    _cacheSizeLimit = 100;
    _analyticsEnabled = true;

    // Save defaults to SharedPreferences
    await Future.wait([
      sharedPreferences.setBool(_notificationsKey, _notificationsEnabled),
      sharedPreferences.setBool(_biometricAuthKey, _biometricAuthEnabled),
      sharedPreferences.setString(_newsRefreshKey, _newsRefreshInterval),
      sharedPreferences.setInt(_cacheSizeLimitKey, _cacheSizeLimit),
      sharedPreferences.setBool(_analyticsKey, _analyticsEnabled),
    ]);

    notifyListeners();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    final newsKeys = sharedPreferences.getStringList('cached_news_keys') ?? [];
    final imageKeys = sharedPreferences.getStringList('cached_images_keys') ?? [];
    
    return {
      'newsCount': newsKeys.length,
      'imagesCount': imageKeys.length,
      'totalSize': '${(newsKeys.length + imageKeys.length) * 0.5} MB',
    };
  }

  /// Export current settings as JSON
  Future<Map<String, dynamic>> exportSettings() async {
    return {
      'notifications_enabled': _notificationsEnabled,
      'biometric_auth_enabled': _biometricAuthEnabled,
      'news_refresh_interval': _newsRefreshInterval,
      'cache_size_limit': _cacheSizeLimit,
      'analytics_enabled': _analyticsEnabled,
    };
  }

  /// Import settings from JSON
  Future<bool> importSettings(Map<String, dynamic> settings) async {
    try {
      // Validate and apply settings
      if (settings.containsKey('notifications_enabled') && settings['notifications_enabled'] is bool) {
        await setNotificationsEnabled(settings['notifications_enabled']);
      }
      
      if (settings.containsKey('biometric_auth_enabled') && settings['biometric_auth_enabled'] is bool) {
        await setBiometricAuthEnabled(settings['biometric_auth_enabled']);
      }
      
      if (settings.containsKey('news_refresh_interval') && settings['news_refresh_interval'] is String) {
        await setNewsRefreshInterval(settings['news_refresh_interval']);
      }
      
      if (settings.containsKey('cache_size_limit') && settings['cache_size_limit'] is int) {
        await setCacheSizeLimit(settings['cache_size_limit']);
      }
      
      if (settings.containsKey('analytics_enabled') && settings['analytics_enabled'] is bool) {
        await setAnalyticsEnabled(settings['analytics_enabled']);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
}