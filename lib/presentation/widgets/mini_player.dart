import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import 'album_art.dart';
import 'progress_scrubber.dart';
import 'source_badge.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({
    required this.playback,
    required this.onOpen,
    required this.compact,
    super.key,
  });

  final SoundPlaybackController playback;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final track = playback.currentTrack;
        if (track == null) return const SizedBox.shrink();
        final album = albumForTrack(track);
        final snapshot = playback.snapshot;
        final duration = snapshot.duration;
        final remaining = duration - snapshot.position;
        final sliderMax = duration > Duration.zero
            ? duration.inMilliseconds.toDouble()
            : 1.0;
        final remainingLabel = duration > Duration.zero
            ? '-${formatDuration(remaining.isNegative ? Duration.zero : remaining)}'
            : '0:00';
        return ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              height: compact ? 64 : 76,
              padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E5DF).withValues(alpha: 0.91),
                borderRadius: BorderRadius.circular(compact ? 16 : 20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox.square(
                      dimension: compact ? 46 : 52,
                      child: AlbumArt(album: album, borderRadius: 6),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    flex: compact ? 1 : 2,
                    child: InkWell(
                      onTap: onOpen,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xE0000000),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${track.artist} — ${track.albumTitle}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0x8F000000),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 7),
                                SourceBadge(track.source),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _DarkIconButton(
                                icon: Icons.skip_previous_rounded,
                                onTap: playback.previous,
                              ),
                              _DarkIconButton(
                                icon: playback.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                onTap: playback.toggle,
                                size: 24,
                              ),
                              _DarkIconButton(
                                icon: Icons.skip_next_rounded,
                                onTap: playback.next,
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 20,
                            child: Row(
                              children: [
                                Text(
                                  formatDuration(snapshot.position),
                                  style: _timeStyle,
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      thumbShape: SliderComponentShape.noThumb,
                                      overlayShape:
                                          SliderComponentShape.noOverlay,
                                      trackHeight: 3,
                                      activeTrackColor: Colors.black87,
                                      inactiveTrackColor: Colors.black12,
                                    ),
                                    child: Slider(
                                      value: snapshot.position.inMilliseconds
                                          .toDouble()
                                          .clamp(0, sliderMax),
                                      max: sliderMax,
                                      onChanged: null,
                                    ),
                                  ),
                                ),
                                Text(remainingLabel, style: _timeStyle),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _DarkIconButton(
                      icon: Icons.favorite_border_rounded,
                      onTap: () {},
                    ),
                    _DarkIconButton(icon: Icons.lyrics_outlined, onTap: onOpen),
                    _DarkIconButton(
                      icon: Icons.queue_music_rounded,
                      onTap: onOpen,
                    ),
                    const SizedBox(width: 4),
                  ] else ...[
                    _DarkIconButton(
                      icon: playback.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onTap: playback.toggle,
                      size: 26,
                    ),
                    _DarkIconButton(
                      icon: Icons.skip_next_rounded,
                      onTap: playback.next,
                      size: 25,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DarkIconButton extends StatelessWidget {
  const _DarkIconButton({
    required this.icon,
    required this.onTap,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: const Color(0xD6000000), size: size),
      visualDensity: VisualDensity.compact,
    );
  }
}

const _timeStyle = TextStyle(
  color: Color(0x7F000000),
  fontSize: 9,
  fontFeatures: [FontFeature.tabularFigures()],
);
