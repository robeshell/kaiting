import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import 'album_art.dart';
import 'album_cover_flow.dart';
import 'ipod_album_flip_card.dart';
import 'progress_scrubber.dart';

/// Compact iPod now playing: cover on the left, song on the right.
///
/// Sized to the Cover Flow plate, not the window. A full-bleed art
/// column made this feel like a different, oversized player.
class IpodNowPlaying extends StatelessWidget {
  const IpodNowPlaying({
    required this.playback,
    required this.fallbackAlbum,
    required this.onMenu,
    this.albums = const [],
    this.coverSize = 200,
    super.key,
  });

  final SoundPlaybackController playback;
  final Album fallbackAlbum;
  final List<Album> albums;
  final VoidCallback onMenu;
  final double coverSize;

  Album _albumFor(Track? track) {
    return coverFlowAlbumForTrack(track, albums) ?? fallbackAlbum;
  }

  @override
  Widget build(BuildContext context) {
    final insets = coverFlowSafeInsets(context);
    return Material(
      key: const ValueKey('ipod-now-playing'),
      color: const Color(0xCC050505),
      child: Padding(
        padding: insets,
        child: AnimatedBuilder(
          animation: playback,
          builder: (context, _) {
            final track =
                playback.displayTrack ??
                (fallbackAlbum.tracks.isEmpty
                    ? null
                    : fallbackAlbum.tracks.first);
            final album = _albumFor(track);
            return Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      TextButton(
                        key: const ValueKey('ipod-now-playing-menu'),
                        onPressed: onMenu,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFE8E8E8),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('菜单'),
                      ),
                      const Expanded(
                        child: Text(
                          '正在播放',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD8D8D8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 56),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final art = math.min(
                        math.min(coverSize, 220.0),
                        math.max(96.0, constraints.maxHeight - 8),
                      );
                      final songWidth = math.min(
                        240.0,
                        math.max(160.0, constraints.maxWidth - art - 28),
                      );
                      return Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AlbumArt(
                              key: ValueKey('ipod-now-playing-art-${album.id}'),
                              album: album,
                              size: art,
                              borderRadius: 4,
                              showShadow: true,
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: songWidth,
                              child: _NowPlayingSong(
                                album: album,
                                track: track,
                                playback: playback,
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
      ),
    );
  }
}

class _NowPlayingSong extends StatelessWidget {
  const _NowPlayingSong({
    required this.album,
    required this.track,
    required this.playback,
  });

  final Album album;
  final Track? track;
  final SoundPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track?.title ?? album.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF4F4F4),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          track?.artist ?? album.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF9A9A9A),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        if ((track?.albumTitle ?? album.title).isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            track?.albumTitle ?? album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7A7A7A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _IpodScrubber(playback: playback),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('ipod-now-playing-previous'),
              tooltip: '上一首',
              onPressed: () => unawaited(playback.previous()),
              color: const Color(0xFFF2F2F2),
              style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
              icon: const Icon(KaitingIcons.previous, size: 22),
            ),
            IconButton(
              key: const ValueKey('ipod-now-playing-toggle'),
              tooltip: playback.isPlaying ? '暂停' : '播放',
              onPressed: () => unawaited(playback.toggle()),
              color: const Color(0xFFF2F2F2),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(
                playback.isPlaying ? KaitingIcons.pause : KaitingIcons.play,
                size: 28,
              ),
            ),
            IconButton(
              key: const ValueKey('ipod-now-playing-next'),
              tooltip: '下一首',
              onPressed: () => unawaited(playback.next()),
              color: const Color(0xFFF2F2F2),
              style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
              icon: const Icon(KaitingIcons.next, size: 22),
            ),
          ],
        ),
      ],
    );
  }
}

class _IpodScrubber extends StatelessWidget {
  const _IpodScrubber({required this.playback});

  final SoundPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback.positionListenable,
      builder: (context, _) {
        final position = playback.displayPosition;
        final duration = playback.displayDuration;
        final remaining = duration > position
            ? duration - position
            : Duration.zero;
        return Column(
          children: [
            ProgressScrubber(
              position: position,
              duration: duration,
              onSeek: playback.seek,
              activeColor: const Color(0xFFF4F4F4),
              inactiveColor: const Color(0x33FFFFFF),
              trackHeight: 2,
              thumbRadius: 4,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  Text(
                    formatIpodDuration(position),
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '-${formatIpodDuration(remaining)}',
                    style: const TextStyle(
                      color: Color(0xFF8A8A8A),
                      fontSize: 10,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
