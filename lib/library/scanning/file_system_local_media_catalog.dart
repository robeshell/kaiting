import 'dart:io';

import 'package:path/path.dart' as path;

import 'audio_format_registry.dart';
import 'local_media_catalog.dart';

class FileSystemLocalMediaCatalog implements LocalMediaCatalog {
  @override
  Future<List<LocalAudioFile>> listAudioFiles(String rootUri) async {
    final uri = Uri.parse(rootUri);
    if (uri.scheme != 'file') {
      throw ArgumentError.value(rootUri, 'rootUri', 'Expected a file URI.');
    }
    final root = Directory(uri.toFilePath(windows: Platform.isWindows));
    if (!await root.exists()) {
      throw FileSystemException('Music directory is unavailable.', root.path);
    }

    final files = <LocalAudioFile>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File || !isSupportedLocalAudioPath(entity.path)) continue;
      final stat = await entity.stat();
      final relativePath = path
          .relative(entity.path, from: root.path)
          .replaceAll('\\', '/');
      files.add(
        LocalAudioFile(
          relativePath: relativePath,
          mediaUri: entity.uri.toString(),
          modifiedAt: stat.modified.toUtc(),
          contentType: audioContentTypeForPath(entity.path),
          fileSize: stat.size,
        ),
      );
    }
    files.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );
    return files;
  }

  @override
  Future<PreparedLocalAudioFile> prepareForMetadata(
    LocalAudioFile audioFile,
  ) async {
    final uri = Uri.parse(audioFile.mediaUri);
    if (uri.scheme != 'file') {
      throw ArgumentError.value(
        audioFile.mediaUri,
        'mediaUri',
        'Expected a file URI.',
      );
    }
    return PreparedLocalAudioFile(
      File(uri.toFilePath(windows: Platform.isWindows)),
    );
  }
}
