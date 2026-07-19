import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_failure.dart';
import '../../core/now_playing_style.dart';
import '../../core/platform_window.dart';
import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../../playback/lyrics_timeline.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/animated_artwork_background.dart';
import '../widgets/playback_status_badge.dart';
import '../widgets/playback_queue_sheet.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/sound_components.dart';
import '../widgets/sound_metadata_line.dart';
import '../widgets/vinyl_record_art.dart';

/// Whether now-playing should paint custom window drag chrome.
///
/// Uses [defaultTargetPlatform] (not `dart:io` Platform) so widget tests that
/// override the target platform keep mobile layout free of desktop drag bands.
/// Windows-only until a Linux native window channel exists.
bool get _nowPlayingUsesWindowChrome =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({
    required this.playback,
    this.userState,
    this.style = NowPlayingStyle.classic,
    this.openLyricsByDefault = false,
    this.isActive = true,
    this.onClose,
    this.onOpenAlbum,
    this.onOpenArtist,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    super.key,
  });

  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final NowPlayingStyle style;

  /// When true, the compact layout opens on the lyrics pane.
  final bool openLyricsByDefault;

  /// Whether this surface should consume real-time playback ticks and animate
  /// its full-screen background. Mobile keeps this false while the surface is
  /// sliding on or off screen so route motion does not compete with playback
  /// position updates and a full-screen repaint on the same frames.
  final bool isActive;
  final VoidCallback? onClose;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;
  final GestureDragStartCallback? onVerticalDragStart;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final GestureDragCancelCallback? onVerticalDragCancel;

  void _close(BuildContext context) {
    final close = onClose;
    if (close != null) {
      close();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      // Keep this wrapper in the tree while mobile expansion is dragged.
      // Swapping between an AnimatedBuilder and its child replaces the whole
      // player subtree, which makes artwork and the gradient flash for a frame.
      child: AnimatedBuilder(
        animation: isActive
            ? Listenable.merge([playback, ?userState])
            : const _SilentListenable(),
        builder: (context, _) => _buildPlayer(context),
      ),
    );
  }

  Widget _buildPlayer(BuildContext context) {
    final track = playback.displayTrack;
    if (track == null) return _NoTrackPlaying(onClose: onClose);
    final album = albumForTrack(track);
    final snapshot = playback.snapshot;
    final compactChrome = context.soundIsCompact;
    final foldableChrome = context.soundUsesMobileShell && !compactChrome;
    final wideIntegratedQueue = MediaQuery.sizeOf(context).width >= 680;
    return Scaffold(
      backgroundColor: album.palette.last,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedArtworkBackground(
            album: album,
            position: playback.displayPosition,
            isPlaying: snapshot.isPlaying && isActive,
          ),
          SafeArea(
            minimum: EdgeInsets.only(top: context.soundTitlebarInset),
            child: Column(
              children: [
                GestureDetector(
                  key: const ValueKey('now-playing-drag-handle'),
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: onVerticalDragStart,
                  onVerticalDragUpdate: onVerticalDragUpdate,
                  onVerticalDragEnd: onVerticalDragEnd,
                  onVerticalDragCancel: onVerticalDragCancel,
                  child: Padding(
                    padding: compactChrome
                        ? const EdgeInsets.fromLTRB(20, 4, 20, 8)
                        : foldableChrome
                        ? const EdgeInsets.fromLTRB(24, 0, 24, 2)
                        : const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => _close(context),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                        // Empty mid-chrome: drag the window on Windows/Linux
                        // where this route covers the shell title bar.
                        Expanded(
                          child: _nowPlayingUsesWindowChrome
                              ? const _WindowDragSurface(
                                  key: ValueKey(
                                    'now-playing-chrome-window-drag',
                                  ),
                                  // Row/Column leaves height unbounded; match
                                  // the shell title bar's fixed-height hit box.
                                  height: 40,
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (!wideIntegratedQueue)
                          IconButton.filledTonal(
                            onPressed: () => showPlaybackQueueSheet(
                              context,
                              playback,
                              onOpenAlbum: onOpenAlbum,
                              onOpenArtist: onOpenArtist,
                            ),
                            tooltip: '播放队列',
                            icon: const Icon(Icons.queue_music_rounded),
                          ),
                        if (_nowPlayingUsesWindowChrome) ...[
                          const SizedBox(width: 8),
                          const _DesktopWindowControls(),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Open foldables are commonly around 700 logical
                      // pixels wide. Use that space for a centered
                      // two-pane player, with the crease falling inside
                      // the inter-pane gap.
                      final compact = constraints.maxWidth < 680;
                      if (compact) {
                        return _CompactNowPlaying(
                          album: album,
                          track: track,
                          playback: playback,
                          userState: userState,
                          style: style,
                          openLyricsByDefault: openLyricsByDefault,
                          isActive: isActive,
                          onOpenAlbum: onOpenAlbum,
                          onOpenArtist: onOpenArtist,
                          onVerticalDragStart: onVerticalDragStart,
                          onVerticalDragUpdate: onVerticalDragUpdate,
                          onVerticalDragEnd: onVerticalDragEnd,
                          onVerticalDragCancel: onVerticalDragCancel,
                        );
                      }
                      return _WideNowPlaying(
                        album: album,
                        track: track,
                        playback: playback,
                        userState: userState,
                        style: style,
                        isActive: isActive,
                        onOpenAlbum: onOpenAlbum,
                        onOpenArtist: onOpenArtist,
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
          // The shell title bar is covered by this full-screen route. Mirror
          // its drag band so the reserved title-bar inset stays movable on
          // Windows / Linux (native HTCAPTION alone is unreliable under the
          // Flutter child HWND).
          if (_nowPlayingUsesWindowChrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: platformTitleBarHeight,
              child: const _WindowDragSurface(
                key: ValueKey('now-playing-titlebar-window-drag'),
              ),
            ),
        ],
      ),
    );
  }
}

/// A stable, inert animation source used while the mobile player is moving.
///
/// Keeping the same [AnimatedBuilder] element preserves the album artwork,
/// scroll position, and animated background state across drag boundaries.
class _SilentListenable implements Listenable {
  const _SilentListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class _NoTrackPlaying extends StatelessWidget {
  const _NoTrackPlaying({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            minimum: EdgeInsets.only(top: context.soundTitlebarInset),
            child: Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 10,
                  child: IconButton.filledTonal(
                    onPressed:
                        onClose ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
                Center(
                  child: Text(
                    '当前没有正在播放的歌曲',
                    style: TextStyle(color: context.soundSecondaryText),
                  ),
                ),
              ],
            ),
          ),
          if (_nowPlayingUsesWindowChrome)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: platformTitleBarHeight,
              child: const _WindowDragSurface(
                key: ValueKey('now-playing-empty-titlebar-window-drag'),
              ),
            ),
        ],
      ),
    );
  }
}

enum _WideNowPlayingView { lyrics, queue }

enum _LyricsMenuAction { resumeFollow, delay, reset, advance }

class _WideNowPlaying extends StatefulWidget {
  const _WideNowPlaying({
    required this.album,
    required this.track,
    required this.playback,
    required this.style,
    this.userState,
    this.isActive = true,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final NowPlayingStyle style;
  final LibraryUserStateController? userState;
  final bool isActive;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  State<_WideNowPlaying> createState() => _WideNowPlayingState();
}

class _WideNowPlayingState extends State<_WideNowPlaying> {
  _WideNowPlayingView _view = _WideNowPlayingView.lyrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const verticalPadding = 50.0;
        // Vinyl needs more chrome clearance (title gap + controls) than a flat cover.
        final playerChromeHeight =
            widget.style == NowPlayingStyle.vinyl ? 250.0 : 230.0;
        final foldableWidth = constraints.maxWidth < 780;
        final horizontalPadding = foldableWidth ? 24.0 : 44.0;
        final paneGap = math.max(
          foldableWidth ? 24.0 : 48.0,
          _centerDisplayFeatureGap(context, constraints),
        );
        // Classic and vinyl share a balanced dual pane; only artwork differs.
        const playerFlex = 1;
        const contentFlex = 1;
        final availableWidth = math.max(
          320.0,
          constraints.maxWidth - horizontalPadding * 2 - paneGap,
        );
        final paneWidth =
            availableWidth * playerFlex / (playerFlex + contentFlex);
        final playerHeight = math.max(
          0.0,
          constraints.maxHeight - verticalPadding,
        );
        // Foldables (~700px) keep a smaller vinyl so the arm pivot still reads
        // with air above the rim; wide desktops can go larger.
        final artLimit = switch (widget.style) {
          NowPlayingStyle.classic => 340.0,
          NowPlayingStyle.vinyl => foldableWidth ? 360.0 : 440.0,
        };
        final playerWidthLimit = switch (widget.style) {
          NowPlayingStyle.classic => 390.0,
          NowPlayingStyle.vinyl => foldableWidth ? 400.0 : 480.0,
        };
        final artSize = math.min(
          math.min(artLimit, paneWidth),
          math.max(160.0, playerHeight - playerChromeHeight),
        );
        return Padding(
          key: const ValueKey('wide-now-playing-content'),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            24,
          ),
          child: Row(
            crossAxisAlignment: foldableWidth
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: playerFlex,
                child: Padding(
                  padding: EdgeInsets.only(top: foldableWidth ? 18 : 0),
                  child: Align(
                    key: const ValueKey('wide-now-playing-player'),
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: playerWidthLimit),
                      child: SingleChildScrollView(
                        child: _PlayerColumn(
                          album: widget.album,
                          track: widget.track,
                          playback: widget.playback,
                          style: widget.style,
                          userState: widget.userState,
                          isActive: widget.isActive,
                          onOpenAlbum: widget.onOpenAlbum,
                          onOpenArtist: widget.onOpenArtist,
                          artSize: artSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: paneGap),
              Expanded(
                flex: contentFlex,
                child: Padding(
                  key: const ValueKey('wide-now-playing-lyrics'),
                  padding: EdgeInsets.fromLTRB(
                    8,
                    6,
                    0,
                    foldableWidth ? 24 : 32,
                  ),
                  child: _WideNowPlayingPane(
                    view: _view,
                    track: widget.track,
                    playback: widget.playback,
                    onViewChanged: (view) => setState(() => _view = view),
                    onOpenAlbum: widget.onOpenAlbum,
                    onOpenArtist: widget.onOpenArtist,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WideNowPlayingPane extends StatelessWidget {
  const _WideNowPlayingPane({
    required this.view,
    required this.track,
    required this.playback,
    required this.onViewChanged,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final _WideNowPlayingView view;
  final Track track;
  final SoundPlaybackController playback;
  final ValueChanged<_WideNowPlayingView> onViewChanged;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('wide-now-playing-pane'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: IndexedStack(
            index: view.index,
            children: [
              _LyricsPanel(
                key: const ValueKey('wide-lyrics-panel'),
                track: track,
                position: playback.displayPosition,
                discontinuityRevision: playback.positionDiscontinuityRevision,
                onSeek: playback.seek,
                verticalControls: true,
              ),
              PlaybackQueuePanel(
                key: const ValueKey('wide-playback-queue'),
                playback: playback,
                embedded: true,
                onOpenAlbum: onOpenAlbum,
                onOpenArtist: onOpenArtist,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WidePaneIconSwitch(
          key: const ValueKey('now-playing-view-switch'),
          view: view,
          onChanged: onViewChanged,
        ),
      ],
    );
  }
}

class _WidePaneIconSwitch extends StatelessWidget {
  const _WidePaneIconSwitch({
    required this.view,
    required this.onChanged,
    super.key,
  });

  final _WideNowPlayingView view;
  final ValueChanged<_WideNowPlayingView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button({
      required Key key,
      required _WideNowPlayingView value,
      required String tooltip,
      required IconData icon,
      double iconSize = 19,
      double opticalOffsetY = 0,
    }) {
      final selected = view == value;
      Widget normalizedIcon() => SizedBox.square(
        dimension: 22,
        child: Center(
          child: Transform.translate(
            offset: Offset(0, opticalOffsetY),
            child: Icon(icon, size: iconSize),
          ),
        ),
      );

      return IconButton(
        key: key,
        onPressed: () => onChanged(value),
        tooltip: tooltip,
        isSelected: selected,
        icon: normalizedIcon(),
        selectedIcon: normalizedIcon(),
        color: selected ? SoundColors.accent : context.soundMutedText,
        visualDensity: VisualDensity.compact,
        style: ButtonStyle(
          fixedSize: const WidgetStatePropertyAll(Size.square(40)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return context.soundTint(0.08);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return context.soundTint(0.05);
            }
            return Colors.transparent;
          }),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          key: const ValueKey('show-wide-lyrics'),
          value: _WideNowPlayingView.lyrics,
          tooltip: '显示歌词',
          icon: Icons.lyrics_rounded,
          iconSize: 17.5,
          opticalOffsetY: 1.5,
        ),
        button(
          key: const ValueKey('show-wide-queue'),
          value: _WideNowPlayingView.queue,
          tooltip: '显示播放清单',
          icon: Icons.queue_music_rounded,
          opticalOffsetY: -1,
        ),
      ],
    );
  }
}

/// Phone / narrow compact vinyl size: large enough to read, small enough that
/// title + transport still fit without crushing the pivot air above the rim.
double _compactVinylArtSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final shortest = size.shortestSide;
  final byWidth = (size.width - 56).clamp(220.0, 360.0);
  // Leave ~48% of height for title, scrubber, transport, and bottom chrome.
  final byHeight = (size.height * 0.42).clamp(220.0, 360.0);
  final side = math.min(byWidth, byHeight);
  // Extra-narrow phones stay slightly smaller so the arm base still has air.
  if (shortest < 360) return math.min(side, 280.0);
  if (shortest < 400) return math.min(side, 320.0);
  return side;
}

double _centerDisplayFeatureGap(
  BuildContext context,
  BoxConstraints constraints,
) {
  var gap = 0.0;
  for (final feature in MediaQuery.of(context).displayFeatures) {
    final bounds = feature.bounds;
    final nearCenter =
        bounds.center.dx > constraints.maxWidth * 0.35 &&
        bounds.center.dx < constraints.maxWidth * 0.65;
    final vertical = bounds.height > constraints.maxHeight * 0.5;
    if (nearCenter && vertical) gap = math.max(gap, bounds.width + 16);
  }
  return gap;
}

class _CompactNowPlaying extends StatefulWidget {
  const _CompactNowPlaying({
    required this.album,
    required this.track,
    required this.playback,
    required this.style,
    this.openLyricsByDefault = false,
    this.userState,
    this.isActive = true,
    this.onOpenAlbum,
    this.onOpenArtist,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final NowPlayingStyle style;
  final bool openLyricsByDefault;
  final LibraryUserStateController? userState;
  final bool isActive;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;
  final GestureDragStartCallback? onVerticalDragStart;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final GestureDragCancelCallback? onVerticalDragCancel;

  @override
  State<_CompactNowPlaying> createState() => _CompactNowPlayingState();
}

class _CompactNowPlayingState extends State<_CompactNowPlaying> {
  late bool _showLyrics;
  final ScrollController _coverScrollController = ScrollController();
  int? _coverPointer;
  double? _coverLastGlobalDy;
  bool _coverDismissGestureActive = false;
  bool _scrubInteractionActive = false;

  @override
  void initState() {
    super.initState();
    _showLyrics = widget.openLyricsByDefault;
  }

  @override
  void didUpdateWidget(covariant _CompactNowPlaying oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openLyricsByDefault == widget.openLyricsByDefault) return;
    // Only adopt the new default when the user has not toggled away yet —
    // if they already opened/closed lyrics this session, leave their choice.
    if (_showLyrics == oldWidget.openLyricsByDefault) {
      _showLyrics = widget.openLyricsByDefault;
    }
  }

  void _handleCoverPointerDown(PointerDownEvent event) {
    // The scrubber dispatches its notification from a descendant Listener
    // during this same pointer-down, so by the time this callback runs the
    // flag already reflects whether the touch started on the scrubber. A
    // scrub with a vertical component must not arm the dismiss gesture.
    if (_scrubInteractionActive) {
      _coverPointer = null;
      _coverLastGlobalDy = null;
      return;
    }
    _coverPointer = event.pointer;
    _coverLastGlobalDy = event.position.dy;
    _coverDismissGestureActive = false;
  }

  void _handleCoverPointerMove(PointerMoveEvent event) {
    if (_coverPointer != event.pointer || _coverLastGlobalDy == null) return;
    final delta = event.position.dy - _coverLastGlobalDy!;
    _coverLastGlobalDy = event.position.dy;
    if (!_coverDismissGestureActive) {
      final scrollOffset = _coverScrollController.hasClients
          ? _coverScrollController.offset
          : 0.0;
      if (delta <= 0 || scrollOffset > 0.5) return;
      _coverDismissGestureActive = true;
      widget.onVerticalDragStart?.call(
        DragStartDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
          sourceTimeStamp: event.timeStamp,
        ),
      );
    }
    widget.onVerticalDragUpdate?.call(
      DragUpdateDetails(
        globalPosition: event.position,
        localPosition: event.localPosition,
        delta: Offset(0, delta),
        primaryDelta: delta,
        sourceTimeStamp: event.timeStamp,
      ),
    );
  }

  void _finishCoverPointer() {
    if (_coverDismissGestureActive) {
      _coverDismissGestureActive = false;
      widget.onVerticalDragEnd?.call(DragEndDetails());
    }
    _coverPointer = null;
    _coverLastGlobalDy = null;
  }

  void _cancelCoverPointer(PointerCancelEvent event) {
    if (_coverDismissGestureActive) {
      _coverDismissGestureActive = false;
      widget.onVerticalDragCancel?.call();
    }
    _coverPointer = null;
    _coverLastGlobalDy = null;
  }

  bool _handleScrubInteractionNotification(
    ProgressScrubInteractionNotification notification,
  ) {
    _scrubInteractionActive = notification.active;
    return false;
  }

  @override
  void dispose() {
    _coverScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      child: _showLyrics
          ? _CompactLyricsPlayer(
              key: const ValueKey('compact-lyrics'),
              album: widget.album,
              track: widget.track,
              playback: widget.playback,
              userState: widget.userState,
              onToggleLyrics: () => setState(() => _showLyrics = false),
              onOpenAlbum: widget.onOpenAlbum,
              onOpenArtist: widget.onOpenArtist,
              onVerticalDragStart: widget.onVerticalDragStart,
              onVerticalDragUpdate: widget.onVerticalDragUpdate,
              onVerticalDragEnd: widget.onVerticalDragEnd,
              onVerticalDragCancel: widget.onVerticalDragCancel,
            )
          : NotificationListener<ProgressScrubInteractionNotification>(
              onNotification: _handleScrubInteractionNotification,
              child: Listener(
                key: const ValueKey('now-playing-cover-drag-region'),
                behavior: HitTestBehavior.translucent,
                onPointerDown: _handleCoverPointerDown,
                onPointerMove: _handleCoverPointerMove,
                onPointerUp: (_) => _finishCoverPointer(),
                onPointerCancel: _cancelCoverPointer,
                child: SingleChildScrollView(
                  key: const ValueKey('compact-player'),
                  controller: _coverScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    28,
                    8,
                    28,
                    widget.style == NowPlayingStyle.vinyl ? 32 : 40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: widget.style == NowPlayingStyle.vinyl
                            ? 400
                            : 430,
                      ),
                      child: _PlayerColumn(
                        album: widget.album,
                        track: widget.track,
                        playback: widget.playback,
                        style: widget.style,
                        onOpenAlbum: widget.onOpenAlbum,
                        onOpenArtist: widget.onOpenArtist,
                        userState: widget.userState,
                        isActive: widget.isActive,
                        compactLayout: true,
                        artSize: widget.style == NowPlayingStyle.vinyl
                            ? _compactVinylArtSize(context)
                            : null,
                        onToggleLyrics: () =>
                            setState(() => _showLyrics = true),
                      ),
                    ),
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
    required this.style,
    this.userState,
    this.isActive = true,
    this.artSize,
    this.compactLayout = false,
    this.onToggleLyrics,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final NowPlayingStyle style;
  final LibraryUserStateController? userState;
  final bool isActive;
  final double? artSize;
  final bool compactLayout;
  final VoidCallback? onToggleLyrics;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final artwork = style == NowPlayingStyle.vinyl
        ? VinylRecordArt(
            key: compactLayout
                ? const ValueKey('compact-now-playing-artwork')
                : null,
            album: album,
            size: artSize,
            isPlaying: playback.snapshot.isPlaying,
            isActive: isActive,
          )
        : _PlaybackResponsiveAlbumArt(
            key: compactLayout
                ? const ValueKey('compact-now-playing-artwork')
                : null,
            album: album,
            size: artSize,
            isPlaying: playback.snapshot.isPlaying,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        artwork,
        // Vinyl keeps a larger gap: the platter sits low in its square, so
        // the same 24px feels tighter than a full-bleed cover art.
        SizedBox(
          height: style == NowPlayingStyle.vinyl
              ? (compactLayout ? 40.0 : 36.0)
              : (compactLayout ? 26.0 : 24.0),
        ),
        if (compactLayout)
          _TrackChangeTransition(
            trackId: track.id,
            child: SizedBox(
              key: const ValueKey('now-playing-track-title'),
              width: double.infinity,
              child: Text(
                track.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _TrackChangeTransition(
                  trackId: track.id,
                  child: Text(
                    key: const ValueKey('now-playing-track-title'),
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              _NowPlayingActions(
                track: track,
                userState: userState,
                lyricsSelected: false,
                onToggleLyrics: onToggleLyrics,
              ),
            ],
          ),
        SizedBox(height: compactLayout ? 8 : 5),
        _TrackChangeTransition(
          trackId: track.id,
          child: SoundMetadataLine(
            artist: track.artist,
            album: track.albumTitle,
            separator: ' — ',
            onOpenArtist: onOpenArtist == null
                ? null
                : () => onOpenArtist!(track.artist),
            onOpenAlbum: onOpenAlbum == null
                ? null
                : () => onOpenAlbum!(album),
            style: TextStyle(color: context.soundSecondaryText, fontSize: 13),
          ),
        ),
        SizedBox(height: compactLayout ? 26 : 20),
        _PlaybackTimelineAndControls(
          key: compactLayout
              ? const ValueKey('compact-cover-playback-controls')
              : null,
          playback: playback,
        ),
        if (compactLayout) ...[
          const SizedBox(height: 24),
          _NowPlayingActions(
            key: const ValueKey('compact-now-playing-secondary-actions'),
            track: track,
            userState: userState,
            lyricsSelected: false,
            onToggleLyrics: onToggleLyrics,
            distributed: true,
          ),
        ],
      ],
    );
  }
}

/// Keeps the artwork visually in sync with the play/pause interaction.
///
/// Uses an explicit [AnimationController] driven by Material Design's
/// [Curves.fastOutSlowIn] for a silky-smooth start/stop feel that avoids
/// the mechanical stiffness of polynomial easing curves. Rapid play/pause
/// taps reverse direction smoothly instead of snapping to either endpoint.
class _PlaybackResponsiveAlbumArt extends StatefulWidget {
  const _PlaybackResponsiveAlbumArt({
    required this.album,
    required this.isPlaying,
    this.size,
    super.key,
  });

  final Album album;
  final bool isPlaying;
  final double? size;

  @override
  State<_PlaybackResponsiveAlbumArt> createState() =>
      _PlaybackResponsiveAlbumArtState();
}

class _PlaybackResponsiveAlbumArtState
    extends State<_PlaybackResponsiveAlbumArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  /// How much the artwork shrinks when paused.
  ///
  /// 1.0 = full size, 0.0 = fully collapsed. 0.88 gives a noticeable but
  /// tasteful contraction that subtly signals the paused state.
  static const _pausedScale = 0.88;

  /// Matches the play/pause button's interaction timing so the artwork
  /// arrives at its final scale simultaneously with the button feedback.
  static const _transitionDuration = Duration(milliseconds: 260);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _controller.value = widget.isPlaying ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_PlaybackResponsiveAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying == oldWidget.isPlaying) return;
    if (widget.isPlaying) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Transform.scale(
        scale: _pausedScale + (1.0 - _pausedScale) * _animation.value,
        alignment: Alignment.center,
        child: child,
      ),
      child: AlbumArt(
        album: widget.album,
        size: widget.size,
        gaplessPlayback: true,
      ),
    );
  }
}

class _TrackChangeTransition extends StatelessWidget {
  const _TrackChangeTransition({required this.trackId, required this.child});

  final String trackId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(trackId), child: child),
    );
  }
}

class _CompactLyricsPlayer extends StatelessWidget {
  const _CompactLyricsPlayer({
    required this.album,
    required this.track,
    required this.playback,
    required this.userState,
    required this.onToggleLyrics,
    this.onOpenAlbum,
    this.onOpenArtist,
    required this.onVerticalDragStart,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
    super.key,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final VoidCallback onToggleLyrics;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;
  final GestureDragStartCallback? onVerticalDragStart;
  final GestureDragUpdateCallback? onVerticalDragUpdate;
  final GestureDragEndCallback? onVerticalDragEnd;
  final GestureDragCancelCallback? onVerticalDragCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      child: Column(
        children: [
          GestureDetector(
            key: const ValueKey('now-playing-expanded-drag-region'),
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: onVerticalDragStart,
            onVerticalDragUpdate: onVerticalDragUpdate,
            onVerticalDragEnd: onVerticalDragEnd,
            onVerticalDragCancel: onVerticalDragCancel,
            child: Row(
              children: [
                AlbumArt(
                  key: const ValueKey('compact-lyrics-artwork'),
                  album: album,
                  size: 56,
                  borderRadius: 8,
                  showShadow: false,
                  gaplessPlayback: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TrackChangeTransition(
                        trackId: track.id,
                        child: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      _TrackChangeTransition(
                        trackId: track.id,
                        child: SoundMetadataLine(
                          artist: track.artist,
                          album: track.albumTitle,
                          separator: ' — ',
                          onOpenArtist: onOpenArtist == null
                              ? null
                              : () => onOpenArtist!(track.artist),
                          onOpenAlbum: onOpenAlbum == null
                              ? null
                              : () => onOpenAlbum!(album),
                          style: TextStyle(
                            color: context.soundSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              key: const ValueKey('compact-lyrics-region'),
              constraints: const BoxConstraints(maxHeight: 392),
              child: _LyricsPanel(
                track: track,
                position: playback.displayPosition,
                discontinuityRevision: playback.positionDiscontinuityRevision,
                onSeek: playback.seek,
                compact: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PlaybackTimelineAndControls(
            key: const ValueKey('compact-lyrics-playback-controls'),
            playback: playback,
          ),
          const SizedBox(height: 24),
          _NowPlayingActions(
            key: const ValueKey('compact-lyrics-secondary-actions'),
            track: track,
            userState: userState,
            lyricsSelected: true,
            onToggleLyrics: onToggleLyrics,
            distributed: true,
          ),
        ],
      ),
    );
  }
}

class _PlaybackTimelineAndControls extends StatelessWidget {
  const _PlaybackTimelineAndControls({required this.playback, super.key});

  final SoundPlaybackController playback;

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
      mainAxisSize: MainAxisSize.min,
      children: [
        ProgressScrubber(
          position: position,
          duration: duration,
          onSeek: playback.seek,
        ),
        Row(
          children: [
            Text(formatDuration(position), style: _timeStyle(context)),
            const Spacer(),
            Text(remainingLabel, style: _timeStyle(context)),
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
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: context.soundSecondaryText,
                      ),
                    )
                  : Icon(visual.primaryIcon),
              iconSize: 34,
              style: IconButton.styleFrom(
                backgroundColor: context.soundPrimaryText,
                foregroundColor: context.soundGlass.canvasHighlight,
                fixedSize: const Size.square(52),
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

class _NowPlayingActions extends StatelessWidget {
  const _NowPlayingActions({
    required this.track,
    required this.userState,
    required this.lyricsSelected,
    required this.onToggleLyrics,
    this.distributed = false,
    super.key,
  });

  final Track track;
  final LibraryUserStateController? userState;
  final bool lyricsSelected;
  final VoidCallback? onToggleLyrics;
  final bool distributed;

  @override
  Widget build(BuildContext context) {
    final state = userState;
    final isFavorite = state?.isFavorite(track.id) ?? false;
    return Row(
      mainAxisSize: distributed ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: distributed
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      textDirection: distributed ? TextDirection.rtl : TextDirection.ltr,
      children: [
        if (state != null)
          IconButton(
            key: ValueKey('favorite-now-playing-${track.id}'),
            onPressed: () => unawaited(state.toggleFavorite(track)),
            tooltip: isFavorite ? '取消收藏' : '收藏歌曲',
            color: isFavorite ? SoundColors.accent : null,
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
        if (state != null)
          IconButton(
            key: ValueKey('add-now-playing-${track.id}-to-playlist'),
            onPressed: () =>
                showAddToPlaylistSheet(context, userState: state, track: track),
            tooltip: '添加到播放列表',
            icon: const Icon(Icons.playlist_add_rounded),
          ),
        if (onToggleLyrics != null)
          IconButton(
            key: ValueKey(
              lyricsSelected
                  ? 'return-now-playing-cover'
                  : 'show-now-playing-lyrics',
            ),
            onPressed: onToggleLyrics,
            tooltip: lyricsSelected ? '返回封面' : '查看歌词',
            color: lyricsSelected ? SoundColors.accent : null,
            icon: const Icon(Icons.lyrics_rounded),
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
    final failure = AppFailure.fromMessage(message);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: SoundGlassSurface(
          key: const ValueKey('playback-error-banner'),
          color: context.soundChromeSurface,
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          borderRadius: BorderRadius.circular(14),
          borderColor: Colors.transparent,
          blur: false,
          showShadow: false,
          child: Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 19,
                  color: context.soundColors.error.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      failure.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.soundPrimaryText,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      failure.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.soundMutedText,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: context.soundColors.error,
                  backgroundColor: Colors.transparent,
                  minimumSize: const Size(48, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _timeStyle(BuildContext context) => TextStyle(
  color: context.soundSecondaryText,
  fontSize: 11,
  fontFeatures: const [FontFeature.tabularFigures()],
);

class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({
    required this.track,
    required this.position,
    required this.discontinuityRevision,
    required this.onSeek,
    this.compact = false,
    this.verticalControls = false,
    super.key,
  });

  final Track track;
  final Duration position;
  final int discontinuityRevision;
  final Future<void> Function(Duration position) onSeek;
  final bool compact;
  final bool verticalControls;

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
        alignment: 0.40,
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

  void _handleLyricsMenuAction(_LyricsMenuAction action) {
    switch (action) {
      case _LyricsMenuAction.resumeFollow:
        _resumeAutoFollow();
        return;
      case _LyricsMenuAction.delay:
        _changeOffset(-_offsetStep);
        return;
      case _LyricsMenuAction.reset:
        setState(() {
          _offset = Duration.zero;
          _lastActiveIndex = null;
          _snapNextFollow = true;
        });
        return;
      case _LyricsMenuAction.advance:
        _changeOffset(_offsetStep);
        return;
    }
  }

  Widget _buildCompactLyricsMenu() {
    return SoundMenuButton<_LyricsMenuAction>(
      key: const ValueKey('compact-lyrics-more'),
      tooltip: '歌词设置',
      menuTitle: '歌词设置',
      actions: [
        if (_autoFollowPaused)
          const SoundMenuAction(
            value: _LyricsMenuAction.resumeFollow,
            label: '回到当前歌词',
            subtitle: '恢复自动跟随',
            icon: Icons.my_location_rounded,
          ),
        SoundMenuAction(
          value: _LyricsMenuAction.delay,
          label: '歌词延后 0.5 秒',
          subtitle: '当前偏移 $_offsetLabel',
          icon: Icons.remove_rounded,
        ),
        SoundMenuAction(
          value: _LyricsMenuAction.reset,
          label: '重置歌词偏移',
          subtitle: '恢复到 +0.0s',
          icon: Icons.refresh_rounded,
          enabled: _offset != Duration.zero,
        ),
        SoundMenuAction(
          value: _LyricsMenuAction.advance,
          label: '歌词提前 0.5 秒',
          subtitle: '当前偏移 $_offsetLabel',
          icon: Icons.add_rounded,
        ),
      ],
      onSelected: _handleLyricsMenuAction,
      child: SizedBox.square(
        dimension: 32,
        child: Center(
          child: Icon(
            Icons.more_horiz_rounded,
            size: 20,
            color: context.soundMutedText.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalControls() {
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '同步\n歌词',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.soundMutedText.withValues(alpha: 0.72),
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (_autoFollowPaused) ...[
            _LyricsOffsetButton(
              label: '跟随',
              tooltip: '恢复自动跟随',
              onTap: _resumeAutoFollow,
            ),
            const SizedBox(height: 6),
          ],
          _LyricsOffsetButton(
            label: '−.5',
            tooltip: '歌词延后 0.5 秒',
            onTap: () => _changeOffset(-_offsetStep),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
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
                  color: context.soundMutedText.withValues(
                    alpha: _offset == Duration.zero ? 0.56 : 0.86,
                  ),
                  fontSize: 10,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _LyricsOffsetButton(
            label: '+.5',
            tooltip: '歌词提前 0.5 秒',
            onTap: () => _changeOffset(_offsetStep),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsScroller(
    List<LyricLine> lyrics, {
    required int? active,
    required bool synchronized,
  }) {
    return LayoutBuilder(
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
              top: widget.verticalControls
                  ? math.max(88, constraints.maxHeight * 0.36)
                  : 0,
              bottom: widget.compact
                  ? math.max(72, constraints.maxHeight * 0.66)
                  : math.max(
                      110,
                      constraints.maxHeight *
                          (widget.verticalControls ? 0.62 : 0.55),
                    ),
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
    );
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
          color: context.soundPrimaryText.withValues(
            alpha: isActive
                ? 1
                : active != null && index < active
                ? 0.28
                : 0.5,
          ),
          fontSize: isActive ? 22 : 20,
          height: synchronized ? 2.25 : 1.7,
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
              color: context.soundSecondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '这首歌曲没有内嵌歌词',
                style: TextStyle(color: context.soundSecondaryText),
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
    if (widget.verticalControls) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(
              right: synchronized && _timeline.hasTimedContent ? 68 : 0,
            ),
            child: _buildLyricsScroller(
              lyrics,
              active: active,
              synchronized: synchronized,
            ),
          ),
          if (synchronized && _timeline.hasTimedContent)
            Positioned(top: 2, right: 0, child: _buildVerticalControls()),
        ],
      );
    }
    if (widget.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (synchronized && _timeline.hasTimedContent)
            Align(
              alignment: Alignment.centerRight,
              child: _buildCompactLyricsMenu(),
            ),
          Expanded(
            child: _buildLyricsScroller(
              lyrics,
              active: active,
              synchronized: synchronized,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              synchronized && _timeline.hasTimedContent ? '同步歌词' : '歌词',
              style: TextStyle(
                color: context.soundSecondaryText,
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
                          ? context.soundSecondaryText.withValues(alpha: 0.68)
                          : context.soundSecondaryText,
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
        SizedBox(height: widget.compact ? 12 : 26),
        Expanded(
          child: _buildLyricsScroller(
            lyrics,
            active: active,
            synchronized: synchronized,
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
        color: context.soundTint(0.06),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                color: context.soundSecondaryText,
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

/// Transparent hit target that moves the desktop window, matching the shell
/// title bar. Double-tap toggles maximize like a standard caption.
class _WindowDragSurface extends StatelessWidget {
  const _WindowDragSurface({super.key, this.height});

  /// When null, fills the parent (must provide bounded constraints).
  /// When set, used as a fixed-height strip inside unbounded flex layouts.
  final double? height;

  Future<void> _toggleMaximize() async {
    if (await isWindowMaximized()) {
      await restoreWindow();
    } else {
      await maximizeWindow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(startWindowDrag()),
      onDoubleTap: () => unawaited(_toggleMaximize()),
      child: height == null
          ? const SizedBox.expand()
          : SizedBox(height: height, width: double.infinity),
    );
  }
}

class _DesktopWindowControls extends StatefulWidget {
  const _DesktopWindowControls();

  @override
  State<_DesktopWindowControls> createState() => _DesktopWindowControlsState();
}

class _DesktopWindowControlsState extends State<_DesktopWindowControls> {
  bool _maximized = false;
  StreamSubscription<bool>? _maximizedSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _maximizedSubscription = windowMaximizedChanges.listen((maximized) {
      if (mounted) setState(() => _maximized = maximized);
    });
  }

  @override
  void dispose() {
    unawaited(_maximizedSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _refresh() async {
    final maximized = await isWindowMaximized();
    if (mounted) setState(() => _maximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    final next = !_maximized;
    if (mounted) setState(() => _maximized = next);
    if (next) {
      await maximizeWindow();
    } else {
      await restoreWindow();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowDot(
          icon: Icons.horizontal_rule_rounded,
          tooltip: '最小化',
          onTap: () => unawaited(minimizeWindow()),
        ),
        const SizedBox(width: 8),
        _WindowDot(
          icon: _maximized
              ? Icons.filter_none_rounded
              : Icons.crop_square_rounded,
          tooltip: _maximized ? '向下还原' : '最大化',
          onTap: () => unawaited(_toggleMaximize()),
        ),
        const SizedBox(width: 8),
        _WindowDot(
          icon: Icons.close_rounded,
          tooltip: '关闭',
          onTap: () => unawaited(closeWindow()),
        ),
      ],
    );
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: context.soundTint(0.12),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              icon,
              size: 11,
              color: context.soundSecondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
