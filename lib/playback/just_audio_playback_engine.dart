import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../domain/library_models.dart';
import 'http_stream_audio_source.dart';
import 'native_position_gate.dart';
import 'playback_engine.dart';
import 'playback_media_provider.dart';
import 'request_header_policy.dart';

/// Production adapter backed by each platform's just_audio implementation
/// (ExoPlayer on Android and AVPlayer on Apple platforms).
///
/// It deliberately exposes the same immutable snapshot contract as the
/// playback contract so the UI and coordinator remain engine-agnostic.
class JustAudioPlaybackEngine
    implements PlaylistPlaybackEngine, PlaybackMediaAccessSink {
  static const _traceEnabled = bool.fromEnvironment('SOUND_PLAYBACK_TRACE');
  static const _validationMuted = bool.fromEnvironment(
    'SOUND_VALIDATION_MUTED',
  );
  // just_audio's default position stream may wait up to 200 ms between
  // updates. That is smooth enough for a seek bar, but visibly late for an
  // LRC cue boundary. Keep the native player authoritative while sampling its
  // interpolated position often enough for time-synchronized presentation.
  static const _positionUpdatePeriod = Duration(milliseconds: 50);
  static const _preciseDarwinTimingOptions =
      just_audio.ProgressiveAudioSourceOptions(
        darwinAssetOptions: just_audio.DarwinAssetOptions(
          preferPreciseDurationAndTiming: true,
        ),
      );

  JustAudioPlaybackEngine({
    just_audio.AudioPlayer? player,
    PlaybackMediaProviderRegistry? mediaProviders,
  }) : _mediaProviders =
           mediaProviders ?? PlaybackMediaProviderRegistry.direct(),
       _player =
           player ??
           just_audio.AudioPlayer(
             // Android and Apple platforms send headers through their native
             // data sources. Windows needs just_audio's loopback proxy because
             // its WinRT implementation does not expose request headers.
             useProxyForRequestHeaders: useProxyForPlaybackRequestHeaders,
           ) {
    _configuration = _configurePlayer(_player);
    _subscriptions.addAll([
      _player
          .createPositionStream(
            minPeriod: _positionUpdatePeriod,
            maxPeriod: _positionUpdatePeriod,
          )
          .listen(_onPosition),
      _player.playerEventStream.listen(_onPlayerEvent),
      _player.errorStream.listen(_onError),
      _player.volumeStream.listen((v) => _volume = v),
    ]);
  }

  final just_audio.AudioPlayer _player;
  final PlaybackMediaProviderRegistry _mediaProviders;
  late final Future<void> _configuration;

  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Map<String, Timer> _cacheDownloadTimers = {};
  final NativePositionGate _positionGate = NativePositionGate();

  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  List<Track> _queue = const [];
  List<_DeferredMediaCache?> _queueCacheActions = const [];
  Track? _track;
  int _sessionId = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  just_audio.ProcessingState _processingState = just_audio.ProcessingState.idle;
  bool _loading = false;
  bool _playing = false;
  double _volume = 1.0;
  bool _disposed = false;
  PlaybackPhase? _lastTracedPhase;
  int? _lastTracedSecond;
  Future<void> _queueMutation = Future<void>.value();

  @override
  bool get supportsGaplessTransitions => !kIsWeb;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  void updatePlaybackMediaAccess(List<PlaybackMediaAccessRule> rules) {
    _mediaProviders.updatePlaybackMediaAccess(rules);
  }

  @override
  Future<void> load(Track track, {required int sessionId}) => loadQueue(
    [track],
    initialIndex: 0,
    sessionId: sessionId,
    loopMode: PlaybackQueueLoopMode.off,
  );

  static Future<void> _configurePlayer(just_audio.AudioPlayer player) async {
    final supportsAudioSession =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (supportsAudioSession) {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration.music());
    }
    if (_validationMuted) await player.setVolume(0);
  }

  @override
  Future<void> loadQueue(
    List<Track> tracks, {
    required int initialIndex,
    required int sessionId,
    required PlaybackQueueLoopMode loopMode,
  }) async {
    if (tracks.isEmpty || initialIndex < 0 || initialIndex >= tracks.length) {
      throw ArgumentError('The playback queue and initial index are invalid.');
    }
    final track = tracks[initialIndex];
    _sessionId = sessionId;
    _queue = List.of(tracks);
    _queueCacheActions = List<_DeferredMediaCache?>.filled(tracks.length, null);
    _track = track;
    _position = Duration.zero;
    _duration = track.duration;
    _processingState = just_audio.ProcessingState.loading;
    _playing = false;
    _positionGate.reset();
    _loading = true;
    _publish(PlaybackPhase.loading);

    if (track.mediaUri?.trim().isEmpty ?? true) {
      _loading = false;
      _publish(PlaybackPhase.error, errorMessage: '这首歌曲没有可播放的媒体地址。');
      return;
    }

    final operationSession = sessionId;
    try {
      await _configuration;
      final prepared = <_PreparedAudioSource>[];
      for (var index = 0; index < tracks.length; index++) {
        prepared.add(
          await _prepareAudioSource(
            tracks[index],
            requirePreciseLocalCache: index == initialIndex,
          ),
        );
        if (_disposed || operationSession != _sessionId) return;
      }
      _queueCacheActions = [for (final item in prepared) item.deferredCache];
      await _player.setLoopMode(_justAudioLoopMode(loopMode));
      if (_disposed || operationSession != _sessionId) return;
      final loadedDuration = await _player.setAudioSources(
        [for (final item in prepared) item.source],
        initialIndex: initialIndex,
        initialPosition: Duration.zero,
      );
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
      _scheduleCurrentTrackCacheDownload();
      _publish(PlaybackPhase.ready);
    } catch (error) {
      if (_disposed || operationSession != _sessionId) return;
      _loading = false;
      _publish(PlaybackPhase.error, errorMessage: _readableError(error));
    }
  }

  @override
  Future<void> setQueueLoopMode(PlaybackQueueLoopMode loopMode) async {
    try {
      await _player.setLoopMode(_justAudioLoopMode(loopMode));
    } catch (error) {
      if (_track != null) {
        _publish(PlaybackPhase.error, errorMessage: _readableError(error));
      }
    }
  }

  @override
  Future<void> updateQueue(List<Track> tracks) {
    final operationSession = _sessionId;
    final operation = _queueMutation.then((_) async {
      if (_disposed ||
          operationSession != _sessionId ||
          tracks.isEmpty ||
          _track == null) {
        return;
      }
      await _reconcileQueue(tracks, operationSession: operationSession);
    });
    _queueMutation = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<_PreparedAudioSource> _prepareAudioSource(
    Track track, {
    bool requirePreciseLocalCache = false,
  }) async {
    final rawUri = Uri.tryParse(track.mediaUri?.trim() ?? '');
    final resource = await _mediaProviders.resolve(
      track,
      preferLocalFile:
          requirePreciseLocalCache &&
          rawUri != null &&
          _requiresPreciseDarwinTiming(rawUri),
    );
    if (resource == null) {
      return _PreparedAudioSource(
        just_audio.AudioSource.uri(
          Uri(scheme: 'sound-unavailable', path: track.id),
          tag: track.id,
        ),
      );
    }

    final uri = resource.uri;
    final isRemote = uri.scheme == 'http' || uri.scheme == 'https';
    if (isRemote) {
      if (!kIsWeb && resource.allowBadCertificate) {
        return _PreparedAudioSource(
          HttpStreamAudioSource(
            uri: uri,
            headers: resource.headers,
            allowBadCertificate: true,
            tag: track.id,
          ),
          deferredCache: _deferredCache(resource),
        );
      }
      return _PreparedAudioSource(
        _progressiveAudioSource(uri, headers: resource.headers, tag: track.id),
        deferredCache: _deferredCache(resource),
      );
    }

    if (uri.scheme.isNotEmpty && uri.scheme != 'file') {
      return _PreparedAudioSource(
        just_audio.AudioSource.uri(uri, tag: track.id),
      );
    }
    return _PreparedAudioSource(_progressiveAudioSource(uri, tag: track.id));
  }

  _DeferredMediaCache? _deferredCache(PlaybackMediaResource resource) {
    final action = resource.cache;
    if (action == null) return null;
    return _DeferredMediaCache(
      key: resource.cacheKey ?? resource.uri.toString(),
      action: action,
    );
  }

  just_audio.ProgressiveAudioSource _progressiveAudioSource(
    Uri uri, {
    Map<String, String>? headers,
    required String tag,
  }) => just_audio.ProgressiveAudioSource(
    uri,
    headers: headers,
    tag: tag,
    options: _requiresPreciseDarwinTiming(uri)
        ? _preciseDarwinTimingOptions
        : null,
  );

  bool _requiresPreciseDarwinTiming(Uri uri) =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      uri.path.toLowerCase().endsWith('.flac');

  Future<void> _reconcileQueue(
    List<Track> desired, {
    required int operationSession,
  }) async {
    for (var index = 0; index < desired.length; index++) {
      if (_disposed || operationSession != _sessionId) return;
      if (index < _queue.length && _queue[index].id == desired[index].id) {
        continue;
      }
      final existingIndex = _queue.indexWhere(
        (track) => track.id == desired[index].id,
        index + 1,
      );
      if (existingIndex >= 0) {
        await _player.moveAudioSource(existingIndex, index);
        final movedTrack = _queue.removeAt(existingIndex);
        final movedCacheAction = _queueCacheActions.removeAt(existingIndex);
        _queue.insert(index, movedTrack);
        _queueCacheActions.insert(index, movedCacheAction);
      } else {
        final prepared = await _prepareAudioSource(desired[index]);
        if (_disposed || operationSession != _sessionId) return;
        await _player.insertAudioSource(index, prepared.source);
        _queue.insert(index, desired[index]);
        _queueCacheActions.insert(index, prepared.deferredCache);
      }
    }
    while (_queue.length > desired.length) {
      if (_disposed || operationSession != _sessionId) return;
      final index = _queue.length - 1;
      await _player.removeAudioSourceAt(index);
      _queue.removeAt(index);
      _queueCacheActions.removeAt(index);
    }
  }

  just_audio.LoopMode _justAudioLoopMode(PlaybackQueueLoopMode mode) =>
      switch (mode) {
        PlaybackQueueLoopMode.off => just_audio.LoopMode.off,
        PlaybackQueueLoopMode.one => just_audio.LoopMode.one,
        PlaybackQueueLoopMode.all => just_audio.LoopMode.all,
      };

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
    final operationSession = _sessionId;
    final operationTrackId = _track?.id;
    try {
      await _player.play();
    } catch (error) {
      if (_track != null &&
          operationSession == _sessionId &&
          operationTrackId == _track?.id) {
        _publish(PlaybackPhase.error, errorMessage: _readableError(error));
      }
    }
  }

  @override
  Future<void> pause() async {
    if (_track == null) return;
    final operationSession = _sessionId;
    try {
      await _player.pause();
    } catch (error) {
      if (operationSession == _sessionId) {
        _publish(PlaybackPhase.error, errorMessage: _readableError(error));
      }
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_track == null || _duration == Duration.zero) return;
    final operationSession = _sessionId;
    final clamped = _positionGate.beginSeek(position, duration: _duration);
    try {
      await _player.seek(clamped);
      if (_disposed || operationSession != _sessionId || _track == null) {
        return;
      }
      // createPositionStream intentionally stops while paused or stalled.
      // Confirm and publish the native seek here so the scrubber and lyrics
      // still move immediately in those states.
      final confirmed = _positionGate.accept(
        _player.position,
        duration: _duration,
      );
      if (confirmed != null) {
        _position = confirmed;
        _publish(_resolvedPhase);
      }
    } catch (error) {
      if (operationSession == _sessionId) {
        _positionGate.cancelSeek();
        _publish(PlaybackPhase.error, errorMessage: _readableError(error));
      }
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } finally {
      _track = null;
      _queue = const [];
      _queueCacheActions = const [];
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

  void _onPlayerEvent(just_audio.PlayerEvent value) {
    final event = value.playbackEvent;
    final index = event.currentIndex;
    final sourceTrackId =
        index != null &&
            index >= 0 &&
            index < _player.sequence.length &&
            _player.sequence[index].tag is String
        ? _player.sequence[index].tag as String
        : null;
    final queueIndex = sourceTrackId == null
        ? -1
        : _queue.indexWhere((track) => track.id == sourceTrackId);
    final changedTrack = queueIndex >= 0 && _queue[queueIndex].id != _track?.id;
    if (changedTrack) {
      _track = _queue[queueIndex];
      _duration = _track!.duration;
      // The player event that reports a new currentIndex can still carry the
      // previous item's final updatePosition. A natural playlist transition
      // always establishes the next track at zero; the gate then rejects any
      // late high timestamp from the previous item.
      _position = _positionGate.beginSeek(Duration.zero, duration: _duration);
    }
    if (event.duration case final duration? when duration > Duration.zero) {
      _duration = duration;
    }
    _playing = value.playing;
    _processingState = event.processingState;
    if (changedTrack) _scheduleCurrentTrackCacheDownload();
    if (_track != null && !_loading) _publish(_resolvedPhase);
  }

  void _onError(just_audio.PlayerException error) {
    if (_track == null || _loading) return;
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
        playWhenReady: _playing,
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
        'track=${snapshot.track?.id ?? '-'} '
        'queueIndex=${_player.currentIndex ?? -1} '
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

  void _scheduleCurrentTrackCacheDownload() {
    final track = _track;
    if (track == null) return;
    final index = _queue.indexWhere((candidate) => candidate.id == track.id);
    if (index < 0 ||
        index >= _queueCacheActions.length ||
        _queueCacheActions[index] == null) {
      return;
    }
    final deferred = _queueCacheActions[index]!;
    _queueCacheActions[index] = null;
    _scheduleCacheDownload(deferred);
  }

  void _scheduleCacheDownload(_DeferredMediaCache deferred) {
    // Defer to avoid competing with the playback stream for bandwidth.
    _cacheDownloadTimers.putIfAbsent(deferred.key, () {
      return Timer(const Duration(seconds: 2), () {
        _cacheDownloadTimers.remove(deferred.key);
        if (_disposed) return;
        unawaited(
          deferred.action().then(
            (_) => debugPrint('Playback cache: background download complete'),
            onError: (Object error) => debugPrint(
              'Playback cache: background download failed: $error',
            ),
          ),
        );
      });
    });
  }

  @override
  Future<void> setVolume(double value) async {
    if (_disposed) return;
    final clamped = value.clamp(0.0, 1.0);
    _volume = clamped;
    await _player.setVolume(clamped);
  }

  @override
  double get volume => _volume;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _cacheDownloadTimers.values) {
      timer.cancel();
    }
    _cacheDownloadTimers.clear();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    unawaited(_snapshots.close());
  }
}

class _PreparedAudioSource {
  const _PreparedAudioSource(this.source, {this.deferredCache});

  final just_audio.AudioSource source;
  final _DeferredMediaCache? deferredCache;
}

class _DeferredMediaCache {
  const _DeferredMediaCache({required this.key, required this.action});

  final String key;
  final Future<void> Function() action;
}
