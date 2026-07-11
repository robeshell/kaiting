import 'package:flutter/painting.dart';

import 'artwork_image_provider_stub.dart'
    if (dart.library.io) 'artwork_image_provider_io.dart'
    as platform;

ImageProvider<Object>? artworkImageProvider(String? uri) =>
    platform.artworkImageProvider(uri);
