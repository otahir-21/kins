import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';

/// A simple confirmation dialog with optional icon, title, message and two actions.
/// Use for logout, delete account, delete post, report, etc. instead of default AlertDialog.
Future<T?> showConfirmDialog<T>({
  required BuildContext context,
  String? title,
  required String message,
  String cancelLabel = 'Cancel',
  required String confirmLabel,
  bool destructive = true,
  IconData? icon,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.destructive,
    this.icon,
  });

  final String? title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;
  final IconData? icon;

  static const double _radius = 24;
  static const double _iconSize = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? Colors.grey.shade900 : Colors.white;
    final onSurface = isDark ? Colors.white : Colors.black87;
    final onSurfaceVariant = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final confirmColor = destructive ? const Color(0xFFB00020) : (isDark ? theme.colorScheme.primary : Colors.black);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: Responsive.screenPaddingH(context) * 2),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(_radius),
        child: Padding(
          padding: EdgeInsets.all(Responsive.spacing(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: _iconSize + 16,
                  height: _iconSize + 16,
                  decoration: BoxDecoration(
                    color: destructive ? confirmColor.withOpacity(0.12) : Colors.grey.shade200,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: _iconSize * 0.6, color: destructive ? confirmColor : onSurfaceVariant),
                ),
                SizedBox(height: Responsive.spacing(context, 16)),
              ],
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: Responsive.fontSize(context, 18),
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: Responsive.spacing(context, 8)),
              ],
              Text(
                message,
                style: TextStyle(
                  fontSize: Responsive.fontSize(context, 14),
                  color: onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Responsive.spacing(context, 24)),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: onSurfaceVariant,
                        padding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  SizedBox(width: Responsive.spacing(context, 12)),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: confirmColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
