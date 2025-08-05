import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insightflo_app/features/news/presentation/providers/theme_provider.dart';

/// 독립적인 설정 화면 - 핵심 기능만 포함
///
/// 기능:
/// - FCM 알림 설정 (푸시 알림 토글)
/// - 테마 선택 (라이트/다크/시스템)
/// - 언어 설정 (한국어/English)
/// - 캐시 관리 (크기 표시 및 삭제 기능)
/// - Material 3 디자인 적용
class IndependentSettingsScreen extends StatefulWidget {
  const IndependentSettingsScreen({super.key});

  @override
  State<IndependentSettingsScreen> createState() =>
      _IndependentSettingsScreenState();
}

class _IndependentSettingsScreenState extends State<IndependentSettingsScreen> {
  // 설정 상태
  bool _fcmNotificationsEnabled = true;
  String _selectedLanguage = 'ko';

  // 캐시 정보
  String _cacheSize = '계산 중...';
  bool _isCalculatingCache = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _calculateCacheSize();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fcmNotificationsEnabled = prefs.getBool('fcm_notifications') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'ko';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fcm_notifications', _fcmNotificationsEnabled);
    await prefs.setString('selected_language', _selectedLanguage);
  }

  Future<void> _calculateCacheSize() async {
    setState(() {
      _isCalculatingCache = true;
    });

    try {
      // 캐시 크기 계산 시뮬레이션 (실제로는 앱 캐시 디렉토리 크기 계산)
      await Future.delayed(const Duration(seconds: 1));

      // 시뮬레이션된 캐시 크기 (실제로는 Directory 크기 계산)
      const simulatedCacheSize = 47 * 1024 * 1024; // 47MB

      setState(() {
        _cacheSize = _formatBytes(simulatedCacheSize);
        _isCalculatingCache = false;
      });
    } catch (e) {
      setState(() {
        _cacheSize = '계산 실패';
        _isCalculatingCache = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 알림 설정 섹션
                _buildSectionCard(
                  title: '알림 설정',
                  icon: Icons.notifications_outlined,
                  theme: theme,
                  colorScheme: colorScheme,
                  children: [
                    _buildSwitchTile(
                      title: 'FCM 푸시 알림',
                      subtitle: '속보 및 중요 뉴스 알림 수신',
                      icon: Icons.push_pin_outlined,
                      value: _fcmNotificationsEnabled,
                      onChanged: (value) async {
                        setState(() {
                          _fcmNotificationsEnabled = value;
                        });
                        await _saveSettings();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'FCM 알림이 활성화되었습니다'
                                    : 'FCM 알림이 비활성화되었습니다',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 테마 설정 섹션
                _buildSectionCard(
                  title: '테마 설정',
                  icon: Icons.palette_outlined,
                  theme: theme,
                  colorScheme: colorScheme,
                  children: [
                    _buildTapTile(
                      title: '테마 모드',
                      subtitle: _getThemeModeText(themeProvider.themeMode),
                      icon: _getThemeModeIcon(themeProvider.themeMode),
                      onTap: () => _showThemeModeDialog(themeProvider),
                      theme: theme,
                      colorScheme: colorScheme,
                    ),

                    _buildSwitchTile(
                      title: '다이나믹 컬러',
                      subtitle: '시스템 색상 구성표 사용',
                      icon: Icons.color_lens_outlined,
                      value: themeProvider.useDynamicColors,
                      onChanged: themeProvider.setDynamicColors,
                      theme: theme,
                      colorScheme: colorScheme,
                    ),

                    _buildTapTile(
                      title: '글꼴 크기',
                      subtitle: _getFontSizeText(themeProvider.fontScale),
                      icon: Icons.text_fields_outlined,
                      onTap: () => _showFontSizeDialog(themeProvider),
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 언어 설정 섹션
                _buildSectionCard(
                  title: '언어 설정',
                  icon: Icons.language_outlined,
                  theme: theme,
                  colorScheme: colorScheme,
                  children: [
                    _buildTapTile(
                      title: '언어',
                      subtitle: _getLanguageText(_selectedLanguage),
                      icon: Icons.translate_outlined,
                      onTap: () => _showLanguageDialog(),
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 캐시 관리 섹션
                _buildSectionCard(
                  title: '캐시 관리',
                  icon: Icons.storage_outlined,
                  theme: theme,
                  colorScheme: colorScheme,
                  children: [
                    // 캐시 크기 표시
                    _buildInfoTile(
                      title: '캐시 크기',
                      subtitle: _isCalculatingCache ? '계산 중...' : _cacheSize,
                      icon: Icons.folder_outlined,
                      trailing: _isCalculatingCache
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.refresh),
                              onPressed: _calculateCacheSize,
                              tooltip: '다시 계산',
                            ),
                      theme: theme,
                      colorScheme: colorScheme,
                    ),

                    // 캐시 삭제 버튼
                    _buildTapTile(
                      title: '캐시 삭제',
                      subtitle: '임시 파일 및 이미지 캐시 정리',
                      icon: Icons.cleaning_services_outlined,
                      onTap: _isClearingCache ? null : _showCacheClearDialog,
                      theme: theme,
                      colorScheme: colorScheme,
                      trailing: _isClearingCache
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 섹션 카드 빌더
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.onPrimaryContainer,
                    size: 18,
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 섹션 내용
            ...children,
          ],
        ),
      ),
    );
  }

  /// 스위치 타일 빌더
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.onSecondaryContainer, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Switch(value: value, onChanged: onChanged),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  /// 탭 가능한 타일 빌더
  Widget _buildTapTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required ThemeData theme,
    required ColorScheme colorScheme,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.onSecondaryContainer, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing:
            trailing ??
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  /// 정보 표시 타일 빌더
  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeData theme,
    required ColorScheme colorScheme,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: colorScheme.onSecondaryContainer, size: 20),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  // 다이얼로그 메서드들

  /// 테마 모드 선택 다이얼로그
  void _showThemeModeDialog(ThemeProvider themeProvider) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테마 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('시스템 설정'),
              subtitle: const Text('기기 설정을 따름'),
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
              title: const Text('라이트 모드'),
              subtitle: const Text('밝은 테마'),
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
              title: const Text('다크 모드'),
              subtitle: const Text('어두운 테마'),
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
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 글꼴 크기 조절 다이얼로그
  void _showFontSizeDialog(ThemeProvider themeProvider) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('글꼴 크기'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '샘플 텍스트입니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16) *
                      themeProvider.fontScale,
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
              Text(
                '${(themeProvider.fontScale * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall,
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
            child: const Text('기본값'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('완료'),
          ),
        ],
      ),
    );
  }

  /// 언어 선택 다이얼로그
  void _showLanguageDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('언어 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('한국어'),
              subtitle: const Text('Korean'),
              value: 'ko',
              groupValue: _selectedLanguage,
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  await _saveSettings();
                  Navigator.pop(context);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('언어가 변경되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              subtitle: const Text('영어'),
              value: 'en',
              groupValue: _selectedLanguage,
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  await _saveSettings();
                  Navigator.pop(context);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language has been changed'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  /// 캐시 삭제 확인 다이얼로그
  void _showCacheClearDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('캐시 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 캐시 크기: $_cacheSize',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('캐시를 삭제하면 다음 항목들이 제거됩니다:'),
            const SizedBox(height: 8),
            const Text('• 이미지 캐시'),
            const Text('• 임시 파일'),
            const Text('• 웹뷰 캐시'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '삭제된 내용은 복구할 수 없습니다.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCache();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  /// 캐시 삭제 실행
  Future<void> _clearCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      // 캐시 삭제 시뮬레이션 (실제로는 앱 캐시 디렉토리 삭제)
      await Future.delayed(const Duration(seconds: 2));

      // 실제 구현에서는 아래와 같이 캐시를 삭제
      // final cacheDir = await getTemporaryDirectory();
      // if (cacheDir.existsSync()) {
      //   cacheDir.deleteSync(recursive: true);
      // }

      setState(() {
        _cacheSize = '0 B';
        _isClearingCache = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('캐시가 성공적으로 삭제되었습니다'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: '다시 계산',
              onPressed: _calculateCacheSize,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isClearingCache = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('캐시 삭제 실패: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 헬퍼 메서드들

  String _getThemeModeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '시스템 설정';
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
    }
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  String _getFontSizeText(double scale) {
    if (scale <= 0.9) return '작게';
    if (scale <= 1.1) return '기본';
    if (scale <= 1.3) return '크게';
    return '매우 크게';
  }

  String _getLanguageText(String langCode) {
    switch (langCode) {
      case 'ko':
        return '한국어';
      case 'en':
        return 'English';
      default:
        return '한국어';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
