import 'package:flutter/material.dart';

/// Breakpoints for responsive design (width in logical pixels).
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Responsive values based on screen size. Use for padding, spacing, typography.
class Responsive {
  Responsive._();

  /// Screen width (logical pixels).
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Screen height (logical pixels).
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Is mobile (portrait phone, small screens).
  static bool isMobile(BuildContext context) =>
      width(context) < Breakpoints.mobile;

  /// Is tablet or larger.
  static bool isTablet(BuildContext context) =>
      width(context) >= Breakpoints.mobile;

  /// Is desktop or larger.
  static bool isDesktop(BuildContext context) =>
      width(context) >= Breakpoints.desktop;

  /// Is small screen (height < 600) – useful for vertical space.
  static bool isSmallHeight(BuildContext context) =>
      height(context) < 600;

  /// Is compact screen (either width or height constrained).
  static bool isCompact(BuildContext context) =>
      width(context) < Breakpoints.mobile || height(context) < 600;

  /// Horizontal screen padding: 16 compact, 24 mobile, 32 tablet+.
  static double screenPaddingH(BuildContext context) {
    final w = width(context);
    if (w < 400) return 16;
    if (w < Breakpoints.mobile) return 24;
    if (w < Breakpoints.tablet) return 32;
    return 40;
  }

  /// Vertical screen padding.
  static double screenPaddingV(BuildContext context) =>
      isSmallHeight(context) ? 12 : 24;

  /// Max content width for centered layouts (cards, forms): 400 compact, 500 mobile, 600 tablet+.
  static double maxContentWidth(BuildContext context) {
    final w = width(context);
    if (w < 400) return w - 32;
    if (w < Breakpoints.mobile) return 500;
    if (w < Breakpoints.tablet) return 560;
    return 600;
  }

  /// Scale a value: compact = smaller, tablet+ = same or slightly larger.
  static double scale(BuildContext context, double base, {double min = 0, double max = double.infinity}) {
    final w = width(context);
    double factor = 1.0;
    if (w < 400) factor = 0.85;
    else if (w < Breakpoints.mobile) factor = 0.92;
    else if (w >= Breakpoints.desktop) factor = 1.1;
    final value = base * factor;
    return value.clamp(min, max);
  }

  /// Font size that scales: compact = smaller.
  static double fontSize(BuildContext context, double base) =>
      scale(context, base, min: base * 0.8, max: base * 1.2);

  /// Spacing that scales with screen size.
  static double spacing(BuildContext context, double base) =>
      scale(context, base, min: base * 0.75);
}
