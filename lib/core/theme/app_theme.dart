import 'package:flutter/material.dart';

/// Post/feed typography — use in PostHeader, PostCardText, feed_post_card, PostInteractionBar.
/// Ensures font family comes from theme; keeps design values consistent.
class AppPostTypography extends ThemeExtension<AppPostTypography> {
  final TextStyle headerName;
  final TextStyle headerMeta;
  final TextStyle headerTime;
  final TextStyle postBody;
  final TextStyle postBodySmall;
  final TextStyle pollQuestion;
  final TextStyle pollOption;
  final TextStyle interactionCount;

  const AppPostTypography({
    required this.headerName,
    required this.headerMeta,
    required this.headerTime,
    required this.postBody,
    required this.postBodySmall,
    required this.pollQuestion,
    required this.pollOption,
    required this.interactionCount,
  });

  @override
  AppPostTypography copyWith({
    TextStyle? headerName,
    TextStyle? headerMeta,
    TextStyle? headerTime,
    TextStyle? postBody,
    TextStyle? postBodySmall,
    TextStyle? pollQuestion,
    TextStyle? pollOption,
    TextStyle? interactionCount,
  }) {
    return AppPostTypography(
      headerName: headerName ?? this.headerName,
      headerMeta: headerMeta ?? this.headerMeta,
      headerTime: headerTime ?? this.headerTime,
      postBody: postBody ?? this.postBody,
      postBodySmall: postBodySmall ?? this.postBodySmall,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOption: pollOption ?? this.pollOption,
      interactionCount: interactionCount ?? this.interactionCount,
    );
  }

  @override
  AppPostTypography lerp(ThemeExtension<AppPostTypography>? other, double t) {
    if (other is! AppPostTypography) return this;
    return AppPostTypography(
      headerName: TextStyle.lerp(headerName, other.headerName, t)!,
      headerMeta: TextStyle.lerp(headerMeta, other.headerMeta, t)!,
      headerTime: TextStyle.lerp(headerTime, other.headerTime, t)!,
      postBody: TextStyle.lerp(postBody, other.postBody, t)!,
      postBodySmall: TextStyle.lerp(postBodySmall, other.postBodySmall, t)!,
      pollQuestion: TextStyle.lerp(pollQuestion, other.pollQuestion, t)!,
      pollOption: TextStyle.lerp(pollOption, other.pollOption, t)!,
      interactionCount: TextStyle.lerp(interactionCount, other.interactionCount, t)!,
    );
  }

  static const Color _greyMeta = Color(0xFF8E8E93);

  static AppPostTypography fromBase(TextTheme base) {
    final inherit = base.bodyLarge ?? const TextStyle();
    // Post content text +20% from previous
    return AppPostTypography(
      headerName: inherit.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
      headerMeta: inherit.copyWith(fontSize: 16, fontWeight: FontWeight.w400, color: _greyMeta),
      headerTime: inherit.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: _greyMeta),
      postBody: inherit.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: Colors.black),
      postBodySmall: inherit.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: Colors.black),
      pollQuestion: inherit.copyWith(fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: Colors.black),
      pollOption: inherit.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black),
      interactionCount: inherit.copyWith(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black),
    );
  }
}

/// Standard app fonts: SF Pro on iOS (from assets), Roboto on Android.
class AppFonts {
  /// SF Pro - font files in assets/fonts/
  static const String ios = 'SF Pro';
  /// Material default on Android; no asset needed.
  static const String android = 'Roboto';
}

class AppTheme {
  /// [platformIsIOS] true → SF Pro (iOS), false → Roboto (Android).
  static ThemeData lightTheme({required bool platformIsIOS}) {
    final fontFamily = platformIsIOS ? AppFonts.ios : AppFonts.android;
    final baseTextTheme = _baseTextTheme(fontFamily);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      textTheme: baseTextTheme,
      extensions: [
        AppPostTypography.fromBase(baseTextTheme),
      ],
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.black,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(fontFamily: fontFamily),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black,
        ),
      ),
    );
  }

  static TextTheme _baseTextTheme(String fontFamily) {
    return TextTheme(
      displayLarge: TextStyle(fontFamily: fontFamily),
      displayMedium: TextStyle(fontFamily: fontFamily),
      displaySmall: TextStyle(fontFamily: fontFamily),
      headlineLarge: TextStyle(fontFamily: fontFamily),
      headlineMedium: TextStyle(fontFamily: fontFamily),
      headlineSmall: TextStyle(fontFamily: fontFamily),
      titleLarge: TextStyle(fontFamily: fontFamily),
      titleMedium: TextStyle(fontFamily: fontFamily),
      titleSmall: TextStyle(fontFamily: fontFamily),
      bodyLarge: TextStyle(fontFamily: fontFamily),
      bodyMedium: TextStyle(fontFamily: fontFamily),
      bodySmall: TextStyle(fontFamily: fontFamily),
      labelLarge: TextStyle(fontFamily: fontFamily),
      labelMedium: TextStyle(fontFamily: fontFamily),
      labelSmall: TextStyle(fontFamily: fontFamily),
    );
  }
}
