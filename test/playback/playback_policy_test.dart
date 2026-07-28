import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/playback/playback_mode.dart';
import 'package:kaiting/playback/playback_policy.dart';

void main() {
  group('combined playback modes', () {
    test('map to canonical order and repeat policies', () {
      expect(
        PlaybackPolicy.fromCombinedMode(PlaybackMode.sequential),
        const PlaybackPolicy(
          order: PlaybackOrder.sequential,
          repeatMode: PlaybackRepeatMode.off,
        ),
      );
      expect(
        PlaybackPolicy.fromCombinedMode(PlaybackMode.repeatOne),
        const PlaybackPolicy(
          order: PlaybackOrder.sequential,
          repeatMode: PlaybackRepeatMode.one,
        ),
      );
      expect(
        PlaybackPolicy.fromCombinedMode(PlaybackMode.repeatAll),
        const PlaybackPolicy.repeatAll(),
      );
      expect(
        PlaybackPolicy.fromCombinedMode(PlaybackMode.shuffle),
        const PlaybackPolicy(
          order: PlaybackOrder.shuffled,
          repeatMode: PlaybackRepeatMode.all,
        ),
      );
    });

    test('shuffle is canonicalized away from a hidden repeat-one state', () {
      final policy = PlaybackPolicy.fromCombinedMode(PlaybackMode.shuffle);

      expect(policy.shuffleEnabled, isTrue);
      expect(policy.repeatMode, PlaybackRepeatMode.all);
      expect(policy.combinedMode, PlaybackMode.shuffle);
      expect(policy.nativeQueueLoopMode, PlaybackQueueLoopMode.off);
    });
  });

  group('forward transitions', () {
    test('natural completion honors repeat-one', () {
      for (final order in PlaybackOrder.values) {
        final transition =
            PlaybackPolicy(
              order: order,
              repeatMode: PlaybackRepeatMode.one,
            ).resolveForward(
              trigger: PlaybackTransitionTrigger.completion,
              currentIndex: 0,
              queueLength: 3,
            );

        expect(transition.kind, PlaybackQueueTransitionKind.replayCurrent);
      }
    });

    test('manual next leaves repeat-one and advances', () {
      final transition =
          const PlaybackPolicy(
            order: PlaybackOrder.sequential,
            repeatMode: PlaybackRepeatMode.one,
          ).resolveForward(
            trigger: PlaybackTransitionTrigger.manual,
            currentIndex: 0,
            queueLength: 3,
          );

      expect(transition.kind, PlaybackQueueTransitionKind.moveToIndex);
      expect(transition.targetIndex, 1);
    });

    test('sequential queue-end behavior is explicit for every repeat mode', () {
      final expected = {
        PlaybackRepeatMode.off: PlaybackQueueTransitionKind.none,
        PlaybackRepeatMode.one: PlaybackQueueTransitionKind.none,
        PlaybackRepeatMode.all: PlaybackQueueTransitionKind.moveToIndex,
      };

      for (final entry in expected.entries) {
        final transition =
            PlaybackPolicy(
              order: PlaybackOrder.sequential,
              repeatMode: entry.key,
            ).resolveForward(
              trigger: PlaybackTransitionTrigger.manual,
              currentIndex: 2,
              queueLength: 3,
            );

        expect(transition.kind, entry.value, reason: entry.key.name);
        if (entry.key == PlaybackRepeatMode.all) {
          expect(transition.targetIndex, 0);
        }
      }
    });

    test('shuffled queue reshuffles only when its cycle may repeat', () {
      for (final repeatMode in PlaybackRepeatMode.values) {
        final transition =
            PlaybackPolicy(
              order: PlaybackOrder.shuffled,
              repeatMode: repeatMode,
            ).resolveForward(
              trigger: PlaybackTransitionTrigger.manual,
              currentIndex: 2,
              queueLength: 3,
            );

        expect(
          transition.kind,
          repeatMode == PlaybackRepeatMode.off
              ? PlaybackQueueTransitionKind.none
              : PlaybackQueueTransitionKind.reshuffle,
          reason: repeatMode.name,
        );
      }
    });

    test('invalid or empty queue positions never transition', () {
      const policy = PlaybackPolicy.repeatAll();

      for (final (index, length) in [(0, 0), (-1, 2), (2, 2)]) {
        expect(
          policy
              .resolveForward(
                trigger: PlaybackTransitionTrigger.manual,
                currentIndex: index,
                queueLength: length,
              )
              .kind,
          PlaybackQueueTransitionKind.none,
        );
      }
    });
  });

  group('previous transitions', () {
    test('moves backward before considering queue wrapping', () {
      final transition = const PlaybackPolicy.repeatAll().resolvePrevious(
        currentIndex: 2,
        queueLength: 3,
      );

      expect(transition.kind, PlaybackQueueTransitionKind.moveToIndex);
      expect(transition.targetIndex, 1);
    });

    test('wraps only for repeat-all or a repeating shuffled queue', () {
      const sequentialOff = PlaybackPolicy(
        order: PlaybackOrder.sequential,
        repeatMode: PlaybackRepeatMode.off,
      );
      const sequentialAll = PlaybackPolicy.repeatAll();
      const shuffledOne = PlaybackPolicy(
        order: PlaybackOrder.shuffled,
        repeatMode: PlaybackRepeatMode.one,
      );

      expect(
        sequentialOff.resolvePrevious(currentIndex: 0, queueLength: 3).kind,
        PlaybackQueueTransitionKind.none,
      );
      expect(
        sequentialAll
            .resolvePrevious(currentIndex: 0, queueLength: 3)
            .targetIndex,
        2,
      );
      expect(
        shuffledOne
            .resolvePrevious(currentIndex: 0, queueLength: 3)
            .targetIndex,
        2,
      );
    });
  });

  test('native loop mode is derived from the same policy', () {
    const cases = [
      (
        PlaybackPolicy(
          order: PlaybackOrder.sequential,
          repeatMode: PlaybackRepeatMode.off,
        ),
        PlaybackQueueLoopMode.off,
      ),
      (PlaybackPolicy.repeatAll(), PlaybackQueueLoopMode.all),
      (
        PlaybackPolicy(
          order: PlaybackOrder.sequential,
          repeatMode: PlaybackRepeatMode.one,
        ),
        PlaybackQueueLoopMode.one,
      ),
      (
        PlaybackPolicy(
          order: PlaybackOrder.shuffled,
          repeatMode: PlaybackRepeatMode.all,
        ),
        PlaybackQueueLoopMode.off,
      ),
      (
        PlaybackPolicy(
          order: PlaybackOrder.shuffled,
          repeatMode: PlaybackRepeatMode.one,
        ),
        PlaybackQueueLoopMode.one,
      ),
    ];

    for (final (policy, expected) in cases) {
      expect(policy.nativeQueueLoopMode, expected);
    }
  });
}
