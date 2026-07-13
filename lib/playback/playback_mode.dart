enum PlaybackMode { sequential, repeatOne, repeatAll, shuffle }

extension PlaybackModeLabel on PlaybackMode {
  String get label => switch (this) {
    PlaybackMode.sequential => '顺序播放',
    PlaybackMode.repeatOne => '单曲循环',
    PlaybackMode.repeatAll => '列表循环',
    PlaybackMode.shuffle => '随机播放',
  };
}
