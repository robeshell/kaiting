import 'local_media_catalog.dart';

class UnsupportedLocalMediaCatalog implements LocalMediaCatalog {
  const UnsupportedLocalMediaCatalog();

  @override
  Future<List<LocalAudioFile>> listAudioFiles(String rootUri) {
    throw UnsupportedError(
      'Local audio scanning is unsupported on this platform.',
    );
  }

  @override
  Future<PreparedLocalAudioFile> prepareForMetadata(LocalAudioFile audioFile) {
    throw UnsupportedError(
      'Local audio scanning is unsupported on this platform.',
    );
  }
}
