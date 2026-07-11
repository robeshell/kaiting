import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/playback_status_badge.dart';
import '../widgets/progress_scrubber.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({required this.playback, super.key});

  final SoundPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final track = playback.displayTrack;
        if (track == null) return const _NoTrackPlaying();
        final album = albumForTrack(track);
        final snapshot = playback.snapshot;
        final visual = PlaybackVisualState.fromSnapshot(
          snapshot,
          hasDisplayTrack: true,
        );
        return Scaffold(
          backgroundColor: album.palette.last,
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.7, -0.55),
                    radius: 1.3,
                    colors: [
                      album.palette.first.withValues(alpha: 0.82),
                      album.palette.last,
                    ],
                  ),
                ),
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                          const Spacer(),
                          PlaybackStatusBadge(state: visual),
                          const Spacer(),
                          IconButton.filledTonal(
                            onPressed: () {},
                            icon: const Icon(Icons.more_horiz_rounded),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 780;
                          if (compact) {
                            return _CompactNowPlaying(
                              album: album,
                              track: track,
                              playback: playback,
                            );
                          }
                          return _WideNowPlaying(
                            album: album,
                            track: track,
                            playback: playback,
                          );
                        },
                      ),
                    ),
                    if (snapshot.errorMessage case final message?)
                      _PlaybackErrorBanner(
                        message: message,
                        onRetry: playback.toggle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoTrackPlaying extends StatelessWidget {
  const _NoTrackPlaying();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 20,
              top: 10,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
            const Center(
              child: Text(
                '当前没有正在播放的歌曲',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WideNowPlaying extends StatelessWidget {
  const _WideNowPlaying({
    required this.album,
    required this.track,
    required this.playback,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = math.min(
          340.0,
          math.max(220.0, constraints.maxHeight - 360),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(54, 24, 54, 32),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 390),
                    child: _PlayerColumn(
                      album: album,
                      track: track,
                      playback: playback,
                      artSize: artSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 64),
              Expanded(
                child: _LyricsPanel(
                  track: track,
                  position: playback.displayPosition,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactNowPlaying extends StatelessWidget {
  const _CompactNowPlaying({
    required this.album,
    required this.track,
    required this.playback,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: _PlayerColumn(album: album, track: track, playback: playback),
        ),
      ),
    );
  }
}

class _PlayerColumn extends StatelessWidget {
  const _PlayerColumn({
    required this.album,
    required this.track,
    required this.playback,
    this.artSize,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final double? artSize;

  @override
  Widget build(BuildContext context) {
    final position = playback.displayPosition;
    final duration = playback.displayDuration;
    final visual = PlaybackVisualState.fromSnapshot(
      playback.snapshot,
      hasDisplayTrack: true,
    );
    final remaining = duration - position;
    final remainingLabel = duration > Duration.zero
        ? '-${formatDuration(remaining.isNegative ? Duration.zero : remaining)}'
        : '0:00';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AlbumArt(album: album, size: artSize),
        const SizedBox(height: 30),
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${track.artist} — ${track.albumTitle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 20),
        ProgressScrubber(
          position: position,
          duration: duration,
          onSeek: playback.seek,
        ),
        Row(
          children: [
            Text(formatDuration(position), style: _timeStyle),
            const Spacer(),
            Text(remainingLabel, style: _timeStyle),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.shuffle_rounded),
            ),
            IconButton(
              onPressed: playback.previous,
              icon: const Icon(Icons.skip_previous_rounded),
              iconSize: 34,
            ),
            IconButton.filled(
              onPressed: visual.primaryEnabled ? playback.toggle : null,
              tooltip: visual.primaryTooltip,
              icon: visual.busy && !visual.primaryEnabled
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black54,
                      ),
                    )
                  : Icon(visual.primaryIcon),
              iconSize: 34,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                fixedSize: const Size.square(62),
              ),
            ),
            IconButton(
              onPressed: playback.next,
              icon: const Icon(Icons.skip_next_rounded),
              iconSize: 34,
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.repeat_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaybackErrorBanner extends StatelessWidget {
  const _PlaybackErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SoundColors.accent.withValues(alpha: 0.52)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: SoundColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

const _timeStyle = TextStyle(
  color: Colors.white54,
  fontSize: 11,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({required this.track, required this.position});

  final Track track;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final lyrics = track.lyrics;
    if (lyrics.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '歌词',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '这首歌曲没有内嵌歌词',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      );
    }
    var active = 0;
    for (var index = 0; index < lyrics.length; index++) {
      if (lyrics[index].time <= position + const Duration(milliseconds: 80)) {
        active = index;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '歌词',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 26),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 110),
            itemCount: lyrics.length,
            itemBuilder: (context, index) {
              final isActive = index == active;
              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: isActive
                        ? 1
                        : index < active
                        ? 0.28
                        : 0.5,
                  ),
                  fontSize: 22,
                  height: 2.4,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
                child: Text(lyrics[index].text),
              );
            },
          ),
        ),
      ],
    );
  }
}
