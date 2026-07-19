import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import 'sound_components.dart';
import 'sound_metadata_line.dart';

Future<void> showPlaybackQueueSheet(
  BuildContext context,
  SoundPlaybackController playback, {
  ValueChanged<Album>? onOpenAlbum,
  ValueChanged<String>? onOpenArtist,
}) {
  return showSoundBottomSheet<void>(
    context,
    showHandle: false,
    builder: (_) => PlaybackQueueSheet(
      playback: playback,
      onOpenAlbum: onOpenAlbum,
      onOpenArtist: onOpenArtist,
    ),
  );
}

class PlaybackQueueSheet extends StatelessWidget {
  const PlaybackQueueSheet({
    required this.playback,
    this.onOpenAlbum,
    this.onOpenArtist,
    super.key,
  });

  final SoundPlaybackController playback;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: PlaybackQueuePanel(
        playback: playback,
        onClose: () => Navigator.of(context).pop(),
        onOpenAlbum: onOpenAlbum,
        onOpenArtist: onOpenArtist,
      ),
    );
  }
}

/// Queue content that can live in either the bottom sheet or the desktop
/// now-playing side pane.
class PlaybackQueuePanel extends StatelessWidget {
  const PlaybackQueuePanel({
    required this.playback,
    this.embedded = false,
    this.onClose,
    this.onOpenAlbum,
    this.onOpenArtist,
    super.key,
  });

  final SoundPlaybackController playback;
  final bool embedded;
  final VoidCallback? onClose;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final compact = embedded || context.soundIsCompact;
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final queue = playback.queue;
        final activeId = playback.displayTrack?.id;
        return Column(
          children: [
            if (!embedded) ...[
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.soundSecondaryText.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
            Padding(
              padding: embedded
                  ? const EdgeInsets.fromLTRB(0, 2, 0, 10)
                  : const EdgeInsets.fromLTRB(22, 18, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          embedded ? '播放清单' : '播放队列',
                          style: TextStyle(
                            fontSize: embedded ? 16 : 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${queue.length} 首歌 · ${playback.playbackMode.label}',
                          style: TextStyle(
                            color: context.soundSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: queue.isEmpty ? null : playback.clearQueue,
                    style: context.soundDestructiveButtonStyle,
                    child: const Text('清空'),
                  ),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      tooltip: '关闭播放队列',
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ),
            Padding(
              padding: embedded
                  ? const EdgeInsets.fromLTRB(0, 0, 0, 12)
                  : const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SoundChoiceStrip<PlaybackMode>(
                  selected: playback.playbackMode,
                  onSelected: playback.setPlaybackMode,
                  spacing: 8,
                  options: [
                    for (final mode in PlaybackMode.values)
                      SoundChoiceOption(
                        value: mode,
                        label: mode.label,
                        icon: _playbackModeIcon(mode),
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: context.soundDivider),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text(
                        '播放队列是空的',
                        style: TextStyle(color: context.soundSecondaryText),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.fromLTRB(
                        embedded ? 0 : 12,
                        8,
                        embedded ? 0 : 12,
                        24,
                      ),
                      buildDefaultDragHandles: false,
                      itemCount: queue.length,
                      onReorderItem: playback.moveQueueItem,
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        final active = track.id == activeId;
                        final album = albumForTrack(track);
                        final openAlbum = onOpenAlbum == null
                            ? null
                            : () {
                                onClose?.call();
                                onOpenAlbum!(album);
                              };
                        final openArtist = onOpenArtist == null
                            ? null
                            : () {
                                onClose?.call();
                                onOpenArtist!(track.artist);
                              };
                        if (compact) {
                          return SoundTrackActivation(
                            key: ValueKey(track.id),
                            onActivate: () => playback.playQueueIndex(index),
                            semanticLabel: track.title,
                            showFocusOutline: false,
                            focusColor: context.soundTint(0.045),
                            borderRadius: BorderRadius.zero,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: active
                                    ? SoundColors.accent.withValues(
                                        alpha: 0.035,
                                      )
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: context.soundDivider.withValues(
                                      alpha: context.soundDivider.a * 0.72,
                                    ),
                                  ),
                                ),
                              ),
                              child: SoundCompactMediaRow(
                                key: ValueKey('queue-track-row-${track.id}'),
                                leading: active
                                    ? Icon(
                                        Icons.graphic_eq_rounded,
                                        color: SoundColors.accent.withValues(
                                          alpha: 0.86,
                                        ),
                                        size: 18,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          color: context.soundMutedText,
                                        ),
                                      ),
                                title: track.title,
                                titleColor: active
                                    ? SoundColors.accent.withValues(alpha: 0.9)
                                    : null,
                                subtitleWidget: SoundMetadataLine(
                                  artist: track.artist,
                                  album: track.albumTitle,
                                  separator: ' — ',
                                  onOpenArtist: openArtist,
                                  onOpenAlbum: openAlbum,
                                  style: TextStyle(
                                    color: context.soundMutedText,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SoundMenuButton<String>(
                                      key: ValueKey(
                                        'queue-track-actions-${track.id}',
                                      ),
                                      tooltip: '更多操作 ${track.title}',
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.more_horiz_rounded,
                                        size: 21,
                                      ),
                                      menuTitle: track.title,
                                      onSelected: (value) {
                                        if (value == 'remove') {
                                          playback.removeQueueItemAt(index);
                                        }
                                      },
                                      actions: const [
                                        SoundMenuAction(
                                          value: 'remove',
                                          label: '从队列移除',
                                          icon: Icons.playlist_remove_rounded,
                                          destructive: true,
                                        ),
                                      ],
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          size: 20,
                                          color: context.soundMutedText,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return SoundListRow(
                          key: ValueKey(track.id),
                          selected: active,
                          onTap: () => playback.playQueueIndex(index),
                          leading: SizedBox(
                            width: 30,
                            child: active
                                ? Icon(
                                    Icons.graphic_eq_rounded,
                                    color: SoundColors.accent,
                                  )
                                : Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: context.soundSecondaryText
                                            .withValues(alpha: 0.72),
                                      ),
                                    ),
                                  ),
                          ),
                          title: Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: SoundMetadataLine(
                            artist: track.artist,
                            album: track.albumTitle,
                            onOpenArtist: openArtist,
                            onOpenAlbum: openAlbum,
                            style: TextStyle(color: context.soundSecondaryText),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    playback.removeQueueItemAt(index),
                                tooltip: '从队列移除 ${track.title}',
                                icon: const Icon(Icons.close_rounded),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.drag_handle_rounded,
                                    color: context.soundSecondaryText
                                        .withValues(alpha: 0.72),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

IconData _playbackModeIcon(PlaybackMode mode) => switch (mode) {
  PlaybackMode.sequential => Icons.arrow_forward_rounded,
  PlaybackMode.repeatOne => Icons.repeat_one_rounded,
  PlaybackMode.repeatAll => Icons.repeat_rounded,
  PlaybackMode.shuffle => Icons.shuffle_rounded,
};
