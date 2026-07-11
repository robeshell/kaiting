import 'package:flutter/painting.dart';

ImageProvider<Object>? artworkImageProvider(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return NetworkImage(uri.toString());
  }
  return null;
}
