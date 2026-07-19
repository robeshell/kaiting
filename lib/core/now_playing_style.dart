enum NowPlayingStyle { classic, vinyl }

extension NowPlayingStyleMetadata on NowPlayingStyle {
  String get id => switch (this) {
    NowPlayingStyle.classic => 'classic',
    NowPlayingStyle.vinyl => 'vinyl',
  };

  String get label => switch (this) {
    NowPlayingStyle.classic => '经典',
    NowPlayingStyle.vinyl => '黑胶唱片',
  };

  String get description => switch (this) {
    NowPlayingStyle.classic => '均衡呈现封面、控制与歌词',
    NowPlayingStyle.vinyl => '旋转的黑胶碟片与唱臂，落针即播放',
  };
}

/// Maps stored style ids, including retired layouts, onto the current set.
///
/// Former `cover-focus` / `immersive-lyrics` values collapse to [classic].
/// Callers that care about the old immersive default should also read
/// [openLyricsByDefaultFromLegacyStyleId].
NowPlayingStyle nowPlayingStyleFromId(String? id) {
  return switch (id) {
    'vinyl' => NowPlayingStyle.vinyl,
    'classic' || 'cover-focus' || 'immersive-lyrics' || null =>
      NowPlayingStyle.classic,
    _ => NowPlayingStyle.classic,
  };
}

/// Whether a legacy style id implied “open lyrics by default” on mobile.
bool openLyricsByDefaultFromLegacyStyleId(String? id) =>
    id == 'immersive-lyrics';
