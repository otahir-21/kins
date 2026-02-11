import 'package:flutter/material.dart';
import 'package:kins_app/core/theme/app_design_tokens.dart';

/// Reusable white card container. Use [padding], [constraints], [border], and
/// [boxShadow] to match each screen's current decoration exactly (no visual change).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.constraints,
    this.color = AppDesignTokens.cardColor,
    this.borderRadius = AppDesignTokens.cardBorderRadius,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final Color color;
  final double borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}
