import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/playback/playback_media_provider.dart';
import 'package:kaiting/sources/webdav/webdav_cache.dart';
import 'package:kaiting/sources/webdav/webdav_playback_media_provider.dart';

void main() {
  group('PlaybackMediaProviderRegistry', () {
    test(
      'controller forwards generic access rules without engine coupling',
      () {
        final engine = _AccessRecordingEngine();
        final controller = SoundPlaybackController(engine: engine);
        addTearDown(controller.dispose);
        final rules = [
          PlaybackMediaAccessRule(
            baseUri: Uri.parse('https://example.test/music/'),
            headers: const {'Authorization': 'secret'},
          ),
        ];

        controller.updatePlaybackMediaAccess(rules);

        expect(engine.rules, same(rules));
      },
    );

    test(
      'uses the first supporting provider and falls through null results',
      () async {
        final skipped = _RecordingProvider(supportsTrack: true, result: null);
        final selected = _RecordingProvider(
          supportsTrack: true,
          result: PlaybackMediaResource(
            uri: Uri(scheme: 'test', path: 'selected'),
          ),
        );
        final unused = _RecordingProvider(
          supportsTrack: true,
          result: PlaybackMediaResource(
            uri: Uri(scheme: 'test', path: 'unused'),
          ),
        );
        final registry = PlaybackMediaProviderRegistry([
          skipped,
          selected,
          unused,
        ]);

        final resource = await registry.resolve(
          _localTrack,
          preferLocalFile: false,
        );

        expect(resource!.uri.path, 'selected');
        expect(skipped.resolveCount, 1);
        expect(selected.resolveCount, 1);
        expect(unused.resolveCount, 0);
      },
    );

    test('direct provider resolves local, file, and custom URIs', () async {
      const provider = DirectPlaybackMediaProvider();

      final relative = await provider.resolve(
        _localTrack,
        preferLocalFile: false,
      );
      final file = await provider.resolve(
        _localTrackWithUri('file:///Music/song.flac'),
        preferLocalFile: false,
      );
      final custom = await provider.resolve(
        _localTrackWithUri('content://media/audio/42'),
        preferLocalFile: false,
      );

      expect(relative!.uri.scheme, 'file');
      expect(relative.uri.toFilePath(), '/Music/song.flac');
      expect(file!.uri.toFilePath(), '/Music/song.flac');
      expect(custom!.uri.scheme, 'content');
    });
  });

  group('WebDavPlaybackMediaProvider', () {
    late Directory cacheDirectory;
    late WebDavPlaybackMediaProvider provider;

    setUp(() async {
      cacheDirectory = await Directory.systemTemp.createTemp(
        'sound_playback_provider_',
      );
      final cache = WebDavCache(cacheDir: cacheDirectory);
      await cache.init();
      provider = WebDavPlaybackMediaProvider(cache: cache);
    });

    tearDown(() async {
      await cacheDirectory.delete(recursive: true);
    });

    test('uses the most specific matching access rule', () async {
      provider.updatePlaybackMediaAccess([
        PlaybackMediaAccessRule(
          baseUri: Uri.parse('https://example.test/dav/'),
          headers: const {'Authorization': 'base'},
        ),
        PlaybackMediaAccessRule(
          baseUri: Uri.parse('https://example.test/dav/private/'),
          headers: const {'Authorization': 'private'},
          allowBadCertificate: true,
        ),
      ]);

      final resource = await provider.resolve(
        _webDavTrack('https://example.test/dav/private/song.flac'),
        preferLocalFile: false,
      );

      expect(resource!.headers['Authorization'], 'private');
      expect(resource.allowBadCertificate, isTrue);
      expect(resource.cache, isNotNull);
      expect(resource.cacheKey, resource.uri.toString());
    });

    test('does not leak access rules to a similar path prefix', () async {
      provider.updatePlaybackMediaAccess([
        PlaybackMediaAccessRule(
          baseUri: Uri.parse('https://example.test/dav/'),
          headers: const {'Authorization': 'secret'},
          allowBadCertificate: true,
        ),
      ]);

      final resource = await provider.resolve(
        _webDavTrack('https://example.test/davish/song.flac'),
        preferLocalFile: false,
      );

      expect(resource!.headers, isEmpty);
      expect(resource.allowBadCertificate, isFalse);
    });

    test('returns null for a non-HTTP WebDAV media reference', () async {
      final resource = await provider.resolve(
        _webDavTrack('content://media/audio/42'),
        preferLocalFile: false,
      );

      expect(resource, isNull);
    });
  });
}

const _localTrack = Track(
  id: 'local',
  title: 'Local',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 1),
  source: SourceKind.local,
  mediaUri: '/Music/song.flac',
);

Track _localTrackWithUri(String uri) => Track(
  id: 'local-$uri',
  title: 'Local',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 1),
  source: SourceKind.local,
  mediaUri: uri,
);

Track _webDavTrack(String uri) => Track(
  id: 'remote-$uri',
  title: 'Remote',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: const Duration(minutes: 1),
  source: SourceKind.webDav,
  mediaUri: uri,
);

class _RecordingProvider implements PlaybackMediaProvider {
  _RecordingProvider({required this.supportsTrack, required this.result});

  final bool supportsTrack;
  final PlaybackMediaResource? result;
  int resolveCount = 0;

  @override
  bool supports(Track track) => supportsTrack;

  @override
  Future<PlaybackMediaResource?> resolve(
    Track track, {
    required bool preferLocalFile,
  }) async {
    resolveCount++;
    return result;
  }
}

class _AccessRecordingEngine
    implements PlaybackEngine, PlaybackMediaAccessSink {
  List<PlaybackMediaAccessRule>? rules;

  @override
  PlaybackSnapshot get current => const PlaybackSnapshot.idle();

  @override
  Stream<PlaybackSnapshot> get snapshots => const Stream.empty();

  @override
  void updatePlaybackMediaAccess(List<PlaybackMediaAccessRule> rules) {
    this.rules = rules;
  }

  @override
  Future<void> load(Track track, {required int sessionId}) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double value) async {}

  @override
  double get volume => 1.0;

  @override
  void dispose() {}
}
