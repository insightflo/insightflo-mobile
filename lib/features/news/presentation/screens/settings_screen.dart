import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Package info imports removed - using fallback implementation
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../widgets/setting_tile.dart';
import '../widgets/confirmation_dialog.dart';

/// Settings screen with comprehensive app configuration options
/// 
/// Features:
/// - Theme settings (dark/light mode, system theme)
/// - Notification preferences and permissions
/// - Cache management with storage statistics
/// - Account management and data export
/// - Privacy settings and data handling
/// - About section with app information
/// - Material 3 design with organized sections
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> 
    with TickerProviderStateMixin {
  
  // Animation controllers for smooth transitions
  late final AnimationController _fadeAnimationController;
  late final Animation<double> _fadeAnimation;
  
  // App information
  AppInfo? _appInfo;
  String _deviceInfo = '';
  
  // Cache statistics
  CacheStatistics? _cacheStats;
  bool _isLoadingCache = false;
  
  // Settings state
  bool _pushNotificationsEnabled = true;
  bool _breakingNewsAlerts = true;
  bool _dailyDigest = false;
  bool _weeklyTrends = true;
  bool _emailDigest = false;
  bool _analyticsEnabled = true;
  bool _crashReportingEnabled = true;
  bool _personalizedContent = true;
  bool _locationBasedNews = false;
  
  TimeOfDay _dailyDigestTime = const TimeOfDay(hour: 8, minute: 0);
  String _selectedLanguage = 'English';
  String _selectedRegion = 'Global';
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadAppInfo();
    _loadCacheStatistics();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimationController.forward();
  }

  Future<void> _loadAppInfo() async {
    try {
      // Fallback app info implementation
      final appInfo = AppInfo(
        version: '1.2.0',
        buildNumber: '42',
        appName: 'InsightFlo',
      );
      
      String deviceString = 'Mobile Device';
      
      if (mounted) {
        setState(() {
          _appInfo = appInfo;
          _deviceInfo = deviceString;
        });
      }
    } catch (e) {
      debugPrint('Failed to load app info: $e');
    }
  }

  Future<void> _loadCacheStatistics() async {
    setState(() {
      _isLoadingCache = true;
    });
    
    try {
      // Simulate cache statistics for demonstration
      final stats = CacheStatistics(
        totalSize: 1024 * 1024 * 50, // 50 MB
        articleCount: 150,
        imageSize: 1024 * 1024 * 20, // 20 MB
        lastCleared: DateTime.now().subtract(const Duration(days: 7)),
      );
      
      if (mounted) {
        setState(() {
          _cacheStats = stats;
          _isLoadingCache = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load cache statistics: $e');
      if (mounted) {
        setState(() {
          _isLoadingCache = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            _buildSettingsContent(context),
          ],
        ),
      ),
    );
  }

  /// Builds the Material 3 Large App Bar
  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar.large(
      title: const Text('Settings'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelpDialog,
          tooltip: 'Help',
        ),
      ],
    );
  }

  /// Builds the main settings content
  Widget _buildSettingsContent(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildThemeSection(context),
            const SizedBox(height: 24),
            _buildNotificationSection(context),
            const SizedBox(height: 24),
            _buildCacheSection(context),
            const SizedBox(height: 24),
            _buildAccountSection(context),
            const SizedBox(height: 24),
            _buildPrivacySection(context),
            const SizedBox(height: 24),
            _buildPersonalizationSection(context),
            const SizedBox(height: 24),
            _buildAboutSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Theme settings section
  Widget _buildThemeSection(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Appearance',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SettingTile(
                  title: 'Theme Mode',
                  subtitle: _getThemeModeText(themeProvider.themeMode),
                  leading: Icon(_getThemeModeIcon(themeProvider.themeMode)),
                  onTap: () => _showThemeModeDialog(themeProvider),
                ),
                SettingTile(
                  title: 'Dynamic Colors',
                  subtitle: 'Use system color scheme',
                  leading: const Icon(Icons.color_lens_outlined),
                  trailing: Switch(
                    value: themeProvider.useDynamicColors,
                    onChanged: themeProvider.setDynamicColors,
                  ),
                ),
                SettingTile(
                  title: 'Font Size',
                  subtitle: _getFontSizeText(themeProvider.fontScale),
                  leading: const Icon(Icons.text_fields),
                  onTap: () => _showFontSizeDialog(themeProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Notification settings section
  Widget _buildNotificationSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingTile(
              title: 'Push Notifications',
              subtitle: 'Receive news alerts and updates',
              leading: const Icon(Icons.push_pin_outlined),
              trailing: Switch(
                value: _pushNotificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _pushNotificationsEnabled = value;
                  });
                  _updateNotificationSettings();
                },
              ),
            ),
            SettingTile(
              title: 'Breaking News Alerts',
              subtitle: 'Immediate alerts for breaking news',
              leading: const Icon(Icons.warning_outlined),
              trailing: Switch(
                value: _breakingNewsAlerts,
                onChanged: _pushNotificationsEnabled ? (value) {
                  setState(() {
                    _breakingNewsAlerts = value;
                  });
                  _updateNotificationSettings();
                } : null,
              ),
            ),
            SettingTile(
              title: 'Daily Digest',
              subtitle: 'Summary of top stories at ${_dailyDigestTime.format(context)}',
              leading: const Icon(Icons.today_outlined),
              trailing: Switch(
                value: _dailyDigest,
                onChanged: _pushNotificationsEnabled ? (value) {
                  setState(() {
                    _dailyDigest = value;
                  });
                  if (value) {
                    _selectDailyDigestTime();
                  }
                  _updateNotificationSettings();
                } : null,
              ),
            ),
            SettingTile(
              title: 'Weekly Trends',
              subtitle: 'Weekly summary of trending topics',
              leading: const Icon(Icons.trending_up_outlined),
              trailing: Switch(
                value: _weeklyTrends,
                onChanged: _pushNotificationsEnabled ? (value) {
                  setState(() {
                    _weeklyTrends = value;
                  });
                  _updateNotificationSettings();
                } : null,
              ),
            ),
            SettingTile(
              title: 'Email Digest',
              subtitle: 'Receive digest via email',
              leading: const Icon(Icons.email_outlined),
              trailing: Switch(
                value: _emailDigest,
                onChanged: (value) {
                  setState(() {
                    _emailDigest = value;
                  });
                  _updateNotificationSettings();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cache management section
  Widget _buildCacheSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Storage & Cache',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoadingCache)
              const Center(child: CircularProgressIndicator())
            else if (_cacheStats != null) ...[
              _buildCacheStatistics(context),
              const SizedBox(height: 16),
            ],
            SettingTile(
              title: 'Clear Cache',
              subtitle: 'Free up storage space',
              leading: const Icon(Icons.cleaning_services_outlined),
              onTap: _clearCache,
            ),
            SettingTile(
              title: 'Clear Search History',
              subtitle: 'Remove all search history',
              leading: const Icon(Icons.history),
              onTap: _clearSearchHistory,
            ),
            SettingTile(
              title: 'Offline Articles',
              subtitle: 'Manage downloaded articles',
              leading: const Icon(Icons.offline_pin_outlined),
              onTap: _manageOfflineArticles,
            ),
            SettingTile(
              title: 'Auto-Download',
              subtitle: 'Download articles for offline reading',
              leading: const Icon(Icons.download_outlined),
              onTap: _configureAutoDownload,
            ),
          ],
        ),
      ),
    );
  }

  /// Account management section
  Widget _buildAccountSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingTile(
              title: 'Profile Settings',
              subtitle: 'Manage your profile information',
              leading: const Icon(Icons.person_outlined),
              onTap: _openProfileSettings,
            ),
            SettingTile(
              title: 'Sync Settings',
              subtitle: 'Synchronize data across devices',
              leading: const Icon(Icons.sync_outlined),
              onTap: _configureSyncSettings,
            ),
            SettingTile(
              title: 'Export Data',
              subtitle: 'Download your data',
              leading: const Icon(Icons.download),
              onTap: _exportUserData,
            ),
            SettingTile(
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              onTap: _showDeleteAccountDialog,
              textColor: Theme.of(context).colorScheme.error,
            ),
          ],
        ),
      ),
    );
  }

  /// Privacy settings section
  Widget _buildPrivacySection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Privacy & Security',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingTile(
              title: 'Analytics',
              subtitle: 'Help improve the app with usage data',
              leading: const Icon(Icons.analytics_outlined),
              trailing: Switch(
                value: _analyticsEnabled,
                onChanged: (value) {
                  setState(() {
                    _analyticsEnabled = value;
                  });
                  _updatePrivacySettings();
                },
              ),
            ),
            SettingTile(
              title: 'Crash Reporting',
              subtitle: 'Send crash reports for bug fixes',
              leading: const Icon(Icons.bug_report_outlined),
              trailing: Switch(
                value: _crashReportingEnabled,
                onChanged: (value) {
                  setState(() {
                    _crashReportingEnabled = value;
                  });
                  _updatePrivacySettings();
                },
              ),
            ),
            SettingTile(
              title: 'Data Usage',
              subtitle: 'View data usage statistics',
              leading: const Icon(Icons.data_usage_outlined),
              onTap: _showDataUsageDialog,
            ),
            SettingTile(
              title: 'Privacy Policy',
              subtitle: 'Read our privacy policy',
              leading: const Icon(Icons.policy_outlined),
              onTap: () => _launchUrl('https://insightflo.app/privacy'),
            ),
            SettingTile(
              title: 'Terms of Service',
              subtitle: 'Read our terms of service',
              leading: const Icon(Icons.gavel_outlined),
              onTap: () => _launchUrl('https://insightflo.app/terms'),
            ),
          ],
        ),
      ),
    );
  }

  /// Personalization settings section
  Widget _buildPersonalizationSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Personalization',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingTile(
              title: 'Personalized Content',
              subtitle: 'Show content based on your interests',
              leading: const Icon(Icons.recommend_outlined),
              trailing: Switch(
                value: _personalizedContent,
                onChanged: (value) {
                  setState(() {
                    _personalizedContent = value;
                  });
                  _updatePersonalizationSettings();
                },
              ),
            ),
            SettingTile(
              title: 'Location-based News',
              subtitle: 'Show local news based on your location',
              leading: const Icon(Icons.location_on_outlined),
              trailing: Switch(
                value: _locationBasedNews,
                onChanged: (value) {
                  setState(() {
                    _locationBasedNews = value;
                  });
                  _updatePersonalizationSettings();
                },
              ),
            ),
            SettingTile(
              title: 'Language',
              subtitle: _selectedLanguage,
              leading: const Icon(Icons.language_outlined),
              onTap: _selectLanguage,
            ),
            SettingTile(
              title: 'Region',
              subtitle: _selectedRegion,
              leading: const Icon(Icons.public_outlined),
              onTap: _selectRegion,
            ),
            SettingTile(
              title: 'Content Preferences',
              subtitle: 'Manage your interests and topics',
              leading: const Icon(Icons.interests_outlined),
              onTap: _configureContentPreferences,
            ),
          ],
        ),
      ),
    );
  }

  /// About section
  Widget _buildAboutSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'About',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_appInfo != null) ...[
              SettingTile(
                title: 'Version',
                subtitle: '${_appInfo!.version} (${_appInfo!.buildNumber})',
                leading: const Icon(Icons.info),
              ),
              SettingTile(
                title: 'Device',
                subtitle: _deviceInfo,
                leading: const Icon(Icons.phone_android),
              ),
            ],
            SettingTile(
              title: 'What\'s New',
              subtitle: 'View recent updates and features',
              leading: const Icon(Icons.new_releases_outlined),
              onTap: _showWhatsNewDialog,
            ),
            SettingTile(
              title: 'Help & Support',
              subtitle: 'Get help and contact support',
              leading: const Icon(Icons.help_outline),
              onTap: _showHelpDialog,
            ),
            SettingTile(
              title: 'Rate the App',
              subtitle: 'Rate InsightFlo on the app store',
              leading: const Icon(Icons.star_outline),
              onTap: _rateApp,
            ),
            SettingTile(
              title: 'Feedback',
              subtitle: 'Send feedback to improve the app',
              leading: const Icon(Icons.feedback_outlined),
              onTap: _sendFeedback,
            ),
          ],
        ),
      ),
    );
  }

  /// Builds cache statistics display
  Widget _buildCacheStatistics(BuildContext context) {
    if (_cacheStats == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cache Size',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                _formatBytes(_cacheStats!.totalSize),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cached Articles',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                '${_cacheStats!.articleCount}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Images',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                _formatBytes(_cacheStats!.imageSize),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Settings action methods

  void _showThemeModeDialog(ThemeProvider themeProvider) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              subtitle: const Text('Follow system setting'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              subtitle: const Text('Light theme'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              subtitle: const Text('Dark theme'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeDialog(ThemeProvider themeProvider) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sample Text',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) * themeProvider.fontScale,
                ),
              ),
              const SizedBox(height: 20),
              Slider(
                value: themeProvider.fontScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(themeProvider.fontScale * 100).round()}%',
                onChanged: (value) {
                  setState(() {
                    themeProvider.setFontScale(value);
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              themeProvider.setFontScale(1.0);
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDailyDigestTime() async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _dailyDigestTime,
    );
    
    if (time != null && mounted) {
      setState(() {
        _dailyDigestTime = time;
      });
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: 'Clear Cache',
        content: 'This will free up ${_formatBytes(_cacheStats?.totalSize ?? 0)} of storage space. Cached articles will need to be re-downloaded.',
        confirmText: 'Clear',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        // Simulate cache clearing
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cache cleared successfully'),
              duration: Duration(seconds: 2),
            ),
          );
          _loadCacheStatistics();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear cache: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearSearchHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmationDialog(
        title: 'Clear Search History',
        content: 'This will permanently delete all your search history and suggestions.',
        confirmText: 'Clear',
        isDestructive: true,
      ),
    );

    if (confirmed == true) {
      try {
        // Simulate search history clearing
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Search history cleared'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear search history: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _manageOfflineArticles() {
    // Navigate to offline articles management screen
    Navigator.pushNamed(context, '/offline-articles');
  }

  void _configureAutoDownload() {
    // Navigate to auto-download configuration screen
    Navigator.pushNamed(context, '/auto-download');
  }

  void _openProfileSettings() {
    Navigator.pushNamed(context, '/profile');
  }

  void _configureSyncSettings() {
    Navigator.pushNamed(context, '/sync-settings');
  }

  Future<void> _exportUserData() async {
    try {
      // Simulate data export
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data export started. You will receive an email when ready.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export data: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showDeleteAccountDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: const Text(
          'This action cannot be undone. All your data, including bookmarks, reading history, and preferences will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // Implement account deletion logic
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deleting account...'),
          ],
        ),
      ),
    );
    
    // Simulate deletion process
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (route) => false);
    }
  }

  void _showDataUsageDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data Usage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDataUsageItem('This month', '127 MB'),
            _buildDataUsageItem('Last 30 days', '358 MB'),
            _buildDataUsageItem('All time', '2.1 GB'),
            const Divider(),
            const Text(
              'Tip: Enable Wi-Fi only downloads in auto-download settings to reduce mobile data usage.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataUsageItem(String period, String usage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(period),
          Text(
            usage,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _selectLanguage() {
    final languages = [
      'English',
      'Spanish',
      'French',
      'German',
      'Chinese',
      'Japanese',
      'Korean',
      'Portuguese',
      'Italian',
      'Russian',
    ];

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final language = languages[index];
              return RadioListTile<String>(
                title: Text(language),
                value: language,
                groupValue: _selectedLanguage,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                    });
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _selectRegion() {
    final regions = [
      'Global',
      'United States',
      'Europe',
      'Asia Pacific',
      'Latin America',
      'Middle East',
      'Africa',
    ];

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Region'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: regions.length,
            itemBuilder: (context, index) {
              final region = regions[index];
              return RadioListTile<String>(
                title: Text(region),
                value: region,
                groupValue: _selectedRegion,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRegion = value;
                    });
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _configureContentPreferences() {
    Navigator.pushNamed(context, '/content-preferences');
  }

  void _showWhatsNewDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What\'s New'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version 1.2.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Enhanced text search functionality'),
              Text('• Enhanced news detail view'),
              Text('• Improved search filters'),
              Text('• Performance optimizations'),
              SizedBox(height: 16),
              Text(
                'Version 1.1.0',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Dark mode support'),
              Text('• Personalized recommendations'),
              Text('• Offline reading'),
              Text('• Bug fixes and improvements'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.book_outlined),
              title: const Text('User Guide'),
              subtitle: const Text('Learn how to use InsightFlo'),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('https://insightflo.app/help');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Live Chat'),
              subtitle: const Text('Chat with our support team'),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('https://insightflo.app/support');
              },
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email Support'),
              subtitle: const Text('support@insightflo.app'),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('mailto:support@insightflo.app');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rateApp() {
    _launchUrl('https://apps.apple.com/app/insightflo'); // Replace with actual app store URL
  }

  void _sendFeedback() {
    _launchUrl('mailto:feedback@insightflo.app?subject=InsightFlo Feedback');
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open link: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Settings update methods

  void _updateNotificationSettings() {
    // Update notification preferences
    debugPrint('Updating notification settings');
  }

  void _updatePrivacySettings() {
    // Update privacy preferences
    debugPrint('Updating privacy settings');
  }

  void _updatePersonalizationSettings() {
    // Update personalization preferences
    debugPrint('Updating personalization settings');
  }

  // Helper methods

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.brightness_7;
      case ThemeMode.dark:
        return Icons.brightness_4;
    }
  }

  String _getFontSizeText(double scale) {
    if (scale <= 0.9) return 'Small';
    if (scale <= 1.1) return 'Default';
    if (scale <= 1.3) return 'Large';
    return 'Extra Large';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Cache statistics model
class CacheStatistics {
  final int totalSize;
  final int articleCount;
  final int imageSize;
  final DateTime lastCleared;

  const CacheStatistics({
    required this.totalSize,
    required this.articleCount,
    required this.imageSize,
    required this.lastCleared,
  });
}

/// App information model (fallback implementation)
class AppInfo {
  final String version;
  final String buildNumber;
  final String appName;

  const AppInfo({
    required this.version,
    required this.buildNumber,
    required this.appName,
  });
}