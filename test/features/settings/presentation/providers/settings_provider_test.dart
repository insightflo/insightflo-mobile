import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:insightflo_app/features/settings/presentation/providers/settings_provider.dart';

// Generate mocks
@GenerateMocks([SharedPreferences])
import 'settings_provider_test.mocks.dart';

void main() {
  late SettingsProvider provider;
  late MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    provider = SettingsProvider(sharedPreferences: mockSharedPreferences);
  });

  group('SettingsProvider', () {
    group('initialization', () {
      test('should initialize with default values', () {
        // Arrange & Act
        when(mockSharedPreferences.getBool('notifications_enabled')).thenReturn(null);
        when(mockSharedPreferences.getBool('biometric_auth_enabled')).thenReturn(null);
        when(mockSharedPreferences.getString('news_refresh_interval')).thenReturn(null);
        when(mockSharedPreferences.getInt('cache_size_limit')).thenReturn(null);
        when(mockSharedPreferences.getBool('analytics_enabled')).thenReturn(null);

        provider = SettingsProvider(sharedPreferences: mockSharedPreferences);

        // Assert
        expect(provider.notificationsEnabled, isTrue);
        expect(provider.biometricAuthEnabled, isFalse);
        expect(provider.newsRefreshInterval, equals('30'));
        expect(provider.cacheSizeLimit, equals(100));
        expect(provider.analyticsEnabled, isTrue);
      });

      test('should initialize with saved preferences', () {
        // Arrange
        when(mockSharedPreferences.getBool('notifications_enabled')).thenReturn(false);
        when(mockSharedPreferences.getBool('biometric_auth_enabled')).thenReturn(true);
        when(mockSharedPreferences.getString('news_refresh_interval')).thenReturn('60');
        when(mockSharedPreferences.getInt('cache_size_limit')).thenReturn(200);
        when(mockSharedPreferences.getBool('analytics_enabled')).thenReturn(false);

        // Act
        provider = SettingsProvider(sharedPreferences: mockSharedPreferences);

        // Assert
        expect(provider.notificationsEnabled, isFalse);
        expect(provider.biometricAuthEnabled, isTrue);
        expect(provider.newsRefreshInterval, equals('60'));
        expect(provider.cacheSizeLimit, equals(200));
        expect(provider.analyticsEnabled, isFalse);
      });
    });

    group('setNotificationsEnabled', () {
      test('should update notifications setting and save to preferences', () async {
        // Arrange
        when(mockSharedPreferences.setBool('notifications_enabled', false))
            .thenAnswer((_) async => true);

        // Act
        await provider.setNotificationsEnabled(false);

        // Assert
        expect(provider.notificationsEnabled, isFalse);
        verify(mockSharedPreferences.setBool('notifications_enabled', false)).called(1);
      });

      test('should notify listeners when notifications setting changes', () async {
        // Arrange
        when(mockSharedPreferences.setBool('notifications_enabled', false))
            .thenAnswer((_) async => true);
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setNotificationsEnabled(false);

        // Assert
        expect(listenerCalled, isTrue);
      });
    });

    group('setBiometricAuthEnabled', () {
      test('should update biometric auth setting and save to preferences', () async {
        // Arrange
        when(mockSharedPreferences.setBool('biometric_auth_enabled', true))
            .thenAnswer((_) async => true);

        // Act
        await provider.setBiometricAuthEnabled(true);

        // Assert
        expect(provider.biometricAuthEnabled, isTrue);
        verify(mockSharedPreferences.setBool('biometric_auth_enabled', true)).called(1);
      });

      test('should notify listeners when biometric auth setting changes', () async {
        // Arrange
        when(mockSharedPreferences.setBool('biometric_auth_enabled', true))
            .thenAnswer((_) async => true);
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setBiometricAuthEnabled(true);

        // Assert
        expect(listenerCalled, isTrue);
      });
    });

    group('setNewsRefreshInterval', () {
      test('should update news refresh interval and save to preferences', () async {
        // Arrange
        const newInterval = '60';
        when(mockSharedPreferences.setString('news_refresh_interval', newInterval))
            .thenAnswer((_) async => true);

        // Act
        await provider.setNewsRefreshInterval(newInterval);

        // Assert
        expect(provider.newsRefreshInterval, equals(newInterval));
        verify(mockSharedPreferences.setString('news_refresh_interval', newInterval)).called(1);
      });

      test('should notify listeners when news refresh interval changes', () async {
        // Arrange
        const newInterval = '120';
        when(mockSharedPreferences.setString('news_refresh_interval', newInterval))
            .thenAnswer((_) async => true);
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setNewsRefreshInterval(newInterval);

        // Assert
        expect(listenerCalled, isTrue);
        expect(provider.newsRefreshInterval, equals(newInterval));
      });
    });

    group('setCacheSizeLimit', () {
      test('should update cache size limit and save to preferences', () async {
        // Arrange
        const newLimit = 250;
        when(mockSharedPreferences.setInt('cache_size_limit', newLimit))
            .thenAnswer((_) async => true);

        // Act
        await provider.setCacheSizeLimit(newLimit);

        // Assert
        expect(provider.cacheSizeLimit, equals(newLimit));
        verify(mockSharedPreferences.setInt('cache_size_limit', newLimit)).called(1);
      });

      test('should clamp cache size limit to valid range', () async {
        // Arrange
        when(mockSharedPreferences.setInt('cache_size_limit', 50))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setInt('cache_size_limit', 1000))
            .thenAnswer((_) async => true);

        // Act & Assert - Test minimum
        await provider.setCacheSizeLimit(10); // Below minimum
        expect(provider.cacheSizeLimit, equals(50));

        // Act & Assert - Test maximum
        await provider.setCacheSizeLimit(2000); // Above maximum
        expect(provider.cacheSizeLimit, equals(1000));
      });

      test('should notify listeners when cache size limit changes', () async {
        // Arrange
        const newLimit = 150;
        when(mockSharedPreferences.setInt('cache_size_limit', newLimit))
            .thenAnswer((_) async => true);
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setCacheSizeLimit(newLimit);

        // Assert
        expect(listenerCalled, isTrue);
        expect(provider.cacheSizeLimit, equals(newLimit));
      });
    });

    group('setAnalyticsEnabled', () {
      test('should update analytics setting and save to preferences', () async {
        // Arrange
        when(mockSharedPreferences.setBool('analytics_enabled', false))
            .thenAnswer((_) async => true);

        // Act
        await provider.setAnalyticsEnabled(false);

        // Assert
        expect(provider.analyticsEnabled, isFalse);
        verify(mockSharedPreferences.setBool('analytics_enabled', false)).called(1);
      });

      test('should notify listeners when analytics setting changes', () async {
        // Arrange
        when(mockSharedPreferences.setBool('analytics_enabled', false))
            .thenAnswer((_) async => true);
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setAnalyticsEnabled(false);

        // Assert
        expect(listenerCalled, isTrue);
      });
    });

    group('clearCache', () {
      test('should clear cache successfully', () async {
        // Arrange
        when(mockSharedPreferences.remove('cached_news'))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.remove('cached_images'))
            .thenAnswer((_) async => true);

        // Act
        final result = await provider.clearCache();

        // Assert
        expect(result, isTrue);
        verify(mockSharedPreferences.remove('cached_news')).called(1);
        verify(mockSharedPreferences.remove('cached_images')).called(1);
      });

      test('should handle cache clear failures', () async {
        // Arrange
        when(mockSharedPreferences.remove(any))
            .thenAnswer((_) async => false);

        // Act
        final result = await provider.clearCache();

        // Assert
        expect(result, isFalse);
      });
    });

    group('resetToDefaults', () {
      test('should reset all settings to default values', () async {
        // Arrange
        when(mockSharedPreferences.setBool('notifications_enabled', true))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setBool('biometric_auth_enabled', false))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setString('news_refresh_interval', '30'))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setInt('cache_size_limit', 100))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setBool('analytics_enabled', true))
            .thenAnswer((_) async => true);

        // Change settings first
        await provider.setNotificationsEnabled(false);
        await provider.setBiometricAuthEnabled(true);
        await provider.setNewsRefreshInterval('120');
        await provider.setCacheSizeLimit(200);
        await provider.setAnalyticsEnabled(false);

        // Act
        await provider.resetToDefaults();

        // Assert
        expect(provider.notificationsEnabled, isTrue);
        expect(provider.biometricAuthEnabled, isFalse);
        expect(provider.newsRefreshInterval, equals('30'));
        expect(provider.cacheSizeLimit, equals(100));
        expect(provider.analyticsEnabled, isTrue);
      });

      test('should notify listeners when resetting to defaults', () async {
        // Arrange
        when(mockSharedPreferences.setBool(any, any))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setString(any, any))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setInt(any, any))
            .thenAnswer((_) async => true);
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.resetToDefaults();

        // Assert
        expect(listenerCalled, isTrue);
      });
    });

    group('getCacheStatistics', () {
      test('should return cache statistics', () async {
        // Arrange
        when(mockSharedPreferences.getStringList('cached_news_keys'))
            .thenReturn(['key1', 'key2', 'key3']);
        when(mockSharedPreferences.getStringList('cached_images_keys'))
            .thenReturn(['img1', 'img2']);

        // Act
        final stats = await provider.getCacheStatistics();

        // Assert
        expect(stats['newsCount'], equals(3));
        expect(stats['imagesCount'], equals(2));
        expect(stats['totalSize'], isA<String>());
      });

      test('should handle missing cache data', () async {
        // Arrange
        when(mockSharedPreferences.getStringList(any))
            .thenReturn(null);

        // Act
        final stats = await provider.getCacheStatistics();

        // Assert
        expect(stats['newsCount'], equals(0));
        expect(stats['imagesCount'], equals(0));
        expect(stats['totalSize'], equals('0 MB'));
      });
    });

    group('exportSettings', () {
      test('should export settings as JSON', () async {
        // Arrange
        provider.setNotificationsEnabled(false);

        // Act
        final exportedSettings = await provider.exportSettings();

        // Assert
        expect(exportedSettings, isA<Map<String, dynamic>>());
        expect(exportedSettings['notifications_enabled'], isFalse);
        expect(exportedSettings['biometric_auth_enabled'], isFalse);
        expect(exportedSettings['news_refresh_interval'], equals('30'));
        expect(exportedSettings['cache_size_limit'], equals(100));
        expect(exportedSettings['analytics_enabled'], isTrue);
      });
    });

    group('importSettings', () {
      test('should import settings from JSON', () async {
        // Arrange
        final settingsToImport = {
          'notifications_enabled': false,
          'biometric_auth_enabled': true,
          'news_refresh_interval': '60',
          'cache_size_limit': 200,
          'analytics_enabled': false,
        };

        when(mockSharedPreferences.setBool(any, any))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setString(any, any))
            .thenAnswer((_) async => true);
        when(mockSharedPreferences.setInt(any, any))
            .thenAnswer((_) async => true);

        // Act
        final result = await provider.importSettings(settingsToImport);

        // Assert
        expect(result, isTrue);
        expect(provider.notificationsEnabled, isFalse);
        expect(provider.biometricAuthEnabled, isTrue);
        expect(provider.newsRefreshInterval, equals('60'));
        expect(provider.cacheSizeLimit, equals(200));
        expect(provider.analyticsEnabled, isFalse);
      });

      test('should handle invalid import data gracefully', () async {
        // Arrange
        final invalidSettings = {
          'invalid_key': 'invalid_value',
          'cache_size_limit': 'not_a_number',
        };

        // Act
        final result = await provider.importSettings(invalidSettings);

        // Assert
        expect(result, isFalse);
      });
    });

    group('error handling', () {
      test('should handle SharedPreferences save failures gracefully', () async {
        // Arrange
        when(mockSharedPreferences.setBool('notifications_enabled', false))
            .thenAnswer((_) async => false);

        // Act & Assert - Should not throw
        expect(() => provider.setNotificationsEnabled(false), returnsNormally);
      });
    });
  });
}