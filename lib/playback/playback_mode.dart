import 'package:flutter/material.dart';

/// Combined playback mode used for session persistence and exclusive mode
/// pickers (for example the queue sheet).
///
/// Runtime control is orthogonal: [SoundPlaybackController.isShuffleEnabled]
/// plus [SoundPlaybackController.repeatMode]. [PlaybackMode.shuffle] in a
/// session means "shuffle was on"; the underlying repeat preference is not
/// stored separately yet and restores as [PlaybackRepeatMode.all].
enum PlaybackMode { sequential, repeatOne, repeatAll, shuffle }

/// List-loop behaviour independent of shuffle.
enum PlaybackRepeatMode { off, one, all }

extension PlaybackModeLabel on PlaybackMode {
  String get label => switch (this) {
    PlaybackMode.sequential => '顺序播放',
    PlaybackMode.repeatOne => '单曲循环',
    PlaybackMode.repeatAll => '列表循环',
    PlaybackMode.shuffle => '随机播放',
  };

  /// Icon for the combined mode control on now-playing.
  IconData get icon => switch (this) {
    PlaybackMode.sequential => Icons.arrow_forward_rounded,
    PlaybackMode.repeatOne => Icons.repeat_one_rounded,
    PlaybackMode.repeatAll => Icons.repeat_rounded,
    PlaybackMode.shuffle => Icons.shuffle_rounded,
  };
}

extension PlaybackRepeatModeLabel on PlaybackRepeatMode {
  String get label => switch (this) {
    PlaybackRepeatMode.off => '顺序播放',
    PlaybackRepeatMode.one => '单曲循环',
    PlaybackRepeatMode.all => '列表循环',
  };
}
