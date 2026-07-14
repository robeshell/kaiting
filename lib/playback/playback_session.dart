import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/library_models.dart';
import '../library/library_records.dart';
import '../library/scanning/embedded_lyrics_parser.dart';
import 'playback_mode.dart';
import 'playback_session_storage_factory.dart';

class PlaybackSession {
  const PlaybackSession({
    required this.queue,
    required this.queueIndex,
    required this.positionMs,
    this.playbackMode = PlaybackMode.repeatAll,
  });

  final List<Track> queue;
  final int queueIndex;
  final int positionMs;
  final PlaybackMode playbackMode;

  Map<String, dynamic> toJson() => {
    'version': 2,
    'queue': queue.map(_trackToJson).toList(growable: false),
    'queueIndex': queueIndex,
    'positionMs': positionMs,
    'playbackMode': playbackMode.name,
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

Map<String, dynamic> _trackToJson(Track track) => {
  'id': track.id,
  'title': track.title,
  'artist': track.artist,
  'albumTitle': track.albumTitle,
  'durationMs': track.duration.inMilliseconds,
  'source': track.source.name,
  'trackNumber': track.trackNumber,
  'discNumber': track.discNumber,
  'mediaUri': track.mediaUri,
  'artworkUri': track.artworkUri,
  'year': track.year,
  'genre': track.genre,
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
    source: SourceKind.values.byName(json['source'] as String),
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
      final session = PlaybackSession.fromJson(json);
      if (session.queue.isEmpty) return null;
      return session;
    } catch (error) {
      debugPrint('Failed to load playback session: $error');
      return null;
    }
  }

  Future<void> save(PlaybackSession session) async {
    try {
      final json = jsonEncode(session.toJson());
      await _storage.write(json);
    } catch (error) {
      debugPrint('Failed to save playback session: $error');
    }
  }

  Future<void> clear() async {
    try {
      await _storage.clear();
    } catch (error) {
      debugPrint('Failed to clear playback session: $error');
    }
  }
}
