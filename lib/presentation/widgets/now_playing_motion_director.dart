import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Stages product motion on the now-playing surface so effects do not all
/// spike on the same frames.
///
/// **Open / expand**
/// 1. Surface inactive → no continuous tickers (gradient, disc).
/// 2. Surface active → ambient gradient may run (after a frame).
///
/// **Play**
/// 1. Immediately: cover scale, tonearm, breath energy (product read).
/// 2. After [discSpinDelay]: vinyl platter continuous spin.
///
/// **Pause**
/// Disc spin stops immediately; cover / arm reverse with their own curves.
///
/// Lyrics attach is deferred separately in [SoundPlaybackController] so it
/// does not need a slot in this director.
class NowPlayingMotionDirector extends ChangeNotifier {
  NowPlayingMotionDirector({
    this.discSpinDelay = const Duration(milliseconds: 300),
  });

  /// Wait after play before starting the continuous disc ticker.
  final Duration discSpinDelay;

  bool _surfaceActive = false;
  bool _playing = false;
  bool _discSpinning = false;
  bool _ambientReady = false;
  Timer? _discTimer;
  int _generation = 0;

  /// Sheet / route is fully presented (not mid-expand).
  bool get surfaceActive => _surfaceActive;

  /// Transport is playing.
  bool get playing => _playing;

  /// Gradient continuous motion may run.
  bool get allowAmbientMotion => _surfaceActive && _ambientReady;

  /// Cover scale + tonearm follow play immediately (product effect).
  bool get primaryPlayEffects => _playing;

  /// Continuous platter spin — staged after primary play effects begin.
  bool get discSpinning => _discSpinning && _playing && _surfaceActive;

  void update({required bool surfaceActive, required bool playing}) {
    final surfaceChanged = _surfaceActive != surfaceActive;
    final playChanged = _playing != playing;
    if (!surfaceChanged && !playChanged) return;

    _surfaceActive = surfaceActive;
    _playing = playing;

    if (!_surfaceActive) {
      _cancelDiscTimer();
      _discSpinning = false;
      _ambientReady = false;
      notifyListeners();
      return;
    }

    if (surfaceChanged) {
      _ambientReady = false;
      notifyListeners();
      // One frame after present so expand layout is not competing with
      // continuous gradient ticks.
      final gen = ++_generation;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (gen != _generation || !_surfaceActive) return;
        _ambientReady = true;
        notifyListeners();
        if (_playing) _scheduleDiscSpin(gen);
      });
      return;
    }

    // Play / pause while already presented.
    if (_playing) {
      _discSpinning = false;
      notifyListeners();
      _scheduleDiscSpin(++_generation);
    } else {
      _cancelDiscTimer();
      _discSpinning = false;
      notifyListeners();
    }
  }

  void _scheduleDiscSpin(int generation) {
    _cancelDiscTimer();
    if (!_playing || !_surfaceActive) return;
    _discTimer = Timer(discSpinDelay, () {
      if (generation != _generation || !_playing || !_surfaceActive) return;
      _discSpinning = true;
      notifyListeners();
    });
  }

  void _cancelDiscTimer() {
    _discTimer?.cancel();
    _discTimer = null;
  }

  @override
  void dispose() {
    _generation++;
    _cancelDiscTimer();
    super.dispose();
  }
}

/// Provides [NowPlayingMotionDirector] to artwork / vinyl / background.
class NowPlayingMotionScope extends InheritedNotifier<NowPlayingMotionDirector> {
  const NowPlayingMotionScope({
    required NowPlayingMotionDirector director,
    required super.child,
    super.key,
  }) : super(notifier: director);

  static NowPlayingMotionDirector? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NowPlayingMotionScope>()
        ?.notifier;
  }

  static NowPlayingMotionDirector of(BuildContext context) {
    final director = maybeOf(context);
    assert(director != null, 'NowPlayingMotionScope not found');
    return director!;
  }
}

/// Owns the director for one now-playing tree and keeps it synced to
/// surface / playback flags.
class NowPlayingMotionHost extends StatefulWidget {
  const NowPlayingMotionHost({
    required this.isActive,
    required this.isPlaying,
    required this.child,
    super.key,
  });

  final bool isActive;
  final bool isPlaying;
  final Widget child;

  @override
  State<NowPlayingMotionHost> createState() => _NowPlayingMotionHostState();
}

class _NowPlayingMotionHostState extends State<NowPlayingMotionHost> {
  late final NowPlayingMotionDirector _director = NowPlayingMotionDirector();

  @override
  void initState() {
    super.initState();
    _director.update(
      surfaceActive: widget.isActive,
      playing: widget.isPlaying,
    );
  }

  @override
  void didUpdateWidget(covariant NowPlayingMotionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _director.update(
      surfaceActive: widget.isActive,
      playing: widget.isPlaying,
    );
  }

  @override
  void dispose() {
    _director.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NowPlayingMotionScope(director: _director, child: widget.child);
  }
}
