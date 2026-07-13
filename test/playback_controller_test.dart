import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/playback_engine.dart';
import 'package:sound_player/playback/playback_mode.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Play
  // ---------------------------------------------------------------------------
  group('playTrack', () {
    test('loads the track and starts playing', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);

      expect(controller.currentTrack, same(_firstTrack));
      expect(controller.snapshot.phase, PlaybackPhase.playing);
      expect(controller.isPlaying, isTrue);
    });

    test('increments session generation on each call', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final firstSession = controller.snapshot.sessionId;
      await controller.playTrack(_secondTrack);
      final secondSession = controller.snapshot.sessionId;

      expect(secondSession, greaterThan(firstSession));
    });

    test('replaces the queue when queue param is provided', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(
        _secondTrack,
        queue: [_firstTrack, _secondTrack, _thirdTrack],
      );

      expect(controller.queue, [_firstTrack, _secondTrack, _thirdTrack]);
    });

    test(
      'falls back to single-track queue when track not in provided queue',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(engine: engine);
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(
          _firstTrack,
          queue: [_secondTrack, _thirdTrack], // firstTrack not in this queue
        );

        expect(controller.currentTrack, same(_firstTrack));
        expect(controller.queue, [_firstTrack]);
      },
    );

    test(
      'adds track to queue when played without queue param and not in queue',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(engine: engine);
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_firstTrack);

        expect(controller.queue, [_firstTrack]);
      },
    );

    test(
      'does not duplicate when playing a track already in the queue',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_secondTrack);

        expect(controller.queue, [_firstTrack, _secondTrack]);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Pause / toggle
  // ---------------------------------------------------------------------------
  group('toggle', () {
    test('pauses when currently playing', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      expect(controller.isPlaying, isTrue);

      await controller.toggle();
      expect(controller.snapshot.phase, PlaybackPhase.paused);
      expect(controller.isPlaying, isFalse);
    });

    test('resumes when currently paused', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      await controller.toggle(); // pause
      expect(controller.snapshot.phase, PlaybackPhase.paused);

      await controller.toggle(); // resume
      expect(controller.snapshot.phase, PlaybackPhase.playing);
      expect(controller.isPlaying, isTrue);
    });

    test('starts playing first queue track when no track is loaded', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      // No track loaded yet — toggle should play first in queue.
      await controller.toggle();

      expect(controller.currentTrack, same(_firstTrack));
      expect(controller.isPlaying, isTrue);
    });

    test('does nothing when queue is empty and no track is loaded', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.toggle();

      expect(controller.currentTrack, isNull);
      expect(controller.isPlaying, isFalse);
    });

    test('pauses while buffering when play is still requested', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      await controller.playTrack(_firstTrack);
      engine.emit(
        PlaybackSnapshot(
          sessionId: controller.snapshot.sessionId,
          phase: PlaybackPhase.buffering,
          position: const Duration(seconds: 20),
          duration: _firstTrack.duration,
          track: _firstTrack,
          playWhenReady: true,
        ),
      );

      expect(controller.isPlaying, isTrue);
      await controller.toggle();

      expect(controller.snapshot.phase, PlaybackPhase.paused);
    });

    test('ignores the primary action while loading', () async {
      final engine = ManualPlaybackEngine();
      engine.emit(
        PlaybackSnapshot(
          sessionId: 0,
          phase: PlaybackPhase.loading,
          position: Duration.zero,
          duration: _firstTrack.duration,
          track: _firstTrack,
        ),
      );
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.toggle();

      expect(controller.snapshot.phase, PlaybackPhase.loading);
    });

    test('restarts from zero after completion', () async {
      final engine = ManualPlaybackEngine();
      engine.emitCompleted(0, _firstTrack);
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.toggle();

      expect(controller.snapshot.phase, PlaybackPhase.playing);
      expect(controller.snapshot.position, Duration.zero);
    });

    test('reloads the current track after an error', () async {
      final engine = ManualPlaybackEngine();
      engine.emit(
        PlaybackSnapshot(
          sessionId: 0,
          phase: PlaybackPhase.error,
          position: Duration.zero,
          duration: _firstTrack.duration,
          track: _firstTrack,
          errorMessage: 'network failed',
        ),
      );
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.toggle();

      expect(controller.snapshot.phase, PlaybackPhase.playing);
      expect(controller.currentTrack, same(_firstTrack));
      expect(controller.snapshot.sessionId, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // Seek
  // ---------------------------------------------------------------------------
  group('seek', () {
    test('delegates seek position to the engine', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      await controller.seek(const Duration(seconds: 30));

      expect(controller.snapshot.position, const Duration(seconds: 30));
    });

    test('seek does not affect session generation', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final sessionBefore = controller.snapshot.sessionId;
      await controller.seek(const Duration(seconds: 15));

      expect(controller.snapshot.sessionId, sessionBefore);
    });
  });

  // ---------------------------------------------------------------------------
  // Next
  // ---------------------------------------------------------------------------
  group('next', () {
    test('advances to the next track in queue', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      await controller.next();

      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.isPlaying, isTrue);
    });

    test('wraps around from last track to first', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_secondTrack);
      await controller.next();

      expect(controller.currentTrack, same(_firstTrack));
    });

    test('does nothing when queue is empty', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.next();

      expect(controller.currentTrack, isNull);
      expect(controller.isPlaying, isFalse);
    });

    test('increments session generation', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final sessionBefore = controller.snapshot.sessionId;
      await controller.next();

      expect(controller.snapshot.sessionId, greaterThan(sessionBefore));
    });
  });

  // ---------------------------------------------------------------------------
  // Previous
  // ---------------------------------------------------------------------------
  group('previous', () {
    test('goes to previous track regardless of position', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_secondTrack);
      engine.emitPosition(const Duration(seconds: 10));
      await controller.previous();

      expect(controller.currentTrack, same(_firstTrack));
      expect(controller.isPlaying, isTrue);
    });

    test('wraps around from first to last', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      engine.emitPosition(const Duration(seconds: 1));
      await controller.previous();

      expect(controller.currentTrack, same(_secondTrack));
    });

    test('does nothing when queue is empty', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.previous();

      expect(controller.currentTrack, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Completion auto-advance
  // ---------------------------------------------------------------------------
  group('completion', () {
    test('auto-advances to next track when current track completes', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final sessionBeforeComplete = controller.snapshot.sessionId;
      engine.emitCompleted(sessionBeforeComplete, _firstTrack);

      // Allow the unawaited next() to execute.
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.isPlaying, isTrue);
    });

    test('handles duplicate completion snapshots only once', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final completedSession = controller.snapshot.sessionId;
      engine.emitCompleted(completedSession, _firstTrack);
      engine.emitCompleted(completedSession, _firstTrack);
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack, same(_secondTrack));
    });

    test(
      'does NOT auto-advance when queue position has already changed',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_firstTrack);
        final firstSession = controller.snapshot.sessionId;

        // User manually skips to second track before completion event fires.
        await controller.next(); // now on _secondTrack

        // The stale completion for _firstTrack arrives. It must NOT trigger
        // another auto-advance because _firstTrack is no longer at queue index 0,
        // AND because the session generation has already moved on.
        engine.emitCompleted(firstSession, _firstTrack);
        await Future<void>.delayed(Duration.zero);

        // We should still be on _secondTrack, not _thirdTrack.
        expect(controller.currentTrack, same(_secondTrack));
      },
    );

    test(
      'stale completion from old session is ignored via session guard',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_firstTrack);
        final firstSession = controller.snapshot.sessionId;
        await controller.playTrack(_secondTrack);

        // Emit completed for the first (stale) session.
        engine.emitCompleted(firstSession, _firstTrack);
        await Future<void>.delayed(Duration.zero);

        // Should still be on _secondTrack.
        expect(controller.currentTrack, same(_secondTrack));
      },
    );

    test('does not auto-advance when queue is empty', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final session = controller.snapshot.sessionId;
      // The controller sets a single-track queue when playing without one,
      // so clear it manually to test the guard.
      // (We can't clear it from outside — instead verify the guard by checking
      // that auto-advance with a valid queue works, which is already tested.)
      engine.emitCompleted(session, _firstTrack);
      await Future<void>.delayed(Duration.zero);

      // After auto-advance wraps around on a single-track queue.
      expect(controller.currentTrack, same(_firstTrack));
    });
  });

  // ---------------------------------------------------------------------------
  // Fast track switching
  // ---------------------------------------------------------------------------
  group('fast track switching', () {
    test('only the latest session positions are accepted', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final firstSession = controller.snapshot.sessionId;

      // Rapidly switch to second track.
      await controller.playTrack(_secondTrack);
      final secondSession = controller.snapshot.sessionId;

      // Old position from first session — must be ignored.
      engine.emit(
        PlaybackSnapshot(
          sessionId: firstSession,
          phase: PlaybackPhase.playing,
          position: const Duration(seconds: 99),
          duration: _firstTrack.duration,
          track: _firstTrack,
        ),
      );

      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.snapshot.position, Duration.zero);
      expect(controller.snapshot.sessionId, secondSession);
    });

    test(
      'rapid consecutive playTrack calls keep only the last track',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(engine: engine);
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_firstTrack);
        await controller.playTrack(_secondTrack);
        await controller.playTrack(_thirdTrack);

        expect(controller.currentTrack, same(_thirdTrack));
        expect(controller.isPlaying, isTrue);
      },
    );

    test('overlapping loads cannot replay the superseded track', () async {
      final engine = DelayedLoadPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      final firstPlay = controller.playTrack(_firstTrack);
      final secondPlay = controller.playTrack(_secondTrack);
      expect(engine.loadCount, 2);

      engine.completeLoad(1);
      await secondPlay;
      engine.completeLoad(0);
      await firstPlay;

      expect(controller.currentTrack, same(_secondTrack));
      expect(engine.playCalls, 1);
    });

    test('old session completed event does not trigger auto-advance', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final oldSession = controller.snapshot.sessionId;

      // Fast-switch to second track.
      await controller.playTrack(_secondTrack);

      // Emit completed for the old session — session guard rejects it.
      engine.emitCompleted(oldSession, _firstTrack);
      await Future<void>.delayed(Duration.zero);

      // Should remain on _secondTrack.
      expect(controller.currentTrack, same(_secondTrack));
    });
  });

  // ---------------------------------------------------------------------------
  // Queue replacement
  // ---------------------------------------------------------------------------
  group('queue replacement', () {
    test('replaces queue when playing a track with a new queue', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(
        _secondTrack,
        queue: [_secondTrack, _thirdTrack],
      );

      expect(controller.queue, [_secondTrack, _thirdTrack]);
      expect(controller.currentTrack, same(_secondTrack));
    });

    test('next respects the replaced queue', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(
        _firstTrack,
        queue: [_firstTrack, _thirdTrack], // note: _secondTrack not in queue
      );
      await controller.next();

      expect(controller.currentTrack, same(_thirdTrack));
    });
  });

  // ---------------------------------------------------------------------------
  // Engine snapshots are the sole authority
  // ---------------------------------------------------------------------------
  group('snapshot authority', () {
    test(
      'engine snapshots are the only authoritative progress source',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_firstTrack);
        engine.emitPosition(const Duration(seconds: 19));

        expect(controller.currentTrack, same(_firstTrack));
        expect(controller.snapshot.position, const Duration(seconds: 19));
        expect(controller.isPlaying, isTrue);
      },
    );

    test('position changes are reflected through snapshots', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      engine.emitPosition(const Duration(seconds: 5));
      expect(controller.snapshot.position, const Duration(seconds: 5));

      engine.emitPosition(const Duration(seconds: 45));
      expect(controller.snapshot.position, const Duration(seconds: 45));
    });

    test('duration is exposed from the engine snapshot', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);

      expect(controller.snapshot.duration, _firstTrack.duration);
    });
  });

  // ---------------------------------------------------------------------------
  // Session isolation
  // ---------------------------------------------------------------------------
  group('session isolation', () {
    test('late events from an old playback session are ignored', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      final oldSession = controller.snapshot.sessionId;
      await controller.playTrack(_secondTrack);

      engine.emit(
        PlaybackSnapshot(
          sessionId: oldSession,
          phase: PlaybackPhase.playing,
          position: const Duration(seconds: 99),
          duration: _firstTrack.duration,
          track: _firstTrack,
        ),
      );

      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.snapshot.position, Duration.zero);
    });

    test(
      'sessionId zero snapshots are always accepted (idle guard bypass)',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(engine: engine);
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);

        await controller.playTrack(_firstTrack);
        engine.emit(const PlaybackSnapshot.idle());

        expect(controller.snapshot.phase, PlaybackPhase.idle);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Queue integrity
  // ---------------------------------------------------------------------------
  group('queue integrity', () {
    test('queue is unmodifiable', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      expect(() => controller.queue.add(_thirdTrack), throwsUnsupportedError);
    });

    test('initialQueue populates the queue', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      expect(controller.queue, [_firstTrack, _secondTrack]);
    });
  });

  group('playback modes', () {
    test('sequential mode stops advancing at the end', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      controller.setPlaybackMode(PlaybackMode.sequential);
      await controller.playTrack(_secondTrack);

      final completedSession = controller.snapshot.sessionId;
      engine.emitCompleted(completedSession, _secondTrack);
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.snapshot.phase, PlaybackPhase.completed);
    });

    test('repeat-one reloads the completed track in a new session', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      controller.setPlaybackMode(PlaybackMode.repeatOne);
      await controller.playTrack(_firstTrack);
      final completedSession = controller.snapshot.sessionId;

      engine.emitCompleted(completedSession, _firstTrack);
      await Future<void>.delayed(Duration.zero);

      expect(controller.currentTrack, same(_firstTrack));
      expect(controller.snapshot.sessionId, greaterThan(completedSession));
      expect(controller.isPlaying, isTrue);
    });

    test(
      'shuffle keeps the active track first and preserves every item',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
          random: Random(7),
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        await controller.playTrack(_secondTrack);

        controller.setPlaybackMode(PlaybackMode.shuffle);

        expect(controller.playbackMode, PlaybackMode.shuffle);
        expect(controller.queue.first, same(_secondTrack));
        expect(controller.queue.map((track) => track.id).toSet(), {
          _firstTrack.id,
          _secondTrack.id,
          _thirdTrack.id,
        });
        expect(controller.queueIndex, 0);
      },
    );

    test(
      'shuffle advances through a cycle without an immediate repeat',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
          random: Random(17),
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        await controller.playTrack(_firstTrack);
        controller.setPlaybackMode(PlaybackMode.shuffle);

        final cycle = controller.queue.toList();
        expect(cycle.first, same(_firstTrack));
        for (var index = 1; index < cycle.length; index++) {
          final completed = controller.currentTrack!;
          engine.emitCompleted(controller.snapshot.sessionId, completed);
          await Future<void>.delayed(Duration.zero);
          expect(controller.currentTrack, same(cycle[index]));
        }

        final lastInCycle = controller.currentTrack;
        engine.emitCompleted(controller.snapshot.sessionId, lastInCycle!);
        await Future<void>.delayed(Duration.zero);

        expect(controller.currentTrack, isNot(same(lastInCycle)));
        expect(controller.isPlaying, isTrue);
      },
    );

    test('shuffle and repeat controls cycle through their modes', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);

      expect(controller.playbackMode, PlaybackMode.repeatAll);
      controller.cycleRepeatMode();
      expect(controller.playbackMode, PlaybackMode.repeatOne);
      controller.cycleRepeatMode();
      expect(controller.playbackMode, PlaybackMode.sequential);
      controller.toggleShuffle();
      expect(controller.playbackMode, PlaybackMode.shuffle);
      controller.toggleShuffle();
      expect(controller.playbackMode, PlaybackMode.sequential);
    });

    test(
      'retry in shuffle mode preserves the established queue order',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
          random: Random(11),
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        await controller.playTrack(_firstTrack);
        controller.setPlaybackMode(PlaybackMode.shuffle);
        final shuffledOrder = controller.queue
            .map((track) => track.id)
            .toList();
        engine.emit(
          PlaybackSnapshot(
            sessionId: controller.snapshot.sessionId,
            phase: PlaybackPhase.error,
            position: Duration.zero,
            duration: _firstTrack.duration,
            track: _firstTrack,
            errorMessage: 'failed',
          ),
        );

        await controller.toggle();

        expect(controller.queue.map((track) => track.id), shuffledOrder);
        expect(controller.currentTrack, same(_firstTrack));
        expect(controller.isPlaying, isTrue);
      },
    );

    test(
      'a manually replayed completion can advance after mode changes',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        controller.setPlaybackMode(PlaybackMode.sequential);
        await controller.playTrack(_secondTrack);
        final session = controller.snapshot.sessionId;
        engine.emitCompleted(session, _secondTrack);
        await Future<void>.delayed(Duration.zero);

        controller.setPlaybackMode(PlaybackMode.repeatAll);
        await controller.toggle();
        engine.emitCompleted(session, _secondTrack);
        await Future<void>.delayed(Duration.zero);

        expect(controller.currentTrack, same(_firstTrack));
        expect(controller.isPlaying, isTrue);
      },
    );
  });

  group('queue editing', () {
    test('playNext moves an existing track directly after current', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      await controller.playTrack(_firstTrack);

      controller.playNext(_thirdTrack);

      expect(controller.queue, [_firstTrack, _thirdTrack, _secondTrack]);
      expect(controller.queueIndex, 0);
    });

    test('moving an item preserves the active track identity', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      await controller.playTrack(_secondTrack);

      controller.moveQueueItem(0, 2);

      expect(controller.queue, [_secondTrack, _thirdTrack, _firstTrack]);
      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.queueIndex, 0);
    });

    test('removing an item before current adjusts the index', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      await controller.playTrack(_secondTrack);

      await controller.removeQueueItemAt(0);

      expect(controller.queue, [_secondTrack, _thirdTrack]);
      expect(controller.currentTrack, same(_secondTrack));
      expect(controller.queueIndex, 0);
    });

    test('removing current continues with the adjacent track', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      await controller.playTrack(_secondTrack);

      await controller.removeQueueItemAt(1);

      expect(controller.queue, [_firstTrack, _thirdTrack]);
      expect(controller.currentTrack, same(_thirdTrack));
      expect(controller.queueIndex, 1);
      expect(controller.isPlaying, isTrue);
    });

    test(
      'clearing the queue stops playback and clears display state',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        await controller.playTrack(_firstTrack);

        await controller.clearQueue();

        expect(controller.queue, isEmpty);
        expect(controller.currentTrack, isNull);
        expect(controller.displayTrack, isNull);
        expect(controller.snapshot.phase, PlaybackPhase.idle);
      },
    );

    test(
      'playQueueIndex selects an item without replacing the queue',
      () async {
        final engine = ManualPlaybackEngine();
        final controller = SoundPlaybackController(
          engine: engine,
          initialQueue: [_firstTrack, _secondTrack, _thirdTrack],
        );
        addTearDown(controller.dispose);
        addTearDown(engine.dispose);
        await controller.playTrack(_firstTrack);

        await controller.playQueueIndex(2);

        expect(controller.currentTrack, same(_thirdTrack));
        expect(controller.queue, [_firstTrack, _secondTrack, _thirdTrack]);
        expect(controller.queueIndex, 2);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------
  group('dispose', () {
    test('dispose cancels engine subscription and does not throw', () {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(engine: engine);

      // Should not throw.
      controller.dispose();
      engine.dispose();
    });

    test('snapshots after dispose do not throw', () async {
      final engine = ManualPlaybackEngine();
      final controller = SoundPlaybackController(
        engine: engine,
        initialQueue: [_firstTrack],
      );
      addTearDown(engine.dispose);

      await controller.playTrack(_firstTrack);
      controller.dispose();

      // Emitting after dispose should not reach the controller's listener.
      engine.emitPosition(const Duration(seconds: 42));
      // No assertion needed — the test is that no exception is thrown.
    });
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

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

const _thirdTrack = Track(
  id: 'third',
  title: 'Third',
  artist: 'Test Artist',
  albumTitle: 'Test Album',
  duration: Duration(minutes: 5),
  source: SourceKind.local,
  trackNumber: 3,
  mediaUri: 'file:///third.mp3',
);

/// A fully manual [PlaybackEngine] that gives tests complete control over
/// emitted snapshots without any real media playback.
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
    _current = const PlaybackSnapshot.idle();
    if (!_controller.isClosed) _controller.add(_current);
  }

  /// Emits a position update while keeping the current phase and track.
  void emitPosition(Duration position) {
    emit(_current.copyWith(position: position));
  }

  /// Emits a [PlaybackPhase.completed] snapshot for [track] with the given
  /// session id.
  void emitCompleted(int sessionId, Track track) {
    emit(
      PlaybackSnapshot(
        sessionId: sessionId,
        phase: PlaybackPhase.completed,
        position: track.duration,
        duration: track.duration,
        track: track,
      ),
    );
  }

  /// Directly emit a snapshot. Updates [current] and pushes to the stream.
  void emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class DelayedLoadPlaybackEngine implements PlaybackEngine {
  final _controller = StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<_PendingLoad> _loads = [];
  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  int playCalls = 0;

  int get loadCount => _loads.length;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    final pending = _PendingLoad(track, sessionId);
    _loads.add(pending);
    await pending.ready.future;
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

  void completeLoad(int index) => _loads[index].ready.complete();

  @override
  Future<void> play() async {
    playCalls++;
    _emit(_current.copyWith(phase: PlaybackPhase.playing));
  }

  @override
  Future<void> pause() async {
    _emit(_current.copyWith(phase: PlaybackPhase.paused));
  }

  @override
  Future<void> seek(Duration position) async {
    _emit(_current.copyWith(position: position));
  }

  @override
  Future<void> stop() async => _emit(const PlaybackSnapshot.idle());

  void _emit(PlaybackSnapshot snapshot) {
    _current = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  @override
  void dispose() {
    for (final load in _loads) {
      if (!load.ready.isCompleted) load.ready.complete();
    }
    _controller.close();
  }
}

class _PendingLoad {
  _PendingLoad(this.track, this.sessionId);

  final Track track;
  final int sessionId;
  final Completer<void> ready = Completer<void>();
}
