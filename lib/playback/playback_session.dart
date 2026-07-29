import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/library_models.dart';
import '../library/library_records.dart';
import '../library/scanning/embedded_lyrics_parser.dart';
import 'playback_mode.dart';
import 'playback_policy.dart';
import 'playback_session_storage_factory.dart';

class PlaybackSession {
  const PlaybackSession({
    required this.queue,
    required this.queueIndex,
    required this.positionMs,
    PlaybackMode playbackMode = PlaybackMode.repeatAll,
    bool? shuffleEnabled,
    PlaybackRepeatMode? repeatMode,
    this.queueRevision = 0,
  }) : _legacyPlaybackMode = playbackMode,
       _persistedShuffleEnabled = shuffleEnabled,
       _persistedRepeatMode = repeatMode;

  final List<Track> queue;
  final int queueIndex;
  final int positionMs;
  final PlaybackMode _legacyPlaybackMode;
  final bool? _persistedShuffleEnabled;
  final PlaybackRepeatMode? _persistedRepeatMode;
  final int queueRevision;

  PlaybackPolicy get playbackPolicy {
    final legacy = PlaybackPolicy.fromCombinedMode(_legacyPlaybackMode);
    return PlaybackPolicy(
      order: (_persistedShuffleEnabled ?? legacy.shuffleEnabled)
          ? PlaybackOrder.shuffled
          : PlaybackOrder.sequential,
      repeatMode: _persistedRepeatMode ?? legacy.repeatMode,
    );
  }

  PlaybackMode get playbackMode => playbackPolicy.combinedMode;
  bool get shuffleEnabled => playbackPolicy.shuffleEnabled;
  PlaybackRepeatMode get repeatMode => playbackPolicy.repeatMode;

  Map<String, dynamic> toJson() => {
    'version': 4,
    'queue': [
      for (final (index, track) in queue.indexed)
        _trackToJson(track, includeLyrics: index == queueIndex),
    ],
    'queueIndex': queueIndex,
    'positionMs': positionMs,
    'playbackMode': playbackMode.name,
    'shuffleEnabled': shuffleEnabled,
    'repeatMode': repeatMode.name,
    'queueRevision': queueRevision,
    'lyricsTrackId': queueIndex >= 0 && queueIndex < queue.length
        ? queue[queueIndex].id
        : null,
  };

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final queueList =
        (json['queue'] as List<dynamic>?)
            ?.map((item) => _trackFromJson(item as Map<String, dynamic>))
            .toList(growable: false) ??
        [];
    return PlaybackSession(
      queue: queueList,
      queueIndex: (json['queueIndex'] as int?) ?? 0,
      positionMs: (json['positionMs'] as int?) ?? 0,
      playbackMode: _playbackModeFromJson(json['playbackMode']),
      shuffleEnabled: json['shuffleEnabled'] as bool?,
      repeatMode: _repeatModeFromJson(json['repeatMode']),
      queueRevision: (json['queueRevision'] as int?) ?? 0,
    );
  }

  PlaybackSession _withCheckpoint(_PlaybackSessionCheckpoint checkpoint) {
    return PlaybackSession(
      queue: queue,
      queueIndex: checkpoint.queueIndex,
      positionMs: checkpoint.positionMs,
      playbackMode: checkpoint.playbackMode,
      shuffleEnabled: checkpoint.playbackPolicy.shuffleEnabled,
      repeatMode: checkpoint.playbackPolicy.repeatMode,
      queueRevision: queueRevision,
    );
  }
}

PlaybackMode _playbackModeFromJson(Object? value) {
  if (value is String) {
    for (final mode in PlaybackMode.values) {
      if (mode.name == value) return mode;
    }
  }
  // Version 1 sessions always wrapped at the ends of the queue.
  return PlaybackMode.repeatAll;
}

PlaybackRepeatMode? _repeatModeFromJson(Object? value) {
  if (value is String) {
    for (final mode in PlaybackRepeatMode.values) {
      if (mode.name == value) return mode;
    }
  }
  return null;
}

Map<String, dynamic> _trackToJson(Track track, {required bool includeLyrics}) =>
    {
      'id': track.id,
      'title': track.title,
      'artist': track.artist,
      'albumTitle': track.albumTitle,
      'durationMs': track.duration.inMilliseconds,
      'source': track.source.name,
      if (track.sourceId != null) 'sourceId': track.sourceId,
      'trackNumber': track.trackNumber,
      'discNumber': track.discNumber,
      'mediaUri': track.mediaUri,
      'artworkUri': track.artworkUri,
      'year': track.year,
      'genre': track.genre,
      if (includeLyrics)
        'lyrics': [
          for (final lyric in track.lyrics)
            {'timeMs': lyric.time?.inMilliseconds, 'text': lyric.text},
        ],
    };

Track _trackFromJson(Map<String, dynamic> json) {
  final rawLyrics = json['lyrics'];
  return Track(
    id: json['id'] as String,
    title: json['title'] as String,
    artist: json['artist'] as String,
    albumTitle: json['albumTitle'] as String,
    duration: Duration(milliseconds: json['durationMs'] as int),
    source: SourceKind.fromName(json['source'] as String),
    sourceId: json['sourceId'] as String?,
    trackNumber: (json['trackNumber'] as int?) ?? 1,
    discNumber: (json['discNumber'] as int?) ?? 0,
    mediaUri: json['mediaUri'] as String?,
    artworkUri: json['artworkUri'] as String?,
    year: json['year'] as int?,
    genre: json['genre'] as String?,
    lyrics: _lyricsFromJson(json['id'] as String, rawLyrics),
  );
}

