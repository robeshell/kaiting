/// Builds one stable album identity from metadata and the release folder.
///
/// The title alone is not sufficient: unrelated artists often publish albums
/// with the same name. Conversely, a multi-disc release commonly stores each
/// disc in a child folder, so those disc folder names must not split it.
String stableGroupedAlbumId({
  required String sourceId,
  required String albumTitle,
  String? albumArtist,
  bool isCompilation = false,
  String? relativePath,
  int discNumber = 0,
}) {
  final normalizedTitle = normalizedAlbumGroupingText(albumTitle);
  final candidateFolder = normalizedAlbumReleaseFolder(
    relativePath,
    discNumber: discNumber,
  );
  final releaseFolder = _folderIdentifiesAlbum(candidateFolder, normalizedTitle)
      ? candidateFolder
      : '';
  final explicitArtist = _nullableNormalized(albumArtist);
  // A matching release folder is the stronger identity and also lets tracks
  // with one missing ALBUMARTIST tag stay with their tagged siblings.
  final artistKey = releaseFolder.isNotEmpty
      ? ''
      : explicitArtist ?? (isCompilation ? 'various-artists' : '');
  final base =
      'album:${Uri.encodeComponent(sourceId)}:${Uri.encodeComponent(normalizedTitle)}';
  if (releaseFolder.isEmpty && artistKey.isEmpty) return base;
  final discriminator = [
    if (releaseFolder.isNotEmpty) 'folder=$releaseFolder',
    if (artistKey.isNotEmpty) 'artist=$artistKey',
  ].join('|');
  return '$base:${Uri.encodeComponent(discriminator)}';
}

/// Returns the directory that represents the release rather than an
/// individual disc. `Album/Disc 1/01.flac` and `Album/CD2/01.flac` therefore
/// resolve to the same folder key.
String normalizedAlbumReleaseFolder(
  String? relativePath, {
  int discNumber = 0,
}) {
  final value = relativePath?.trim();
  if (value == null || value.isEmpty) return '';
  final parsed = Uri.tryParse(value);
  final rawPath = parsed != null && parsed.hasScheme ? parsed.path : value;
  final segments = rawPath
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .map(_decodePathSegment)
      .toList();
  if (segments.isEmpty) return '';
  segments.removeLast();
  while (segments.isNotEmpty && _isDiscFolder(segments.last, discNumber)) {
    segments.removeLast();
  }
  return segments.map(normalizedAlbumGroupingText).join('/');
}

String normalizedAlbumGroupingText(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

String _decodePathSegment(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return value;
  }
}

bool _isDiscFolder(String value, int discNumber) {
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'^[\[\(【（]\s*|\s*[\]\)】）]$'), '')
      .toLowerCase();
  if (RegExp(
    r'^(?:cd|disc|disk|dvd|part|vol(?:ume)?|碟|盘)\s*[-_. ]*\d+(?:\s*(?:of|/)\s*\d+)?$',
  ).hasMatch(normalized)) {
    return true;
  }
  if (RegExp(r'^第\s*\d+\s*[碟盘]$').hasMatch(normalized)) return true;
  return discNumber > 0 && normalized == '$discNumber';
}

String? _nullableNormalized(String? value) {
  final normalized = value == null ? '' : normalizedAlbumGroupingText(value);
  return normalized.isEmpty ? null : normalized;
}

bool _folderIdentifiesAlbum(String folder, String albumTitle) {
  if (folder.isEmpty || albumTitle.isEmpty) return false;
  final segments = folder.split('/');
  final folderName = _comparableAlbumText(segments.last);
  final title = _comparableAlbumText(albumTitle);
  if (folderName.isEmpty || title.isEmpty) return false;
  return folderName == title ||
      (title.length >= 4 && folderName.contains(title)) ||
      (folderName.length >= 4 && title.contains(folderName));
}

String _comparableAlbumText(String value) => normalizedAlbumGroupingText(
  value,
).replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
