import 'package:flutter/material.dart';

/// 설정 섹션 위젯 - 관련 설정들을 그룹화하는 카드 기반 컨테이너
/// 
/// 기능:
/// - Material 3 디자인 카드 스타일
/// - 섹션 제목과 아이콘 표시
/// - 중첩 가능한 설정 항목들
/// - 일관된 간격과 스타일링
class SettingSection extends StatelessWidget {
  /// 섹션 제목
  final String title;
  
  /// 섹션 아이콘
  final IconData icon;
  
  /// 섹션 내 설정 항목들
  final List<Widget> children;
  
  /// 초기 확장 상태 (확장 가능한 섹션의 경우)
  final bool initiallyExpanded;
  
  /// 확장 가능 여부
  final bool isExpandable;
  
  /// 커스텀 배경색
  final Color? backgroundColor;
  
  /// 커스텀 패딩
  final EdgeInsetsGeometry? padding;

  const SettingSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
    this.isExpandable = false,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isExpandable) {
      return Card(
        color: backgroundColor,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            leading: Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
            title: Text(
              title,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 4,
            ),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            children: [
              Padding(
                padding: padding ?? const EdgeInsets.symmetric(horizontal: 8),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: backgroundColor,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(
          icon,
          color: colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

/// 간단한 설정 그룹 위젯 (카드 없이)
class SettingGroup extends StatelessWidget {
  /// 그룹 제목
  final String? title;
  
  /// 그룹 내 설정 항목들
  final List<Widget> children;
  
  /// 커스텀 패딩
  final EdgeInsetsGeometry? padding;
  
  /// 제목 스타일
  final TextStyle? titleStyle;

  const SettingGroup({
    super.key,
    this.title,
    required this.children,
    this.padding,
    this.titleStyle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title!,
                style: titleStyle ?? textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// 구분선이 있는 설정 섹션
class SettingSectionWithDivider extends StatelessWidget {
  /// 섹션 제목
  final String title;
  
  /// 섹션 아이콘
  final IconData icon;
  
  /// 섹션 내 설정 항목들
  final List<Widget> children;
  
  /// 구분선 표시 여부
  final bool showDivider;
  
  /// 구분선 들여쓰기
  final double dividerIndent;

  const SettingSectionWithDivider({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.showDivider = true,
    this.dividerIndent = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SettingSection(
          title: title,
          icon: icon,
          children: children,
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colorScheme.outline.withValues(alpha: 0.1),
            indent: dividerIndent,
          ),
      ],
    );
  }
}

/// 접을 수 있는 설정 섹션
class CollapsibleSettingSection extends StatefulWidget {
  /// 섹션 제목
  final String title;
  
  /// 섹션 아이콘
  final IconData icon;
  
  /// 섹션 내 설정 항목들
  final List<Widget> children;
  
  /// 초기 확장 상태
  final bool initiallyExpanded;
  
  /// 확장 상태 변경 콜백
  final ValueChanged<bool>? onExpansionChanged;

  const CollapsibleSettingSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  @override
  State<CollapsibleSettingSection> createState() => _CollapsibleSettingSectionState();
}

class _CollapsibleSettingSectionState extends State<CollapsibleSettingSection>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    widget.onExpansionChanged?.call(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        return Card(
          child: Column(
            children: [
              InkWell(
                onTap: _toggleExpansion,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        widget.icon,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.expand_more,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(children: widget.children),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 색상 테마가 적용된 설정 섹션
class ThemedSettingSection extends StatelessWidget {
  /// 섹션 제목
  final String title;
  
  /// 섹션 아이콘
  final IconData icon;
  
  /// 섹션 내 설정 항목들
  final List<Widget> children;
  
  /// 테마 색상
  final Color themeColor;
  
  /// 배경 투명도
  final double backgroundOpacity;

  const ThemedSettingSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    required this.themeColor,
    this.backgroundOpacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    return SettingSection(
      title: title,
      icon: icon,
      children: children,
      backgroundColor: themeColor.withValues(alpha: backgroundOpacity),
    );
  }
}