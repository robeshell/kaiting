import 'package:flutter/painting.dart';

import 'artwork_image_provider_stub.dart'
    if (dart.library.io) 'artwork_image_provider_io.dart'
    as platform;

ImageProvider<Object>? artworkImageProvider(
  String? uri, {
  int? cacheWidth,
  int? cacheHeight,
}) {
  final provider = platform.artworkImageProvider(uri);
  if (provider == null || (cacheWidth == null && cacheHeight == null)) {
    return provider;
  }
  return ResizeImage(
    provider,
    width: cacheWidth,
    height: cacheHeight,
    policy: ResizeImagePolicy.fit,
  );
}
