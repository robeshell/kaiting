enum NowPlayingStyle { classic, coverFocus, immersiveLyrics }

extension NowPlayingStyleMetadata on NowPlayingStyle {
  String get id => switch (this) {
    NowPlayingStyle.classic => 'classic',
    NowPlayingStyle.coverFocus => 'cover-focus',
    NowPlayingStyle.immersiveLyrics => 'immersive-lyrics',
  };

  String get label => switch (this) {
    NowPlayingStyle.classic => '经典双栏',
    NowPlayingStyle.coverFocus => '封面主导',
    NowPlayingStyle.immersiveLyrics => '沉浸歌词',
  };

  String get description => switch (this) {
    NowPlayingStyle.classic => '均衡呈现封面、控制与歌词',
    NowPlayingStyle.coverFocus => '放大唱片封面，保留精简歌词',
    NowPlayingStyle.immersiveLyrics => '为歌词留出更多空间，移动端默认打开歌词',
  };
}

NowPlayingStyle nowPlayingStyleFromId(String? id) {
  for (final style in NowPlayingStyle.values) {
    if (style.id == id) return style;
  }
  return NowPlayingStyle.classic;
}
