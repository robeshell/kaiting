import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';
import 'package:sound_player/playback/playback_mode.dart';
import 'package:sound_player/playback/playback_session.dart';

void main() {
  group('Track serialization', () {
    test('round-trips playback fields without sensitive or heavy data', () {
      final original = Track(
        id: 'track-1',
        title: '测试歌曲',
        artist: '测试艺人',
        albumTitle: '测试专辑',
        duration: const Duration(minutes: 3, seconds: 42),
        source: SourceKind.local,
        trackNumber: 5,
        discNumber: 2,
        mediaUri: 'file:///music/test.mp3',
        artworkUri: 'file:///music/cover.jpg',
        year: 2024,
        genre: 'Rock',
        lyrics: const [
          LyricLine(Duration(seconds: 3), 'First line'),
          LyricLine(Duration(seconds: 8), 'Second line'),
        ],
      );

      final restored = _roundTripTrack(original);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.artist, original.artist);
      expect(restored.albumTitle, original.albumTitle);
      expect(restored.duration, original.duration);
      expect(restored.source, original.source);
      expect(restored.trackNumber, original.trackNumber);
      expect(restored.discNumber, original.discNumber);
      expect(restored.mediaUri, original.mediaUri);
      expect(restored.artworkUri, original.artworkUri);
      expect(restored.year, original.year);
      expect(restored.genre, original.genre);
      expect(restored.lyrics, hasLength(2));
      expect(restored.lyrics.first.time, const Duration(seconds: 3));
      expect(restored.lyrics.first.text, 'First line');

      final encoded = jsonEncode(
        PlaybackSession(
          queue: [original],
          queueIndex: 0,
          positionMs: 0,
        ).toJson(),
      );
      expect(encoded, contains('First line'));
    });

    test('handles null optional fields', () {
      final original = Track(
        id: 'minimal',
        title: 'Minimal',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: const Duration(minutes: 1),
        source: SourceKind.webDav,
      );

      final restored = _roundTripTrack(original);

      expect(restored.mediaUri, isNull);
      expect(restored.artworkUri, isNull);
      expect(restored.year, isNull);
      expect(restored.genre, isNull);
    });

    test('only keeps lyrics for the current track fallback', () {
      const first = Track(
        id: 'first',
        title: 'First',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 1),
        source: SourceKind.local,
        lyrics: [LyricLine(Duration(seconds: 1), 'First lyrics')],
      );
      const second = Track(
        id: 'second',
        title: 'Second',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 1),
        source: SourceKind.local,
        lyrics: [LyricLine(Duration(seconds: 2), 'Second lyrics')],
      );

      final encoded = jsonEncode(
        const PlaybackSession(
          queue: [first, second],
          queueIndex: 1,
          positionMs: 0,
        ).toJson(),
      );

      expect(encoded, isNot(contains('First lyrics')));
      expect(encoded, contains('Second lyrics'));
    });
  });

  // ---------------------------------------------------------------------------
  // PlaybackSession JSON round-trip
  // ---------------------------------------------------------------------------
  group('PlaybackSession serialization', () {
    test('round-trips through JSON', () {
      final session = PlaybackSession(
        queue: [_trackA, _trackB],
        queueIndex: 1,
        positionMs: 42000,
        playbackMode: PlaybackMode.shuffle,
      );

      final encoded = jsonEncode(session.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = PlaybackSession.fromJson(decoded);

      expect(restored.queue.length, 2);
      expect(restored.queue[0].id, _trackA.id);
      expect(restored.queue[1].id, _trackB.id);
      expect(restored.queueIndex, 1);
      expect(restored.positionMs, 42000);
      expect(restored.playbackMode, PlaybackMode.shuffle);
    });

    test('empty queue fromJson produces empty session', () {
      final session = PlaybackSession.fromJson({});

      expect(session.queue, isEmpty);
      expect(session.queueIndex, 0);
      expect(session.positionMs, 0);
      expect(session.playbackMode, PlaybackMode.repeatAll);
    });

    test('version 1 and unknown modes keep legacy repeat-all behavior', () {
      final legacy = PlaybackSession.fromJson({
        'version': 1,
        'queue': const [],
        'playbackMode': 'not-a-mode',
      });

      expect(legacy.playbackMode, PlaybackMode.repeatAll);
    });

    test('version 2 sessions still restore their embedded lyrics', () {
      final legacy = PlaybackSession.fromJson({
        'version': 2,
        'queue': [
          {
            'id': 'legacy-track',
            'title': 'Legacy',
            'artist': 'Artist',
            'albumTitle': 'Album',
            'durationMs': 60000,
            'source': 'local',
            'lyrics': [
              {'timeMs': 3000, 'text': 'Legacy lyric'},
            ],
          },
        ],
      });

      expect(legacy.queue.single.lyrics.single.text, 'Legacy lyric');
      expect(
        legacy.queue.single.lyrics.single.time,
        const Duration(seconds: 3),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PlaybackSessionStore
  // ---------------------------------------------------------------------------
  group('PlaybackSessionStore', () {
    late Directory tmpDir;
    late PlaybackSessionStore store;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('sound_session_test_');
      store = PlaybackSessionStore(documentsDir: tmpDir.path);
    });

    tearDown(() {
      tmpDir.deleteSync(recursive: true);
    });

    test('load returns null when no session file exists', () async {
      final session = await store.load();
      expect(session, isNull);
    });

    test('save and load round-trips', () async {
      final session = PlaybackSession(
        queue: [_trackA, _trackB],
        queueIndex: 0,
        positionMs: 15000,
      );

      await store.save(session);
      final restored = await store.load();

      expect(restored, isNotNull);
      expect(restored!.queue.length, 2);
      expect(restored.queue[0].id, _trackA.id);
      expect(restored.queueIndex, 0);
      expect(restored.positionMs, 15000);
    });

    test('position updates only rewrite the lightweight checkpoint', () async {
      const queueRevision = 7;
      final session = PlaybackSession(
        queue: [_trackA, _trackB],
        queueIndex: 0,
        positionMs: 15000,
        queueRevision: queueRevision,
      );
      await store.save(session);
      final sessionFile = File('${tmpDir.path}/playback_session.json');
      final structureBefore = await sessionFile.readAsString();

      await store.save(
        PlaybackSession(
          queue: session.queue,
          queueIndex: 0,
          positionMs: 42000,
          playbackMode: PlaybackMode.shuffle,
          queueRevision: queueRevision,
        ),
      );

      expect(await sessionFile.readAsString(), structureBefore);
      final checkpoint =
          jsonDecode(
                await File(
                  '${tmpDir.path}/playback_session_checkpoint.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(checkpoint['positionMs'], 42000);
      expect(checkpoint['queueIndex'], 0);

      final restored = await PlaybackSessionStore(
        documentsDir: tmpDir.path,
      ).load();
      expect(restored!.positionMs, 42000);
      expect(restored.queueIndex, 0);
      expect(restored.playbackMode, PlaybackMode.shuffle);
    });

    test('changing the current track refreshes its lyrics fallback', () async {
      const first = Track(
        id: 'first',
        title: 'First',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 1),
        source: SourceKind.local,
        lyrics: [LyricLine(Duration(seconds: 1), 'First lyrics')],
      );
      const second = Track(
        id: 'second',
        title: 'Second',
        artist: 'Artist',
        albumTitle: 'Album',
        duration: Duration(minutes: 1),
        source: SourceKind.local,
        lyrics: [LyricLine(Duration(seconds: 2), 'Second lyrics')],
      );
      const queue = [first, second];
      await store.save(
        const PlaybackSession(
          queue: queue,
          queueIndex: 0,
          positionMs: 0,
          queueRevision: 3,
        ),
      );

      await store.save(
        const PlaybackSession(
          queue: queue,
          queueIndex: 1,
          positionMs: 0,
          queueRevision: 3,
        ),
      );
      final structure = await File(
        '${tmpDir.path}/playback_session.json',
      ).readAsString();

      expect(structure, isNot(contains('First lyrics')));
      expect(structure, contains('Second lyrics'));
    });

    test('queue revision changes rewrite the queue structure', () async {
      await store.save(
        PlaybackSession(
          queue: [_trackA],
          queueIndex: 0,
          positionMs: 0,
          queueRevision: 1,
        ),
      );
      final sessionFile = File('${tmpDir.path}/playback_session.json');
      final structureBefore = await sessionFile.readAsString();

      await store.save(
        PlaybackSession(
          queue: [_trackA, _trackB],
          queueIndex: 1,
          positionMs: 0,
          queueRevision: 2,
        ),
      );

      expect(await sessionFile.readAsString(), isNot(structureBefore));
      expect((await store.load())!.queue, hasLength(2));
    });

    test('saving a version 2 file migrates it to compact version 3', () async {
      final file = File('${tmpDir.path}/playback_session.json');
      await file.writeAsString(
        jsonEncode({
          'version': 2,
          'queue': [
            {
              'id': 'legacy-track',
              'title': 'Legacy',
              'artist': 'Artist',
              'albumTitle': 'Album',
              'durationMs': 60000,
              'source': 'local',
              'lyrics': [
                {'timeMs': 1000, 'text': 'Current fallback kept'},
              ],
            },
            {
              'id': 'legacy-track-2',
              'title': 'Legacy 2',
              'artist': 'Artist',
              'albumTitle': 'Album',
              'durationMs': 60000,
              'source': 'local',
              'lyrics': [
                {'timeMs': 2000, 'text': 'Removed after migration'},
              ],
            },
          ],
          'queueIndex': 0,
          'positionMs': 1000,
        }),
      );

      final legacy = await store.load();
      await store.save(legacy!);
      final migrated = await file.readAsString();

      expect(jsonDecode(migrated)['version'], 3);
      expect(migrated, isNot(contains('Removed after migration')));
      expect(migrated, contains('Current fallback kept'));
    });

    test('clear removes the session', () async {
      await store.save(
        PlaybackSession(queue: [_trackA], queueIndex: 0, positionMs: 0),
      );
      await store.clear();
      final session = await store.load();
      expect(session, isNull);
    });

    test('load returns null for empty queue', () async {
      await store.save(
        PlaybackSession(queue: [], queueIndex: 0, positionMs: 0),
      );
      final session = await store.load();
      expect(session, isNull);
    });

    test('load survives corrupt JSON gracefully', () async {
      final file = File('${tmpDir.path}/playback_session.json');
      await file.writeAsString('not valid json {{{');

      final session = await store.load();
      expect(session, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Controller: session snapshot
  // ---------------------------------------------------------------------------
  group('controller sessionSnapshot', () {
    test('captures current queue and position', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_trackA, _trackB],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_trackA);
      engine.emitPosition(const Duration(seconds: 15));

      final snap = controller.sessionSnapshot;
      expect(snap.queue, [_trackA, _trackB]);
      expect(snap.queueIndex, 0);
      expect(snap.positionMs, 15000);
      expect(snap.playbackMode, PlaybackMode.repeatAll);
    });

    test('captures resume position when set via session restore', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA],
          queueIndex: 0,
          positionMs: 30000,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      final snap = controller.sessionSnapshot;
      expect(snap.positionMs, 30000);
    });
  });

  // ---------------------------------------------------------------------------
  // Controller: restore without auto-play
  // ---------------------------------------------------------------------------
  group('session restore', () {
    test('restores queue and index without loading the engine', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA, _trackB, _trackC],
          queueIndex: 2,
          positionMs: 0,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // Queue and index are restored.
      expect(controller.queue, [_trackA, _trackB, _trackC]);
      // Engine is NOT loaded — no track should be active.
      expect(controller.hasActiveTrack, isFalse);
      expect(controller.isPlaying, isFalse);
      expect(controller.currentTrack, isNull);
      expect(controller.displayTrack, same(_trackC));
    });

    test('restores the persisted playback mode', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA, _trackB],
          queueIndex: 0,
          positionMs: 0,
          playbackMode: PlaybackMode.shuffle,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      expect(controller.playbackMode, PlaybackMode.shuffle);
      expect(controller.sessionSnapshot.playbackMode, PlaybackMode.shuffle);
    });

    test('toggle plays the restored track after session restore', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA, _trackB],
          queueIndex: 1, // _trackB should be current
          positionMs: 0,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.toggle();

      // Should play the track at restored queue index.
      expect(controller.currentTrack, same(_trackB));
      expect(controller.isPlaying, isTrue);
    });

    test('restored session with position seeks after play', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA],
          queueIndex: 0,
          positionMs: 45000, // 45 seconds into the track
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.toggle();

      expect(controller.currentTrack, same(_trackA));
      expect(controller.isPlaying, isTrue);
      expect(controller.snapshot.position, const Duration(seconds: 45));
      expect(engine.commands, ['load:a', 'seek:45000', 'play']);
    });

    test('resume position is consumed only once', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA, _trackB],
          queueIndex: 0,
          positionMs: 60000,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // First play: should seek to resume position.
      await controller.toggle();
      expect(controller.snapshot.position, const Duration(seconds: 60));

      // Skip to next track — should NOT apply resume position.
      await controller.next();
      expect(controller.currentTrack, same(_trackB));
      // The second track starts from 0, not 60s.
      expect(controller.snapshot.position, Duration.zero);
    });

    test('manual seek before first play clears resume position', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA],
          queueIndex: 0,
          positionMs: 60000,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // User seeks before the first play — this should clear resume.
      // (Seek only works if there's a loaded track, so this is a no-op seek
      // but still tests that the code path doesn't crash.)
      await controller.seek(
        const Duration(seconds: 10),
      ); // no track loaded, engine no-ops
      await controller.toggle();

      // Resume position was cleared by the explicit seek call.
      expect(controller.snapshot.position, Duration.zero);
    });

    test('next after restore clears resume position', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA, _trackB],
          queueIndex: 0,
          positionMs: 30000,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // User clicks next (skips to _trackB) instead of playing _trackA.
      await controller.next();

      expect(controller.currentTrack, same(_trackB));
      expect(controller.snapshot.position, Duration.zero);
    });

    test('empty session does nothing', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [],
          queueIndex: 0,
          positionMs: 0,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      expect(controller.queue, isEmpty);
      expect(controller.hasActiveTrack, isFalse);
    });

    test('clamps queueIndex to valid range', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA, _trackB],
          queueIndex: 99, // out of range
          positionMs: 0,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // Should clamp to last valid index.
      expect(controller.queue, [_trackA, _trackB]);
    });
  });

  // ---------------------------------------------------------------------------
  // Persistence does not overwrite live engine state
  // ---------------------------------------------------------------------------
  group('persistence isolation', () {
    test('session save never feeds position back into the engine', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_trackA);
      engine.emitPosition(const Duration(seconds: 30));

      // Take a snapshot (simulating what persistence does).
      final snap = controller.sessionSnapshot;

      // Later, the engine updates the position.
      engine.emitPosition(const Duration(seconds: 31));

      // The snapshot does NOT affect the live controller state.
      expect(controller.snapshot.position, const Duration(seconds: 31));
      // The snapshot is just a copy from an earlier point in time.
      expect(snap.positionMs, 30000);
    });

    test('creating a new controller from session does not auto-play', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialSession: PlaybackSession(
          queue: [_trackA],
          queueIndex: 0,
          positionMs: 99999,
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // Engine is untouched — no load/play/seek calls happened.
      expect(controller.isPlaying, isFalse);
      expect(controller.hasActiveTrack, isFalse);
      // The snapshot is still idle from the engine.
      expect(controller.snapshot.phase, PlaybackPhase.idle);
    });

    test('sessionSnapshot reads controller state, never mutates it', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_trackA, _trackB],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      final queueBefore = controller.queue;
      final snapshot = controller.sessionSnapshot;

      // The queue is unchanged after taking a snapshot.
      expect(controller.queue, queueBefore);
      // Snapshot returns the same data.
      expect(snapshot.queue, [_trackA, _trackB]);
    });
  });
}

