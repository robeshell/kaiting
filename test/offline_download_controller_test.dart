import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/offline/offline_media_provider.dart';
import 'package:kaiting/presentation/controllers/offline_download_controller.dart';

void main() {
  test(
    'routes tracks to independent providers and aggregates their storage',
    () async {
      final alpha = _MemoryOfflineProvider(
        id: 'alpha',
        displayName: 'Alpha Cloud',
        scheme: 'alpha',
      );
      final beta = _MemoryOfflineProvider(
        id: 'beta',
        displayName: 'Beta Server',
        scheme: 'beta',
      );
      final controller = OfflineDownloadController(providers: [alpha, beta]);
      final alphaTrack = _track('alpha://music/one.flac');
      final betaTrack = _track('beta://library/two.mp3');
      controller.updateLibraryTracks([alphaTrack, betaTrack]);
      await controller.refresh();

      final result = await controller.pinTracks([alphaTrack, betaTrack]);

      expect(result.completed, 2);
      expect(result.failed, 0);
      expect(alpha.pinnedResources, ['alpha://music/one.flac']);
      expect(beta.pinnedResources, ['beta://library/two.mp3']);
      expect(controller.stats.pinnedEntries, 2);
      expect(controller.stats.pinnedBytes, 2048);
      expect(
        controller.offlineItems.map((item) => item.providerLabel).toSet(),
        {'Alpha Cloud', 'Beta Server'},
      );
      controller.dispose();
    },
  );

  test('rejects duplicate provider identifiers', () {
    final first = _MemoryOfflineProvider(
      id: 'remote',
      displayName: 'First',
      scheme: 'first',
    );
    final second = _MemoryOfflineProvider(
      id: 'remote',
      displayName: 'Second',
      scheme: 'second',
    );

    expect(
      () => OfflineDownloadController(providers: [first, second]),
      throwsArgumentError,
    );
  });
}

Track _track(String mediaUri) => Track(
  id: mediaUri,
  title: mediaUri.split('/').last,
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 3),
  source: SourceKind.webDav,
  mediaUri: mediaUri,
);

class _MemoryOfflineProvider implements OfflineMediaProvider {
  _MemoryOfflineProvider({
    required this.id,
    required this.displayName,
    required this.scheme,
  });

  @override
  final String id;

  @override
  final String displayName;

  final String scheme;
  final Map<OfflineMediaReference, OfflineStoredMedia> _items = {};

  List<String> get pinnedResources => [
    for (final item in _items.values) item.reference.resourceId,
  ];

  @override
  bool supports(Track track) =>
      Uri.tryParse(track.mediaUri ?? '')?.scheme == scheme;

  @override
  OfflineMediaReference referenceFor(Track track) =>
      OfflineMediaReference(providerId: id, resourceId: track.mediaUri!);

  @override
  Future<String> pin(
    Track track, {
    OfflineDownloadProgressCallback? onProgress,
  }) async {
    final reference = referenceFor(track);
    onProgress?.call(
      const OfflineDownloadProgress(receivedBytes: 1024, totalBytes: 1024),
    );
    _items[reference] = OfflineStoredMedia(
      reference: reference,
      path: '/offline/${track.id.hashCode}',
      size: 1024,
      pinned: true,
      accessedAt: DateTime.now(),
    );
    return _items[reference]!.path;
  }

  @override
  bool cancel(OfflineMediaReference reference, {bool includePending = false}) =>
      false;

  @override
  Future<bool> remove(OfflineMediaReference reference) async =>
      _items.remove(reference) != null;

  @override
  Future<List<OfflineStoredMedia>> items() async =>
      List.unmodifiable(_items.values);

  @override
  Future<OfflineStorageStats> stats() async => OfflineStorageStats(
    totalBytes: _items.length * 1024,
    pinnedBytes: _items.length * 1024,
    transientBytes: 0,
    totalEntries: _items.length,
    pinnedEntries: _items.length,
  );

  @override
  Future<int> clearAll() async {
    final count = _items.length;
    _items.clear();
    return count;
  }

  @override
  Future<int> clearTransient() async => 0;
}
