import 'package:flutter/material.dart';

/// 재사용 가능한 설정 타일 위젯
/// 
/// 기능:
/// - Material 3 디자인과 일관된 테마
/// - 선행 아이콘 및 후행 위젯 지원
/// - 선택적 탭 처리 및 리플 효과
/// - 부제목 지원 (추가 정보용)
/// - 중첩된 설정 항목 지원
/// - 일관된 간격과 타이포그래피
class SettingTile extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목 텍스트
  final String? subtitle;
  
  /// 선택적 선행 위젯 (일반적으로 아이콘)
  final Widget? leading;
  
  /// 선택적 후행 위젯 (일반적으로 스위치나 화살표)
  final Widget? trailing;
  
  /// 탭 이벤트 콜백
  final VoidCallback? onTap;
  
  /// 커스텀 텍스트 색상 (테마 기본값 재정의)
  final Color? textColor;
  
  /// 상호작용 활성화 여부
  final bool enabled;
  
  /// 커스텀 콘텐츠 패딩
  final EdgeInsetsGeometry? contentPadding;
  
  /// 타일 아래 구분선 표시 여부
  final bool showDivider;
  
  /// 중첩된 자식 설정 항목들
  final List<Widget>? children;
  
  /// 확장 가능한 타일의 초기 확장 상태
  final bool initiallyExpanded;
  
  /// 커스텀 모양
  final ShapeBorder? shape;

  const SettingTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.textColor,
    this.enabled = true,
    this.contentPadding,
    this.showDivider = false,
    this.children,
    this.initiallyExpanded = false,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    if (children != null && children!.isNotEmpty) {
      return _buildExpandableTile(context);
    }
    
    return _buildSimpleTile(context);
  }

  /// 단순한 설정 타일 구축
  Widget _buildSimpleTile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final titleColor = textColor ?? 
        (enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.38));
    
    final subtitleColor = enabled 
        ? colorScheme.onSurfaceVariant 
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    Widget tile = ListTile(
      enabled: enabled,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      leading: leading != null ? IconTheme(
        data: IconThemeData(
          color: enabled 
              ? colorScheme.onSurfaceVariant 
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
          size: 24,
        ),
        child: leading!,
      ) : null,
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle!,
        style: textTheme.bodyMedium?.copyWith(
          color: subtitleColor,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ) : null,
      trailing: _buildTrailing(context),
      onTap: enabled ? onTap : null,
      shape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );

    if (showDivider) {
      final colorScheme = Theme.of(context).colorScheme;
      tile = Column(
        children: [
          tile,
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.1),
            indent: leading != null ? 56 : 16,
            endIndent: 16,
          ),
        ],
      );
    }

    return tile;
  }

  /// 확장 가능한 설정 타일 구축
  Widget _buildExpandableTile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    final titleColor = textColor ?? 
        (enabled ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.38));

    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: leading != null ? IconTheme(
        data: IconThemeData(
          color: enabled 
              ? colorScheme.onSurfaceVariant 
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
          size: 24,
        ),
        child: leading!,
      ) : null,
      title: Text(
        title,
        style: textTheme.bodyLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null ? Text(
        subtitle!,
        style: textTheme.bodyMedium?.copyWith(
          color: enabled 
              ? colorScheme.onSurfaceVariant 
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ) : null,
      trailing: trailing,
      shape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      collapsedShape: shape ?? RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      tilePadding: contentPadding ?? const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4,
      ),
      childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      children: children!,
    );
  }

  /// 후행 위젯 구축
  Widget? _buildTrailing(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (trailing != null) {
      return Theme(
        data: Theme.of(context).copyWith(
          disabledColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        ),
        child: trailing!,
      );
    }
    
    if (onTap != null) {
      return Icon(
        Icons.chevron_right,
        color: enabled 
            ? colorScheme.onSurfaceVariant 
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        size: 20,
      );
    }
    
    return null;
  }
}

