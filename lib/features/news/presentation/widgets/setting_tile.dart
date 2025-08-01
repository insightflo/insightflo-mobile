import 'package:flutter/material.dart';

/// Reusable setting tile widget for consistent settings UI
/// 
/// Features:
/// - Material 3 design with proper theming
/// - Support for leading icons and trailing widgets
/// - Optional tap handling with ripple effects
/// - Subtitle support for additional information
/// - Consistent spacing and typography
class SettingTile extends StatelessWidget {
  /// The primary text to display
  final String title;
  
  /// Optional subtitle text for additional information
  final String? subtitle;
  
  /// Optional leading widget (typically an icon)
  final Widget? leading;
  
  /// Optional trailing widget (typically a switch or chevron)
  final Widget? trailing;
  
  /// Callback for tap events
  final VoidCallback? onTap;
  
  /// Custom text color (overrides theme default)
  final Color? textColor;
  
  /// Whether the tile is enabled for interaction
  final bool enabled;
  
  /// Custom content padding
  final EdgeInsetsGeometry? contentPadding;
  
  /// Whether to show a divider below the tile
  final bool showDivider;

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
  });

  @override
  Widget build(BuildContext context) {
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
          color: enabled ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
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
      trailing: trailing != null ? Theme(
        data: Theme.of(context).copyWith(
          // Ensure trailing widgets use the correct disabled colors
          disabledColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        ),
        child: trailing!,
      ) : (onTap != null ? Icon(
        Icons.chevron_right,
        color: enabled ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
        size: 20,
      ) : null),
      onTap: enabled ? onTap : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );

    if (showDivider) {
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
}

/// Setting tile specifically for categories/sections
class SettingCategoryTile extends StatelessWidget {
  /// The category title
  final String title;
  
  /// Optional category icon
  final IconData? icon;
  
  /// List of child setting tiles
  final List<Widget> children;
  
  /// Whether the category is initially expanded
  final bool initiallyExpanded;
  
  /// Custom background color
  final Color? backgroundColor;

  const SettingCategoryTile({
    super.key,
    required this.title,
    this.icon,
    required this.children,
    this.initiallyExpanded = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: backgroundColor,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: icon != null ? Icon(
          icon,
          color: colorScheme.primary,
        ) : null,
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(
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
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// Setting tile with custom slider control
class SettingSliderTile extends StatelessWidget {
  /// The setting title
  final String title;
  
  /// Optional subtitle
  final String? subtitle;
  
  /// Optional leading icon
  final Widget? leading;
  
  /// Current slider value
  final double value;
  
  /// Minimum slider value
  final double min;
  
  /// Maximum slider value
  final double max;
  
  /// Number of discrete divisions
  final int? divisions;
  
  /// Callback when value changes
  final ValueChanged<double> onChanged;
  
  /// Optional value formatter
  final String Function(double)? valueFormatter;

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
                    color: colorScheme.onSurfaceVariant,
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
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
            onChanged: onChanged,
            label: valueFormatter?.call(value),
          ),
        ],
      ),
    );
  }
}

/// Setting tile with color picker
class SettingColorTile extends StatelessWidget {
  /// The setting title
  final String title;
  
  /// Optional subtitle
  final String? subtitle;
  
  /// Current selected color
  final Color selectedColor;
  
  /// Available color options
  final List<Color> colors;
  
  /// Callback when color is selected
  final ValueChanged<Color> onColorSelected;

  const SettingColorTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SettingTile(
      title: title,
      subtitle: subtitle,
      leading: const Icon(Icons.palette_outlined),
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
      onTap: () => _showColorPicker(context),
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}