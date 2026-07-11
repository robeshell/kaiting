import 'package:flutter/material.dart';

enum SourceKind { local, webDav }

extension SourceKindLabel on SourceKind {
  String get label => switch (this) {
    SourceKind.local => '本地',
    SourceKind.webDav => 'WebDAV',
  };

  IconData get icon => switch (this) {
    SourceKind.local => Icons.laptop_mac_rounded,
    SourceKind.webDav => Icons.cloud_outlined,
  };
}

class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumTitle,
    required this.duration,
    required this.source,
    this.trackNumber = 1,
    this.lyrics = const [],
    this.mediaUri,
    this.httpHeaders = const {},
  });

  final String id;
  final String title;
  final String artist;
  final String albumTitle;
  final Duration duration;
  final SourceKind source;
  final int trackNumber;
  final List<LyricLine> lyrics;
  final String? mediaUri;
  final Map<String, String> httpHeaders;

  bool get isPlayable => mediaUri != null && mediaUri!.trim().isNotEmpty;
}

class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.genre,
    required this.source,
    required this.palette,
    required this.tracks,
  });

  final String id;
  final String title;
  final String artist;
  final int year;
  final String genre;
  final SourceKind source;
  final List<Color> palette;
  final List<Track> tracks;
}

const _lyrics = [
  LyricLine(Duration(seconds: 0), '想要有直升机'),
  LyricLine(Duration(seconds: 7), '想要和你飞到宇宙去'),
  LyricLine(Duration(seconds: 14), '想要和你融化在一起'),
  LyricLine(Duration(seconds: 21), '融化在银河里'),
  LyricLine(Duration(seconds: 28), '我每天每天每天在想想想想着你'),
  LyricLine(Duration(seconds: 37), '这样的甜蜜让我开始相信命运'),
];

const demoAlbums = [
  Album(
    id: 'fantasy',
    title: '范特西',
    artist: '周杰伦',
    year: 2001,
    genre: '华语流行',
    source: SourceKind.webDav,
    palette: [Color(0xFF214E58), Color(0xFF9B6D46)],
    tracks: [
      Track(
        id: 'love-before-ad',
        title: '爱在西元前',
        artist: '周杰伦',
        albumTitle: '范特西',
        duration: Duration(minutes: 3, seconds: 50),
        source: SourceKind.webDav,
        lyrics: _lyrics,
      ),
      Track(
        id: 'dad-im-back',
        title: '爸，我回来了',
        artist: '周杰伦',
        albumTitle: '范特西',
        duration: Duration(minutes: 3, seconds: 55),
        source: SourceKind.webDav,
        trackNumber: 2,
      ),
      Track(
        id: 'simple-love',
        title: '简单爱',
        artist: '周杰伦',
        albumTitle: '范特西',
        duration: Duration(minutes: 4, seconds: 31),
        source: SourceKind.webDav,
        trackNumber: 3,
        lyrics: _lyrics,
      ),
      Track(
        id: 'ninja',
        title: '忍者',
        artist: '周杰伦',
        albumTitle: '范特西',
        duration: Duration(minutes: 2, seconds: 38),
        source: SourceKind.webDav,
        trackNumber: 4,
      ),
    ],
  ),
  Album(
    id: 'after-hours',
    title: 'After Hours',
    artist: 'The Weeknd',
    year: 2020,
    genre: 'R&B',
    source: SourceKind.local,
    palette: [Color(0xFF6B111D), Color(0xFF1A1724)],
    tracks: [
      Track(
        id: 'blinding-lights',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        albumTitle: 'After Hours',
        duration: Duration(minutes: 3, seconds: 20),
        source: SourceKind.local,
      ),
      Track(
        id: 'save-your-tears',
        title: 'Save Your Tears',
        artist: 'The Weeknd',
        albumTitle: 'After Hours',
        duration: Duration(minutes: 3, seconds: 35),
        source: SourceKind.local,
        trackNumber: 2,
      ),
    ],
  ),
  Album(
    id: 'random-access-memories',
    title: 'Random Access Memories',
    artist: 'Daft Punk',
    year: 2013,
    genre: 'Electronic',
    source: SourceKind.local,
    palette: [Color(0xFFB8903D), Color(0xFF17191D)],
    tracks: [
      Track(
        id: 'give-life-back-to-music',
        title: 'Give Life Back to Music',
        artist: 'Daft Punk',
        albumTitle: 'Random Access Memories',
        duration: Duration(minutes: 4, seconds: 35),
        source: SourceKind.local,
      ),
      Track(
        id: 'get-lucky',
        title: 'Get Lucky',
        artist: 'Daft Punk',
        albumTitle: 'Random Access Memories',
        duration: Duration(minutes: 6, seconds: 9),
        source: SourceKind.local,
        trackNumber: 2,
      ),
    ],
  ),
  Album(
    id: 'folklore',
    title: 'folklore',
    artist: 'Taylor Swift',
    year: 2020,
    genre: 'Alternative',
    source: SourceKind.webDav,
    palette: [Color(0xFF7A7B78), Color(0xFF2B302E)],
    tracks: [
      Track(
        id: 'the-one',
        title: 'the 1',
        artist: 'Taylor Swift',
        albumTitle: 'folklore',
        duration: Duration(minutes: 3, seconds: 30),
        source: SourceKind.webDav,
      ),
      Track(
        id: 'cardigan',
        title: 'cardigan',
        artist: 'Taylor Swift',
        albumTitle: 'folklore',
        duration: Duration(minutes: 3, seconds: 59),
        source: SourceKind.webDav,
        trackNumber: 2,
      ),
    ],
  ),
];

Album albumForTrack(Track track) {
  for (final album in demoAlbums) {
    if (album.title == track.albumTitle ||
        album.tracks.any((candidate) => candidate.id == track.id)) {
      return album;
    }
  }
  return Album(
    id: 'external:${track.id}',
    title: track.albumTitle,
    artist: track.artist,
    year: DateTime.now().year,
    genre: '播放验证',
    source: track.source,
    palette: track.source == SourceKind.local
        ? const [Color(0xFF315C4E), Color(0xFF171D1B)]
        : const [Color(0xFF314D78), Color(0xFF171A24)],
    tracks: [track],
  );
}
