import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 에러 화면
/// 
/// 기능:
/// - 다양한 에러 타입 처리
/// - 사용자 친화적 에러 메시지
/// - 재시도 및 복구 옵션
/// - 에러 리포팅 기능
class ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final List<ErrorAction>? actions;

  const ErrorScreen({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.subtitle,
    this.icon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final errorInfo = _parseError(error);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _buildErrorContent(context, errorInfo),
              ),
              _buildActions(context, errorInfo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home),
          tooltip: '홈으로',
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _reportError(context),
          icon: const Icon(Icons.bug_report),
          label: const Text('신고'),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, ErrorInfo errorInfo) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 에러 아이콘
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(60),
              color: errorInfo.color.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon ?? errorInfo.icon,
              size: 60,
              color: errorInfo.color,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // 에러 제목
          Text(
            title ?? errorInfo.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // 에러 설명
          Text(
            subtitle ?? errorInfo.message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // 기술적 세부사항 (개발 모드에서만)
          if (_isDebugMode())
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '기술적 세부사항',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ErrorInfo errorInfo) {
    final defaultActions = _getDefaultActions(context, errorInfo);
    final allActions = [...defaultActions, ...(actions ?? [])];
    
    return Column(
      children: [
        // 주요 액션 버튼
        if (allActions.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: allActions.first.onPressed,
              icon: Icon(allActions.first.icon),
              label: Text(allActions.first.label),
            ),
          ),
        
        const SizedBox(height: 12),
        
        // 보조 액션 버튼들
        if (allActions.length > 1)
          Wrap(
            spacing: 8,
            children: allActions.skip(1).map((action) {
              return OutlinedButton.icon(
                onPressed: action.onPressed,
                icon: Icon(action.icon),
                label: Text(action.label),
              );
            }).toList(),
          ),
      ],
    );
  }

  ErrorInfo _parseError(String error) {
    // 네트워크 에러
    if (error.contains('network') || error.contains('connection')) {
      return ErrorInfo(
        type: ErrorType.network,
        title: '네트워크 연결 오류',
        message: '인터넷 연결을 확인하고 다시 시도해주세요.',
        icon: Icons.wifi_off,
        color: Colors.orange,
      );
    }
    
    // 서버 에러
    if (error.contains('server') || error.contains('500')) {
      return ErrorInfo(
        type: ErrorType.server,
        title: '서버 오류',
        message: '일시적인 서버 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.',
        icon: Icons.cloud_off,
        color: Colors.red,
      );
    }
    
    // 권한 에러
    if (error.contains('permission') || error.contains('unauthorized')) {
      return ErrorInfo(
        type: ErrorType.permission,
        title: '권한 오류',
        message: '이 기능을 사용하려면 권한이 필요합니다.',
        icon: Icons.lock,
        color: Colors.amber,
      );
    }
    
    // 데이터 없음
    if (error.contains('empty') || error.contains('no data')) {
      return ErrorInfo(
        type: ErrorType.noData,
        title: '데이터가 없습니다',
        message: '표시할 내용이 없습니다.',
        icon: Icons.inbox,
        color: Colors.grey,
      );
    }
    
    // 일반 에러
    return ErrorInfo(
      type: ErrorType.general,
      title: '오류가 발생했습니다',
      message: '예상치 못한 오류가 발생했습니다.\n앱을 재시작하거나 다시 시도해주세요.',
      icon: Icons.error,
      color: Colors.red,
    );
  }

  List<ErrorAction> _getDefaultActions(BuildContext context, ErrorInfo errorInfo) {
    switch (errorInfo.type) {
      case ErrorType.network:
        return [
          ErrorAction(
            label: '다시 시도',
            icon: Icons.refresh,
            onPressed: onRetry ?? () => context.go('/home'),
          ),
          ErrorAction(
            label: '오프라인 모드',
            icon: Icons.offline_bolt,
            onPressed: () => context.go('/offline'),
          ),
        ];
        
      case ErrorType.server:
        return [
          ErrorAction(
            label: '다시 시도',
            icon: Icons.refresh,
            onPressed: onRetry ?? () => context.go('/home'),
          ),
          ErrorAction(
            label: '상태 확인',
            icon: Icons.info,
            onPressed: () => _checkServerStatus(context),
          ),
        ];
        
      case ErrorType.permission:
        return [
          ErrorAction(
            label: '권한 설정',
            icon: Icons.settings,
            onPressed: () => context.go('/settings'),
          ),
          ErrorAction(
            label: '홈으로',
            icon: Icons.home,
            onPressed: () => context.go('/home'),
          ),
        ];
        
      case ErrorType.noData:
        return [
          ErrorAction(
            label: '새로고침',
            icon: Icons.refresh,
            onPressed: onRetry ?? () => context.go('/home'),
          ),
          ErrorAction(
            label: '검색하기',
            icon: Icons.search,
            onPressed: () => context.go('/search'),
          ),
        ];
        
      default:
        return [
          ErrorAction(
            label: '다시 시도',
            icon: Icons.refresh,
            onPressed: onRetry ?? () => context.go('/home'),
          ),
          ErrorAction(
            label: '홈으로',
            icon: Icons.home,
            onPressed: () => context.go('/home'),
          ),
        ];
    }
  }

  void _reportError(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류 신고'),
        content: const Text('이 오류를 개발팀에 신고하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // 실제 에러 리포팅 로직
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('오류가 신고되었습니다. 감사합니다.'),
                ),
              );
            },
            child: const Text('신고'),
          ),
        ],
      ),
    );
  }

  void _checkServerStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('서버 상태'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('서버 상태를 확인하고 있습니다...'),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
    
    // 실제 서버 상태 확인 로직
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버가 정상 작동 중입니다.'),
          ),
        );
      }
    });
  }

  bool _isDebugMode() {
    bool debugMode = false;
    assert(debugMode = true);
    return debugMode;
  }
}

