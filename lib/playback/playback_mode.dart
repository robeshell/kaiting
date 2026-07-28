import 'package:flutter/material.dart';

import '../core/kaiting_icons.dart';

/// Combined playback mode used by exclusive mode pickers (for example the
/// queue sheet and the now-playing single mode button).
///
/// Runtime state and persistence use [PlaybackPolicy], where shuffle order and
/// repeat behavior are explicit independent axes.
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
    PlaybackMode.sequential => KaitingIcons.forward,
    PlaybackMode.repeatOne => KaitingIcons.repeatOne,
    PlaybackMode.repeatAll => KaitingIcons.repeatAll,
    PlaybackMode.shuffle => KaitingIcons.shuffle,
  };
}

extension PlaybackRepeatModeLabel on PlaybackRepeatMode {
  String get label => switch (this) {
    PlaybackRepeatMode.off => '顺序播放',
    PlaybackRepeatMode.one => '单曲循环',
    PlaybackRepeatMode.all => '列表循环',
  };
}
