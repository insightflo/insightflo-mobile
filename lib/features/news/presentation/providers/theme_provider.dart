import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme provider for managing app-wide theme settings
/// 
/// Features:
/// - Theme mode management (light, dark, system)
/// - Dynamic color scheme support (Material You)
/// - Custom font scaling
/// - Persistent theme preferences
/// - Smooth theme transitions
/// - Platform-specific optimizations
class ThemeProvider extends ChangeNotifier {
  // Private fields
  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColors = true;
  double _fontScale = 1.0;
  Color? _customSeedColor;
  bool _useHighContrast = false;
  SharedPreferences? _prefs;

  // Storage keys
  static const String _themeModeKey = 'theme_mode';
  static const String _dynamicColorsKey = 'dynamic_colors';
  static const String _fontScaleKey = 'font_scale';
  static const String _customSeedColorKey = 'custom_seed_color';
  static const String _highContrastKey = 'high_contrast';

  // Public getters
  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColors => _useDynamicColors;
  double get fontScale => _fontScale;
  Color? get customSeedColor => _customSeedColor;
  bool get useHighContrast => _useHighContrast;

  /// Initialize the theme provider with saved preferences
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  /// Load saved theme preferences
  Future<void> _loadPreferences() async {
    if (_prefs == null) return;

    // Load theme mode
    final themeModeIndex = _prefs!.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // Load dynamic colors preference
    _useDynamicColors = _prefs!.getBool(_dynamicColorsKey) ?? true;

    // Load font scale
    _fontScale = _prefs!.getDouble(_fontScaleKey) ?? 1.0;

    // Load custom seed color
    final colorValue = _prefs!.getInt(_customSeedColorKey);
    if (colorValue != null) {
      _customSeedColor = Color(colorValue);
    }

    // Load high contrast preference
    _useHighContrast = _prefs!.getBool(_highContrastKey) ?? false;

    notifyListeners();
  }

  /// Set the theme mode and persist the preference
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;

    _themeMode = mode;
    await _prefs?.setInt(_themeModeKey, mode.index);
    
    // Update system UI overlay style based on theme
    _updateSystemUIOverlayStyle();
    
