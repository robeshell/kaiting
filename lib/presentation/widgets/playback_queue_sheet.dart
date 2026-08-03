import 'package:flutter/material.dart';

import '../../core/brand_tokens.g.dart';
import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import 'animated_artwork_background.dart';
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
    this.useArtworkChrome = false,
    this.onClose,
    this.onOpenAlbum,
    this.onOpenArtist,
    super.key,
  });

  final SoundPlaybackController playback;
  final bool embedded;
  final bool useArtworkChrome;
  final VoidCallback? onClose;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final compact = embedded || context.soundIsCompact;
    final primaryText = useArtworkChrome
        ? context.chromePrimaryText
        : context.soundPrimaryText;
    final secondaryText = useArtworkChrome
        ? context.chromeSecondaryText
        : context.soundSecondaryText;
    final mutedText = useArtworkChrome
        ? context.chromeMutedText
        : context.soundMutedText;
    final divider = useArtworkChrome
        ? primaryText.withValues(alpha: 0.10)
        : context.soundDivider;
    final interactionTint = primaryText.withValues(alpha: 0.045);
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final queue = playback.queue;
        final activeId = playback.displayTrack?.id;
        return Column(
          children: [
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
                          key: embedded
                              ? const ValueKey('embedded-queue-title')
                              : null,
                          embedded ? '播放清单' : '播放队列',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: embedded
                                ? KaiProductTokens
                                      .typographyPlaybackQueueTitleCompact
                                : KaiProductTokens
                                      .typographyPlaybackQueueTitleWide,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${queue.length} 首歌 · ${playback.playbackMode.label}',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: KaiProductTokens
                                .typographyPlaybackQueueMetadata,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: queue.isEmpty ? null : playback.clearQueue,
                    style: context.soundDestructiveButtonStyle,
                    child: Text(
                      '清空',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      tooltip: '关闭播放队列',
                      icon: const Icon(KaitingIcons.close),
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
                  foregroundColor: useArtworkChrome ? secondaryText : null,
                  neutralSurfaceColor: useArtworkChrome
                      ? primaryText.withValues(alpha: 0.04)
                      : null,
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
            Divider(height: 1, color: divider),
            Expanded(
              child: queue.isEmpty
                  ? Center(
                      child: Text(
                        '播放队列是空的',
                        style: TextStyle(color: secondaryText),
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
                            focusColor: interactionTint,
                            borderRadius: BorderRadius.zero,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: active
                                    ? SoundColors.accent.withValues(
                                        alpha: soundListTileSelectedOpacity,
                                      )
                                    : Colors.transparent,
                                border: Border(
                                  bottom: BorderSide(
                                    color: divider.withValues(
                                      alpha: divider.a * 0.72,
                                    ),
                                  ),
                                ),
                              ),
                              child: SoundCompactMediaRow(
                                key: ValueKey('queue-track-row-${track.id}'),
                                leading: active
                                    ? Icon(
                                        KaitingIcons.playing,
                                        color: SoundColors.accent,
                                        size: 18,
                                      )
                                    : Text(
                                        '${index + 1}',
                                        style: TextStyle(color: mutedText),
                                      ),
                                title: track.title,
                                titleColor: active
                                    ? SoundColors.accent.withValues(alpha: 0.9)
                                    : primaryText.withValues(
                                        alpha: primaryText.a * 0.92,
                                      ),
                                subtitleColor: mutedText,
                                subtitleWidget: SoundMetadataLine(
                                  artist: track.artist,
                                  album: track.albumTitle,
                                  separator: ' — ',
                                  onOpenArtist: openArtist,
                                  onOpenAlbum: openAlbum,
                                  style: TextStyle(
                                    color: mutedText,
                                    fontSize: KaiProductTokens
                                        .typographyPlaybackQueueMetadata,
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
                                      icon: Icon(
                                        KaitingIcons.moreHorizontal,
                                        size: 21,
                                        color: mutedText,
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
                                          icon: KaitingIcons.playlistRemove,
                                          destructive: true,
                                        ),
                                      ],
                                    ),
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(
                                          KaitingIcons.dragHandle,
                                          size: 20,
                                          color: mutedText,
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
                                    KaitingIcons.playing,
                                    color: SoundColors.accent,
                                  )
                                : Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: context.soundMutedText,
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
                                  ? FontWeight.w600
                                  : FontWeight.w500,
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
                                icon: const Icon(KaitingIcons.close),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(
                                    KaitingIcons.dragHandle,
                                    color: context.soundMutedText,
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
  PlaybackMode.sequential => KaitingIcons.forward,
  PlaybackMode.repeatOne => KaitingIcons.repeatOne,
  PlaybackMode.repeatAll => KaitingIcons.repeatAll,
  PlaybackMode.shuffle => KaitingIcons.shuffle,
};
