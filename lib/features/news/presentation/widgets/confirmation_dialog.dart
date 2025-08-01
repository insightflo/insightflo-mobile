import 'package:flutter/material.dart';

/// Reusable confirmation dialog for destructive actions
/// 
/// Features:
/// - Material 3 design with proper theming
/// - Support for destructive and non-destructive actions
/// - Customizable title, content, and action labels
/// - Icon support for visual context
/// - Consistent styling across the app
class ConfirmationDialog extends StatelessWidget {
  /// The dialog title
  final String title;
  
  /// The dialog content/message
  final String content;
  
  /// Text for the confirm button
  final String confirmText;
  
  /// Text for the cancel button
  final String cancelText;
  
  /// Whether this is a destructive action (uses error colors)
  final bool isDestructive;
  
  /// Optional icon to display
  final IconData? icon;
  
  /// Additional widgets to display in the content area
  final List<Widget>? additionalContent;
  
  /// Custom confirm button color
  final Color? confirmButtonColor;
  
  /// Custom confirm text color
  final Color? confirmTextColor;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
    this.icon,
    this.additionalContent,
    this.confirmButtonColor,
    this.confirmTextColor,
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
          color: isDestructive ? colorScheme.error : null,
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
}

/// Specialized confirmation dialog for deletion actions
class DeleteConfirmationDialog extends StatelessWidget {
  /// What is being deleted (e.g., "article", "bookmark")
  final String itemType;
  
  /// Optional specific item name
  final String? itemName;
  
  /// Additional warning message
  final String? warningMessage;
  
  /// Whether the deletion is permanent
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
    final itemText = itemName != null ? '"$itemName"' : 'this $itemType';
    final permanentText = isPermanent ? 'permanently ' : '';
    
    String content = 'Are you sure you want to ${permanentText}delete $itemText?';
    
    if (isPermanent) {
      content += ' This action cannot be undone.';
    }
    
    if (warningMessage != null) {
      content += '\n\n$warningMessage';
    }

    return ConfirmationDialog(
      title: 'Delete ${itemName ?? itemType}',
      content: content,
      confirmText: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever_outlined,
    );
  }
}

/// Specialized confirmation dialog for clearing data
class ClearDataConfirmationDialog extends StatelessWidget {
  /// Type of data being cleared
  final String dataType;
  
  /// Amount of data (e.g., "127 MB", "45 items")
  final String? dataAmount;
  
  /// Additional consequences description
  final String? consequences;

  const ClearDataConfirmationDialog({
    super.key,
    required this.dataType,
    this.dataAmount,
    this.consequences,
  });

  @override
  Widget build(BuildContext context) {
    String content = 'This will clear all $dataType';
    
    if (dataAmount != null) {
      content += ' ($dataAmount)';
    }
    
    content += '.';
    
    if (consequences != null) {
      content += '\n\n$consequences';
    }

    return ConfirmationDialog(
      title: 'Clear $dataType',
      content: content,
      confirmText: 'Clear',
      isDestructive: true,
      icon: Icons.clear_all,
    );
  }
}

/// Confirmation dialog with additional options/checkboxes
class AdvancedConfirmationDialog extends StatefulWidget {
  /// The dialog title
  final String title;
  
  /// The dialog content/message
  final String content;
  
  /// Text for the confirm button
  final String confirmText;
  
  /// Text for the cancel button
  final String cancelText;
  
  /// Whether this is a destructive action
  final bool isDestructive;
  
  /// Optional icon to display
  final IconData? icon;
  
  /// List of checkbox options
  final List<CheckboxOption> options;
  
  /// Callback when dialog is confirmed with selected options
  final Function(Map<String, bool> selectedOptions)? onConfirm;

  const AdvancedConfirmationDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
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
          color: widget.isDestructive ? colorScheme.error : null,
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
              title: Text(
                option.title,
                style: textTheme.bodyMedium,
              ),
              subtitle: option.subtitle != null ? Text(
                option.subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ) : null,
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

/// Model for checkbox options in advanced confirmation dialog
class CheckboxOption {
  /// Unique key for the option
  final String key;
  
  /// Display title for the option
  final String title;
  
  /// Optional subtitle/description
  final String? subtitle;
  
  /// Initial checked state
  final bool initialValue;

  const CheckboxOption({
    required this.key,
    required this.title,
    this.subtitle,
    this.initialValue = false,
  });
}

/// Simple loading dialog for long-running operations
class LoadingDialog extends StatelessWidget {
  /// Loading message to display
  final String message;
  
  /// Whether the dialog can be dismissed by tapping outside
  final bool barrierDismissible;

  const LoadingDialog({
    super.key,
    required this.message,
    this.barrierDismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  /// Show a loading dialog
  static Future<void> show(
    BuildContext context, {
    required String message,
    bool barrierDismissible = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => LoadingDialog(
        message: message,
        barrierDismissible: barrierDismissible,
      ),
    );
  }

  /// Hide the currently shown loading dialog
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}