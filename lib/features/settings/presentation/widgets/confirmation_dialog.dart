import 'package:flutter/material.dart';

/// 파괴적 작업에 대한 재사용 가능한 확인 다이얼로그
/// 
/// 기능:
/// - Material 3 디자인과 적절한 테마 적용
/// - 파괴적 및 비파괴적 작업 지원
/// - 커스터마이징 가능한 제목, 내용, 액션 레이블
/// - 시각적 컨텍스트를 위한 아이콘 지원
/// - 앱 전체에서 일관된 스타일링
class ConfirmationDialog extends StatelessWidget {
  /// 다이얼로그 제목
  final String title;
  
  /// 다이얼로그 내용/메시지
  final String content;
  
  /// 확인 버튼 텍스트
  final String confirmText;
  
  /// 취소 버튼 텍스트
  final String cancelText;
  
  /// 파괴적 작업 여부 (오류 색상 사용)
  final bool isDestructive;
  
  /// 표시할 선택적 아이콘
  final IconData? icon;
  
  /// 내용 영역에 표시할 추가 위젯들
  final List<Widget>? additionalContent;
  
  /// 커스텀 확인 버튼 색상
  final Color? confirmButtonColor;
  
  /// 커스텀 확인 텍스트 색상
  final Color? confirmTextColor;
  
  /// 배경 터치로 닫기 가능 여부
  final bool barrierDismissible;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '확인',
    this.cancelText = '취소',
    this.isDestructive = false,
    this.icon,
    this.additionalContent,
    this.confirmButtonColor,
    this.confirmTextColor,
    this.barrierDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final effectiveConfirmButtonColor = confirmButtonColor ?? 
        (isDestructive ? colorScheme.error : colorScheme.primary);
    
    final effectiveConfirmTextColor = confirmTextColor ?? 
        (isDestructive ? colorScheme.onError : colorScheme.onPrimary);

    return AlertDialog(
      icon: icon != null ? Icon(
        icon,
        color: isDestructive ? colorScheme.error : colorScheme.primary,
        size: 28,
      ) : null,
      title: Text(
        title,
        style: textTheme.headlineSmall?.copyWith(
          color: isDestructive ? colorScheme.error : colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (additionalContent != null) ...[
            const SizedBox(height: 16),
            ...additionalContent!,
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: effectiveConfirmButtonColor,
            foregroundColor: effectiveConfirmTextColor,
          ),
          child: Text(confirmText),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  /// 확인 다이얼로그 표시
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    String confirmText = '확인',
    String cancelText = '취소',
    bool isDestructive = false,
    IconData? icon,
    List<Widget>? additionalContent,
    Color? confirmButtonColor,
    Color? confirmTextColor,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ConfirmationDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        isDestructive: isDestructive,
        icon: icon,
        additionalContent: additionalContent,
        confirmButtonColor: confirmButtonColor,
        confirmTextColor: confirmTextColor,
        barrierDismissible: barrierDismissible,
      ),
    );
  }
}

/// 삭제 작업을 위한 특화된 확인 다이얼로그
class DeleteConfirmationDialog extends StatelessWidget {
  /// 삭제할 항목 유형 (예: "기사", "북마크")
  final String itemType;
  
  /// 선택적 특정 항목 이름
  final String? itemName;
  
  /// 추가 경고 메시지
  final String? warningMessage;
  
  /// 삭제가 영구적인지 여부
  final bool isPermanent;

  const DeleteConfirmationDialog({
    super.key,
    required this.itemType,
    this.itemName,
    this.warningMessage,
    this.isPermanent = true,
  });

  @override
  Widget build(BuildContext context) {
    final itemText = itemName != null ? '"$itemName"' : '이 $itemType';
    final permanentText = isPermanent ? '영구적으로 ' : '';
    
    String content = '$itemText을(를) $permanentText삭제하시겠습니까?';
    
    if (isPermanent) {
      content += ' 이 작업은 되돌릴 수 없습니다.';
    }
    
    if (warningMessage != null) {
      content += '\n\n$warningMessage';
    }

    return ConfirmationDialog(
      title: '${itemName ?? itemType} 삭제',
      content: content,
      confirmText: '삭제',
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
    );
  }

  /// 삭제 확인 다이얼로그 표시
  static Future<bool?> show(
    BuildContext context, {
    required String itemType,
    String? itemName,
    String? warningMessage,
    bool isPermanent = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemType: itemType,
        itemName: itemName,
        warningMessage: warningMessage,
        isPermanent: isPermanent,
      ),
    );
  }
}

/// 데이터 지우기를 위한 특화된 확인 다이얼로그
class ClearDataConfirmationDialog extends StatelessWidget {
  /// 지울 데이터 유형
  final String dataType;
  
  /// 데이터 양 (예: "127 MB", "45개 항목")
  final String? dataAmount;
  
  /// 추가 결과 설명
  final String? consequences;

  const ClearDataConfirmationDialog({
    super.key,
    required this.dataType,
    this.dataAmount,
    this.consequences,
  });

  @override
  Widget build(BuildContext context) {
    String content = '모든 $dataType을(를) 지웁니다';
    
    if (dataAmount != null) {
      content += ' ($dataAmount)';
    }
    
    content += '.';
    
    if (consequences != null) {
      content += '\n\n$consequences';
    }

    return ConfirmationDialog(
      title: '$dataType 지우기',
      content: content,
      confirmText: '지우기',
      isDestructive: true,
      icon: Icons.clear_all,
    );
  }

