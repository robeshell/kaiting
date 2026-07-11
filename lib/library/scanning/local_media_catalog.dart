import 'dart:io';

class LocalAudioFile {
  const LocalAudioFile({
    required this.relativePath,
    required this.mediaUri,
    required this.modifiedAt,
    this.contentType,
    this.fileSize,
  });

  final String relativePath;
  final String mediaUri;
  final DateTime modifiedAt;
  final String? contentType;
  final int? fileSize;
}

class PreparedLocalAudioFile {
  PreparedLocalAudioFile(this.file, {this.onRelease});

  final File file;
  final Future<void> Function()? onRelease;
  bool _released = false;

  Future<void> release() async {
    if (_released) return;
    _released = true;
    await onRelease?.call();
  }
}

abstract interface class LocalMediaCatalog {
  Future<List<LocalAudioFile>> listAudioFiles(String rootUri);

  Future<PreparedLocalAudioFile> prepareForMetadata(LocalAudioFile audioFile);
}

bool isSupportedLocalAudioPath(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.mp3') || lower.endsWith('.flac');
}
