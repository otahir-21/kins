import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_design_tokens.dart';

/// Primary action button matching OTP and About you screens: height 52,
/// radius 26, black when enabled, grey when disabled, optional loading state.
/// [loadingColor] defaults to black (OTP); use Colors.grey.shade600 for User details.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.loadingColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final Color? loadingColor;

  static const double _height = AppDesignTokens.primaryButtonHeight;
  static const double _borderRadius = AppDesignTokens.primaryButtonBorderRadius;
  static const double _loaderSize = AppDesignTokens.primaryButtonLoaderSize;
  static const double _loaderStrokeWidth = AppDesignTokens.primaryButtonLoaderStrokeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final enabled = (onPressed != null) && !isLoading;

    return SizedBox(
      height: _height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? Colors.black : Colors.grey.shade300,
          foregroundColor: enabled ? Colors.white : Colors.grey.shade600,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade600,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: _loaderSize,
                width: _loaderSize,
                child: CircularProgressIndicator(
                  strokeWidth: _loaderStrokeWidth,
                  color: loadingColor ?? Colors.black,
                ),
              )
            : Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : Colors.grey.shade600,
                ),
              ),
      ),
    );
  }
}
