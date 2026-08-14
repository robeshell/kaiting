import 'package:flutter/material.dart';

import '../../core/brand_tokens.g.dart';
import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import 'album_art.dart';
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
                    style: TextButton.styleFrom(
                      foregroundColor: context.soundColors.primary,
                      textStyle: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    child: const Text('清除'),
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
                        24 + MediaQuery.paddingOf(context).bottom,
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
                                leading: _QueueTrackLeading(
                                  album: album,
                                  index: index,
                                  active: active,
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
                          leading: _QueueTrackLeading(
                            album: album,
                            index: index,
                            active: active,
                            size: 40,
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

class _QueueTrackLeading extends StatelessWidget {
  const _QueueTrackLeading({
    required this.album,
    required this.index,
    required this.active,
    this.size,
  });

  final Album album;
  final int index;
  final bool active;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final plate = Stack(
      fit: StackFit.expand,
      children: [
        AlbumArt(
          album: album,
          size: size,
          borderRadius: 8,
          showShadow: false,
          cacheExtent: 80,
        ),
        if (active)
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x8A000000),
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(
              KaitingIcons.playing,
              color: Color(0xFFF5F5F5),
              size: 16,
            ),
          )
        else
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xB3000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFFF0F0F0),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (size == null) return plate;
    return SizedBox.square(dimension: size, child: plate);
  }
}

IconData _playbackModeIcon(PlaybackMode mode) => switch (mode) {
  PlaybackMode.sequential => KaitingIcons.forward,
  PlaybackMode.repeatOne => KaitingIcons.repeatOne,
  PlaybackMode.repeatAll => KaitingIcons.repeatAll,
  PlaybackMode.shuffle => KaitingIcons.shuffle,
};
