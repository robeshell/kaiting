import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/app/theme_preferences.dart';
import 'package:sound_player/core/now_playing_style.dart';
import 'package:sound_player/core/sound_theme.dart';

void main() {
  late Directory supportDirectory;

  setUp(() async {
    SoundColors.defaultAccentPreset.apply();
    supportDirectory = await Directory.systemTemp.createTemp(
      'sound-theme-preferences-',
    );
  });

  tearDown(() async {
    SoundColors.defaultAccentPreset.apply();
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test(
    'persists a preset without mutating the live application theme',
    () async {
      final preferences = await ThemePreferences.load(
        supportDirectory: supportDirectory,
      );
      final violet = SoundColors.accentPresets.firstWhere(
        (preset) => preset.id == 'violet',
      );
      await preferences.save(
        accentPreset: violet,
        skinPreset: SoundSkins.deepNight,
        nowPlayingStyle: NowPlayingStyle.vinyl,
      );

      SoundColors.defaultAccentPreset.apply();
      final restored = await ThemePreferences.load(
        supportDirectory: supportDirectory,
      );

      expect(restored.selectedAccentPreset, same(violet));
      expect(restored.selectedSkinPreset, same(SoundSkins.deepNight));
      expect(restored.selectedNowPlayingStyle, NowPlayingStyle.vinyl);
      expect(SoundColors.accent, SoundColors.defaultAccentPreset.accent);
    },
  );

  test('falls back safely when the stored preset is unknown', () async {
    await File(
      '${supportDirectory.path}/theme.json',
    ).writeAsString('{"accentPreset":"missing"}');

    final restored = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );

    expect(
      restored.selectedAccentPreset,
      same(SoundColors.defaultAccentPreset),
    );
    expect(restored.selectedSkinPreset, same(SoundSkins.defaultPreset));
    expect(restored.selectedNowPlayingStyle, NowPlayingStyle.classic);
  });

  test('migrates an accent-only preference to the default skin', () async {
    await File(
      '${supportDirectory.path}/theme.json',
    ).writeAsString('{"accentPreset":"indigo"}');

    final restored = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );

    expect(restored.selectedAccentPreset.id, 'indigo');
    expect(restored.selectedSkinPreset, same(SoundSkins.standard));
    expect(restored.selectedNowPlayingStyle, NowPlayingStyle.classic);
  });

  test('migrates the temporary warm-mist skin identifier', () async {
    await File(
      '${supportDirectory.path}/theme.json',
    ).writeAsString('{"accentPreset":"coral","skinPreset":"warm-mist"}');

    final restored = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );

    expect(restored.selectedSkinPreset, same(SoundSkins.standard));
  });

  test('maps retired now-playing styles onto classic', () async {
    await File('${supportDirectory.path}/theme.json').writeAsString(
      '{"nowPlayingStyle":"cover-focus"}',
    );
    final cover = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );
    expect(cover.selectedNowPlayingStyle, NowPlayingStyle.classic);
    expect(cover.openLyricsByDefault, isFalse);

    await File('${supportDirectory.path}/theme.json').writeAsString(
      '{"nowPlayingStyle":"immersive-lyrics"}',
    );
    final immersive = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );
    expect(immersive.selectedNowPlayingStyle, NowPlayingStyle.classic);
    expect(immersive.openLyricsByDefault, isTrue);
  });

  test('persists open-lyrics-by-default independently of style', () async {
    final preferences = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );
    await preferences.save(
      nowPlayingStyle: NowPlayingStyle.vinyl,
      openLyricsByDefault: true,
    );

    final restored = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );
    expect(restored.selectedNowPlayingStyle, NowPlayingStyle.vinyl);
    expect(restored.openLyricsByDefault, isTrue);
  });

  test('persists and restores a custom accent color', () async {
    final preferences = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );
    final custom = AccentPreset.custom(const Color(0xFF327A74));

    await preferences.save(accentPreset: custom);
    final restored = await ThemePreferences.load(
      supportDirectory: supportDirectory,
    );

    expect(restored.selectedAccentPreset.id, 'custom');
    expect(restored.selectedAccentPreset.name, '自定义');
    expect(restored.selectedAccentPreset.accent, const Color(0xFF327A74));
    expect(
      restored.selectedAccentPreset.accentHover,
      isNot(restored.selectedAccentPreset.accent),
    );
    expect(
      restored.selectedAccentPreset.accentPressed,
      isNot(restored.selectedAccentPreset.accent),
    );
  });
}
