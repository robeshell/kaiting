Future<void> initArtworkUriResolver({String? cacheDirectory}) async {}

Uri? resolveArtworkUri(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null) return null;
  return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
}
