import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../news/presentation/providers/theme_provider.dart';
import '../widgets/edit_profile_dialog.dart';

/// 프로필 화면 - Material 3 디자인
/// 
/// 기능:
/// - 사용자 정보 표시 (Consumer2 패턴)
/// - 계정 설정 메뉴
/// - 앱 설정 메뉴 (테마, 알림 등)
/// - 정보 섹션 (약관, 개인정보처리방침 등)
/// - 로그아웃 확인 다이얼로그
/// - Material 3 Card 기반 섹션 구성
/// - BookmarksScreen 스타일 일관성
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {

  PackageInfo? _packageInfo;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _packageInfo = info;
        });
      }
    } catch (e) {
      debugPrint('패키지 정보 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Consumer2<AuthProvider, ThemeProvider>(
      builder: (context, authProvider, themeProvider, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final user = authProvider.currentUser;

        return Scaffold(
          backgroundColor: colorScheme.surface,
          
          // BookmarksScreen과 동일한 AppBar 스타일
          appBar: AppBar(
            title: const Text(
              '프로필',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: colorScheme.surface,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  // TODO: 설정 화면으로 이동
                  _showSettingsDialog(context, theme, colorScheme);
                },
                tooltip: '설정',
              ),
            ],
          ),
          
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 사용자 정보 카드
                _buildUserInfoCard(user, theme, colorScheme),
                
                const SizedBox(height: 24),
                
                // 계정 설정 섹션
                _buildAccountSection(theme, colorScheme, authProvider),
                
                const SizedBox(height: 16),
                
                // 앱 설정 섹션
                _buildAppSettingsSection(theme, colorScheme, themeProvider),
                
                const SizedBox(height: 16),
                
                // 정보 섹션
                _buildInfoSection(theme, colorScheme),
                
                const SizedBox(height: 32),
                
                // 로그아웃 버튼
                _buildLogoutButton(theme, colorScheme, authProvider),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 사용자 정보 카드
  Widget _buildUserInfoCard(dynamic user, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 프로필 아바타
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                size: 40,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // 사용자 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.email ?? 'guest@insightflo.com',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    user != null 
                        ? '가입일: ${_formatDate(user.createdAt ?? DateTime.now())}'
                        : '게스트 사용자',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 사용자 상태
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: user?.emailConfirmed == true 
                          ? colorScheme.primaryContainer
                          : colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user?.emailConfirmed == true ? '인증됨' : '미인증',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: user?.emailConfirmed == true 
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // 편집 버튼
            IconButton(
              onPressed: () => _showProfileEditDialog(theme, colorScheme),
              icon: Icon(
                Icons.edit_outlined,
                color: colorScheme.primary,
              ),
              tooltip: '프로필 편집',
            ),
          ],
        ),
      ),
    );
  }

  /// 계정 설정 섹션
  Widget _buildAccountSection(ThemeData theme, ColorScheme colorScheme, AuthProvider authProvider) {
    return _buildSection(
      title: '계정 설정',
      theme: theme,
      colorScheme: colorScheme,
      children: [
        _buildListTile(
          icon: Icons.person_outline,
          title: '프로필 편집',
          subtitle: '개인정보 수정',
          onTap: () => _showProfileEditDialog(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.notifications_outlined,
          title: '알림 설정',
          subtitle: '푸시 알림 및 이메일 설정',
          onTap: () => _showNotificationSettings(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.security_outlined,
          title: '보안 설정',
          subtitle: '비밀번호 변경 및 2단계 인증',
          onTap: () => _showSecuritySettings(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.sync_outlined,
          title: '데이터 동기화',
          subtitle: '북마크 및 설정 동기화',
          onTap: () => _showSyncSettings(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  /// 앱 설정 섹션
  Widget _buildAppSettingsSection(ThemeData theme, ColorScheme colorScheme, ThemeProvider themeProvider) {
    return _buildSection(
      title: '앱 설정',
      theme: theme,
      colorScheme: colorScheme,
      children: [
        _buildListTile(
          icon: Icons.palette_outlined,
          title: '테마 설정',
          subtitle: _getThemeDescription(themeProvider),
          onTap: () => _showThemeSettings(theme, colorScheme, themeProvider),
          theme: theme,
          colorScheme: colorScheme,
          trailing: Icon(
            _getThemeIcon(themeProvider.themeMode),
            color: colorScheme.primary,
          ),
        ),
        
        _buildListTile(
          icon: Icons.language_outlined,
          title: '언어 설정',
          subtitle: '한국어',
          onTap: () => _showLanguageSettings(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.text_fields_outlined,
          title: '글꼴 크기',
          subtitle: _getFontSizeDescription(themeProvider),
          onTap: () => _showFontSizeSettings(theme, colorScheme, themeProvider),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.storage_outlined,
          title: '캐시 관리',
          subtitle: '저장된 기사 및 이미지 관리',
          onTap: () => _showCacheManagement(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  /// 정보 섹션
  Widget _buildInfoSection(ThemeData theme, ColorScheme colorScheme) {
    return _buildSection(
      title: '정보',
      theme: theme,
      colorScheme: colorScheme,
      children: [
        _buildListTile(
          icon: Icons.help_outline,
          title: '도움말',
          subtitle: '사용법 및 FAQ',
          onTap: () => _showHelp(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.description_outlined,
          title: '이용약관',
          subtitle: '서비스 이용약관',
          onTap: () => _showTermsOfService(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.privacy_tip_outlined,
          title: '개인정보처리방침',
          subtitle: '개인정보 수집 및 이용',
          onTap: () => _showPrivacyPolicy(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
        
        _buildListTile(
          icon: Icons.info_outline,
          title: '버전 정보',
          subtitle: _packageInfo != null 
              ? '${_packageInfo!.version} (${_packageInfo!.buildNumber})'
              : '로딩 중...',
          onTap: () => _showVersionInfo(theme, colorScheme),
          theme: theme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  /// 섹션 빌더
  Widget _buildSection({
    required String title,
    required List<Widget> children,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
        
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  /// ListTile 빌더
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
    required ColorScheme colorScheme,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
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
      trailing: trailing ?? Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  /// 로그아웃 버튼
  Widget _buildLogoutButton(ThemeData theme, ColorScheme colorScheme, AuthProvider authProvider) {
    if (!authProvider.isAuthenticated) {
      return const SizedBox.shrink();
    }
    
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutConfirmDialog(theme, colorScheme, authProvider),
        icon: Icon(
          Icons.logout,
          color: colorScheme.error,
        ),
        label: Text(
          '로그아웃',
          style: TextStyle(
            color: colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: colorScheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // 유틸리티 메서드들

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _getThemeDescription(ThemeProvider themeProvider) {
    switch (themeProvider.themeMode) {
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
      case ThemeMode.system:
        return '시스템 설정';
    }
  }

  IconData _getThemeIcon(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String _getFontSizeDescription(ThemeProvider themeProvider) {
    final scale = themeProvider.fontScale;
    if (scale <= 0.9) return '작음';
    if (scale <= 1.1) return '보통';
    if (scale <= 1.3) return '큼';
    return '매우 큼';
  }

  // 다이얼로그 및 액션 메서드들

  Future<void> _showLogoutConfirmDialog(ThemeData theme, ColorScheme colorScheme, AuthProvider authProvider) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await authProvider.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그아웃되었습니다'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그아웃 실패: $e'),
              backgroundColor: colorScheme.error,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _showProfileEditDialog(ThemeData theme, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => const EditProfileDialog(),
    );
  }

  void _showSettingsDialog(BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정'),
        content: const Text('고급 설정 기능은 준비 중입니다.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showThemeSettings(ThemeData theme, ColorScheme colorScheme, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('테마 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeMode.values.map((mode) {
            return RadioListTile<ThemeMode>(
              title: Text(_getThemeDescription(ThemeProvider()..setThemeMode(mode))),
              value: mode,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  void _showFontSizeSettings(ThemeData theme, ColorScheme colorScheme, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('글꼴 크기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('현재: ${_getFontSizeDescription(themeProvider)}'),
            const SizedBox(height: 16),
            Slider(
              value: themeProvider.fontScale,
              min: 0.8,
              max: 1.4,
              divisions: 6,
              label: _getFontSizeDescription(themeProvider),
              onChanged: (value) {
                themeProvider.setFontScale(value);
              },
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 나머지 다이얼로그 메서드들 (준비중 표시)
  void _showNotificationSettings(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('알림 설정');
  }

  void _showSecuritySettings(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('보안 설정');
  }

  void _showSyncSettings(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('데이터 동기화');
  }

  void _showLanguageSettings(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('언어 설정');
  }

  void _showCacheManagement(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('캐시 관리');
  }

  void _showHelp(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('도움말');
  }

  void _showTermsOfService(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('이용약관');
  }

  void _showPrivacyPolicy(ThemeData theme, ColorScheme colorScheme) {
    _showComingSoonDialog('개인정보처리방침');
  }

  void _showVersionInfo(ThemeData theme, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('버전 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('앱 이름: ${_packageInfo?.appName ?? 'InsightFlo'}'),
            Text('버전: ${_packageInfo?.version ?? '1.0.0'}'),
            Text('빌드: ${_packageInfo?.buildNumber ?? '1'}'),
            Text('패키지명: ${_packageInfo?.packageName ?? 'com.insightflo.app'}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature 기능은 준비 중입니다.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}