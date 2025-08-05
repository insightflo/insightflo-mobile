import 'package:flutter/material.dart';

/// 앱 설정 데이터 모델
///
/// 앱의 모든 설정 상태를 관리하는 중앙 모델
class AppSettings {
  // 테마 설정
  final ThemeMode themeMode;
  final bool useDynamicColors;
  final double fontScale;
  final Color? customSeedColor;
  final bool useHighContrast;

  // 알림 설정
  final bool pushNotifications;
  final bool breakingNewsAlerts;
  final bool dailyDigest;
  final bool emailNotifications;
  final TimeOfDay digestTime;

  // 개인정보 설정
  final bool analyticsEnabled;
  final bool crashReporting;

  // 캐시 설정
  final bool autoDownload;
  final bool wifiOnlyDownload;
  final int maxCacheSize; // MB 단위

  // 기타 설정
  final String language;
  final bool autoRefresh;
  final int refreshInterval; // 분 단위

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.useDynamicColors = true,
    this.fontScale = 1.0,
    this.customSeedColor,
    this.useHighContrast = false,
    this.pushNotifications = true,
    this.breakingNewsAlerts = true,
    this.dailyDigest = false,
    this.emailNotifications = false,
    this.digestTime = const TimeOfDay(hour: 8, minute: 0),
    this.analyticsEnabled = true,
    this.crashReporting = true,
    this.autoDownload = true,
    this.wifiOnlyDownload = true,
    this.maxCacheSize = 500,
    this.language = 'ko',
    this.autoRefresh = true,
    this.refreshInterval = 30,
  });

  /// 설정 복사 (불변성 유지)
  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? useDynamicColors,
    double? fontScale,
    Color? customSeedColor,
    bool? useHighContrast,
    bool? pushNotifications,
    bool? breakingNewsAlerts,
    bool? dailyDigest,
    bool? emailNotifications,
    TimeOfDay? digestTime,
    bool? analyticsEnabled,
    bool? crashReporting,
    bool? autoDownload,
    bool? wifiOnlyDownload,
    int? maxCacheSize,
    String? language,
    bool? autoRefresh,
    int? refreshInterval,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      useDynamicColors: useDynamicColors ?? this.useDynamicColors,
      fontScale: fontScale ?? this.fontScale,
      customSeedColor: customSeedColor ?? this.customSeedColor,
      useHighContrast: useHighContrast ?? this.useHighContrast,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      breakingNewsAlerts: breakingNewsAlerts ?? this.breakingNewsAlerts,
      dailyDigest: dailyDigest ?? this.dailyDigest,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      digestTime: digestTime ?? this.digestTime,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      crashReporting: crashReporting ?? this.crashReporting,
      autoDownload: autoDownload ?? this.autoDownload,
      wifiOnlyDownload: wifiOnlyDownload ?? this.wifiOnlyDownload,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      language: language ?? this.language,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  /// JSON으로 직렬화
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'useDynamicColors': useDynamicColors,
      'fontScale': fontScale,
      'customSeedColor': customSeedColor?.toARGB32(),
      'useHighContrast': useHighContrast,
      'pushNotifications': pushNotifications,
      'breakingNewsAlerts': breakingNewsAlerts,
      'dailyDigest': dailyDigest,
      'emailNotifications': emailNotifications,
      'digestTimeHour': digestTime.hour,
      'digestTimeMinute': digestTime.minute,
      'analyticsEnabled': analyticsEnabled,
      'crashReporting': crashReporting,
      'autoDownload': autoDownload,
      'wifiOnlyDownload': wifiOnlyDownload,
      'maxCacheSize': maxCacheSize,
      'language': language,
      'autoRefresh': autoRefresh,
      'refreshInterval': refreshInterval,
    };
  }

  /// JSON에서 역직렬화
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: ThemeMode.values[json['themeMode'] ?? 0],
      useDynamicColors: json['useDynamicColors'] ?? true,
      fontScale: json['fontScale']?.toDouble() ?? 1.0,
      customSeedColor: json['customSeedColor'] != null
          ? Color(json['customSeedColor'])
          : null,
      useHighContrast: json['useHighContrast'] ?? false,
      pushNotifications: json['pushNotifications'] ?? true,
      breakingNewsAlerts: json['breakingNewsAlerts'] ?? true,
      dailyDigest: json['dailyDigest'] ?? false,
      emailNotifications: json['emailNotifications'] ?? false,
      digestTime: TimeOfDay(
        hour: json['digestTimeHour'] ?? 8,
        minute: json['digestTimeMinute'] ?? 0,
      ),
      analyticsEnabled: json['analyticsEnabled'] ?? true,
      crashReporting: json['crashReporting'] ?? true,
      autoDownload: json['autoDownload'] ?? true,
      wifiOnlyDownload: json['wifiOnlyDownload'] ?? true,
      maxCacheSize: json['maxCacheSize'] ?? 500,
      language: json['language'] ?? 'ko',
      autoRefresh: json['autoRefresh'] ?? true,
      refreshInterval: json['refreshInterval'] ?? 30,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppSettings &&
        other.themeMode == themeMode &&
        other.useDynamicColors == useDynamicColors &&
        other.fontScale == fontScale &&
        other.customSeedColor == customSeedColor &&
        other.useHighContrast == useHighContrast &&
        other.pushNotifications == pushNotifications &&
        other.breakingNewsAlerts == breakingNewsAlerts &&
        other.dailyDigest == dailyDigest &&
        other.emailNotifications == emailNotifications &&
        other.digestTime == digestTime &&
        other.analyticsEnabled == analyticsEnabled &&
        other.crashReporting == crashReporting &&
        other.autoDownload == autoDownload &&
        other.wifiOnlyDownload == wifiOnlyDownload &&
        other.maxCacheSize == maxCacheSize &&
        other.language == language &&
        other.autoRefresh == autoRefresh &&
        other.refreshInterval == refreshInterval;
  }

  @override
  int get hashCode {
    return Object.hash(
      themeMode,
      useDynamicColors,
      fontScale,
      customSeedColor,
      useHighContrast,
      pushNotifications,
      breakingNewsAlerts,
      dailyDigest,
      emailNotifications,
      digestTime,
      analyticsEnabled,
      crashReporting,
      autoDownload,
      wifiOnlyDownload,
      maxCacheSize,
      language,
      autoRefresh,
      refreshInterval,
    );
  }

  @override
  String toString() {
    return 'AppSettings('
        'themeMode: $themeMode, '
        'useDynamicColors: $useDynamicColors, '
        'fontScale: $fontScale, '
        'customSeedColor: $customSeedColor, '
        'useHighContrast: $useHighContrast, '
        'pushNotifications: $pushNotifications, '
        'breakingNewsAlerts: $breakingNewsAlerts, '
        'dailyDigest: $dailyDigest, '
        'emailNotifications: $emailNotifications, '
        'digestTime: $digestTime, '
        'analyticsEnabled: $analyticsEnabled, '
        'crashReporting: $crashReporting, '
        'autoDownload: $autoDownload, '
        'wifiOnlyDownload: $wifiOnlyDownload, '
        'maxCacheSize: $maxCacheSize, '
        'language: $language, '
        'autoRefresh: $autoRefresh, '
        'refreshInterval: $refreshInterval'
        ')';
  }
}

/// 설정 카테고리 열거형
enum SettingsCategory {
  theme('테마'),
  notifications('알림'),
  cache('저장소'),
  account('계정'),
  privacy('개인정보'),
  about('앱 정보');

  const SettingsCategory(this.displayName);
  final String displayName;
}

/// 설정 항목 모델
class SettingItem {
  final String key;
  final String title;
  final String? subtitle;
  final IconData icon;
  final SettingsCategory category;
  final SettingType type;
  final dynamic defaultValue;
  final Map<String, dynamic>? options;

  const SettingItem({
    required this.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.category,
    required this.type,
    this.defaultValue,
    this.options,
  });
}

/// 설정 타입 열거형
enum SettingType { toggle, radio, slider, dropdown, action, info }
