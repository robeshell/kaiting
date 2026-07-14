import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../../playback/lyrics_timeline.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/playback_status_badge.dart';
import '../widgets/playback_queue_sheet.dart';
import '../widgets/progress_scrubber.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({required this.playback, this.userState, super.key});

  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([playback, ?userState]),
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
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                            ),
                            const Spacer(),
                            PlaybackStatusBadge(state: visual),
                            const Spacer(),
                            IconButton.filledTonal(
                              onPressed: () =>
                                  showPlaybackQueueSheet(context, playback),
                              tooltip: '播放队列',
                              icon: const Icon(Icons.queue_music_rounded),
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
                                userState: userState,
                              );
                            }
                            return _WideNowPlaying(
                              album: album,
                              track: track,
                              playback: playback,
                              userState: userState,
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
      ),
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
    this.userState,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;

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
                      userState: userState,
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
                  discontinuityRevision: playback.positionDiscontinuityRevision,
                  onSeek: playback.seek,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactNowPlaying extends StatefulWidget {
  const _CompactNowPlaying({
    required this.album,
    required this.track,
    required this.playback,
    this.userState,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;

  @override
  State<_CompactNowPlaying> createState() => _CompactNowPlayingState();
}

class _CompactNowPlayingState extends State<_CompactNowPlaying> {
  bool _showLyrics = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _NowPlayingViewSwitch(
          showLyrics: _showLyrics,
          onChanged: (value) => setState(() => _showLyrics = value),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _showLyrics
                ? Padding(
                    key: const ValueKey('compact-lyrics'),
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 12),
                    child: _LyricsPanel(
                      track: widget.track,
                      position: widget.playback.displayPosition,
                      discontinuityRevision:
                          widget.playback.positionDiscontinuityRevision,
                      onSeek: widget.playback.seek,
                    ),
                  )
                : SingleChildScrollView(
                    key: const ValueKey('compact-player'),
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: _PlayerColumn(
                          album: widget.album,
                          track: widget.track,
                          playback: widget.playback,
                          userState: widget.userState,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _NowPlayingViewSwitch extends StatelessWidget {
  const _NowPlayingViewSwitch({
    required this.showLyrics,
    required this.onChanged,
  });

  final bool showLyrics;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '正在播放视图',
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NowPlayingViewChoice(
              label: '封面',
              selected: !showLyrics,
              onTap: () => onChanged(false),
            ),
            _NowPlayingViewChoice(
              label: '歌词',
              selected: showLyrics,
              onTap: () => onChanged(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPlayingViewChoice extends StatelessWidget {
  const _NowPlayingViewChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
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
    this.userState,
    this.artSize,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
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
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (userState case final state?)
              IconButton(
                key: ValueKey('add-now-playing-${track.id}-to-playlist'),
                onPressed: () => showAddToPlaylistSheet(
                  context,
                  userState: state,
                  track: track,
                ),
                tooltip: '添加到播放列表',
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            if (userState case final state?)
              IconButton(
                key: ValueKey('favorite-now-playing-${track.id}'),
                onPressed: () => unawaited(state.toggleFavorite(track)),
                tooltip: state.isFavorite(track.id) ? '取消收藏' : '收藏歌曲',
                color: state.isFavorite(track.id) ? SoundColors.accent : null,
                icon: Icon(
                  state.isFavorite(track.id)
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
          ],
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
              onPressed: playback.toggleShuffle,
              tooltip: PlaybackMode.shuffle.label,
              icon: const Icon(Icons.shuffle_rounded),
              color: playback.playbackMode == PlaybackMode.shuffle
                  ? SoundColors.accent
                  : null,
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
              onPressed: playback.cycleRepeatMode,
              tooltip: playback.playbackMode.label,
              icon: Icon(
                playback.playbackMode == PlaybackMode.repeatOne
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
              ),
              color:
                  playback.playbackMode == PlaybackMode.repeatAll ||
                      playback.playbackMode == PlaybackMode.repeatOne
                  ? SoundColors.accent
                  : null,
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

class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({
    required this.track,
    required this.position,
    required this.discontinuityRevision,
    required this.onSeek,
  });

  final Track track;
  final Duration position;
  final int discontinuityRevision;
  final Future<void> Function(Duration position) onSeek;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  static const _offsetStep = Duration(milliseconds: 500);
  static const _followDuration = Duration(milliseconds: 300);
  static const _manualScrollPause = Duration(seconds: 3);

  final _scrollController = ScrollController();
  late List<GlobalKey> _lineKeys;
  late LyricsTimeline _timeline;
  Duration _offset = Duration.zero;
  int? _lastActiveIndex;
  bool _snapNextFollow = false;
  bool _showingPreamble = true;
  bool _autoFollowPaused = false;
  Timer? _manualScrollTimer;

  Track get track => widget.track;

  @override
  void initState() {
    super.initState();
    _lineKeys = _keysFor(track.lyrics.length);
    _timeline = LyricsTimeline.forTrack(track);
  }

  @override
  void didUpdateWidget(covariant _LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != track.id) {
      _manualScrollTimer?.cancel();
      _offset = Duration.zero;
      _lastActiveIndex = null;
      _snapNextFollow = false;
      _showingPreamble = true;
      _autoFollowPaused = false;
      _lineKeys = _keysFor(track.lyrics.length);
      _timeline = LyricsTimeline.forTrack(track);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } else if (!identical(oldWidget.track.lyrics, track.lyrics)) {
      _lineKeys = _keysFor(track.lyrics.length);
      _timeline = LyricsTimeline.forTrack(track);
      _lastActiveIndex = null;
    } else if (widget.discontinuityRevision !=
            oldWidget.discontinuityRevision ||
        widget.position + const Duration(milliseconds: 500) <
            oldWidget.position) {
      // Seeks and repeat-one wraps cancel any old follow animation.
      _manualScrollTimer?.cancel();
      _autoFollowPaused = false;
      _snapNextFollow = true;
      _lastActiveIndex = null;
    }
  }

  @override
  void dispose() {
    _manualScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<GlobalKey> _keysFor(int length) =>
      List.generate(length, (index) => GlobalKey(debugLabel: 'lyric-$index'));

  void _followActiveLine(int active) {
    final cueStart = _timeline.cueStartIndex(active);
    if (_autoFollowPaused || _lastActiveIndex == cueStart) return;
    _showingPreamble = false;
    final snap = _snapNextFollow;
    _snapNextFollow = false;
    _lastActiveIndex = cueStart;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoFollowPaused || cueStart >= _lineKeys.length) {
        return;
      }
      final lineContext = _lineKeys[cueStart].currentContext;
      if (lineContext == null) return;
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.45,
        duration: snap ? Duration.zero : _followDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _followPreamble() {
    if (_autoFollowPaused || _showingPreamble) return;
    _showingPreamble = true;
    _lastActiveIndex = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(0);
    });
  }

  Future<void> _seekToLine(int index, LyricLine line) async {
    final timestamp = line.time;
    if (timestamp == null || !_timeline.isSeekable(index)) return;
    final target = timestamp - _offset;
    _resumeAutoFollow();
    await widget.onSeek(target.isNegative ? Duration.zero : target);
  }

  void _pauseAutoFollow() {
    if (!_timeline.isSynchronized) return;
    _manualScrollTimer?.cancel();
    if (!_autoFollowPaused && mounted) {
      setState(() => _autoFollowPaused = true);
    }
    _manualScrollTimer = Timer(_manualScrollPause, _resumeAutoFollow);
  }

  void _resumeAutoFollow() {
    _manualScrollTimer?.cancel();
    _manualScrollTimer = null;
    if (!mounted) return;
    setState(() {
      _autoFollowPaused = false;
      _snapNextFollow = true;
      _lastActiveIndex = null;
    });
  }

  void _changeOffset(Duration delta) {
    setState(() {
      _offset += delta;
      _lastActiveIndex = null;
      _showingPreamble = false;
      _snapNextFollow = true;
    });
  }

  String get _offsetLabel {
    final seconds = _offset.inMilliseconds / 1000;
    return '${seconds >= 0 ? '+' : ''}${seconds.toStringAsFixed(1)}s';
  }

  Widget _buildLyricLine(
    List<LyricLine> lyrics,
    int index, {
    required int? active,
    required bool synchronized,
  }) {
    final isActive = _timeline.isInCue(index, active);
    final line = lyrics[index];
    return GestureDetector(
      key: _lineKeys[index],
      behavior: HitTestBehavior.opaque,
      onTap: !_timeline.isSeekable(index)
          ? null
          : () => _seekToLine(index, line),
      // The cue must become visibly active on its timestamp. Animating the
      // text style here made a correct cue index appear roughly 320 ms late.
      child: AnimatedDefaultTextStyle(
        duration: Duration.zero,
        style: TextStyle(
          color: Colors.white.withValues(
            alpha: isActive
                ? 1
                : active != null && index < active
                ? 0.28
                : 0.5,
          ),
          fontSize: isActive ? 23 : 22,
          height: synchronized ? 2.4 : 1.75,
          fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
          letterSpacing: -0.4,
        ),
        child: Text(line.text),
      ),
    );
  }

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
    final synchronized = _timeline.isSynchronized;
    final active = synchronized
        ? _timeline.activeLineIndex(widget.position, offset: _offset)
        : null;
    if (active != null) {
      _followActiveLine(active);
    } else if (synchronized) {
      _followPreamble();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              synchronized && _timeline.hasTimedContent ? '同步歌词' : '歌词',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (synchronized && _timeline.hasTimedContent) ...[
              const Spacer(),
              if (_autoFollowPaused) ...[
                _LyricsOffsetButton(
                  label: '回到当前',
                  tooltip: '恢复自动跟随',
                  onTap: _resumeAutoFollow,
                ),
                const SizedBox(width: 8),
              ],
              _LyricsOffsetButton(
                label: '−0.5',
                tooltip: '歌词延后 0.5 秒',
                onTap: () => _changeOffset(-_offsetStep),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: _offset == Duration.zero
                      ? null
                      : () => setState(() {
                          _offset = Duration.zero;
                          _lastActiveIndex = null;
                          _snapNextFollow = true;
                        }),
                  child: Text(
                    _offsetLabel,
                    style: TextStyle(
                      color: _offset == Duration.zero
                          ? Colors.white38
                          : Colors.white70,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              _LyricsOffsetButton(
                label: '+0.5',
                tooltip: '歌词提前 0.5 秒',
                onTap: () => _changeOffset(_offsetStep),
              ),
            ],
          ],
        ),
        const SizedBox(height: 26),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) _pauseAutoFollow();
              },
              child: NotificationListener<ScrollStartNotification>(
                onNotification: (notification) {
                  if (notification.dragDetails != null) _pauseAutoFollow();
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: math.max(110, constraints.maxHeight * 0.45),
                    bottom: math.max(110, constraints.maxHeight * 0.55),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var index = 0; index < lyrics.length; index++)
                        _buildLyricLine(
                          lyrics,
                          index,
                          active: active,
                          synchronized: synchronized,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LyricsOffsetButton extends StatelessWidget {
  const _LyricsOffsetButton({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