    notifyListeners();
  }

  /// Set dynamic colors preference and persist it
  Future<void> setDynamicColors(bool enabled) async {
    if (_useDynamicColors == enabled) return;

    _useDynamicColors = enabled;
    await _prefs?.setBool(_dynamicColorsKey, enabled);
    notifyListeners();
  }

  /// Set font scale and persist the preference
  Future<void> setFontScale(double scale) async {
    if (_fontScale == scale) return;

    _fontScale = scale.clamp(0.8, 1.4);
    await _prefs?.setDouble(_fontScaleKey, _fontScale);
    notifyListeners();
  }

  /// Set custom seed color for theming
  Future<void> setCustomSeedColor(Color? color) async {
    if (_customSeedColor == color) return;

    _customSeedColor = color;
    
    if (color != null) {
      await _prefs?.setInt(_customSeedColorKey, color.value);
    } else {
      await _prefs?.remove(_customSeedColorKey);
    }
    
    notifyListeners();
  }

  /// Set high contrast mode
  Future<void> setHighContrast(bool enabled) async {
    if (_useHighContrast == enabled) return;

    _useHighContrast = enabled;
    await _prefs?.setBool(_highContrastKey, enabled);
    notifyListeners();
  }

  /// Reset all theme settings to defaults
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _useDynamicColors = true;
    _fontScale = 1.0;
    _customSeedColor = null;
    _useHighContrast = false;

    // Clear stored preferences
    await _prefs?.remove(_themeModeKey);
    await _prefs?.remove(_dynamicColorsKey);
    await _prefs?.remove(_fontScaleKey);
    await _prefs?.remove(_customSeedColorKey);
    await _prefs?.remove(_highContrastKey);

    _updateSystemUIOverlayStyle();
    notifyListeners();
  }

  /// Get the current brightness based on theme mode and system setting
  Brightness getCurrentBrightness(BuildContext context) {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return MediaQuery.of(context).platformBrightness;
    }
  }

  /// Check if dark mode is currently active
  bool isDarkMode(BuildContext context) {
    return getCurrentBrightness(context) == Brightness.dark;
  }

  /// Get the light theme data
  ThemeData getLightTheme(BuildContext context) {
    ColorScheme colorScheme;

    if (_useDynamicColors && _customSeedColor == null) {
      // Use system dynamic colors if available
      colorScheme = _getDynamicColorScheme(context, Brightness.light) ??
          _getDefaultColorScheme(Brightness.light);
    } else if (_customSeedColor != null) {
      // Use custom seed color
      colorScheme = ColorScheme.fromSeed(
        seedColor: _customSeedColor!,
        brightness: Brightness.light,
      );
    } else {
      // Use default color scheme
      colorScheme = _getDefaultColorScheme(Brightness.light);
    }

    if (_useHighContrast) {
      colorScheme = _applyHighContrast(colorScheme);
    }

    return _buildThemeData(colorScheme, Brightness.light);
  }

  /// Get the dark theme data
  ThemeData getDarkTheme(BuildContext context) {
    ColorScheme colorScheme;

    if (_useDynamicColors && _customSeedColor == null) {
      // Use system dynamic colors if available
      colorScheme = _getDynamicColorScheme(context, Brightness.dark) ??
          _getDefaultColorScheme(Brightness.dark);
    } else if (_customSeedColor != null) {
      // Use custom seed color
      colorScheme = ColorScheme.fromSeed(
        seedColor: _customSeedColor!,
        brightness: Brightness.dark,
      );
    } else {
      // Use default color scheme
      colorScheme = _getDefaultColorScheme(Brightness.dark);
    }

    if (_useHighContrast) {
      colorScheme = _applyHighContrast(colorScheme);
    }

    return _buildThemeData(colorScheme, Brightness.dark);
  }

  /// Get dynamic color scheme from the system (Material You)
  ColorScheme? _getDynamicColorScheme(BuildContext context, Brightness brightness) {
    // This would integrate with dynamic_color package in a real implementation
    // For now, return null to use fallback colors
    return null;
  }

  /// Get default app color scheme
  ColorScheme _getDefaultColorScheme(Brightness brightness) {
    const seedColor = Color(0xFF2196F3); // Material Blue
    
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
  }

  /// Apply high contrast adjustments to color scheme
  ColorScheme _applyHighContrast(ColorScheme colorScheme) {
    if (colorScheme.brightness == Brightness.light) {
      return colorScheme.copyWith(
        surface: Colors.white,
        onSurface: Colors.black,
        primary: colorScheme.primary,
        onPrimary: Colors.white,
        outline: Colors.black,
      );
    } else {
      return colorScheme.copyWith(
        surface: Colors.black,
        onSurface: Colors.white,
        primary: colorScheme.primary,
        onPrimary: Colors.black,
        outline: Colors.white,
      );
    }
  }

  /// Build complete theme data from color scheme
  ThemeData _buildThemeData(ColorScheme colorScheme, Brightness brightness) {
    final baseTheme = ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
      fontFamily: 'Roboto', // Can be customized
    );

    return baseTheme.copyWith(
      // Apply font scaling
      textTheme: _scaleTextTheme(baseTheme.textTheme),
      primaryTextTheme: _scaleTextTheme(baseTheme.primaryTextTheme),

      // Custom component themes
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: _scaleTextTheme(baseTheme.textTheme).titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card theme removed due to compatibility issues
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        labelStyle: _scaleTextTheme(baseTheme.textTheme).bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 8,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
        selectedLabelTextStyle: _scaleTextTheme(baseTheme.textTheme).bodyMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: _scaleTextTheme(baseTheme.textTheme).bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: _scaleTextTheme(baseTheme.textTheme).bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog theme removed due to compatibility issues
      
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),

      // Tab bar theme removed due to compatibility issues
      
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return null;
        }),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.primaryContainer,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colorScheme.primary,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.primaryContainer,
        circularTrackColor: colorScheme.primaryContainer,
      ),
    );
  }

  /// Scale text theme according to font scale setting
  TextTheme _scaleTextTheme(TextTheme textTheme) {
    return TextTheme(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontSize: (textTheme.displayLarge?.fontSize ?? 57) * _fontScale,
      ),
      displayMedium: textTheme.displayMedium?.copyWith(
        fontSize: (textTheme.displayMedium?.fontSize ?? 45) * _fontScale,
      ),
      displaySmall: textTheme.displaySmall?.copyWith(
        fontSize: (textTheme.displaySmall?.fontSize ?? 36) * _fontScale,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontSize: (textTheme.headlineLarge?.fontSize ?? 32) * _fontScale,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: (textTheme.headlineMedium?.fontSize ?? 28) * _fontScale,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontSize: (textTheme.headlineSmall?.fontSize ?? 24) * _fontScale,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontSize: (textTheme.titleLarge?.fontSize ?? 22) * _fontScale,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: (textTheme.titleMedium?.fontSize ?? 16) * _fontScale,
      ),
      titleSmall: textTheme.titleSmall?.copyWith(
        fontSize: (textTheme.titleSmall?.fontSize ?? 14) * _fontScale,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        fontSize: (textTheme.bodyLarge?.fontSize ?? 16) * _fontScale,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: (textTheme.bodyMedium?.fontSize ?? 14) * _fontScale,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: (textTheme.bodySmall?.fontSize ?? 12) * _fontScale,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontSize: (textTheme.labelLarge?.fontSize ?? 14) * _fontScale,
      ),
      labelMedium: textTheme.labelMedium?.copyWith(
        fontSize: (textTheme.labelMedium?.fontSize ?? 12) * _fontScale,
      ),
      labelSmall: textTheme.labelSmall?.copyWith(
        fontSize: (textTheme.labelSmall?.fontSize ?? 11) * _fontScale,
      ),
    );
  }

  /// Update system UI overlay style based on current theme
  void _updateSystemUIOverlayStyle() {
    SystemUiOverlayStyle overlayStyle;

    if (_themeMode == ThemeMode.dark || 
        (_themeMode == ThemeMode.system && 
         WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark)) {
      // Dark theme
      overlayStyle = const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      );
    } else {
      // Light theme
      overlayStyle = const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      );
    }

    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }

  /// Get theme mode display name
  String getThemeModeDisplayName() {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  /// Get font scale display name
  String getFontScaleDisplayName() {
    if (_fontScale <= 0.9) return 'Small';
    if (_fontScale <= 1.1) return 'Default';
    if (_fontScale <= 1.3) return 'Large';
    return 'Extra Large';
  }

  /// Check if current settings match system defaults
  bool get isUsingDefaults {
    return _themeMode == ThemeMode.system &&
           _useDynamicColors == true &&
           _fontScale == 1.0 &&
           _customSeedColor == null &&
           _useHighContrast == false;
  }
}