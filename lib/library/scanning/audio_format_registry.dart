class AudioFormatDefinition {
  const AudioFormatDefinition({
    required this.extension,
    required this.contentType,
    required this.displayName,
    this.mimeAliases = const <String>[],
    this.metadataReaderSupported = true,
  });

  final String extension;
  final String contentType;
  final String displayName;
  final List<String> mimeAliases;

  /// Whether audio_metadata_reader can parse this container directly.
  ///
  /// Raw AAC is indexed through a validated filename fallback. AAC and ALAC
  /// inside M4A use the MP4 metadata parser.
  final bool metadataReaderSupported;
}

const supportedAudioFormats = <AudioFormatDefinition>[
  AudioFormatDefinition(
    extension: '.mp3',
    contentType: 'audio/mpeg',
    displayName: 'MP3',
    mimeAliases: <String>['audio/mp3'],
  ),
  AudioFormatDefinition(
    extension: '.flac',
    contentType: 'audio/flac',
    displayName: 'FLAC',
    mimeAliases: <String>['audio/x-flac'],
  ),
  AudioFormatDefinition(
    extension: '.m4a',
    contentType: 'audio/mp4',
    displayName: 'M4A (AAC/ALAC)',
    mimeAliases: <String>['audio/x-m4a', 'audio/m4a'],
  ),
  AudioFormatDefinition(
    extension: '.aac',
    contentType: 'audio/aac',
    displayName: 'AAC (ADTS)',
    mimeAliases: <String>['audio/x-aac'],
    metadataReaderSupported: false,
  ),
  AudioFormatDefinition(
    extension: '.wav',
    contentType: 'audio/wav',
    displayName: 'WAV',
    mimeAliases: <String>['audio/x-wav', 'audio/vnd.wave'],
  ),
  AudioFormatDefinition(
    extension: '.ogg',
    contentType: 'audio/ogg',
    displayName: 'Ogg Vorbis',
    mimeAliases: <String>['application/ogg'],
  ),
  AudioFormatDefinition(
    extension: '.opus',
    contentType: 'audio/ogg',
    displayName: 'Opus',
    mimeAliases: <String>['audio/opus'],
  ),
];

AudioFormatDefinition? audioFormatForPath(String value) {
  final lowerPath = _pathWithoutQueryOrFragment(value).toLowerCase();
  for (final format in supportedAudioFormats) {
    if (lowerPath.endsWith(format.extension)) return format;
  }
  return null;
}

AudioFormatDefinition? audioFormatForMimeType(String? value) {
  final normalized = value?.split(';').first.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) return null;
  for (final format in supportedAudioFormats) {
    if (format.contentType == normalized ||
        format.mimeAliases.contains(normalized)) {
      return format;
    }
  }
  return null;
}

bool isSupportedAudioPath(String value) => audioFormatForPath(value) != null;

bool isSupportedAudioMimeType(String? value) =>
    audioFormatForMimeType(value) != null;

String? audioContentTypeForPath(String value) =>
    audioFormatForPath(value)?.contentType;

String audioExtensionForPath(String value) =>
    audioFormatForPath(value)?.extension ?? '';

String _pathWithoutQueryOrFragment(String value) {
  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme) return uri.path;
  final queryIndex = value.indexOf('?');
  final fragmentIndex = value.indexOf('#');
  final cutAt = <int>[
    if (queryIndex >= 0) queryIndex,
    if (fragmentIndex >= 0) fragmentIndex,
  ];
  if (cutAt.isEmpty) return value;
  cutAt.sort();
  return value.substring(0, cutAt.first);
}
