import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/sound_theme.dart';

class ThemePreferences {
  ThemePreferences._(this._file, this.selectedPreset);

  final File _file;
  AccentPreset selectedPreset;

  static Future<ThemePreferences> load({Directory? supportDirectory}) async {
    final dir = supportDirectory ?? await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'theme.json'));
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final presetId = json['accentPreset'] as String?;
        AccentPreset? preset;
        for (final p in SoundColors.accentPresets) {
          if (p.id == presetId) {
            preset = p;
            break;
          }
        }
        if (preset != null) {
          return ThemePreferences._(file, preset);
        }
      }
    } catch (_) {
      // Corrupted file — fall back to default (rose, already applied).
    }
    return ThemePreferences._(file, SoundColors.defaultAccentPreset);
  }

  Future<void> save(AccentPreset preset) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode({'accentPreset': preset.id}),
      flush: true,
    );
    selectedPreset = preset;
  }
}
