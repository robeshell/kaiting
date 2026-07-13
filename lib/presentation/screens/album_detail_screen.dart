import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/source_badge.dart';

class AlbumDetailScreen extends StatelessWidget {
  const AlbumDetailScreen({
    required this.album,
    required this.playback,
    required this.onBack,
    super.key,
  });

  final Album album;
  final SoundPlaybackController playback;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: playback,
        builder: (context, _) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(album: album, playback: playback, onBack: onBack),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 140),
                sliver: SliverList.builder(
                  itemCount: album.tracks.length,
                  itemBuilder: (context, index) {
                    final track = album.tracks[index];
                    final active = playback.currentTrack?.id == track.id;
                    return _TrackRow(
                      track: track,
                      active: active,
                      onTap: () =>
                          playback.playTrack(track, queue: album.tracks),
                      onPlayNext: () => playback.playNext(track),
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
    required this.onBack,
  });

  final Album album;
  final SoundPlaybackController playback;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final metadata = [
          if (album.genre?.trim().isNotEmpty == true) album.genre!,
          if (album.year != null) '${album.year}',
          '${album.tracks.length} 首歌',
        ].join(' · ');
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '专辑',
              style: TextStyle(
                color: album.palette.first,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              style: TextStyle(
                fontSize: compact ? 30 : 40,
                height: 1.05,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              album.artist,
              style: TextStyle(
                color: album.palette.first.withValues(alpha: 0.95),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  metadata,
                  style: const TextStyle(fontSize: 13, color: Colors.white54),
                ),
                SourceBadge(album.source),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
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
                    backgroundColor: SoundColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 30),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.65, 0.8),
              radius: 1.2,
              colors: [
                album.palette.first.withValues(alpha: 0.22),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(height: 18),
              if (compact) ...[
                Center(child: AlbumArt(album: album, size: 230)),
                const SizedBox(height: 28),
                details,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AlbumArt(album: album, size: 260),
                    const SizedBox(width: 30),
                    Expanded(child: details),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.active,
    required this.onTap,
    required this.onPlayNext,
  });

  final Track track;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: active
                  ? const Icon(
                      Icons.graphic_eq_rounded,
                      color: SoundColors.accent,
                      size: 18,
                    )
                  : Text(
                      track.trackNumber > 0 ? '${track.trackNumber}' : '–',
                      style: const TextStyle(color: Colors.white54),
                    ),
            ),
            Expanded(
              child: Text(
                track.title,
                style: TextStyle(
                  color: active ? SoundColors.accent : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDuration(track.duration),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            PopupMenuButton<String>(
              key: ValueKey('track-actions-${track.id}'),
              tooltip: '歌曲操作',
              onSelected: (value) {
                if (value == 'play-next') onPlayNext();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'play-next',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.playlist_play_rounded),
                    title: Text('下一首播放'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