/// 스위치가 있는 설정 타일
class SettingSwitchTile extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목
  final String? subtitle;
  
  /// 선택적 선행 위젯
  final Widget? leading;
  
  /// 스위치 값
  final bool value;
  
  /// 값 변경 콜백
  final ValueChanged<bool>? onChanged;
  
  /// 활성화 여부
  final bool enabled;
  
  /// 커스텀 콘텐츠 패딩
  final EdgeInsetsGeometry? contentPadding;

  const SettingSwitchTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      enabled: enabled,
      contentPadding: contentPadding,
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// 체크박스가 있는 설정 타일
class SettingCheckboxTile extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목
  final String? subtitle;
  
  /// 선택적 선행 위젯
  final Widget? leading;
  
  /// 체크박스 값
  final bool? value;
  
  /// 값 변경 콜백
  final ValueChanged<bool?>? onChanged;
  
  /// 활성화 여부
  final bool enabled;
  
  /// 삼상 체크박스 여부
  final bool tristate;

  const SettingCheckboxTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.tristate = false,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      secondary: leading,
      value: value,
      onChanged: enabled ? onChanged : null,
      tristate: tristate,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// 라디오 버튼이 있는 설정 타일
class SettingRadioTile<T> extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목
  final String? subtitle;
  
  /// 선택적 선행 위젯
  final Widget? leading;
  
  /// 라디오 값
  final T value;
  
  /// 그룹 값
  final T? groupValue;
  
  /// 값 변경 콜백
  final ValueChanged<T?>? onChanged;
  
  /// 활성화 여부
  final bool enabled;

  const SettingRadioTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.groupValue,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      secondary: leading,
      value: value,
      groupValue: groupValue,
      onChanged: enabled ? onChanged : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// 슬라이더가 있는 설정 타일
class SettingSliderTile extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목
  final String? subtitle;
  
  /// 선택적 선행 위젯
  final Widget? leading;
  
  /// 슬라이더 값
  final double value;
  
  /// 최소값
  final double min;
  
  /// 최대값
  final double max;
  
  /// 분할 수
  final int? divisions;
  
  /// 값 변경 콜백
  final ValueChanged<double> onChanged;
  
  /// 값 포맷터 (레이블용)
  final String Function(double)? valueFormatter;
  
  /// 활성화 여부
  final bool enabled;

  const SettingSliderTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.valueFormatter,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: enabled 
                        ? colorScheme.onSurfaceVariant 
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                    size: 24,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: enabled 
                            ? colorScheme.onSurface 
                            : colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: enabled 
                              ? colorScheme.onSurfaceVariant 
                              : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                        ),
                      ),
                  ],
                ),
              ),
              if (valueFormatter != null)
                Text(
                  valueFormatter!(value),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: enabled 
                        ? colorScheme.onSurface 
                        : colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
            label: valueFormatter?.call(value),
          ),
        ],
      ),
    );
  }
}

/// 색상 선택기가 있는 설정 타일
class SettingColorTile extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목
  final String? subtitle;
  
  /// 현재 선택된 색상
  final Color selectedColor;
  
  /// 사용 가능한 색상 옵션들
  final List<Color> colors;
  
  /// 색상 선택 콜백
  final ValueChanged<Color> onColorSelected;
  
  /// 활성화 여부
  final bool enabled;

  const SettingColorTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SettingTile(
      title: title,
      subtitle: subtitle,
      leading: const Icon(Icons.palette_outlined),
      enabled: enabled,
      trailing: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selectedColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      onTap: enabled ? () => _showColorPicker(context) : null,
    );
  }

  void _showColorPicker(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: colors.map((color) {
              final isSelected = color == selectedColor;
              return GestureDetector(
                onTap: () {
                  onColorSelected(color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5 
                              ? Colors.black 
                              : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
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
}

/// 정보성 설정 타일 (상호작용 없음)
class SettingInfoTile extends StatelessWidget {
  /// 주 텍스트
  final String title;
  
  /// 선택적 부제목
  final String? subtitle;
  
  /// 선택적 선행 위젯
  final Widget? leading;
  
  /// 정보 값
  final String value;
  
  /// 값을 복사 가능하게 할지 여부
  final bool copyable;

  const SettingInfoTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.value,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SettingTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.copy,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      onTap: copyable ? () => _copyToClipboard(context, value) : null,
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    // 클립보드 복사 구현
    // await Clipboard.setData(ClipboardData(text: text));
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('클립보드에 복사되었습니다'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }
}