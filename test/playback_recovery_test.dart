import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';
import 'package:sound_player/playback/sleep_timer_controller.dart';
import 'package:sound_player/presentation/controllers/app_diagnostics_controller.dart';
import 'package:sound_player/presentation/controllers/playback_recovery_controller.dart';

void main() {
  testWidgets('retry keeps queue and resumes the failed playback position', (
    tester,
  ) async {
    final engine = _RecoveryEngine();
    final playback = SoundPlaybackController(engine: engine);
    addTearDown(() {
      playback.dispose();
      engine.dispose();
    });

    await playback.playTrack(_remoteTrack, queue: const [_remoteTrack, _next]);
    await playback.seek(const Duration(seconds: 47));
    engine.fail('Connection timed out');
    await playback.retryCurrent();

    expect(playback.queue, const [_remoteTrack, _next]);
    expect(playback.queueIndex, 0);
    expect(engine.loadCount, 2);
    expect(engine.seekPositions.last, const Duration(seconds: 47));
    expect(playback.displayPosition, const Duration(seconds: 47));
  });

  testWidgets('transient remote failures retry automatically once available', (
    tester,
  ) async {
    final engine = _RecoveryEngine();
    final playback = SoundPlaybackController(engine: engine);
    final diagnostics = AppDiagnosticsController();
    var probes = 0;
    final recovery = PlaybackRecoveryController(
      playback,
      diagnostics,
      beforeRetry: () async {
        probes++;
      },
      retryDelays: const [Duration(milliseconds: 1)],
    );
    addTearDown(() {
      recovery.dispose();
      diagnostics.dispose();
      playback.dispose();
      engine.dispose();
    });

    await playback.playTrack(_remoteTrack);
    engine.fail('Connection reset by peer');
    await tester.pump(const Duration(milliseconds: 5));

    expect(probes, 1);
    expect(engine.loadCount, 2);
    expect(playback.snapshot.phase, PlaybackPhase.playing);
    expect(diagnostics.events.single.failure.isTransient, isTrue);
  });

  testWidgets('automatic recovery continues through the full retry schedule', (
    tester,
  ) async {
    final engine = _RecoveryEngine();
    final playback = SoundPlaybackController(engine: engine);
    final diagnostics = AppDiagnosticsController();
    var probes = 0;
    final recovery = PlaybackRecoveryController(
      playback,
      diagnostics,
      beforeRetry: () async {
        probes++;
        if (probes < 3) throw StateError('Connection timed out');
      },
      retryDelays: const [
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
        Duration(milliseconds: 1),
      ],
    );
    addTearDown(() {
      recovery.dispose();
      diagnostics.dispose();
      playback.dispose();
      engine.dispose();
    });

    await playback.playTrack(_remoteTrack);
    engine.fail('Connection timed out');
    await tester.pump(const Duration(milliseconds: 20));

    expect(probes, 3);
    expect(engine.loadCount, 2);
    expect(playback.snapshot.phase, PlaybackPhase.playing);
  });

  testWidgets('sleep timer pauses by deadline and after the current track', (
    tester,
  ) async {
    final engine = _RecoveryEngine();
    final playback = SoundPlaybackController(engine: engine);
    final timer = SleepTimerController(playback);
    addTearDown(() {
      timer.dispose();
      playback.dispose();
      engine.dispose();
    });

    await playback.playTrack(_remoteTrack, queue: const [_remoteTrack, _next]);
    timer.start(const Duration(milliseconds: 5));
    await tester.pump(const Duration(milliseconds: 10));
    expect(playback.snapshot.phase, PlaybackPhase.paused);
    expect(timer.mode, SleepTimerMode.off);

    await playback.playTrack(_remoteTrack, queue: const [_remoteTrack, _next]);
    timer.stopAfterCurrentTrack();
    await playback.playTrack(_next);
    await tester.pump();
    expect(playback.snapshot.phase, PlaybackPhase.paused);
    expect(timer.mode, SleepTimerMode.off);
  });
}

const _remoteTrack = Track(
  id: 'remote',
  title: 'Remote',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 3),
  source: SourceKind.webDav,
  mediaUri: 'https://example.test/music/remote.flac',
);

const _next = Track(
  id: 'next',
  title: 'Next',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 4),
  source: SourceKind.webDav,
  mediaUri: 'https://example.test/music/next.flac',
);

class _RecoveryEngine implements PlaybackEngine {
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  int loadCount = 0;
  final List<Duration> seekPositions = [];

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    loadCount++;
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
    _emit(_current.copyWith(phase: PlaybackPhase.playing));
  }

  @override
  Future<void> pause() async {
    _emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    seekPositions.add(position);
    _emit(_current.copyWith(position: position));
  }

  void fail(String message) {
    _emit(
      PlaybackSnapshot(
        sessionId: _current.sessionId,
        phase: PlaybackPhase.error,
        position: _current.position,
        duration: _current.duration,
        track: _current.track,
        errorMessage: message,
      ),
    );
  }

  @override
  Future<void> stop() async => _emit(const PlaybackSnapshot.idle());

  void _emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    if (!_snapshots.isClosed) _snapshots.add(snapshot);
  }

  @override
  Future<void> setVolume(double value) async {}

  @override
  double get volume => 1.0;

  @override
  void dispose() => _snapshots.close();
}
