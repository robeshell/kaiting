import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../domain/library_models.dart';
import '../sources/webdav/webdav_cache.dart';
import 'native_position_gate.dart';
import 'playback_engine.dart';
import 'request_header_policy.dart';
import 'webdav_stream_audio_source.dart';

/// Production adapter backed by each platform's just_audio implementation
/// (ExoPlayer on Android and AVPlayer on Apple platforms).
///
/// It deliberately exposes the same immutable snapshot contract as the
/// playback contract so the UI and coordinator remain engine-agnostic.
class JustAudioPlaybackEngine implements PlaylistPlaybackEngine {
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
    this.webDavAuthHeaders = const {},
    this.webDavAllowBadCertificateUrls = const {},
    this.webDavCache,
  }) : _player =
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
      _player
          .createPositionStream(
            minPeriod: _positionUpdatePeriod,
            maxPeriod: _positionUpdatePeriod,
          )
          .listen(_onPosition),
      _player.playerEventStream.listen(_onPlayerEvent),
      _player.errorStream.listen(_onError),
    ]);
  }

  final just_audio.AudioPlayer _player;
  late final Future<void> _configuration;

  /// Auth headers for WebDAV sources, keyed by connection base URL.
  /// Set by [SoundApp] when connections are available.
  Map<String, Map<String, String>> webDavAuthHeaders;

  /// Connection base URLs whose user explicitly allowed an untrusted TLS
  /// certificate. The exception is applied only to cache downloads for that
  /// connection, never process-wide.
  Set<String> webDavAllowBadCertificateUrls;

  /// Optional cache for remote WebDAV files.
  WebDavCache? webDavCache;

  final StreamController<PlaybackSnapshot> _snapshots =
      StreamController<PlaybackSnapshot>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Map<String, Timer> _cacheDownloadTimers = {};
  final NativePositionGate _positionGate = NativePositionGate();

  PlaybackSnapshot _current = const PlaybackSnapshot.idle();
  List<Track> _queue = const [];
  List<bool> _queueCacheMisses = const [];
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
  Future<void> _queueMutation = Future<void>.value();

  @override
  bool get supportsGaplessTransitions => !kIsWeb;

  @override
  PlaybackSnapshot get current => _current;

  @override
  Stream<PlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<void> load(Track track, {required int sessionId}) => loadQueue(
    [track],
    initialIndex: 0,
    sessionId: sessionId,
    loopMode: PlaybackQueueLoopMode.off,
  );

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
    _queueCacheMisses = List<bool>.filled(tracks.length, false);
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
      _queueCacheMisses = [for (final item in prepared) item.shouldCache];
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
    final resource = track.mediaUri?.trim();
    if (resource == null || resource.isEmpty) {
      return _PreparedAudioSource(
        just_audio.AudioSource.uri(
          Uri(scheme: 'sound-unavailable', path: track.id),
          tag: track.id,
        ),
        shouldCache: false,
      );
    }

    final uri = Uri.tryParse(resource);
    final isRemote =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    if (isRemote) {
      final remote = _remoteAccessFor(track, resource);
      final cache = webDavCache;
      var cachedPath = cache != null && track.source == SourceKind.webDav
          ? await cache.get(resource)
          : null;
      if (cachedPath == null &&
          requirePreciseLocalCache &&
          cache != null &&
          track.source == SourceKind.webDav &&
          remote.allowBadCertificate &&
          _requiresPreciseDarwinTiming(uri)) {
        // StreamAudioSource cannot pass ProgressiveAudioSourceOptions to the
        // Darwin implementation. Download only the initially selected FLAC so
        // AVPlayer can build an exact timeline from a local AVURLAsset. Other
        // queue items continue to load lazily and cache in the background.
        try {
          cachedPath = await cache.download(
            resource,
            headers: remote.headers,
            allowBadCertificate: true,
          );
        } catch (error) {
          debugPrint(
            'WebDAV precise FLAC preparation failed; falling back to stream: '
            '$error',
          );
        }
      }
      if (cachedPath != null) {
        return _PreparedAudioSource(
          _progressiveAudioSource(Uri.file(cachedPath), tag: track.id),
          shouldCache: false,
        );
      }
      if (!kIsWeb &&
          track.source == SourceKind.webDav &&
          remote.allowBadCertificate) {
        return _PreparedAudioSource(
          WebDavStreamAudioSource(
            uri: uri,
            headers: remote.headers,
            allowBadCertificate: true,
            tag: track.id,
          ),
          shouldCache: cache != null,
        );
      }
      return _PreparedAudioSource(
        _progressiveAudioSource(uri, headers: remote.headers, tag: track.id),
        shouldCache: cache != null && track.source == SourceKind.webDav,
      );
    }

    if (uri != null && uri.scheme.isNotEmpty && uri.scheme != 'file') {
      return _PreparedAudioSource(
        just_audio.AudioSource.uri(uri, tag: track.id),
        shouldCache: false,
      );
    }
    return _PreparedAudioSource(
      _progressiveAudioSource(
        Uri.file(uri?.scheme == 'file' ? uri!.toFilePath() : resource),
        tag: track.id,
      ),
      shouldCache: false,
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
        final movedCacheState = _queueCacheMisses.removeAt(existingIndex);
        _queue.insert(index, movedTrack);
        _queueCacheMisses.insert(index, movedCacheState);
      } else {
        final prepared = await _prepareAudioSource(desired[index]);
        if (_disposed || operationSession != _sessionId) return;
        await _player.insertAudioSource(index, prepared.source);
        _queue.insert(index, desired[index]);
        _queueCacheMisses.insert(index, prepared.shouldCache);
      }
    }
    while (_queue.length > desired.length) {
      if (_disposed || operationSession != _sessionId) return;
      final index = _queue.length - 1;
      await _player.removeAudioSourceAt(index);
      _queue.removeAt(index);
      _queueCacheMisses.removeAt(index);
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
      _queueCacheMisses = const [];
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

  _RemoteAccess _remoteAccessFor(Track track, String resource) {
    var headers = track.httpHeaders;
    String? bestKey;
    if (track.source == SourceKind.webDav && webDavAuthHeaders.isNotEmpty) {
      for (final key in webDavAuthHeaders.keys) {
        if (_isWithinWebDavBase(resource, key) &&
            (bestKey == null || key.length > bestKey.length)) {
          bestKey = key;
        }
      }
      if (bestKey != null) headers = webDavAuthHeaders[bestKey]!;
    }
    return _RemoteAccess(
      headers: headers,
      allowBadCertificate:
          bestKey != null && webDavAllowBadCertificateUrls.contains(bestKey),
    );
  }

  void _scheduleCurrentTrackCacheDownload() {
    final track = _track;
    if (track == null || track.source != SourceKind.webDav) return;
    final index = _queue.indexWhere((candidate) => candidate.id == track.id);
    if (index < 0 ||
        index >= _queueCacheMisses.length ||
        !_queueCacheMisses[index]) {
      return;
    }
    _queueCacheMisses[index] = false;
    final resource = track.mediaUri?.trim();
    if (resource == null || resource.isEmpty) return;
    final remote = _remoteAccessFor(track, resource);
    _scheduleCacheDownload(
      webDavCache,
      resource,
      remote.headers,
      allowBadCertificate: remote.allowBadCertificate,
    );
  }

  bool _isWithinWebDavBase(String resource, String base) {
    final resourceUri = Uri.tryParse(resource);
    final baseUri = Uri.tryParse(base);
    if (resourceUri == null || baseUri == null) return false;
    if (resourceUri.scheme.toLowerCase() != baseUri.scheme.toLowerCase() ||
        resourceUri.host.toLowerCase() != baseUri.host.toLowerCase() ||
        resourceUri.port != baseUri.port) {
      return false;
    }
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return resourceUri.path.startsWith(basePath);
  }

  void _scheduleCacheDownload(
    WebDavCache? cache,
    String? url,
    Map<String, String> headers, {
    required bool allowBadCertificate,
  }) {
    if (cache == null || url == null) return;
    final capturedHeaders = Map.of(headers);
    // Defer to avoid competing with the playback stream for bandwidth.
    _cacheDownloadTimers.putIfAbsent(url, () {
      return Timer(const Duration(seconds: 2), () {
        _cacheDownloadTimers.remove(url);
        if (_disposed) return;
        unawaited(
          cache
              .download(
                url,
                headers: capturedHeaders,
                allowBadCertificate: allowBadCertificate,
              )
              .then(
                (_) => debugPrint('WebDAV cache: background download complete'),
                onError: (Object error) => debugPrint(
                  'WebDAV cache: background download failed: $error',
                ),
              ),
        );
      });
    });
  }

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
  const _PreparedAudioSource(this.source, {required this.shouldCache});

  final just_audio.AudioSource source;
  final bool shouldCache;
}

class _RemoteAccess {
  const _RemoteAccess({
    required this.headers,
    required this.allowBadCertificate,
  });

  final Map<String, String> headers;
  final bool allowBadCertificate;
}
