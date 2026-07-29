import 'dart:io';

import 'package:flutter/painting.dart';

import '../../library/scanning/image_bytes.dart';
import '../../library/scanning/artwork_uri.dart';

ImageProvider<Object>? artworkImageProvider(String? value) {
  final uri = resolveArtworkUri(value);
  if (uri == null) return null;
  if (uri.scheme == 'file') {
    final file = File.fromUri(uri);
    if (artworkFileLooksValid(uri.toString())) {
      return FileImage(file);
    }
    return null;
  }
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return NetworkImage(uri.toString());
  }
  return null;
}
