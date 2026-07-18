import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/app/theme_preferences.dart';
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
      await preferences.save(violet);

      SoundColors.defaultAccentPreset.apply();
      final restored = await ThemePreferences.load(
        supportDirectory: supportDirectory,
      );

      expect(restored.selectedPreset, same(violet));
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

    expect(restored.selectedPreset, same(SoundColors.defaultAccentPreset));
  });
}
