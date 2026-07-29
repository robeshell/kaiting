import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

String? _artworkCacheDirectory;

Future<void> initArtworkUriResolver({String? cacheDirectory}) async {
  if (cacheDirectory != null) {
    _artworkCacheDirectory = cacheDirectory;
    return;
  }
  final support = await getApplicationSupportDirectory();
  _artworkCacheDirectory = p.join(support.path, 'sound_artwork');
}

Uri? resolveArtworkUri(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;

  final parsed = Uri.tryParse(normalized);
  if (parsed != null &&
      (parsed.scheme == 'http' ||
          parsed.scheme == 'https' ||
          parsed.scheme == 'content')) {
    return parsed;
  }
  if (parsed != null && parsed.scheme == 'file') {
    final original = File.fromUri(parsed);
    if (original.existsSync()) return parsed;
    return _currentCacheUri(p.basename(parsed.path));
  }
  if (parsed != null && parsed.hasScheme) return null;
  return _currentCacheUri(normalized);
}

Uri? _currentCacheUri(String filename) {
  if (filename.isEmpty ||
      filename != p.basename(filename) ||
      filename.contains('/') ||
      filename.contains(r'\') ||
      !filename.contains('.')) {
    return null;
  }
  final cacheDirectory = _artworkCacheDirectory;
  if (cacheDirectory == null) return null;
  return File(p.join(cacheDirectory, filename)).uri;
}
