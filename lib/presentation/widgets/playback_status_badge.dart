import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../playback/playback_engine.dart';

enum PlaybackPrimaryVisual { none, play, pause, replay, retry }

@immutable
class PlaybackVisualState {
  const PlaybackVisualState({
    required this.label,
    required this.color,
    required this.statusIcon,
    required this.primaryVisual,
    this.busy = false,
  });

  factory PlaybackVisualState.fromSnapshot(
    PlaybackSnapshot snapshot, {
    required bool hasDisplayTrack,
  }) {
    return switch (snapshot.phase) {
      PlaybackPhase.idle => PlaybackVisualState(
        label: hasDisplayTrack ? '等待播放' : '未播放',
        color: Colors.blueGrey,
        statusIcon: Icons.schedule_rounded,
        primaryVisual: hasDisplayTrack
            ? PlaybackPrimaryVisual.play
            : PlaybackPrimaryVisual.none,
      ),
      PlaybackPhase.loading => const PlaybackVisualState(
        label: '正在载入',
        color: Colors.amber,
        statusIcon: Icons.downloading_rounded,
        primaryVisual: PlaybackPrimaryVisual.none,
        busy: true,
      ),
      PlaybackPhase.ready => const PlaybackVisualState(
        label: '已就绪',
        color: Colors.lightBlueAccent,
        statusIcon: Icons.check_circle_outline_rounded,
        primaryVisual: PlaybackPrimaryVisual.play,
      ),
      PlaybackPhase.playing => const PlaybackVisualState(
        label: '正在播放',
        color: SoundColors.local,
        statusIcon: Icons.graphic_eq_rounded,
        primaryVisual: PlaybackPrimaryVisual.pause,
      ),
      PlaybackPhase.paused => const PlaybackVisualState(
        label: '已暂停',
        color: Colors.blueGrey,
        statusIcon: Icons.pause_circle_outline_rounded,
        primaryVisual: PlaybackPrimaryVisual.play,
      ),
      PlaybackPhase.buffering => PlaybackVisualState(
        label: '正在缓冲',
        color: Colors.amber,
        statusIcon: Icons.hourglass_top_rounded,
        primaryVisual: snapshot.isPlaying
            ? PlaybackPrimaryVisual.pause
            : PlaybackPrimaryVisual.play,
        busy: true,
      ),
      PlaybackPhase.completed => const PlaybackVisualState(
        label: '播放完成',
        color: Colors.lightBlueAccent,
        statusIcon: Icons.check_circle_rounded,
        primaryVisual: PlaybackPrimaryVisual.replay,
      ),
      PlaybackPhase.error => const PlaybackVisualState(
        label: '播放错误',
        color: SoundColors.accent,
        statusIcon: Icons.error_outline_rounded,
        primaryVisual: PlaybackPrimaryVisual.retry,
      ),
    };
  }

  final String label;
  final Color color;
  final IconData statusIcon;
  final PlaybackPrimaryVisual primaryVisual;
  final bool busy;

  bool get primaryEnabled => primaryVisual != PlaybackPrimaryVisual.none;

  IconData get primaryIcon => switch (primaryVisual) {
    PlaybackPrimaryVisual.none => Icons.hourglass_empty_rounded,
    PlaybackPrimaryVisual.play => Icons.play_arrow_rounded,
    PlaybackPrimaryVisual.pause => Icons.pause_rounded,
    PlaybackPrimaryVisual.replay => Icons.replay_rounded,
    PlaybackPrimaryVisual.retry => Icons.refresh_rounded,
  };

  String get primaryTooltip => switch (primaryVisual) {
    PlaybackPrimaryVisual.none => label,
    PlaybackPrimaryVisual.play => '播放',
    PlaybackPrimaryVisual.pause => '暂停',
    PlaybackPrimaryVisual.replay => '重新播放',
    PlaybackPrimaryVisual.retry => '重试播放',
  };
}

class PlaybackStatusBadge extends StatelessWidget {
  const PlaybackStatusBadge({
    required this.state,
    this.onLightSurface = false,
    this.compact = false,
    super.key,
  });

  final PlaybackVisualState state;
  final bool onLightSurface;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = onLightSurface
        ? Color.alphaBlend(state.color.withValues(alpha: 0.24), Colors.black)
        : state.color;
    final iconSize = compact ? 10.0 : 12.0;
    return Semantics(
      label: '播放状态：${state.label}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: state.color.withValues(alpha: onLightSurface ? 0.13 : 0.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.busy)
              SizedBox.square(
                dimension: iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: foreground,
                ),
              )
            else
              Icon(state.statusIcon, size: iconSize, color: foreground),
            SizedBox(width: compact ? 3 : 5),
            Text(
              state.label,
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 9 : 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
