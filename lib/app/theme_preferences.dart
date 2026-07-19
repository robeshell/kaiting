import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/sound_theme.dart';
import '../core/now_playing_style.dart';

class ThemePreferences {
  ThemePreferences._(
    this._file,
    this.selectedAccentPreset,
    this.selectedSkinPreset,
    this.selectedNowPlayingStyle,
    this.openLyricsByDefault,
  );

  final File _file;
  AccentPreset selectedAccentPreset;
  SoundSkinPreset selectedSkinPreset;
  NowPlayingStyle selectedNowPlayingStyle;

  /// When true, the compact now-playing surface opens on the lyrics pane.
  bool openLyricsByDefault;

  /// Kept as a compatibility alias for callers created before skin support.
  AccentPreset get selectedPreset => selectedAccentPreset;

  static Future<ThemePreferences> load({Directory? supportDirectory}) async {
    final dir = supportDirectory ?? await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'theme.json'));
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final accentPresetId = json['accentPreset'] as String?;
        final storedSkinPresetId = json['skinPreset'] as String?;
        final skinPresetId = storedSkinPresetId == 'warm-mist'
            ? SoundSkins.defaultPreset.id
            : storedSkinPresetId;
        AccentPreset? accentPreset;
        if (accentPresetId == 'custom' && json['customAccent'] is int) {
          accentPreset = AccentPreset.custom(
            Color(json['customAccent'] as int),
          );
        }
        for (final p in SoundColors.accentPresets) {
          if (p.id == accentPresetId) {
            accentPreset = p;
            break;
          }
        }
        SoundSkinPreset? skinPreset;
        for (final p in SoundSkins.presets) {
          if (p.id == skinPresetId) {
            skinPreset = p;
            break;
          }
        }
        final styleId = json['nowPlayingStyle'] as String?;
        final openLyrics = json.containsKey('openLyricsByDefault')
            ? json['openLyricsByDefault'] == true
            : openLyricsByDefaultFromLegacyStyleId(styleId);
        return ThemePreferences._(
          file,
          accentPreset ?? SoundColors.defaultAccentPreset,
          skinPreset ?? SoundSkins.defaultPreset,
          nowPlayingStyleFromId(styleId),
          openLyrics,
        );
      }
    } catch (_) {
      // Corrupted file — fall back to the original Reverie appearance.
    }
    return ThemePreferences._(
      file,
      SoundColors.defaultAccentPreset,
      SoundSkins.defaultPreset,
      NowPlayingStyle.classic,
      false,
    );
  }

  Future<void> save({
    AccentPreset? accentPreset,
    SoundSkinPreset? skinPreset,
    NowPlayingStyle? nowPlayingStyle,
    bool? openLyricsByDefault,
  }) async {
    final nextAccent = accentPreset ?? selectedAccentPreset;
    final nextSkin = skinPreset ?? selectedSkinPreset;
    final nextNowPlayingStyle = nowPlayingStyle ?? selectedNowPlayingStyle;
    final nextOpenLyrics = openLyricsByDefault ?? this.openLyricsByDefault;
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({
        'accentPreset': nextAccent.id,
        if (nextAccent.id == 'custom')
          'customAccent': nextAccent.accent.toARGB32(),
        'skinPreset': nextSkin.id,
        'nowPlayingStyle': nextNowPlayingStyle.id,
        'openLyricsByDefault': nextOpenLyrics,
      }),
      flush: true,
    );
    selectedAccentPreset = nextAccent;
    selectedSkinPreset = nextSkin;
    selectedNowPlayingStyle = nextNowPlayingStyle;
    this.openLyricsByDefault = nextOpenLyrics;
  }
}
