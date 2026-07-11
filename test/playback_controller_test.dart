import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';

void main() {
  test('engine snapshots are the only authoritative progress source', () async {
    final engine = ManualPlaybackEngine();
    final controller = SoundPlaybackController(
      engine: engine,
      initialQueue: const [_firstTrack, _secondTrack],
    );
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    const track = _firstTrack;
    await controller.playTrack(track);
    engine.emitPosition(const Duration(seconds: 19));

    expect(controller.currentTrack, same(track));
    expect(controller.snapshot.position, const Duration(seconds: 19));
    expect(controller.isPlaying, isTrue);
  });

  test('late events from an old playback session are ignored', () async {
    final engine = ManualPlaybackEngine();
    final controller = SoundPlaybackController(engine: engine);
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    const first = _firstTrack;
    const second = _secondTrack;
    await controller.playTrack(first);
    final oldSession = controller.snapshot.sessionId;
    await controller.playTrack(second);

    engine.emit(
      PlaybackSnapshot(
        sessionId: oldSession,
        phase: PlaybackPhase.playing,
        position: const Duration(seconds: 99),
        duration: first.duration,
        track: first,
      ),
    );

    expect(controller.currentTrack, same(second));
    expect(controller.snapshot.position, Duration.zero);
  });
}

const _firstTrack = Track(
  id: 'first',
  title: 'First',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 3),
  source: SourceKind.local,
  mediaUri: 'file:///first.mp3',
);

const _secondTrack = Track(
  id: 'second',
  title: 'Second',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 4),
  source: SourceKind.local,
  trackNumber: 2,
  mediaUri: 'file:///second.flac',
);

class ManualPlaybackEngine implements PlaybackEngine {
  final _controller = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
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
    emit(_current.copyWith(phase: PlaybackPhase.playing));
  }

  @override
  Future<void> pause() async {
    emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    emit(_current.copyWith(position: position));
  }

  @override
  Future<void> stop() async {
    emit(const PlaybackSnapshot.idle());
  }

  void emitPosition(Duration position) {
    emit(_current.copyWith(position: position));
  }

  void emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    _controller.add(snapshot);
  }

  @override
  void dispose() {
    _controller.close();
  }
}
