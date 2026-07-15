import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sound_player/library/scanning/audio_format_registry.dart';
import 'package:sound_player/library/scanning/audio_metadata_fallback.dart';
import 'package:sound_player/library/scanning/audio_metadata_extractor.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/probe_audio_formats.dart <file-or-directory> [...]',
    );
    exitCode = 64;
    return;
  }

  final files = <File>[];
  for (final argument in arguments) {
    final type = await FileSystemEntity.type(argument);
    if (type == FileSystemEntityType.file) {
      files.add(File(argument));
    } else if (type == FileSystemEntityType.directory) {
      await for (final entity in Directory(argument).list(recursive: true)) {
        if (entity is File && isSupportedAudioPath(entity.path)) {
          files.add(entity);
        }
      }
    } else {
      stderr.writeln('Not found: $argument');
      exitCode = 66;
    }
  }
  files.sort((left, right) => left.path.compareTo(right.path));

  const extractor = PackageAudioMetadataExtractor();
  var failures = 0;
  for (final file in files) {
    final format = audioFormatForPath(file.path);
    try {
      final metadata = await extractor.extract(file);
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'file': path.basename(file.path),
          'format': format?.displayName,
          'metadata': 'parsed',
          'title': metadata.title,
          'artist': metadata.artist,
          'album': metadata.album,
          'durationMs': metadata.duration.inMilliseconds,
        }),
      );
    } catch (error) {
      final fallback = await readFilenameMetadataFallback(file, file.path);
      if (fallback != null) {
        stdout.writeln(
          jsonEncode(<String, Object?>{
            'file': path.basename(file.path),
            'format': format?.displayName,
            'metadata': 'filename-fallback',
          }),
        );
      } else {
        failures++;
        stdout.writeln(
          jsonEncode(<String, Object?>{
            'file': path.basename(file.path),
            'format': format?.displayName,
            'metadata': 'failed',
            'error': error.toString(),
          }),
        );
      }
    }
  }
  if (failures > 0) exitCode = 1;
}
