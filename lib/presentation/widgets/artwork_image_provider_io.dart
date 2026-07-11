import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object>? artworkImageProvider(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null) return null;
  if (uri.scheme == 'file') return FileImage(File(uri.toFilePath()));
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return NetworkImage(uri.toString());
  }
  return null;
}
