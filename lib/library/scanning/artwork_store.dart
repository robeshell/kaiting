import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'image_bytes.dart';

abstract interface class ArtworkStore {
  Future<String?> store({
    required String albumId,
    required List<int> bytes,
    required String mimeType,
  });
}

class FileArtworkStore implements ArtworkStore {
  FileArtworkStore({Future<Directory> Function()? rootDirectory})
    : _rootDirectory = rootDirectory ?? _defaultRootDirectory;

  final Future<Directory> Function() _rootDirectory;

  @override
  Future<String?> store({
    required String albumId,
    required List<int> bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty) return null;
    if (!looksLikeCompleteImageBytes(bytes)) return null;
    final root = await _rootDirectory();
    await root.create(recursive: true);
    final digest = sha1.convert(albumId.codeUnits).toString();
    final ext = _extension(mimeType);
    final filename = '$digest.$ext';
    final file = File(path.join(root.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    // Store only the filename so the artwork survives a container-UUID
    // change across Xcode reinstalls. Relative paths are resolved at load
    // time against the current ApplicationSupport directory.
    return filename;
  }
}

Future<Directory> _defaultRootDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(path.join(support.path, 'sound_artwork'));
}

String _extension(String mimeType) {
  return switch (mimeType.toLowerCase()) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
}
