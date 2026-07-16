import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../offline/offline_media_provider.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../controllers/library_user_state_controller.dart';
import '../controllers/offline_download_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/sound_components.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({
    required this.album,
    required this.playback,
    this.userState,
    this.offline,
    required this.onBack,
    super.key,
  });

  final Album album;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final OfflineDownloadController? offline;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([playback, ?userState, ?offline]),
        builder: (context, _) {
          final discNumbers = {
            for (final track in album.tracks) _effectiveDiscNumber(track),
          };
          final showDiscSections = discNumbers.length > 1;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  album: album,
                  playback: playback,
                  offline: offline,
                  onBack: onBack,
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  context.soundPageGutter,
                  8,
                  context.soundPageGutter,
                  context.soundContentBottomPadding,
                ),
                sliver: SliverList.builder(
                  itemCount: album.tracks.length,
                  itemBuilder: (context, index) {
                    final track = album.tracks[index];
                    final active = playback.currentTrack?.id == track.id;
                    final discNumber = _effectiveDiscNumber(track);
                    final startsDisc =
                        showDiscSections &&
                        (index == 0 ||
                            _effectiveDiscNumber(album.tracks[index - 1]) !=
                                discNumber);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (startsDisc) _DiscHeader(number: discNumber),
                        _TrackRow(
                          track: track,
                          active: active,
                          favorite: userState?.isFavorite(track.id) ?? false,
                          onTap: () =>
                              playback.playTrack(track, queue: album.tracks),
                          onPlayNext: () => playback.playNext(track),
                          onToggleFavorite: userState == null
                              ? null
                              : () =>
                                    unawaited(userState!.toggleFavorite(track)),
                          onAddToPlaylist: userState == null
                              ? null
                              : () => showAddToPlaylistSheet(
                                  context,
                                  userState: userState!,
                                  track: track,
                                ),
                          offline: offline,
                          onToggleOffline:
                              offline == null || !offline!.supports(track)
                              ? null
                              : () => unawaited(
                                  _toggleTrackOffline(context, offline!, track),
                                ),
                        ),
                      ],
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

class _Hero extends StatelessWidget {
  const _Hero({
    required this.album,
    required this.playback,
    required this.offline,
    required this.onBack,
  });

  final Album album;
  final SoundPlaybackController playback;
  final OfflineDownloadController? offline;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = context.soundIsCompact;
        final discCount = {
          for (final track in album.tracks) _effectiveDiscNumber(track),
        }.length;
        final metadata = [
          if (album.genre?.trim().isNotEmpty == true) album.genre!,
          if (album.year != null) '${album.year}',
          if (discCount > 1) '$discCount 张碟',
          '${album.tracks.length} 首歌',
        ].join(' · ');
        final supportedTracks = offline == null
            ? const <Track>[]
            : album.tracks.where(offline!.supports).toList(growable: false);
        final allOffline =
            supportedTracks.isNotEmpty &&
            offline!.areAllPinned(supportedTracks);
        final downloading =
            supportedTracks.isNotEmpty &&
            offline!.isDownloadingAny(supportedTracks);
        final offlineProgress = supportedTracks.isEmpty
            ? null
            : offline!.progressFor(supportedTracks);
        final offlineCount = supportedTracks.isEmpty
            ? 0
            : offline!.pinnedCount(supportedTracks);
        final offlineLabel = downloading
            ? '取消下载 ${((offlineProgress ?? 0) * 100).round()}%'
            : allOffline
            ? '已离线'
            : offlineCount > 0
            ? '继续下载 $offlineCount/${supportedTracks.length}'
            : '离线保存';

        if (compact) {
          return Container(
            key: const ValueKey('album-detail-hero'),
            padding: EdgeInsets.fromLTRB(
              context.soundPageGutter,
              8,
              context.soundPageGutter,
              16,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.soundDivider)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onBack,
                  tooltip: '返回',
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: AlbumArt(
                    key: const ValueKey('album-detail-artwork'),
                    album: album,
                    size: 156,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  album.title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  album.artist,
                  style: TextStyle(
                    color: context.soundSecondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  metadata,
                  style: TextStyle(fontSize: 13, color: context.soundMutedText),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: album.tracks.isEmpty
                          ? null
                          : () => playback.playTrack(
                              album.tracks.first,
                              queue: album.tracks,
                            ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('播放'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    if (supportedTracks.isNotEmpty)
                      OutlinedButton.icon(
                        key: const ValueKey('album-offline-action'),
                        onPressed: () => unawaited(
                          _toggleAlbumOffline(context, offline!, album),
                        ),
                        icon: downloading
                            ? const Icon(Icons.close_rounded)
                            : Icon(
                                allOffline
                                    ? Icons.cloud_done_rounded
                                    : Icons.download_for_offline_outlined,
                              ),
                        label: Text(offlineLabel),
                      ),
                  ],
                ),
              ],
            ),
          );
        }

        final artworkSize = (constraints.maxWidth * 0.36)
            .clamp(280.0, 420.0)
            .toDouble();
        final buttonWidth = constraints.maxWidth >= 1040 ? 146.0 : 132.0;
        final horizontalGap = constraints.maxWidth >= 1000 ? 48.0 : 32.0;

        return Container(
          key: const ValueKey('album-detail-hero'),
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            8,
            context.soundPageGutter,
            30,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.soundDivider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('desktop-album-back'),
                    onPressed: onBack,
                    tooltip: '返回',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  if (supportedTracks.isNotEmpty)
                    IconButton.filledTonal(
                      key: const ValueKey('album-offline-action'),
                      onPressed: () => unawaited(
                        _toggleAlbumOffline(context, offline!, album),
                      ),
                      tooltip: offlineLabel,
                      icon: downloading
                          ? const Icon(Icons.close_rounded)
                          : Icon(
                              allOffline
                                  ? Icons.cloud_done_rounded
                                  : Icons.download_for_offline_outlined,
                            ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    key: const ValueKey('desktop-album-actions'),
                    tooltip: '更多专辑操作',
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (value) {
                      if (value == 'shuffle' && album.tracks.isNotEmpty) {
                        playback.setPlaybackMode(PlaybackMode.shuffle);
                        unawaited(
                          playback.playTrack(
                            album.tracks.first,
                            queue: album.tracks,
                          ),
                        );
                      }
                      if (value == 'offline' && supportedTracks.isNotEmpty) {
                        unawaited(
                          _toggleAlbumOffline(context, offline!, album),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'shuffle',
                        child: Text('随机播放'),
                      ),
                      if (supportedTracks.isNotEmpty)
                        PopupMenuItem(
                          value: 'offline',
                          child: Text(offlineLabel),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AlbumArt(
                    key: const ValueKey('album-detail-artwork'),
                    album: album,
                    size: artworkSize,
                    borderRadius: 12,
                  ),
                  SizedBox(width: horizontalGap),
                  Expanded(
                    child: SizedBox(
                      height: artworkSize,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 38,
                              height: 1.04,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.25,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            album.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: SoundColors.accent,
                              fontSize: 28,
                              height: 1.08,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            metadata,
                            style: TextStyle(
                              color: context.soundMutedText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          LayoutBuilder(
                            builder: (context, buttonConstraints) {
                              final condensed =
                                  buttonConstraints.maxWidth <
                                  buttonWidth * 2 + 16;
                              final playButton = _DesktopAlbumActionButton(
                                key: const ValueKey('desktop-album-play'),
                                label: '播放',
                                icon: Icons.play_arrow_rounded,
                                showIcon: !condensed,
                                onPressed: album.tracks.isEmpty
                                    ? null
                                    : () => playback.playTrack(
                                        album.tracks.first,
                                        queue: album.tracks,
                                      ),
                              );
                              final shuffleButton = _DesktopAlbumActionButton(
                                key: const ValueKey('desktop-album-shuffle'),
                                label: '随机播放',
                                icon: Icons.shuffle_rounded,
                                showIcon: !condensed,
                                onPressed: album.tracks.isEmpty
                                    ? null
                                    : () {
                                        playback.setPlaybackMode(
                                          PlaybackMode.shuffle,
                                        );
                                        unawaited(
                                          playback.playTrack(
                                            album.tracks.first,
                                            queue: album.tracks,
                                          ),
                                        );
                                      },
                              );
                              return Row(
                                children: [
                                  if (condensed)
                                    Expanded(child: playButton)
                                  else
                                    SizedBox(
                                      width: buttonWidth,
                                      child: playButton,
                                    ),
                                  SizedBox(width: condensed ? 8 : 16),
                                  if (condensed)
                                    Expanded(child: shuffleButton)
                                  else
                                    SizedBox(
                                      width: buttonWidth,
                                      child: shuffleButton,
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopAlbumActionButton extends StatelessWidget {
  const _DesktopAlbumActionButton({
    required this.label,
    required this.icon,
    required this.showIcon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool showIcon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: EdgeInsets.symmetric(horizontal: showIcon ? 14 : 8),
    );
    if (!showIcon) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label, maxLines: 1),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, maxLines: 1),
      style: style,
    );
  }
}

class _DiscHeader extends StatelessWidget {
  const _DiscHeader({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 24, 14, 8),
      child: Row(
        children: [
          Text(
            '第 $number 碟',
            style: const TextStyle(
              color: SoundColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: context.soundDivider)),
        ],
      ),
    );
  }
}

int _effectiveDiscNumber(Track track) =>
    track.discNumber > 0 ? track.discNumber : 1;

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.active,
    required this.favorite,
    required this.onTap,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.offline,
    required this.onToggleOffline,
  });

  final Track track;
  final bool active;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;
  final OfflineDownloadController? offline;
  final VoidCallback? onToggleOffline;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    final offlineTask = offline?.taskFor(track);
    final downloading =
        offlineTask?.state == OfflineDownloadTaskState.downloading;
    final failed = offlineTask?.state == OfflineDownloadTaskState.failed;
    return SoundTrackActivation(
      onActivate: onTap,
      semanticLabel: track.title,
      showFocusOutline: false,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: ValueKey('album-track-row-${track.id}'),
        constraints: BoxConstraints.tightFor(height: compact ? 64 : 68),
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 18),
        decoration: BoxDecoration(
          color: active
              ? SoundColors.accent.withValues(alpha: 0.075)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: context.soundDivider)),
        ),
        child: compact
            ? SoundCompactMediaRow(
                leading: active
                    ? const Icon(
                        Icons.graphic_eq_rounded,
                        color: SoundColors.accent,
                        size: 18,
                      )
                    : Text(
                        track.trackNumber > 0 ? '${track.trackNumber}' : '–',
                        style: TextStyle(color: context.soundSecondaryText),
                      ),
                title: track.title,
                titleColor: active ? SoundColors.accent : null,
                subtitle: '${track.artist} — ${formatDuration(track.duration)}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onToggleOffline != null)
                      _TrackOfflineIndicator(track: track, offline: offline!),
                    _actions(
                      compact: true,
                      downloading: downloading,
                      failed: failed,
                    ),
                  ],
                ),
              )
            : Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: active
                        ? const Icon(
                            Icons.graphic_eq_rounded,
                            color: SoundColors.accent,
                            size: 18,
                          )
                        : Text(
                            track.trackNumber > 0
                                ? '${track.trackNumber}'
                                : '–',
                            style: TextStyle(color: context.soundSecondaryText),
                          ),
                  ),
                  Expanded(
                    child: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? SoundColors.accent
                            : context.soundPrimaryText,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (onToggleOffline != null) ...[
                    _TrackOfflineIndicator(track: track, offline: offline!),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    formatDuration(track.duration),
                    style: TextStyle(
                      fontSize: 14,
                      color: context.soundSecondaryText,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  _actions(
                    compact: false,
                    downloading: downloading,
                    failed: failed,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _actions({
    required bool compact,
    required bool downloading,
    required bool failed,
  }) {
    return PopupMenuButton<String>(
      key: ValueKey('track-actions-${track.id}'),
      tooltip: '更多操作 ${track.title}',
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, size: 21),
      onSelected: (value) {
        if (value == 'play-next') onPlayNext();
        if (value == 'favorite') onToggleFavorite?.call();
        if (value == 'playlist') onAddToPlaylist?.call();
        if (value == 'offline') onToggleOffline?.call();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'play-next', child: Text('下一首播放')),
        if (onToggleFavorite != null)
          PopupMenuItem(
            value: 'favorite',
            child: Text(favorite ? '取消收藏' : '收藏'),
          ),
        if (onAddToPlaylist != null)
          const PopupMenuItem(value: 'playlist', child: Text('添加到播放列表')),
        if (onToggleOffline != null)
          PopupMenuItem(
            value: 'offline',
            child: Text(
              downloading
                  ? '取消下载'
                  : offline!.isPinned(track)
                  ? '移除离线下载'
                  : failed
                  ? '重试下载'
                  : '离线保存',
            ),
          ),
      ],
    );
  }
}

class _TrackOfflineIndicator extends StatelessWidget {
  const _TrackOfflineIndicator({required this.track, required this.offline});

  final Track track;
  final OfflineDownloadController offline;

  @override
  Widget build(BuildContext context) {
    final task = offline.taskFor(track);
    if (task?.state == OfflineDownloadTaskState.downloading) {
      return SizedBox(
        width: 15,
        height: 15,
        child: CircularProgressIndicator(
          value: task?.progress,
          strokeWidth: 1.8,
          color: SoundColors.webDav,
        ),
      );
    }
    if (task?.state == OfflineDownloadTaskState.failed) {
      return const Icon(
        Icons.error_outline_rounded,
        size: 16,
        color: SoundColors.accent,
      );
    }
    if (offline.isPinned(track)) {
      return const Icon(
        Icons.cloud_done_rounded,
        size: 16,
        color: SoundColors.webDav,
      );
    }
    return const SizedBox.shrink();
  }
}

Future<void> _toggleTrackOffline(
  BuildContext context,
  OfflineDownloadController offline,
  Track track,
) async {
  try {
    if (offline.isDownloading(track)) {
      offline.cancelTrack(track);
      if (context.mounted) {
        _showOfflineMessage(context, '已取消「${track.title}」的下载');
      }
    } else if (offline.isPinned(track)) {
      await offline.removeTrack(track);
      if (context.mounted) {
        _showOfflineMessage(context, '已移除「${track.title}」的离线下载');
      }
    } else {
      await offline.pinTrack(track);
      if (context.mounted) {
        _showOfflineMessage(context, '「${track.title}」已可离线播放');
      }
    }
  } on OfflineDownloadCancelledException {
    // The explicit cancel action already provided user feedback.
  } catch (_) {
    if (!context.mounted) return;
    final message = offline.taskFor(track)?.error ?? '下载失败，请检查网络与来源设置';
    _showOfflineMessage(context, message);
  }
}

Future<void> _toggleAlbumOffline(
  BuildContext context,
  OfflineDownloadController offline,
  Album album,
) async {
  if (offline.isDownloadingAny(album.tracks)) {
    offline.cancelTracks(album.tracks);
    _showOfflineMessage(context, '已取消「${album.title}」的剩余下载');
    return;
  }
  if (offline.areAllPinned(album.tracks)) {
    final confirmed = await _confirmRemoveOfflineAlbum(context, album.title);
    if (!confirmed || !context.mounted) return;
    await offline.removeTracks(album.tracks);
    if (context.mounted) {
      _showOfflineMessage(context, '已移除「${album.title}」的离线下载');
    }
    return;
  }

  final result = await offline.pinTracks(album.tracks);
  if (!context.mounted) return;
  if (result.wasCancelled) {
    return;
  } else if (result.hasFailures) {
    _showOfflineMessage(
      context,
      '已下载 ${result.completed} 首，${result.failed} 首失败，可稍后继续',
    );
  } else {
    _showOfflineMessage(context, '「${album.title}」已可离线播放');
  }
}

Future<bool> _confirmRemoveOfflineAlbum(
  BuildContext context,
  String albumTitle,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => SoundDialog(
          maxWidth: 400,
          title: const Text('移除离线下载？'),
          content: Text(
            '将删除「$albumTitle」已下载的音频，不会影响音乐来源中的原文件。',
            style: TextStyle(color: dialogContext.soundMutedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: dialogContext.soundDestructiveButtonStyle,
              child: const Text('移除'),
            ),
          ],
        ),
      ) ??
      false;
}

void _showOfflineMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