Track _roundTripTrack(Track track) {
  final session = PlaybackSession(queue: [track], queueIndex: 0, positionMs: 0);
  return PlaybackSession.fromJson(session.toJson()).queue.single;
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

const _trackA = Track(
  id: 'a',
  title: 'Track A',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 2),
  source: SourceKind.local,
  mediaUri: 'file:///a.mp3',
);

const _trackB = Track(
  id: 'b',
  title: 'Track B',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
  mediaUri: 'file:///b.mp3',
);

const _trackC = Track(
  id: 'c',
  title: 'Track C',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 4),
  source: SourceKind.local,
  mediaUri: 'file:///c.flac',
);

/// Minimal manual engine for session persistence tests.
class ManualPlaybackEngine implements PlaybackEngine {
  final _controller = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  final List<String> commands = [];

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    commands.add('load:${track.id}');
    emit(
      PlaybackSnapshot(
        sessionId: sessionId,
        phase: PlaybackPhase.ready,
        position: Duration.zero,
        duration: track.duration,
        track: track,
      ),
    );
  }

  @override
  Future<void> play() async {
    commands.add('play');
    emit(_current.copyWith(phase: PlaybackPhase.playing));
  }

  @override
  Future<void> pause() async {
    commands.add('pause');
    emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    commands.add('seek:${position.inMilliseconds}');
    emit(_current.copyWith(position: position));
  }

  @override
  Future<void> stop() async {
    _current = const PlaybackSnapshot.idle();
    if (!_controller.isClosed) _controller.add(_current);
  }

  void emitPosition(Duration position) {
    emit(_current.copyWith(position: position));
  }

  void emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  @override
  Future<void> setVolume(double value) async {}

  @override
  double get volume => 1.0;

  @override
  void dispose() {
    _controller.close();
  }
}