List<LyricLine> _lyricsFromJson(String trackId, Object? rawLyrics) {
  if (rawLyrics is! List) return const [];
  final records = <LibraryLyricRecord>[];
  for (final (index, item) in rawLyrics.indexed) {
    if (item case {'text': final String text}) {
      final rawTime = item['timeMs'];
      records.add(
        LibraryLyricRecord(
          trackId: trackId,
          sequence: index,
          timestampMs: rawTime is int
              ? rawTime
              : unsynchronizedLyricTimestampMs,
          text: text,
        ),
      );
    }
  }
  return [
    for (final lyric in normalizePersistedLyrics(trackId, records))
      LyricLine(
        lyric.timestampMs == unsynchronizedLyricTimestampMs
            ? null
            : Duration(milliseconds: lyric.timestampMs),
        lyric.text,
      ),
  ];
}

class PlaybackSessionStore {
  PlaybackSessionStore({required String documentsDir})
    : this.withStorage(createPlaybackSessionStorageAt(documentsDir));

  PlaybackSessionStore.withStorage(this._storage);

  factory PlaybackSessionStore.memory() {
    return PlaybackSessionStore.withStorage(MemoryPlaybackSessionStorage());
  }

  final PlaybackSessionStorage _storage;
  int? _persistedQueueRevision;
  String? _persistedLyricsTrackId;
  bool _requiresStructureWrite = false;

  static Future<PlaybackSessionStore> create() async {
    return PlaybackSessionStore.withStorage(
      await createDefaultPlaybackSessionStorage(),
    );
  }

  Future<PlaybackSession?> load() async {
    try {
      final content = await _storage.read();
      if (content == null) return null;
      if (content.trim().isEmpty) return null;
      final json = jsonDecode(content) as Map<String, dynamic>;
      var session = PlaybackSession.fromJson(json);
      if (session.queue.isEmpty) return null;
      _persistedQueueRevision = session.queueRevision;
      _persistedLyricsTrackId = json['lyricsTrackId'] as String?;
      _requiresStructureWrite = (json['version'] as int? ?? 1) < 4;

      final checkpointContent = await _storage.readCheckpoint();
      if (checkpointContent != null && checkpointContent.trim().isNotEmpty) {
        try {
          final checkpoint = _PlaybackSessionCheckpoint.fromJson(
            jsonDecode(checkpointContent) as Map<String, dynamic>,
          );
          if (checkpoint.queueRevision == session.queueRevision) {
            session = session._withCheckpoint(checkpoint);
          }
        } catch (error) {
          debugPrint('Failed to load playback checkpoint: $error');
        }
      }
      return session;
    } catch (error) {
      debugPrint('Failed to load playback session: $error');
      return null;
    }
  }

  Future<void> save(PlaybackSession session) async {
    try {
      final currentTrackId =
          session.queueIndex >= 0 && session.queueIndex < session.queue.length
          ? session.queue[session.queueIndex].id
          : null;
      if (_requiresStructureWrite ||
          _persistedQueueRevision != session.queueRevision ||
          _persistedLyricsTrackId != currentTrackId) {
        await _storage.write(jsonEncode(session.toJson()));
        _persistedQueueRevision = session.queueRevision;
        _persistedLyricsTrackId = currentTrackId;
        _requiresStructureWrite = false;
      }
      await _storage.writeCheckpoint(
        jsonEncode(_PlaybackSessionCheckpoint.fromSession(session).toJson()),
      );
    } catch (error) {
      debugPrint('Failed to save playback session: $error');
    }
  }

  Future<void> clear() async {
    try {
      await _storage.clear();
      _persistedQueueRevision = null;
      _persistedLyricsTrackId = null;
      _requiresStructureWrite = false;
    } catch (error) {
      debugPrint('Failed to clear playback session: $error');
    }
  }
}

class _PlaybackSessionCheckpoint {
  const _PlaybackSessionCheckpoint({
    required this.queueRevision,
    required this.queueIndex,
    required this.positionMs,
    required this.playbackPolicy,
  });

  factory _PlaybackSessionCheckpoint.fromSession(PlaybackSession session) {
    return _PlaybackSessionCheckpoint(
      queueRevision: session.queueRevision,
      queueIndex: session.queueIndex,
      positionMs: session.positionMs,
      playbackPolicy: session.playbackPolicy,
    );
  }

  factory _PlaybackSessionCheckpoint.fromJson(Map<String, dynamic> json) {
    final legacyMode = _playbackModeFromJson(json['playbackMode']);
    final legacyPolicy = PlaybackPolicy.fromCombinedMode(legacyMode);
    return _PlaybackSessionCheckpoint(
      queueRevision: (json['queueRevision'] as int?) ?? 0,
      queueIndex: (json['queueIndex'] as int?) ?? 0,
      positionMs: (json['positionMs'] as int?) ?? 0,
      playbackPolicy: PlaybackPolicy(
        order: (json['shuffleEnabled'] as bool? ?? legacyPolicy.shuffleEnabled)
            ? PlaybackOrder.shuffled
            : PlaybackOrder.sequential,
        repeatMode:
            _repeatModeFromJson(json['repeatMode']) ?? legacyPolicy.repeatMode,
      ),
    );
  }

  final int queueRevision;
  final int queueIndex;
  final int positionMs;
  final PlaybackPolicy playbackPolicy;

  PlaybackMode get playbackMode => playbackPolicy.combinedMode;

  Map<String, dynamic> toJson() => {
    'version': 2,
    'queueRevision': queueRevision,
    'queueIndex': queueIndex,
    'positionMs': positionMs,
    'playbackMode': playbackMode.name,
    'shuffleEnabled': playbackPolicy.shuffleEnabled,
    'repeatMode': playbackPolicy.repeatMode.name,
  };
}
