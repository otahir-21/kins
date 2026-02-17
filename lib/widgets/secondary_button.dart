import 'package:flutter/material.dart';
import 'package:kins_app/core/responsive/responsive.dart';

/// Standard secondary button for the app: #EFEFEF background, black text.
/// Always shows the actual button (no loading animation). When disabled/loading,
/// shows grey background. Validate in onPressed and show SnackBar on error
/// (same pattern as phone auth screen). Reusable across auth, forms, and other screens.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  static const double _height = 52;
  static const double _borderRadius = 30;
  static const Color _backgroundColor = Color(0xffEFEFEF);
  static const Color _textColor = Colors.black;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = (onPressed != null) && !isLoading;

    return SizedBox(
      height: _height,
      width: double.infinity,
      child: Material(
        color: enabled ? _backgroundColor : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(_borderRadius),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(_borderRadius),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: Responsive.fontSize(context, 15),
                color: enabled ? _textColor : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