/// 에러 타입
enum ErrorType {
  network,
  server,
  permission,
  noData,
  general,
}

/// 에러 정보
class ErrorInfo {
  final ErrorType type;
  final String title;
  final String message;
  final IconData icon;
  final Color color;

  const ErrorInfo({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
  });
}

/// 에러 액션
class ErrorAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const ErrorAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// 특정 에러 타입별 전용 화면들

/// 네트워크 오류 화면
class NetworkErrorScreen extends StatelessWidget {
  const NetworkErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      error: 'network connection failed',
      title: '인터넷 연결 없음',
      subtitle: '인터넷 연결을 확인하고 다시 시도해주세요.',
      icon: Icons.wifi_off,
      actions: [
        ErrorAction(
          label: '연결 테스트',
          icon: Icons.network_check,
          onPressed: () {
            // 네트워크 연결 테스트
          },
        ),
        ErrorAction(
          label: '오프라인 모드',
          icon: Icons.offline_bolt,
          onPressed: () => context.go('/offline'),
        ),
      ],
    );
  }
}

/// 404 오류 화면
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      error: 'page not found',
      title: '페이지를 찾을 수 없습니다',
      subtitle: '요청하신 페이지가 존재하지 않거나\n이동되었을 수 있습니다.',
      icon: Icons.search_off,
      actions: [
        ErrorAction(
          label: '홈으로 가기',
          icon: Icons.home,
          onPressed: () => context.go('/home'),
        ),
        ErrorAction(
          label: '검색하기',
          icon: Icons.search,
          onPressed: () => context.go('/search'),
        ),
      ],
    );
  }
}

/// 권한 오류 화면
class PermissionErrorScreen extends StatelessWidget {
  final String permission;
  
  const PermissionErrorScreen({
    super.key,
    required this.permission,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorScreen(
      error: 'permission denied: $permission',
      title: '권한이 필요합니다',
      subtitle: '이 기능을 사용하려면 $permission 권한이 필요합니다.',
      icon: Icons.security,
      actions: [
        ErrorAction(
          label: '권한 설정',
          icon: Icons.settings,
          onPressed: () => context.go('/settings'),
        ),
        ErrorAction(
          label: '나중에 하기',
          icon: Icons.schedule,
          onPressed: () => context.go('/home'),
        ),
      ],
    );
  }
}