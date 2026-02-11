import 'package:flutter/material.dart';

/// Design tokens using current app values. Do not change numeric values
/// so that visual output remains identical to the existing design.
class AppDesignTokens {
  AppDesignTokens._();

  // ----- Card -----
  static const double cardBorderRadius = 40;
  static const Color cardColor = Colors.white;

  /// Shadow used on OTP, User details, Interests cards.
  static List<BoxShadow> get cardShadowStandard => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
      ];

  /// Shadow used on Phone auth SignIn card.
  static List<BoxShadow> get cardShadowSignIn => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];

  // ----- Primary button (black Continue on OTP / About you) -----
  static const double primaryButtonHeight = 52;
  static const double primaryButtonBorderRadius = 26;
  static const double primaryButtonLoaderSize = 24;
  static const double primaryButtonLoaderStrokeWidth = 2;

  // ----- Spacing (for reference; use where refactoring) -----
  static const double spacing8 = 8;
  static const double spacing12 = 12;
  static const double spacing16 = 16;
  static const double spacing20 = 20;
  static const double spacing24 = 24;
  static const double spacing28 = 28;
  static const double horizontalScreenPadding = 24;
}
