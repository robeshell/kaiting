import 'package:flutter/painting.dart';

import '../../library/scanning/artwork_uri.dart';
import 'artwork_image_provider_stub.dart'
    if (dart.library.io) 'artwork_image_provider_io.dart'
    as platform;

/// Call once during bootstrap so the platform can cache the artwork
/// directory path before the first build.
Future<void> initArtworkProvider() => initArtworkUriResolver();

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
