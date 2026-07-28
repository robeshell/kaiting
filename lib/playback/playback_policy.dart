import 'playback_engine.dart';
import 'playback_mode.dart';

/// The order in which queue entries are visited.
enum PlaybackOrder { sequential, shuffled }

/// Why a forward queue transition was requested.
///
/// Repeat-one applies only to [completion]. A user pressing next always asks
/// to leave the current track.
enum PlaybackTransitionTrigger { manual, completion }

enum PlaybackQueueTransitionKind { none, replayCurrent, moveToIndex, reshuffle }

/// A pure queue decision. The controller applies this result to its mutable
/// queue and then asks the engine to load the selected track.
class PlaybackQueueTransition {
  const PlaybackQueueTransition._(this.kind, [this.targetIndex]);

  const PlaybackQueueTransition.none()
    : this._(PlaybackQueueTransitionKind.none);

  const PlaybackQueueTransition.replayCurrent()
    : this._(PlaybackQueueTransitionKind.replayCurrent);

  const PlaybackQueueTransition.moveTo(int targetIndex)
    : this._(PlaybackQueueTransitionKind.moveToIndex, targetIndex);

  const PlaybackQueueTransition.reshuffle()
    : this._(PlaybackQueueTransitionKind.reshuffle);

  final PlaybackQueueTransitionKind kind;
  final int? targetIndex;
}

/// Immutable source of truth for playback order and queue-end behaviour.
///
/// Order and repeat are independent for system controls, while the app's
/// combined mode picker maps to canonical policies through [fromCombinedMode].
class PlaybackPolicy {
  const PlaybackPolicy({required this.order, required this.repeatMode});

  const PlaybackPolicy.repeatAll()
    : order = PlaybackOrder.sequential,
      repeatMode = PlaybackRepeatMode.all;

  factory PlaybackPolicy.fromCombinedMode(PlaybackMode mode) => switch (mode) {
    PlaybackMode.sequential => const PlaybackPolicy(
      order: PlaybackOrder.sequential,
      repeatMode: PlaybackRepeatMode.off,
    ),
    PlaybackMode.repeatOne => const PlaybackPolicy(
      order: PlaybackOrder.sequential,
      repeatMode: PlaybackRepeatMode.one,
    ),
    PlaybackMode.repeatAll => const PlaybackPolicy.repeatAll(),
    PlaybackMode.shuffle => const PlaybackPolicy(
      order: PlaybackOrder.shuffled,
      repeatMode: PlaybackRepeatMode.all,
    ),
  };

  final PlaybackOrder order;
  final PlaybackRepeatMode repeatMode;

  bool get shuffleEnabled => order == PlaybackOrder.shuffled;

  /// Canonical app mode for exclusive selectors and the combined player button.
  PlaybackMode get combinedMode {
    if (shuffleEnabled) return PlaybackMode.shuffle;
    return switch (repeatMode) {
      PlaybackRepeatMode.off => PlaybackMode.sequential,
      PlaybackRepeatMode.one => PlaybackMode.repeatOne,
      PlaybackRepeatMode.all => PlaybackMode.repeatAll,
    };
  }

  PlaybackPolicy toggleShuffle() => PlaybackPolicy(
    order: shuffleEnabled ? PlaybackOrder.sequential : PlaybackOrder.shuffled,
    repeatMode: repeatMode,
  );

  PlaybackPolicy cycleRepeatMode() => PlaybackPolicy(
    order: order,
    repeatMode: switch (repeatMode) {
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
    },
  );

  PlaybackQueueTransition resolveForward({
    required PlaybackTransitionTrigger trigger,
    required int currentIndex,
    required int queueLength,
  }) {
    if (!_isValidQueuePosition(currentIndex, queueLength)) {
      return const PlaybackQueueTransition.none();
    }
    if (trigger == PlaybackTransitionTrigger.completion &&
        repeatMode == PlaybackRepeatMode.one) {
      return const PlaybackQueueTransition.replayCurrent();
    }
    if (currentIndex + 1 < queueLength) {
      return PlaybackQueueTransition.moveTo(currentIndex + 1);
    }
    if (shuffleEnabled) {
      return repeatMode == PlaybackRepeatMode.off
          ? const PlaybackQueueTransition.none()
          : const PlaybackQueueTransition.reshuffle();
    }
    return repeatMode == PlaybackRepeatMode.all
        ? const PlaybackQueueTransition.moveTo(0)
        : const PlaybackQueueTransition.none();
  }

  PlaybackQueueTransition resolvePrevious({
    required int currentIndex,
    required int queueLength,
  }) {
    if (!_isValidQueuePosition(currentIndex, queueLength)) {
      return const PlaybackQueueTransition.none();
    }
    if (currentIndex > 0) {
      return PlaybackQueueTransition.moveTo(currentIndex - 1);
    }
    final wraps =
        repeatMode == PlaybackRepeatMode.all ||
        (shuffleEnabled && repeatMode != PlaybackRepeatMode.off);
    return wraps
        ? PlaybackQueueTransition.moveTo(queueLength - 1)
        : const PlaybackQueueTransition.none();
  }

  /// Native looping handles stable loops. Shuffled queue cycles stay off so
  /// the controller can create a fresh permutation at the cycle boundary.
  PlaybackQueueLoopMode get nativeQueueLoopMode {
    if (repeatMode == PlaybackRepeatMode.one) {
      return PlaybackQueueLoopMode.one;
    }
    if (shuffleEnabled) return PlaybackQueueLoopMode.off;
    return repeatMode == PlaybackRepeatMode.all
        ? PlaybackQueueLoopMode.all
        : PlaybackQueueLoopMode.off;
  }

  static bool _isValidQueuePosition(int currentIndex, int queueLength) =>
      queueLength > 0 && currentIndex >= 0 && currentIndex < queueLength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaybackPolicy &&
          order == other.order &&
          repeatMode == other.repeatMode;

  @override
  int get hashCode => Object.hash(order, repeatMode);
}