  /// 데이터 지우기 확인 다이얼로그 표시
  static Future<bool?> show(
    BuildContext context, {
    required String dataType,
    String? dataAmount,
    String? consequences,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ClearDataConfirmationDialog(
        dataType: dataType,
        dataAmount: dataAmount,
        consequences: consequences,
      ),
    );
  }
}

/// 추가 옵션/체크박스가 있는 확인 다이얼로그
class AdvancedConfirmationDialog extends StatefulWidget {
  /// 다이얼로그 제목
  final String title;
  
  /// 다이얼로그 내용/메시지
  final String content;
  
  /// 확인 버튼 텍스트
  final String confirmText;
  
  /// 취소 버튼 텍스트
  final String cancelText;
  
  /// 파괴적 작업 여부
  final bool isDestructive;
  
  /// 표시할 선택적 아이콘
  final IconData? icon;
  
  /// 체크박스 옵션 목록
  final List<CheckboxOption> options;
  
  /// 선택된 옵션으로 다이얼로그 확인 시 콜백
  final Function(Map<String, bool> selectedOptions)? onConfirm;

  const AdvancedConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = '확인',
    this.cancelText = '취소',
    this.isDestructive = false,
    this.icon,
    required this.options,
    this.onConfirm,
  });

  @override
  State<AdvancedConfirmationDialog> createState() => _AdvancedConfirmationDialogState();
}

class _AdvancedConfirmationDialogState extends State<AdvancedConfirmationDialog> {
  late Map<String, bool> _selectedOptions;

  @override
  void initState() {
    super.initState();
    _selectedOptions = {
      for (final option in widget.options) option.key: option.initialValue
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final effectiveConfirmButtonColor = widget.isDestructive 
        ? colorScheme.error 
        : colorScheme.primary;
    
    final effectiveConfirmTextColor = widget.isDestructive 
        ? colorScheme.onError 
        : colorScheme.onPrimary;

    return AlertDialog(
      icon: widget.icon != null ? Icon(
        widget.icon,
        color: widget.isDestructive ? colorScheme.error : colorScheme.primary,
        size: 28,
      ) : null,
      title: Text(
        widget.title,
        style: textTheme.headlineSmall?.copyWith(
          color: widget.isDestructive ? colorScheme.error : colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.content,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (widget.options.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...widget.options.map((option) => CheckboxListTile(
              title: Text(option.title),
              subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
              value: _selectedOptions[option.key] ?? false,
              onChanged: (value) {
                setState(() {
                  _selectedOptions[option.key] = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            )),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            widget.onConfirm?.call(_selectedOptions);
          },
          style: FilledButton.styleFrom(
            backgroundColor: effectiveConfirmButtonColor,
            foregroundColor: effectiveConfirmTextColor,
          ),
          child: Text(widget.confirmText),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

/// 고급 확인 다이얼로그의 체크박스 옵션 모델
class CheckboxOption {
  /// 옵션의 고유 키
  final String key;
  
  /// 옵션의 표시 제목
  final String title;
  
  /// 선택적 부제목/설명
  final String? subtitle;
  
  /// 초기 체크 상태
  final bool initialValue;

  const CheckboxOption({
    required this.key,
    required this.title,
    this.subtitle,
    this.initialValue = false,
  });
}

/// 장시간 실행되는 작업을 위한 간단한 로딩 다이얼로그
class LoadingDialog extends StatelessWidget {
  /// 표시할 로딩 메시지
  final String message;
  
  /// 외부 터치로 닫기 가능 여부
  final bool barrierDismissible;
  
  /// 진행률 (0.0-1.0, null이면 무한 로딩)
  final double? progress;

  const LoadingDialog({
    super.key,
    required this.message,
    this.barrierDismissible = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress != null)
            CircularProgressIndicator(value: progress)
          else
            const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(progress! * 100).round()}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  /// 로딩 다이얼로그 표시
  static Future<void> show(
    BuildContext context, {
    required String message,
    bool barrierDismissible = false,
    double? progress,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LoadingDialog(
        message: message,
        barrierDismissible: barrierDismissible,
        progress: progress,
      ),
    );
  }

  /// 현재 표시된 로딩 다이얼로그 숨기기
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}

/// 성공 메시지 다이얼로그
class SuccessDialog extends StatelessWidget {
  /// 제목
  final String title;
  
  /// 메시지
  final String message;
  
  /// 확인 버튼 텍스트
  final String buttonText;
  
  /// 확인 버튼 콜백
  final VoidCallback? onConfirm;

  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = '확인',
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.check_circle,
        color: colorScheme.primary,
        size: 48,
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm?.call();
          },
          child: Text(buttonText),
        ),
      ],
      actionsAlignment: MainAxisAlignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  /// 성공 다이얼로그 표시
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = '확인',
    VoidCallback? onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => SuccessDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onConfirm: onConfirm,
      ),
    );
  }
}

/// 오류 메시지 다이얼로그
class ErrorDialog extends StatelessWidget {
  /// 제목
  final String title;
  
  /// 오류 메시지
  final String message;
  
  /// 확인 버튼 텍스트
  final String buttonText;
  
  /// 재시도 버튼 표시 여부
  final bool showRetry;
  
  /// 재시도 콜백
  final VoidCallback? onRetry;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonText = '확인',
    this.showRetry = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: colorScheme.error,
        size: 48,
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.error,
        ),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      actions: [
        if (showRetry)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry?.call();
            },
            child: const Text('재시도'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(buttonText),
        ),
      ],
      actionsAlignment: showRetry 
          ? MainAxisAlignment.spaceEvenly 
          : MainAxisAlignment.center,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  /// 오류 다이얼로그 표시
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = '확인',
    bool showRetry = false,
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        showRetry: showRetry,
        onRetry: onRetry,
      ),
    );
  }
}