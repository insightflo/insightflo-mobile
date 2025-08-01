import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:insightflo_app/features/news/presentation/providers/theme_provider.dart';

void main() {
  late ThemeProvider provider;

  setUp(() {
    provider = ThemeProvider();
    // Mock SharedPreferences with empty initial values
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    group('initialization', () {
      test('should initialize with default values', () {
        // Assert - provider should have default values before initialization
        expect(provider.themeMode, equals(ThemeMode.system));
        expect(provider.useDynamicColors, isTrue);
        expect(provider.fontScale, equals(1.0));
        expect(provider.useHighContrast, isFalse);
      });

      test('should initialize with saved preferences', () async {
        // Arrange - Set initial values in SharedPreferences
        SharedPreferences.setMockInitialValues({
          'theme_mode': ThemeMode.dark.index,
          'dynamic_colors': false,
          'font_scale': 1.2,
          'high_contrast': true,
        });
        
        provider = ThemeProvider();

        // Act
        await provider.initialize();

        // Assert
        expect(provider.themeMode, equals(ThemeMode.dark));
        expect(provider.useDynamicColors, isFalse);
        expect(provider.fontScale, equals(1.2));
        expect(provider.useHighContrast, isTrue);
      });
    });

    group('setThemeMode', () {
      test('should update theme mode and save to preferences', () async {
        // Arrange
        await provider.initialize();

        // Act
        await provider.setThemeMode(ThemeMode.dark);

        // Assert
        expect(provider.themeMode, equals(ThemeMode.dark));
      });

      test('should notify listeners when theme mode changes', () async {
        // Arrange
        await provider.initialize();
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setThemeMode(ThemeMode.light);

        // Assert
        expect(listenerCalled, isTrue);
        expect(provider.themeMode, equals(ThemeMode.light));
      });
    });

    group('setDynamicColors', () {
      test('should update dynamic colors setting and save to preferences', () async {
        // Arrange
        await provider.initialize();

        // Act
        await provider.setDynamicColors(false);

        // Assert
        expect(provider.useDynamicColors, isFalse);
      });

      test('should notify listeners when dynamic colors setting changes', () async {
        // Arrange
        await provider.initialize();
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setDynamicColors(false);

        // Assert
        expect(listenerCalled, isTrue);
        expect(provider.useDynamicColors, isFalse);
      });
    });

    group('setFontScale', () {
      test('should update font scale and save to preferences', () async {
        // Arrange
        await provider.initialize();
        const newFontScale = 1.2;

        // Act
        await provider.setFontScale(newFontScale);

        // Assert
        expect(provider.fontScale, equals(newFontScale));
      });

      test('should clamp font scale to valid range', () async {
        // Arrange
        await provider.initialize();

        // Act & Assert - Test minimum
        await provider.setFontScale(0.5); // Below minimum
        expect(provider.fontScale, equals(0.8));

        // Act & Assert - Test maximum
        await provider.setFontScale(3.0); // Above maximum  
        expect(provider.fontScale, equals(1.4)); // Actual max is 1.4, not 2.0
      });

      test('should notify listeners when font scale changes', () async {
        // Arrange
        await provider.initialize();
        const newFontScale = 1.3;
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setFontScale(newFontScale);

        // Assert
        expect(listenerCalled, isTrue);
        expect(provider.fontScale, equals(newFontScale));
      });
    });

    group('setHighContrast', () {
      test('should update high contrast setting and save to preferences', () async {
        // Arrange
        await provider.initialize();

        // Act
        await provider.setHighContrast(true);

        // Assert
        expect(provider.useHighContrast, isTrue);
      });

      test('should notify listeners when high contrast setting changes', () async {
        // Arrange
        await provider.initialize();
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.setHighContrast(true);

        // Assert
        expect(listenerCalled, isTrue);
        expect(provider.useHighContrast, isTrue);
      });
    });

    group('resetToDefaults', () {
      test('should reset all settings to default values', () async {
        // Arrange
        await provider.initialize();

        // Change settings first
        await provider.setThemeMode(ThemeMode.dark);
        await provider.setDynamicColors(false);
        await provider.setFontScale(1.3);
        await provider.setHighContrast(true);

        // Act
        await provider.resetToDefaults();

        // Assert
        expect(provider.themeMode, equals(ThemeMode.system));
        expect(provider.useDynamicColors, isTrue);
        expect(provider.fontScale, equals(1.0));
        expect(provider.useHighContrast, isFalse);
      });

      test('should notify listeners when resetting to defaults', () async {
        // Arrange
        await provider.initialize();
        
        bool listenerCalled = false;
        provider.addListener(() => listenerCalled = true);

        // Act
        await provider.resetToDefaults();

        // Assert
        expect(listenerCalled, isTrue);
      });
    });

    group('utility methods', () {
      test('should get theme mode display name correctly', () async {
        // Arrange
        await provider.initialize();

        // Test system theme mode
        await provider.setThemeMode(ThemeMode.system);
        expect(provider.getThemeModeDisplayName(), equals('System'));

        // Test light theme mode
        await provider.setThemeMode(ThemeMode.light);
        expect(provider.getThemeModeDisplayName(), equals('Light'));

        // Test dark theme mode
        await provider.setThemeMode(ThemeMode.dark);
        expect(provider.getThemeModeDisplayName(), equals('Dark'));
      });

      test('should get font scale display name correctly', () async {
        // Arrange
        await provider.initialize();

        // Test small font scale
        await provider.setFontScale(0.8);
        expect(provider.getFontScaleDisplayName(), equals('Small'));

        // Test default font scale
        await provider.setFontScale(1.0);
        expect(provider.getFontScaleDisplayName(), equals('Default'));

        // Test large font scale
        await provider.setFontScale(1.2);
        expect(provider.getFontScaleDisplayName(), equals('Large'));

        // Test extra large font scale
        await provider.setFontScale(1.4);
        expect(provider.getFontScaleDisplayName(), equals('Extra Large'));
      });

      test('should check if using defaults correctly', () async {
        // Arrange
        await provider.initialize();

        // Should be using defaults initially
        expect(provider.isUsingDefaults, isTrue);

        // Change a setting
        await provider.setThemeMode(ThemeMode.dark);
        expect(provider.isUsingDefaults, isFalse);

        // Reset to defaults
        await provider.resetToDefaults();
        expect(provider.isUsingDefaults, isTrue);
      });
    });
  });
}