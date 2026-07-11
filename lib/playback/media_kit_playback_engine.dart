import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as media_kit;

import '../domain/library_models.dart';
import 'native_position_gate.dart';
import 'playback_engine.dart';

/// Production playback adapter. All media-kit events are collapsed into the
/// immutable snapshot stream consumed by the rest of Sound.
class MediaKitPlaybackEngine implements PlaybackEngine {
  static const _traceEnabled = bool.fromEnvironment('SOUND_PLAYBACK_TRACE');
  static const _validationMuted = bool.fromEnvironment(
    'SOUND_VALIDATION_MUTED',
  );

  MediaKitPlaybackEngine({media_kit.Player? player})
    : _player =
          player ??
          media_kit.Player(
            configuration: const media_kit.PlayerConfiguration(
              muted: _validationMuted,
            ),
          ) {
    _subscriptions.addAll([
      _player.stream.position.listen(_onPosition),
      _player.stream.duration.listen(_onDuration),
      _player.stream.playing.listen(_onPlaying),
      _player.stream.buffering.listen(_onBuffering),
      _player.stream.completed.listen(_onCompleted),
      _player.stream.error.listen(_onError),
    ]);
  }

  final media_kit.Player _player;
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];

  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  Track? _track;
  int _sessionId = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;
  bool _playing = false;
  bool _buffering = false;
  bool _completed = false;
  bool _disposed = false;
  final NativePositionGate _positionGate = NativePositionGate();
  PlaybackPhase? _lastTracedPhase;
  int? _lastTracedSecond;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) async {
    _sessionId = sessionId;
    _track = track;
    _position = Duration.zero;
    _duration = track.duration;
    _playing = false;
    _buffering = false;
    _completed = false;
    _positionGate.reset();
    _loading = true;
    _publish(PlaybackPhase.loading);

    final resource = track.mediaUri?.trim();
    if (resource == null || resource.isEmpty) {
      _loading = false;
      _publish(
        PlaybackPhase.error,
        errorMessage: '这是一条设计演示数据，请从「播放验证」选择真实音频文件。',
      );
      return;
    }

    final operationSession = sessionId;
    try {
      await _player.open(
        media_kit.Media(resource, httpHeaders: track.httpHeaders),
        play: false,
      );
      if (_disposed || operationSession != _sessionId) return;
      _position = _positionGate.normalize(
        _player.state.position,
        duration: _duration,
      );
      if (_player.state.duration > Duration.zero) {
        _duration = _player.state.duration;
      }
      _loading = false;
      _publish(PlaybackPhase.ready);
    } catch (error) {
      if (_disposed || operationSession != _sessionId) return;
      _loading = false;
      _publish(PlaybackPhase.error, errorMessage: _readableError(error));
    }
  }

  @override
  Future<void> play() async {
    if (_track == null || _current.phase == PlaybackPhase.error) return;
    try {
      await _player.play();
    } catch (error) {
      _publish(PlaybackPhase.error, errorMessage: _readableError(error));
    }
  }

  @override
  Future<void> pause() async {
    if (_track == null) return;
    try {
      await _player.pause();
    } catch (error) {
      _publish(PlaybackPhase.error, errorMessage: _readableError(error));
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_track == null || _duration == Duration.zero) return;
    final clamped = _positionGate.beginSeek(position, duration: _duration);
    try {
      // Do not publish the requested target optimistically. The position
      // stream reports the playhead after the native engine has settled.
      await _player.seek(clamped);
    } catch (error) {
      _positionGate.cancelSeek();
      _publish(PlaybackPhase.error, errorMessage: _readableError(error));
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      _track = null;
      _sessionId = 0;
      _position = Duration.zero;
      _duration = Duration.zero;
      _loading = false;
      _playing = false;
      _buffering = false;
      _completed = false;
      _positionGate.reset();
      _emit(const PlaybackSnapshot.idle());
    }
  }

  void _onPosition(Duration value) {
    if (_track == null || _loading) return;
    final accepted = _positionGate.accept(value, duration: _duration);
    if (accepted == null) return;
    _position = accepted;
    _publish(_resolvedPhase);
  }

  void _onDuration(Duration value) {
    if (_track == null || value <= Duration.zero) return;
    _duration = value;
    if (!_loading) _publish(_resolvedPhase);
  }

  void _onPlaying(bool value) {
    _playing = value;
    if (_track != null && !_loading && !_completed) {
      _publish(_resolvedPhase);
    }
  }

  void _onBuffering(bool value) {
    _buffering = value;
    if (_track != null && !_loading && !_completed) {
      _publish(_resolvedPhase);
    }
  }

  void _onCompleted(bool value) {
    _completed = value;
    if (_track != null && !_loading) {
      _publish(_resolvedPhase);
    }
  }

  void _onError(String message) {
    if (_track == null || message.trim().isEmpty) return;
    _publish(PlaybackPhase.error, errorMessage: message.trim());
  }

  PlaybackPhase get _resolvedPhase {
    if (_completed) return PlaybackPhase.completed;
    if (_buffering) return PlaybackPhase.buffering;
    if (_playing) return PlaybackPhase.playing;
    return PlaybackPhase.paused;
  }

  void _publish(PlaybackPhase phase, {String? errorMessage}) {
    final track = _track;
    if (track == null) return;
    _emit(
      PlaybackSnapshot(
        sessionId: _sessionId,
        phase: phase,
        position: _position,
        duration: _duration,
        track: track,
        errorMessage: errorMessage,
      ),
    );
  }

  void _emit(PlaybackSnapshot snapshot) {
    if (_disposed) return;
    _current = snapshot;
    final traceSecond = snapshot.position.inSeconds;
    final shouldTrace =
        snapshot.phase != _lastTracedPhase ||
        traceSecond != _lastTracedSecond ||
        snapshot.errorMessage != null;
    if (_traceEnabled && shouldTrace) {
      debugPrint(
        'SOUND_PLAYBACK session=${snapshot.sessionId} '
        'phase=${snapshot.phase.name} '
        'positionMs=${snapshot.position.inMilliseconds} '
        'durationMs=${snapshot.duration.inMilliseconds}'
        '${snapshot.errorMessage == null ? '' : ' error=${snapshot.errorMessage}'}',
      );
      _lastTracedPhase = snapshot.phase;
      _lastTracedSecond = traceSecond;
    }
    _snapshots.add(snapshot);
  }

  String _readableError(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? '播放引擎发生未知错误。' : message;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    unawaited(_snapshots.close());
  }
}
