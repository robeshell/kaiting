import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/offline/offline_media_provider.dart';
import 'package:kaiting/playback/playback_media_provider.dart';
import 'package:kaiting/presentation/controllers/offline_download_controller.dart';
import 'package:kaiting/sources/source_provider.dart';

void main() {
  test(
    'a second remote protocol crosses every shared provider boundary',
    () async {
      const type = LibrarySourceType('subsonic');
      const kind = SourceKind('subsonic');
      const definition = SourceProviderDefinition(
        type: type,
        displayName: 'Subsonic',
        addActionLabel: '添加 Subsonic',
        sectionDescription: '音乐服务器',
        capabilities: {
          SourceProviderCapability.connectionManagement,
          SourceProviderCapability.directoryBrowsing,
          SourceProviderCapability.scanning,
          SourceProviderCapability.streaming,
          SourceProviderCapability.offline,
        },
      );
      final connections = _SubsonicConnections();
      final scanner = _SubsonicScanner();
      final sourceRegistry = SourceProviderRegistry([definition]);
      final connectionRegistry = SourceConnectionProviderRegistry([
        connections,
      ]);
      final scanRegistry = SourceScanProviderRegistry([scanner]);
      final playbackRegistry = PlaybackMediaProviderRegistry([
        const _SubsonicPlaybackProvider(),
      ]);
      final offlineController = OfflineDownloadController(
        providers: [_SubsonicOfflineProvider()],
      );
      addTearDown(offlineController.dispose);
      const track = Track(
        id: 'song-1',
        title: 'Song',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 3),
        source: kind,
        mediaUri: 'subsonic://server/song-1',
      );

      final resource = await playbackRegistry.resolve(
        track,
        preferLocalFile: false,
      );
      final scan = await scanRegistry.requireProvider(type).rescan('library-1');
      final browser = await connectionRegistry
          .requireProvider(type)
          .openBrowser('server-1');
      offlineController.updateLibraryTracks(const [track]);
      await offlineController.pinTrack(track);

      expect(sourceRegistry.providerFor(type), definition);
      expect((await connections.watchResources().first).single.type, type);
      expect(scan.indexedTracks, 1);
      expect(
        (await browser.browse(browser.rootId)).single.displayName,
        'Albums',
      );
      expect(resource!.uri.scheme, 'https');
      expect(offlineController.isPinned(track), isTrue);
    },
  );
}

class _SubsonicConnections implements SourceConnectionProvider {
  @override
  LibrarySourceType get type => const LibrarySourceType('subsonic');

  @override
  Stream<List<SourceManagedResource>> watchResources() => Stream.value(const [
    SourceManagedResource(
      id: 'server-1',
      type: LibrarySourceType('subsonic'),
      kind: SourceManagedResourceKind.connection,
      displayName: 'Subsonic Server',
      location: 'subsonic://server',
      status: SourceManagedStatus.available,
    ),
  ]);

  @override
  Future<SourceDirectoryBrowser> openBrowser(String connectionId) async {
    return const _SubsonicBrowser();
  }

  @override
  Future<SourceManagedResource> probe(String connectionId) async {
    return (await watchResources().first).single;
  }

  @override
  Future<void> remove(String resourceId) async {}
}

class _SubsonicScanner implements SourceScanProvider {
  @override
  LibrarySourceType get type => const LibrarySourceType('subsonic');

  @override
  bool cancel(String sourceId) => false;

  @override
  bool isScanning(String sourceId) => false;

  @override
  Future<SourceScanSummary> rescan(String sourceId) async {
    return const SourceScanSummary(indexedTracks: 1, addedTracks: 1);
  }
}

class _SubsonicBrowser implements SourceDirectoryBrowser {
  const _SubsonicBrowser();

  @override
  String get rootId => 'root';

  @override
  Future<List<SourceDirectoryEntry>> browse(String directoryId) async {
    return const [
      SourceDirectoryEntry(
        id: 'albums',
        displayName: 'Albums',
        isDirectory: true,
      ),
    ];
  }
}

class _SubsonicPlaybackProvider implements PlaybackMediaProvider {
  const _SubsonicPlaybackProvider();

  @override
  bool supports(Track track) => track.source == const SourceKind('subsonic');

  @override
  Future<PlaybackMediaResource?> resolve(
    Track track, {
    required bool preferLocalFile,
  }) async {
    return PlaybackMediaResource(
      uri: Uri.parse('https://server/rest/stream?id=${track.id}'),
    );
  }
}

class _SubsonicOfflineProvider implements OfflineMediaProvider {
  bool _pinned = false;

  @override
  String get id => 'subsonic';

  @override
  String get displayName => 'Subsonic';

  @override
  bool supports(Track track) => track.source == const SourceKind('subsonic');

  @override
  OfflineMediaReference referenceFor(Track track) {
    return OfflineMediaReference(providerId: id, resourceId: track.id);
  }

  @override
  Future<String> pin(
    Track track, {
    OfflineDownloadProgressCallback? onProgress,
  }) async {
    _pinned = true;
    return '/offline/${track.id}';
  }

  @override
  Future<List<OfflineStoredMedia>> items() async => _pinned
      ? [
          OfflineStoredMedia(
            reference: const OfflineMediaReference(
              providerId: 'subsonic',
              resourceId: 'song-1',
            ),
            path: '/offline/song-1',
            size: 1,
            pinned: true,
            accessedAt: DateTime.utc(2026, 7, 15),
          ),
        ]
      : const [];

  @override
  Future<OfflineStorageStats> stats() async => OfflineStorageStats(
    totalBytes: _pinned ? 1 : 0,
    pinnedBytes: _pinned ? 1 : 0,
    transientBytes: 0,
    totalEntries: _pinned ? 1 : 0,
    pinnedEntries: _pinned ? 1 : 0,
  );

  @override
  bool cancel(OfflineMediaReference reference, {bool includePending = false}) =>
      false;

  @override
  Future<bool> remove(OfflineMediaReference reference) async {
    final existed = _pinned;
    _pinned = false;
    return existed;
  }

  @override
  Future<int> clearAll() async {
    final count = _pinned ? 1 : 0;
    _pinned = false;
    return count;
  }

  @override
  Future<int> clearTransient() async => 0;
}
