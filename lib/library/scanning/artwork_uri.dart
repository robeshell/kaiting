import 'artwork_uri_stub.dart'
    if (dart.library.io) 'artwork_uri_io.dart'
    as platform;

/// Initializes resolution of relocatable artwork cache keys.
///
/// Production callers omit [cacheDirectory]. Tests with an isolated artwork
/// store can provide its root explicitly.
Future<void> initArtworkUriResolver({String? cacheDirectory}) =>
    platform.initArtworkUriResolver(cacheDirectory: cacheDirectory);

/// Resolves an artwork key to a URI understood by image codecs and system
/// media controls.
///
/// Current records use a cache-relative filename so they survive application
/// container UUID changes. Older absolute file URIs and remote HTTP(S) artwork
/// remain supported.
Uri? resolveArtworkUri(String? value) => platform.resolveArtworkUri(value);
