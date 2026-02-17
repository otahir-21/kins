import 'package:flutter/material.dart';

/// Widget that builds different layouts based on screen size.
/// Use for breakpoint-based layouts (e.g. sidebar on tablet).
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 1200 && desktop != null) return desktop!;
    if (width >= 600 && tablet != null) return tablet!;
    return mobile;
  }
}
