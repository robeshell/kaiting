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
      initialQueue: demoAlbums.first.tracks,
    );
    addTearDown(controller.dispose);
    addTearDown(engine.dispose);

    final track = demoAlbums.first.tracks.first;
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

    final first = demoAlbums.first.tracks.first;
    final second = demoAlbums[1].tracks.first;
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
