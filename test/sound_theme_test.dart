import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';

void main() {
  tearDown(SoundColors.defaultAccentPreset.apply);

  test('coral remains the default and presets use the muted palette', () {
    expect(SoundColors.defaultAccentPreset.id, 'coral');
    expect(SoundColors.accentPresets.first, SoundColors.defaultAccentPreset);
    expect(SoundColors.accentPresets.map((preset) => preset.accent), const [
      Color(0xFFFF5A4D),
      Color(0xFFD95770),
      Color(0xFF6673C7),
      Color(0xFF3F9E98),
      Color(0xFFC7842F),
      Color(0xFF8067BC),
    ]);
  });

  test('light theme exposes the approved warm glass tokens', () {
    final theme = SoundTheme.light;
    final glass = theme.extension<SoundGlassTheme>();

    expect(theme.scaffoldBackgroundColor, SoundColors.lightCanvas);
    expect(theme.colorScheme.primary, SoundColors.accent);
    expect(theme.colorScheme.outline.a, closeTo(0.08, 0.005));
    expect(theme.colorScheme.outlineVariant.a, closeTo(0.055, 0.005));
    expect(
      theme.colorScheme.outlineVariant.a,
      lessThan(theme.colorScheme.outline.a),
    );
    expect(glass, isNotNull);
    expect(glass?.surface.a, closeTo(0.72, 0.01));
    expect(glass?.strongSurface.a, closeTo(0.87, 0.01));
    expect(soundChromeSurfaceTransparency, 0.20);
    expect(soundChromeSurfaceOpacity, closeTo(0.80, 0.001));
    expect(glass?.primaryText, const Color(0xFF1C1C22));
    expect(glass?.secondaryText, const Color(0xFF5A5A62));
    expect(glass?.mutedText, const Color(0xFF77747D));
    expect(glass?.blur, 20);
    expect(glass?.strongBlur, 28);
    expect(theme.chipTheme.disabledColor?.a, lessThan(0.04));
    final filledStyle = theme.filledButtonTheme.style!;
    final primaryText = glass!.primaryText;
    expect(
      filledStyle.backgroundColor?.resolve({}),
      primaryText.withValues(alpha: 0.045),
    );
    expect(
      filledStyle.backgroundColor?.resolve({WidgetState.hovered}),
      primaryText.withValues(alpha: 0.075),
    );
    expect(
      filledStyle.backgroundColor?.resolve({WidgetState.pressed}),
      primaryText.withValues(alpha: 0.11),
    );
    expect(filledStyle.foregroundColor?.resolve({}), SoundColors.accent);
    expect(filledStyle.minimumSize?.resolve({}), const Size(36, 36));
    for (final style in [
      filledStyle,
      theme.elevatedButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
    ]) {
      expect(style.shape?.resolve({}), isA<StadiumBorder>());
    }
    expect(theme.outlinedButtonTheme.style?.side?.resolve({}), BorderSide.none);
    expect(theme.chipTheme.side, BorderSide.none);
    expect(
      theme.chipTheme.backgroundColor,
      primaryText.withValues(alpha: 0.025),
    );
    expect(theme.chipTheme.showCheckmark, isFalse);
    expect(
      theme.iconButtonTheme.style?.shape?.resolve({}),
      isA<CircleBorder>(),
    );
    expect(theme.floatingActionButtonTheme.shape, isA<CircleBorder>());
    expect(theme.listTileTheme.shape, const RoundedRectangleBorder());
    expect(
      theme.listTileTheme.selectedTileColor,
      SoundColors.accent.withValues(alpha: 0.035),
    );
    expect(theme.focusColor, primaryText.withValues(alpha: 0.065));
  });

  test(
    'accent presets rebuild theme tokens and choose readable foregrounds',
    () {
      final amber = SoundColors.accentPresets.firstWhere(
        (preset) => preset.id == 'amber',
      );
      amber.apply();

      final theme = SoundTheme.light;

      expect(theme.colorScheme.primary, amber.accent);
      expect(
        theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
        amber.accent,
      );
      expect(theme.sliderTheme.activeTrackColor, amber.accent);
      expect(theme.colorScheme.onPrimary, amber.onAccent);
      expect(
        theme.checkboxTheme.checkColor?.resolve({WidgetState.selected}),
        theme.colorScheme.onPrimary,
      );
      expect(
        theme.switchTheme.thumbColor?.resolve({WidgetState.selected}),
        theme.colorScheme.onPrimary,
      );
    },
  );
}
