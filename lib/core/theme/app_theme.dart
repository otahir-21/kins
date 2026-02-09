import 'package:flutter/material.dart';

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
