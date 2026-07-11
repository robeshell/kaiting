/// Normalizes native playback positions and protects the UI from stale
/// callbacks while a seek is settling.
///
/// Native players may briefly emit a timestamp from before the seek after
/// already reporting the new position. This gate keeps the requested target
/// pending until the native engine confirms it, then waits for one plausible
/// forward-progress callback before returning to pass-through mode.
class NativePositionGate {
  NativePositionGate({
    this.confirmationTolerance = const Duration(milliseconds: 300),
    this.settleWindow = const Duration(seconds: 3),
  });

  final Duration confirmationTolerance;
  final Duration settleWindow;

  Duration? _pendingTarget;
  Duration? _confirmedTarget;

  Duration normalize(Duration value, {required Duration duration}) {
    final nonNegative = value.inMicroseconds.clamp(0, 1 << 62);
    final upperBound = duration > Duration.zero
        ? duration.inMicroseconds
        : nonNegative;
    return Duration(microseconds: nonNegative.clamp(0, upperBound));
  }

  Duration beginSeek(Duration target, {required Duration duration}) {
    final normalized = normalize(target, duration: duration);
    _pendingTarget = normalized;
    _confirmedTarget = null;
    return normalized;
  }

  void cancelSeek() {
    _pendingTarget = null;
    _confirmedTarget = null;
  }

  void reset() => cancelSeek();

  /// Returns a safe position to publish, or `null` while a stale callback is
  /// being rejected.
  Duration? accept(Duration value, {required Duration duration}) {
    final reported = normalize(value, duration: duration);
    final pending = _pendingTarget;
    if (pending != null) {
      if ((reported - pending).abs() > confirmationTolerance) return null;
      _pendingTarget = null;
      _confirmedTarget = pending;
      return pending;
    }

    final confirmed = _confirmedTarget;
    if (confirmed != null) {
      final progress = reported - confirmed;
      if (progress.isNegative || progress > settleWindow) return null;
      if (progress > Duration.zero) _confirmedTarget = null;
    }

    return reported;
  }
}
