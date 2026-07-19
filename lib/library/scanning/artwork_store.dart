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
    // Reject truncated WebDAV/FLAC picture buffers (header present, body
    // zero-padded) before they land in the cache and crash precacheImage.
    if (!looksLikeCompleteImageBytes(bytes)) return null;
    final root = await _rootDirectory();
    await root.create(recursive: true);
    final digest = sha1.convert(albumId.codeUnits).toString();
    final file = File(path.join(root.path, '$digest.${_extension(mimeType)}'));
    await file.writeAsBytes(bytes, flush: true);
    return file.uri.toString();
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
