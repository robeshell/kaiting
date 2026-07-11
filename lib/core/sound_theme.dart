import 'package:flutter/material.dart';

abstract final class SoundColors {
  static const accent = Color(0xFFFA243C);
  static const darkCanvas = Color(0xFF0D0D0F);
  static const darkSurface = Color(0xFF17171A);
  static const darkElevated = Color(0xFF202024);
  static const lightCanvas = Color(0xFFF5F3F0);
  static const lightSurface = Color(0xFFFCFBF9);
  static const webDav = Color(0xFF5E8BFF);
  static const local = Color(0xFF55B889);
}

abstract final class SoundTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: SoundColors.accent,
      brightness: Brightness.dark,
      surface: SoundColors.darkSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(
        primary: SoundColors.accent,
        surface: SoundColors.darkSurface,
      ),
      scaffoldBackgroundColor: SoundColors.darkCanvas,
      fontFamily: '.SF Pro Text',
      dividerColor: Colors.white.withValues(alpha: 0.08),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: SoundColors.accent,
      brightness: Brightness.light,
      surface: SoundColors.lightSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme.copyWith(primary: SoundColors.accent),
      scaffoldBackgroundColor: SoundColors.lightCanvas,
      fontFamily: '.SF Pro Text',
    );
  }
}
