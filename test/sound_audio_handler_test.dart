import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';
import 'package:sound_player/playback/sound_audio_handler.dart';

void main() {
  test('system media commands stay synchronized with the controller', () async {
    final engine = _HandlerEngine();
    const first = Track(
      id: 'first',
      title: 'First',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 3),
      source: SourceKind.local,
      mediaUri: '/music/first.mp3',
    );
    const second = Track(
      id: 'second',
      title: 'Second',
      artist: 'Artist',
      albumTitle: 'Album',
      duration: Duration(minutes: 4),
      source: SourceKind.local,
      mediaUri: '/music/second.mp3',
    );
    final controller = SoundPlaybackController(
      engine: engine,
      initialQueue: const [first, second],
    );
    final handler = SoundAudioHandler()..attach(controller);
    addTearDown(() {
      handler.detach();
      controller.dispose();
      engine.dispose();
    });

    await handler.play();

    expect(controller.currentTrack, first);
    expect(handler.mediaItem.value?.title, 'First');
    expect(handler.queue.value.map((item) => item.id), ['first', 'second']);
    expect(handler.playbackState.value.playing, isTrue);
    expect(handler.playbackState.value.controls, contains(MediaControl.pause));

    await handler.seek(const Duration(seconds: 75));
    expect(controller.snapshot.position, const Duration(seconds: 75));
    expect(
      handler.playbackState.value.updatePosition,
      const Duration(seconds: 75),
    );

    await handler.skipToNext();
    expect(controller.currentTrack, second);
    expect(handler.mediaItem.value?.title, 'Second');
    expect(handler.playbackState.value.queueIndex, 1);

    await handler.pause();
    expect(controller.isPlaying, isFalse);
    expect(handler.playbackState.value.controls, contains(MediaControl.play));

    await handler.skipToPrevious();
    expect(controller.currentTrack, first);
    expect(handler.playbackState.value.queueIndex, 0);
  });
}

class _HandlerEngine implements PlaybackEngine {
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    _emit(
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
    if (_current.track == null) return;
    _emit(_current.copyWith(phase: PlaybackPhase.playing));
  }

  @override
  Future<void> pause() async {
    if (_current.track == null) return;
    _emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    if (_current.track == null) return;
    _emit(_current.copyWith(position: position));
  }

  @override
  Future<void> stop() async {
    _emit(const PlaybackSnapshot.idle());
  }

  void _emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    _snapshots.add(snapshot);
  }

  @override
  void dispose() {
    unawaited(_snapshots.close());
  }
}
