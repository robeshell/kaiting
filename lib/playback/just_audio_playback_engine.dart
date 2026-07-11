import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../domain/library_models.dart';
import 'native_position_gate.dart';
import 'playback_engine.dart';
import 'request_header_policy.dart';

/// Production adapter backed by each platform's just_audio implementation
/// (ExoPlayer on Android and AVPlayer on Apple platforms).
///
/// It deliberately exposes the same immutable snapshot contract as the
/// playback contract so the UI and coordinator remain engine-agnostic.
class JustAudioPlaybackEngine implements PlaybackEngine {
  static const _traceEnabled = bool.fromEnvironment('SOUND_PLAYBACK_TRACE');
  static const _validationMuted = bool.fromEnvironment(
    'SOUND_VALIDATION_MUTED',
  );

  JustAudioPlaybackEngine({just_audio.AudioPlayer? player})
    : _player =
          player ??
          just_audio.AudioPlayer(
            // Android and Apple platforms send headers through their native
            // data sources. Windows needs just_audio's loopback proxy because
            // its WinRT implementation does not expose request headers.
            useProxyForRequestHeaders: useProxyForPlaybackRequestHeaders,
          ) {
    _configuration = _validationMuted
        ? _player.setVolume(0)
        : Future<void>.value();
    _subscriptions.addAll([
      _player.positionStream.listen(_onPosition),
      _player.durationStream.listen(_onDuration),
      _player.playerStateStream.listen(_onPlayerState),
      _player.errorStream.listen(_onError),
    ]);
  }

  final just_audio.AudioPlayer _player;
  late final Future<void> _configuration;
  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final NativePositionGate _positionGate = NativePositionGate();

  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  Track? _track;
  int _sessionId = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  just_audio.ProcessingState _processingState = just_audio.ProcessingState.idle;
  bool _loading = false;
  bool _playing = false;
  bool _disposed = false;
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
    _processingState = just_audio.ProcessingState.loading;
    _playing = false;
    _positionGate.reset();
    _loading = true;
    _publish(PlaybackPhase.loading);

    final resource = track.mediaUri?.trim();
    if (resource == null || resource.isEmpty) {
      _loading = false;
      _publish(PlaybackPhase.error, errorMessage: '这首歌曲没有可播放的媒体地址。');
      return;
    }

    final operationSession = sessionId;
    try {
      await _configuration;
      final uri = Uri.tryParse(resource);
      final isRemote =
          uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      final Duration? loadedDuration;
      if (isRemote) {
        loadedDuration = await _player.setUrl(
          resource,
          headers: track.httpHeaders,
        );
      } else if (uri != null && uri.scheme.isNotEmpty && uri.scheme != 'file') {
        loadedDuration = await _player.setAudioSource(
          just_audio.AudioSource.uri(uri),
        );
      } else {
        loadedDuration = await _player.setFilePath(
          uri?.scheme == 'file' ? uri!.toFilePath() : resource,
        );
      }
      if (_disposed || operationSession != _sessionId) return;
      _position = _positionGate.normalize(
        _player.position,
        duration: _duration,
      );
      if (loadedDuration != null && loadedDuration > Duration.zero) {
        _duration = loadedDuration;
      } else if (_player.duration case final duration?
          when duration > Duration.zero) {
        _duration = duration;
      }
      _processingState = _player.processingState;
      _playing = _player.playing;
      _loading = false;
      _publish(PlaybackPhase.ready);
    } catch (error) {
      if (_disposed || operationSession != _sessionId) return;
      _loading = false;
      _publish(PlaybackPhase.error, errorMessage: _readableError(error));
    }
  }

  @override
  Future<void> play() {
    if (_track == null || _current.phase == PlaybackPhase.error) {
      return Future<void>.value();
    }
    // just_audio's play Future completes only after playback pauses, stops, or
    // completes, so it must not block the command path.
    unawaited(_playSafely());
    return Future<void>.value();
  }

  Future<void> _playSafely() async {
    try {
      await _player.play();
    } catch (error) {
      if (_track != null) {
        _publish(PlaybackPhase.error, errorMessage: _readableError(error));
      }
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
      _processingState = just_audio.ProcessingState.idle;
      _playing = false;
      _loading = false;
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

  void _onDuration(Duration? value) {
    if (_track == null || value == null || value <= Duration.zero) return;
    _duration = value;
    if (!_loading) _publish(_resolvedPhase);
  }

  void _onPlayerState(just_audio.PlayerState value) {
    _playing = value.playing;
    _processingState = value.processingState;
    if (_track != null && !_loading) _publish(_resolvedPhase);
  }

  void _onError(just_audio.PlayerException error) {
    if (_track == null) return;
    final message = error.message?.trim();
    _publish(
      PlaybackPhase.error,
      errorMessage: message == null || message.isEmpty
          ? error.toString()
          : message,
    );
  }

  PlaybackPhase get _resolvedPhase => switch (_processingState) {
    just_audio.ProcessingState.idle => PlaybackPhase.paused,
    just_audio.ProcessingState.loading => PlaybackPhase.loading,
    just_audio.ProcessingState.buffering => PlaybackPhase.buffering,
    just_audio.ProcessingState.ready =>
      _playing ? PlaybackPhase.playing : PlaybackPhase.paused,
    just_audio.ProcessingState.completed => PlaybackPhase.completed,
  };

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
        'SOUND_PLAYBACK at=${DateTime.now().toIso8601String()} '
        'engine=just_audio '
        'session=${snapshot.sessionId} '
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
