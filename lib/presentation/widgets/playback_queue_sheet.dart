import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import 'sound_components.dart';

Future<void> showPlaybackQueueSheet(
  BuildContext context,
  SoundPlaybackController playback,
) {
  return showSoundBottomSheet<void>(
    context,
    showHandle: false,
    builder: (_) => PlaybackQueueSheet(playback: playback),
  );
}

class PlaybackQueueSheet extends StatelessWidget {
  const PlaybackQueueSheet({required this.playback, super.key});

  final SoundPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return FractionallySizedBox(
      heightFactor: 0.78,
      child: AnimatedBuilder(
        animation: playback,
        builder: (context, _) {
          final queue = playback.queue;
          final activeId = playback.displayTrack?.id;
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.soundSecondaryText.withValues(alpha: 0.38),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '播放队列',
                            style: TextStyle(
                              fontSize: 22,
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
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: '关闭播放队列',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  children: [
                    for (final mode in PlaybackMode.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(mode.label),
                          selected: playback.playbackMode == mode,
                          onSelected: (_) => playback.setPlaybackMode(mode),
                          selectedColor: SoundColors.accent.withValues(
                            alpha: 0.24,
                          ),
                          side: BorderSide(
                            color: playback.playbackMode == mode
                                ? SoundColors.accent
                                : context.soundDivider,
                          ),
                        ),
                      ),
                  ],
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
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        buildDefaultDragHandles: false,
                        itemCount: queue.length,
                        onReorderItem: playback.moveQueueItem,
                        itemBuilder: (context, index) {
                          final track = queue[index];
                          final active = track.id == activeId;
                          if (compact) {
                            return SoundTrackActivation(
                              key: ValueKey(track.id),
                              onActivate: () => playback.playQueueIndex(index),
                              semanticLabel: track.title,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: active
                                      ? SoundColors.accent.withValues(
                                          alpha: 0.075,
                                        )
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: context.soundDivider,
                                    ),
                                  ),
                                ),
                                child: SoundCompactMediaRow(
                                  key: ValueKey('queue-track-row-${track.id}'),
                                  leading: active
                                      ? const Icon(
                                          Icons.graphic_eq_rounded,
                                          color: SoundColors.accent,
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
                                      ? SoundColors.accent
                                      : null,
                                  subtitle:
                                      '${track.artist} — ${track.albumTitle}',
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PopupMenuButton<String>(
                                        key: ValueKey(
                                          'queue-track-actions-${track.id}',
                                        ),
                                        tooltip: '更多操作 ${track.title}',
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.more_horiz_rounded,
                                          size: 21,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'remove') {
                                            playback.removeQueueItemAt(index);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Text('从队列移除'),
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
                          return ListTile(
                            key: ValueKey(track.id),
                            selected: active,
                            selectedTileColor: SoundColors.accent.withValues(
                              alpha: 0.08,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onTap: () => playback.playQueueIndex(index),
                            leading: SizedBox(
                              width: 30,
                              child: active
                                  ? const Icon(
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
                            subtitle: Text(
                              '${track.artist} · ${track.albumTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.soundSecondaryText,
                              ),
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
      ),
    );
  }
}
