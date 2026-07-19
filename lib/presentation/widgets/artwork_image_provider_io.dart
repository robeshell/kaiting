import 'dart:io';

import 'package:flutter/painting.dart';

import '../../library/scanning/image_bytes.dart';

ImageProvider<Object>? artworkImageProvider(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null) return null;
  if (uri.scheme == 'file') {
    // Prefer File.fromUri so Application%20Support decodes correctly.
    final file = File.fromUri(uri);
    // Missing or truncated caches (deleted after a bad WebDAV pass, etc.)
    // must not create a FileImage that later crashes precacheImage.
    if (!file.existsSync() || !artworkFileLooksValid(uri.toString())) {
      return null;
    }
    return FileImage(file);
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return NetworkImage(uri.toString());
  }
  return null;
}
