import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../core/app_failure.dart';
import '../../core/now_playing_style.dart';
import '../../core/platform_window.dart';
import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_mode.dart';
import '../../playback/lyrics_timeline.dart';
import '../../playback/sleep_timer_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/animated_artwork_background.dart';
import '../widgets/playback_visual_state.dart';
import '../widgets/playback_queue_sheet.dart';
import '../widgets/progress_scrubber.dart';
import '../widgets/sound_components.dart';
import '../widgets/balanced_lyric_text.dart';
import '../widgets/karaoke_lyric_text.dart';
import '../widgets/now_playing_motion_director.dart';
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
    this.sleepTimer,
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
  final SleepTimerController? sleepTimer;
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
            ? Listenable.merge([playback, ?userState, ?sleepTimer])
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
    final usesMobileShell = context.soundUsesMobileShell;
    final foldableChrome = usesMobileShell && !compactChrome;
    final mediaSize = MediaQuery.sizeOf(context);
    final artworkBrightness = Theme.of(context).brightness;
    // Keep touch navigation on iPad, but still use the space-efficient
    // two-pane player when a full-height tablet is in landscape.
    final usesWidePlayer = soundUsesWideContentForSize(mediaSize);
    final wideIntegratedQueue = usesWidePlayer && mediaSize.width >= 680;
    return NowPlayingMotionHost(
      isActive: isActive,
      isPlaying: snapshot.isPlaying,
      child: _NowPlayingArtworkChrome(
        album: album,
        isActive: isActive,
        brightness: artworkBrightness,
        child: Builder(
          builder: (context) {
            final chrome = context.artworkChrome;
            final topButtonStyle = IconButton.styleFrom(
              foregroundColor: context.chromePrimaryText,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (chrome?.useLightText ?? context.chromeUseLightText)
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
              child: Scaffold(
                backgroundColor: artworkNowPlayingFallbackGradientColors(
                  album,
                  artworkBrightness,
                ).last,
                body: Stack(
                  fit: StackFit.expand,
                  children: [
                    Builder(
                      builder: (context) {
                        final director = NowPlayingMotionScope.maybeOf(context);
                        if (director == null) {
                          return AnimatedArtworkBackground(
                            album: album,
                            position: playback.displayPosition,
                            isPlaying: snapshot.isPlaying,
                            isActive: isActive,
                            paletteBrightness: artworkBrightness,
                            staticVerticalGradient: true,
                          );
                        }
                        return AnimatedBuilder(
                          animation: director,
                          builder: (context, _) => AnimatedArtworkBackground(
                            album: album,
                            position: playback.displayPosition,
                            isPlaying: director.playing,
                            // Director stages ambient after surface is active.
                            isActive: director.allowAmbientMotion,
                            paletteBrightness: artworkBrightness,
                            staticVerticalGradient: true,
                          ),
                        );
                      },
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
                                  IconButton(
                                    onPressed: () => _close(context),
                                    style: topButtonStyle,
                                    icon: const Icon(KaitingIcons.arrowDown),
                                  ),
                                  // Empty mid-chrome: drag the window on
                                  // Windows/Linux where this route covers the
                                  // shell title bar.
                                  Expanded(
                                    child: _nowPlayingUsesWindowChrome
                                        ? const _WindowDragSurface(
                                            key: ValueKey(
                                              'now-playing-chrome-window-drag',
                                            ),
                                            height: 40,
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                  if (!wideIntegratedQueue)
                                    IconButton(
                                      onPressed: () => showPlaybackQueueSheet(
                                        context,
                                        playback,
                                        onOpenAlbum: onOpenAlbum,
                                        onOpenArtist: onOpenArtist,
                                      ),
                                      tooltip: '播放队列',
                                      style: topButtonStyle,
                                      icon: const Icon(KaitingIcons.queue),
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
                                // Navigation and content adapt independently:
                                // iPad keeps touch navigation while landscape
                                // can still use the two-pane player.
                                if (!usesWidePlayer) {
                                  return _CompactNowPlaying(
                                    album: album,
                                    track: track,
                                    playback: playback,
                                    sleepTimer: sleepTimer,
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
                                  sleepTimer: sleepTimer,
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
                    // Shell title bar is covered by this full-screen route.
                    // Mirror its drag band on Windows / Linux.
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
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Loads cover colors and provides [ArtworkChromeTheme] for NP icons/text.
class _NowPlayingArtworkChrome extends StatefulWidget {
  const _NowPlayingArtworkChrome({
    required this.album,
    required this.isActive,
    required this.brightness,
    required this.child,
  });

  final Album album;
  final bool isActive;
  final Brightness brightness;
  final Widget child;

  @override
  State<_NowPlayingArtworkChrome> createState() =>
      _NowPlayingArtworkChromeState();
}

class _NowPlayingArtworkChromeState extends State<_NowPlayingArtworkChrome>
    with SingleTickerProviderStateMixin {
  late List<Color> _fromColors;
  late List<Color> _targetColors;
  late final AnimationController _paletteController;
  String? _requestKey;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _targetColors = _initialColors(widget.album, widget.brightness);
    _fromColors = List<Color>.of(_targetColors);
    _paletteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _paletteController.duration =
        context.soundSkinEffects.paletteTransitionDuration;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _refresh(widget.brightness);
  }

  @override
  void didUpdateWidget(covariant _NowPlayingArtworkChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.id != widget.album.id ||
        oldWidget.album.artworkUri != widget.album.artworkUri ||
        oldWidget.brightness != widget.brightness ||
        (!oldWidget.isActive && widget.isActive)) {
      _refresh(
        widget.brightness,
        force: !oldWidget.isActive && widget.isActive,
      );
    }
  }

  void _refresh(Brightness brightness, {bool force = false}) {
    final album = widget.album;
    final requestKey = '${album.id}|${album.artworkUri}|${brightness.name}';
    if (_requestKey == requestKey && !force) return;
    _requestKey = requestKey;
    final artworkUri = album.artworkUri?.trim();
    if (artworkUri == null || artworkUri.isEmpty) {
      _transitionTo(artworkNowPlayingFallbackGradientColors(album, brightness));
      return;
    }

    final hasPrewarm = AnimatedArtworkBackground.hasPrewarmedPalette(
      album: album,
      brightness: brightness,
    );
    if (hasPrewarm) {
      unawaited(_loadScheme(requestKey, brightness, album));
      return;
    }
    if (!widget.isActive) {
      return;
    }
    // Let the completed expansion frame reach the screen before image decode
    // and palette generation begin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive || _requestKey != requestKey) return;
      unawaited(_loadScheme(requestKey, brightness, album));
    });
  }

  Future<void> _loadScheme(
    String requestKey,
    Brightness brightness,
    Album album,
  ) async {
    try {
      final scheme = await AnimatedArtworkBackground.colorSchemeForAlbum(
        album: album,
        brightness: brightness,
      );
      if (!mounted || _requestKey != requestKey) return;
      final next = scheme == null
          ? artworkNowPlayingFallbackGradientColors(album, brightness)
          : artworkNowPlayingGradientColorsFromScheme(scheme, brightness);
      _transitionTo(next);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Now-playing chrome palette failed: $error');
      }
    }
  }

  void _transitionTo(List<Color> colors) {
    if (listEquals(_targetColors, colors)) return;
    final currentColors = _interpolatedColors;
    setState(() {
      _fromColors = currentColors;
      _targetColors = List<Color>.of(colors);
    });
    if (_reduceMotion) {
      _paletteController.value = 1;
    } else {
      _paletteController.forward(from: 0);
    }
  }

  List<Color> _initialColors(Album album, Brightness brightness) {
    final scheme = AnimatedArtworkBackground.cachedColorSchemeForAlbum(
      album: album,
      brightness: brightness,
    );
    return scheme == null
        ? artworkNowPlayingFallbackGradientColors(album, brightness)
        : artworkNowPlayingGradientColorsFromScheme(scheme, brightness);
  }

  List<Color> get _interpolatedColors {
    final progress = Curves.easeOutCubic.transform(_paletteController.value);
    return List<Color>.generate(
      _targetColors.length,
      (index) => Color.lerp(
        _fromColors[index.clamp(0, _fromColors.length - 1)],
        _targetColors[index],
        progress,
      )!,
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _paletteController,
      child: widget.child,
      builder: (context, child) {
        final palette = ArtworkPagePalette.fromBackground(_interpolatedColors);
        return ArtworkChromeTheme(palette: palette, child: child!);
      },
    );
  }

  @override
  void dispose() {
    _paletteController.dispose();
    super.dispose();
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
                  child: IconButton(
                    onPressed:
                        onClose ?? () => Navigator.of(context).maybePop(),
                    icon: const Icon(KaitingIcons.arrowDown),
                  ),
                ),
                Center(
                  child: Text(
                    '当前没有正在播放的歌曲',
                    style: TextStyle(color: context.chromeSecondaryText),
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
    this.sleepTimer,
    this.userState,
    this.isActive = true,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final SleepTimerController? sleepTimer;
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
        const maxStageWidth = 1600.0;
        const maxStageHeight = 1080.0;
        final stageWidth = math.min(maxStageWidth, constraints.maxWidth);
        final stageHeight = math.min(maxStageHeight, constraints.maxHeight);
        // Vinyl needs more chrome clearance (title gap + controls) than a flat cover.
        final playerChromeHeight = widget.style == NowPlayingStyle.vinyl
            ? 250.0
            : 230.0;
        final foldableWidth = constraints.maxWidth < 780;
        // Tighter chrome on foldables so the lyrics column keeps more usable
        // width (fewer single-character wraps).
        final horizontalPadding = foldableWidth ? 24.0 : 44.0;
        final paneGap = math.max(
          foldableWidth ? 16.0 : 48.0,
          _centerDisplayFeatureGap(context, constraints),
        );
        // Classic and vinyl share a balanced dual pane; only artwork differs.
        const playerFlex = 1;
        const contentFlex = 1;
        final playerHorizontalInset = foldableWidth ? 12.0 : 0.0;
        final availableWidth = math.max(
          320.0,
          stageWidth - horizontalPadding * 2 - paneGap,
        );
        final paneWidth =
            availableWidth * playerFlex / (playerFlex + contentFlex);
        final playerContentWidth = math.max(
          0.0,
          paneWidth - playerHorizontalInset * 2,
        );
        final playerHeight = math.max(0.0, stageHeight - verticalPadding);
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
          math.min(artLimit, playerContentWidth),
          math.max(160.0, playerHeight - playerChromeHeight),
        );
        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            key: const ValueKey('wide-now-playing-stage'),
            width: stageWidth,
            height: stageHeight,
            child: Padding(
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
                      key: const ValueKey('wide-now-playing-player-padding'),
                      padding: EdgeInsets.fromLTRB(
                        playerHorizontalInset,
                        foldableWidth ? 18 : 0,
                        playerHorizontalInset,
                        0,
                      ),
                      child: Align(
                        key: const ValueKey('wide-now-playing-player'),
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: playerWidthLimit,
                          ),
                          child: SingleChildScrollView(
                            child: _PlayerColumn(
                              album: widget.album,
                              track: widget.track,
                              playback: widget.playback,
                              sleepTimer: widget.sleepTimer,
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
                        foldableWidth ? 16 : 8,
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
            ),
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
                positionListenable: playback.positionListenable,
                positionOf: () => playback.displayPosition,
                discontinuityRevision: playback.positionDiscontinuityRevision,
                onSeek: playback.seek,
                verticalControls: true,
              ),
              PlaybackQueuePanel(
                key: const ValueKey('wide-playback-queue'),
                playback: playback,
                embedded: true,
                useArtworkChrome: true,
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
    }) {
      final selected = view == value;
      Widget normalizedIcon() => SizedBox.square(
        dimension: 24,
        child: Center(child: Icon(icon, size: 21)),
      );

      return IconButton(
        key: key,
        onPressed: () => onChanged(value),
        tooltip: tooltip,
        isSelected: selected,
        icon: normalizedIcon(),
        selectedIcon: normalizedIcon(),
        color: selected ? SoundColors.accent : context.chromeMutedText,
        visualDensity: VisualDensity.compact,
        style: ButtonStyle(
          fixedSize: const WidgetStatePropertyAll(Size.square(40)),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return context.chromePrimaryText.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return context.chromePrimaryText.withValues(alpha: 0.08);
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
          icon: KaitingIcons.lyrics,
        ),
        button(
          key: const ValueKey('show-wide-queue'),
          value: _WideNowPlayingView.queue,
          tooltip: '显示播放清单',
          icon: KaitingIcons.queue,
        ),
      ],
    );
  }
}

double _compactVisualStageHeight(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final maxClamp = context.soundIsCompact ? 370.0 : 500.0;
  return (size.height * 0.45).clamp(320.0, maxClamp);
}

double _compactArtworkTopInset(NowPlayingStyle style) =>
    style == NowPlayingStyle.vinyl ? 16 : 28;

double _compactVisualArtSize(
  BuildContext context, {
  required NowPlayingStyle style,
}) {
  final size = MediaQuery.sizeOf(context);
  final horizontalInset = style == NowPlayingStyle.vinyl ? 24.0 : 56.0;
  final widthMax = context.soundIsCompact ? 420.0 : 520.0;
  return math.min(
    (size.width - horizontalInset).clamp(240.0, widthMax),
    _compactVisualStageHeight(context) - _compactArtworkTopInset(style),
  );
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
    this.sleepTimer,
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
  final SleepTimerController? sleepTimer;
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
  int? _scrubPointer;

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

  bool _isScrubPointer(int pointer) =>
      _scrubInteractionActive || _scrubPointer == pointer;

  void _abortCoverDismissForScrub() {
    final wasDismissing = _coverDismissGestureActive;
    _coverDismissGestureActive = false;
    _coverPointer = null;
    _coverLastGlobalDy = null;
    // Only notify cancel when dismiss actually armed — snaps the sheet without
    // a settle bounce (see AppShell._handleNowPlayingDragCancel).
    if (wasDismissing) {
      widget.onVerticalDragCancel?.call();
    }
  }

  void _handleCoverPointerDown(PointerDownEvent event) {
    // The scrubber dispatches its notification from a descendant Listener
    // during this same pointer-down, so by the time this callback runs the
    // flag already reflects whether the touch started on the scrubber. A
    // scrub with a vertical component must not arm the dismiss gesture.
    if (_isScrubPointer(event.pointer)) {
      _abortCoverDismissForScrub();
      return;
    }
    _coverPointer = event.pointer;
    _coverLastGlobalDy = event.position.dy;
    _coverDismissGestureActive = false;
  }

  void _handleCoverPointerMove(PointerMoveEvent event) {
    // Scrub may claim the pointer after down, or vertical noise during a
    // horizontal scrub must never slide the page shut.
    if (_isScrubPointer(event.pointer)) {
      _abortCoverDismissForScrub();
      return;
    }
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

  void _finishCoverPointer(PointerEvent event) {
    if (_isScrubPointer(event.pointer)) {
      _abortCoverDismissForScrub();
      return;
    }
    if (_coverPointer != null &&
        event is PointerUpEvent &&
        _coverPointer != event.pointer) {
      return;
    }
    if (_coverDismissGestureActive) {
      _coverDismissGestureActive = false;
      widget.onVerticalDragEnd?.call(DragEndDetails());
    }
    _coverPointer = null;
    _coverLastGlobalDy = null;
  }

  void _cancelCoverPointer(PointerCancelEvent event) {
    if (_isScrubPointer(event.pointer)) {
      _abortCoverDismissForScrub();
      return;
    }
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
    final wasActive = _scrubInteractionActive;
    _scrubInteractionActive = notification.active;
    _scrubPointer = notification.active ? notification.pointer : null;
    if (notification.active) {
      _abortCoverDismissForScrub();
    }
    // Rebuild so cover scroll physics can freeze while scrubbing.
    if (wasActive != notification.active && mounted) {
      setState(() {});
    }
    return false;
  }

  @override
  void dispose() {
    _coverScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ProgressScrubInteractionNotification>(
      onNotification: _handleScrubInteractionNotification,
      child: Listener(
        key: const ValueKey('now-playing-cover-drag-region'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handleCoverPointerDown,
        onPointerMove: _showLyrics ? null : _handleCoverPointerMove,
        onPointerUp: _finishCoverPointer,
        onPointerCancel: _cancelCoverPointer,
        child: SingleChildScrollView(
          key: const ValueKey('compact-player'),
          controller: _coverScrollController,
          // Freeze scroll while scrubbing so vertical finger noise cannot
          // bounce the page. Otherwise use clamping (no iOS rubber-band).
          physics: _scrubInteractionActive
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
                ),
          padding: EdgeInsets.fromLTRB(
            28,
            context.soundIsCompact ? 8 : 48,
            28,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.soundIsCompact ? 430 : 540,
              ),
              child: _PlayerColumn(
                album: widget.album,
                track: widget.track,
                playback: widget.playback,
                sleepTimer: widget.sleepTimer,
                style: widget.style,
                onOpenAlbum: widget.onOpenAlbum,
                onOpenArtist: widget.onOpenArtist,
                userState: widget.userState,
                isActive: widget.isActive,
                compactLayout: true,
                artSize: _compactVisualArtSize(context, style: widget.style),
                visualStageHeight: _compactVisualStageHeight(context),
                showLyrics: _showLyrics,
                onToggleLyrics: () =>
                    setState(() => _showLyrics = !_showLyrics),
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
    this.sleepTimer,
    this.userState,
    this.isActive = true,
    this.artSize,
    this.compactLayout = false,
    this.visualStageHeight,
    this.showLyrics = false,
    this.onToggleLyrics,
    this.onOpenAlbum,
    this.onOpenArtist,
  });

  final Album album;
  final Track track;
  final SoundPlaybackController playback;
  final SleepTimerController? sleepTimer;
  final NowPlayingStyle style;
  final LibraryUserStateController? userState;
  final bool isActive;
  final double? artSize;
  final bool compactLayout;
  final double? visualStageHeight;
  final bool showLyrics;
  final VoidCallback? onToggleLyrics;
  final ValueChanged<Album>? onOpenAlbum;
  final ValueChanged<String>? onOpenArtist;

  @override
  Widget build(BuildContext context) {
    final director = NowPlayingMotionScope.maybeOf(context);
    if (director == null) {
      final playing = playback.snapshot.isPlaying;
      return _playerColumnBody(
        context,
        _artwork(
          isPlaying: playing,
          isActive: isActive,
          discSpinning: playing && isActive,
        ),
      );
    }
    // Rebuild when the director stages disc spin after the cover scale window.
    return AnimatedBuilder(
      animation: director,
      builder: (context, _) => _playerColumnBody(
        context,
        _artwork(
          isPlaying: director.primaryPlayEffects,
          isActive: director.surfaceActive,
          discSpinning: director.discSpinning,
        ),
      ),
    );
  }

  Widget _artwork({
    required bool isPlaying,
    required bool isActive,
    required bool discSpinning,
  }) {
    if (style == NowPlayingStyle.vinyl) {
      return VinylRecordArt(
        key: compactLayout
            ? const ValueKey('compact-now-playing-artwork')
            : null,
        album: album,
        size: artSize,
        isPlaying: isPlaying,
        isActive: isActive,
        discSpinning: discSpinning,
      );
    }
    return _PlaybackResponsiveAlbumArt(
      key: compactLayout ? const ValueKey('compact-now-playing-artwork') : null,
      album: album,
      size: artSize,
      isPlaying: isPlaying,
    );
  }

  Widget _playerColumnBody(BuildContext context, Widget artwork) {
    final detailsPadding = EdgeInsets.zero;
    final compactStage = compactLayout && visualStageHeight != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compactStage)
          SizedBox(
            key: const ValueKey('compact-visual-stage'),
            height: visualStageHeight,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.center,
                children: [...previousChildren, ?currentChild],
              ),
              child: showLyrics
                  ? _CompactLyricsStage(
                      key: const ValueKey('compact-lyrics'),
                      track: track,
                      playback: playback,
                      onExit: onToggleLyrics!,
                    )
                  : Semantics(
                      button: true,
                      label: '查看歌词',
                      child: GestureDetector(
                        key: const ValueKey('compact-visual-to-lyrics'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggleLyrics,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              top: _compactArtworkTopInset(style),
                            ),
                            child: style == NowPlayingStyle.vinyl
                                ? OverflowBox(
                                    alignment: Alignment.topCenter,
                                    maxWidth: double.infinity,
                                    maxHeight: double.infinity,
                                    child: artwork,
                                  )
                                : artwork,
                          ),
                        ),
                      ),
                    ),
            ),
          )
        else
          Center(child: artwork),
        SizedBox(height: compactLayout ? 24 : 34),
        if (compactLayout) ...[
          Padding(
            padding: detailsPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TrackChangeTransition(
                        trackId: track.id,
                        child: _OverflowMarquee(
                          key: const ValueKey('now-playing-track-title'),
                          motionKey: const ValueKey(
                            'now-playing-track-title-marquee-motion',
                          ),
                          text: track.title,
                          style: TextStyle(
                            color: context.chromePrimaryText,
                            fontSize: 22,
                            height: 1.08,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _TrackChangeTransition(
                        trackId: track.id,
                        child: _OverflowMarquee(
                          key: const ValueKey('now-playing-track-artist'),
                          motionKey: const ValueKey(
                            'now-playing-track-artist-marquee-motion',
                          ),
                          text: track.artist.trim().isEmpty
                              ? '未知艺人'
                              : track.artist.trim(),
                          onTap: onOpenArtist == null
                              ? null
                              : () => onOpenArtist!(track.artist),
                          semanticsLabel: onOpenArtist == null
                              ? null
                              : '打开艺人 ${track.artist}',
                          style: TextStyle(
                            color: context.chromeSecondaryText,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _NowPlayingActions(
                  key: const ValueKey('compact-now-playing-title-actions'),
                  track: track,
                  userState: userState,
                  lyricsSelected: false,
                  onToggleLyrics: null,
                ),
              ],
            ),
          ),
        ] else ...[
          // Foldable / desktop:
          // [ title                     ] [♥]  [＋]
          // [ artist                    ]
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TrackChangeTransition(
                      trackId: track.id,
                      child: _OverflowMarquee(
                        key: const ValueKey('now-playing-track-title'),
                        text: track.title,
                        style: TextStyle(
                          color: context.chromePrimaryText,
                          fontSize: 24,
                          height: 1.08,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TrackChangeTransition(
                      trackId: track.id,
                      child: _OverflowMarquee(
                        key: const ValueKey('now-playing-track-artist'),
                        text: track.artist.trim().isEmpty
                            ? '未知艺人'
                            : track.artist.trim(),
                        onTap: onOpenArtist == null
                            ? null
                            : () => onOpenArtist!(track.artist),
                        semanticsLabel: onOpenArtist == null
                            ? null
                            : '打开艺人 ${track.artist}',
                        style: TextStyle(
                          color: context.chromeSecondaryText,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _NowPlayingActions(
                track: track,
                userState: userState,
                lyricsSelected: false,
                onToggleLyrics: onToggleLyrics,
              ),
            ],
          ),
        ],
        const SizedBox(height: 30),
        Padding(
          padding: detailsPadding,
          child: _PlaybackTimelineAndControls(
            key: compactLayout
                ? const ValueKey('compact-playback-controls')
                : null,
            playback: playback,
            sleepTimer: sleepTimer,
            edgeAlignTransport: compactLayout,
          ),
        ),
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
  /// Keep the delta small so play/pause does not compete with lyrics attach
  /// or vinyl spin on the same frames.
  static const _pausedScale = 0.94;

  /// Slightly longer than the primary button so scale eases in after the tap.
  static const _transitionDuration = Duration(milliseconds: 340);

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

class _CompactLyricsStage extends StatefulWidget {
  const _CompactLyricsStage({
    required this.track,
    required this.playback,
    required this.onExit,
    super.key,
  });

  final Track track;
  final SoundPlaybackController playback;
  final VoidCallback onExit;

  @override
  State<_CompactLyricsStage> createState() => _CompactLyricsStageState();
}

class _CompactLyricsStageState extends State<_CompactLyricsStage> {
  final GlobalKey<_LyricsPanelState> _lyricsPanelKey =
      GlobalKey<_LyricsPanelState>();

  @override
  void initState() {
    super.initState();
    // Panel state is available after the first frame for the header ⋯ slot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _CompactLyricsStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.id != widget.track.id ||
        !identical(oldWidget.track.lyrics, widget.track.lyrics)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trailingMenu = _lyricsPanelKey.currentState?.compactTrailingMenu();
    return Semantics(
      button: true,
      label: '返回封面',
      child: GestureDetector(
        key: const ValueKey('compact-lyrics-region'),
        behavior: HitTestBehavior.translucent,
        onTap: widget.onExit,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _LyricsPanel(
                key: _lyricsPanelKey,
                track: widget.track,
                positionListenable: widget.playback.positionListenable,
                positionOf: () => widget.playback.displayPosition,
                discontinuityRevision:
                    widget.playback.positionDiscontinuityRevision,
                onSeek: widget.playback.seek,
                compact: true,
              ),
            ),
            if (trailingMenu != null)
              Positioned(top: 0, right: -8, child: trailingMenu),
          ],
        ),
      ),
    );
  }
}

class _OverflowMarquee extends StatefulWidget {
  const _OverflowMarquee({
    required this.text,
    required this.style,
    this.onTap,
    this.semanticsLabel,
    this.motionKey,
    super.key,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final Key? motionKey;

  @override
  State<_OverflowMarquee> createState() => _OverflowMarqueeState();
}

class _OverflowMarqueeState extends State<_OverflowMarquee>
    with SingleTickerProviderStateMixin {
  static const _repeatGap = 48.0;
  static const _pixelsPerSecond = 28.0;

  late final AnimationController _controller;
  bool? _targetRunning;
  Duration? _targetDuration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncMotion({required bool running, required Duration duration}) {
    if (_targetRunning == running && _targetDuration == duration) return;
    _targetRunning = running;
    _targetDuration = duration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _targetRunning != running ||
          _targetDuration != duration) {
        return;
      }
      if (!running) {
        _controller
          ..stop()
          ..value = 0;
        return;
      }
      _controller
        ..duration = duration
        ..repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: direction,
          textScaler: scaler,
        )..layout();
        final overflow = math.max(0.0, painter.width - constraints.maxWidth);
        final running = overflow > 1 && !reduceMotion;
        final cycleDistance = painter.width + _repeatGap;
        final duration = Duration(
          milliseconds: ((cycleDistance / _pixelsPerSecond) * 1000).round(),
        );
        _syncMotion(running: running, duration: duration);

        Widget child;
        if (!running) {
          child = Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: widget.style,
          );
        } else {
          child = SizedBox(
            height: painter.height,
            child: ClipRect(
              child: ShaderMask(
                key: const ValueKey('overflow-marquee-edge-mask'),
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  final fade = (14 / bounds.width).clamp(0.04, 0.12);
                  return LinearGradient(
                    colors: const [
                      Color(0x00000000),
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0x00000000),
                    ],
                    stops: [0, fade, 1 - fade, 1],
                  ).createShader(bounds);
                },
                child: AnimatedBuilder(
                  animation: _controller,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.text,
                        maxLines: 1,
                        softWrap: false,
                        style: widget.style,
                      ),
                      const SizedBox(
                        key: ValueKey('overflow-marquee-repeat-gap'),
                        width: _repeatGap,
                      ),
                      Text(
                        widget.text,
                        maxLines: 1,
                        softWrap: false,
                        style: widget.style,
                      ),
                      const SizedBox(width: _repeatGap),
                    ],
                  ),
                  builder: (context, content) => OverflowBox(
                    alignment: AlignmentDirectional.centerStart,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: painter.height,
                    maxHeight: painter.height,
                    child: FractionalTranslation(
                      key: widget.motionKey,
                      translation: Offset(-_controller.value / 2, 0),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        child = Semantics(
          label: widget.semanticsLabel ?? widget.text,
          button: widget.onTap != null,
          excludeSemantics: true,
          child: child,
        );
        if (widget.onTap == null) return child;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: child,
        );
      },
    );
  }
}

class _PlaybackTimelineAndControls extends StatefulWidget {
  const _PlaybackTimelineAndControls({
    required this.playback,
    this.sleepTimer,
    this.edgeAlignTransport = false,
    super.key,
  });

  final SoundPlaybackController playback;
  final SleepTimerController? sleepTimer;
  final bool edgeAlignTransport;

  @override
  State<_PlaybackTimelineAndControls> createState() =>
      _PlaybackTimelineAndControlsState();
}

class _PlaybackTimelineAndControlsState
    extends State<_PlaybackTimelineAndControls> {
  /// Live position while the user drags the bar (labels + remaining).
  ///
  /// Engine [displayPosition] does not tick while paused, so labels must
  /// follow the scrubber preview directly or they stay frozen mid-drag.
  Duration? _scrubPreview;

  SoundPlaybackController get playback => widget.playback;
  SleepTimerController? get sleepTimer => widget.sleepTimer;

  void _onScrubPreviewChanged(Duration? preview) {
    if (_scrubPreview == preview) return;
    if (!mounted) return;
    // Keep the field current immediately so a parent rebuild already in
    // flight can still read the latest scrub time if it re-enters build.
    _scrubPreview = preview;
    // ProgressScrubber.didUpdateWidget can emit while our AnimatedBuilder is
    // mid-build (engine position catch-up). setState then asserts.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  void _cycleMode(BuildContext context) {
    playback.cycleCombinedPlaybackMode();
    showSoundSnackBar(context, playback.playbackMode.label);
  }

  Future<void> _openSleepTimer(BuildContext context) async {
    final timer = sleepTimer;
    if (timer == null) {
      showSoundSnackBar(context, '睡眠定时暂不可用');
      return;
    }
    await showSoundBottomSheet<void>(
      context,
      maxWidth: 420,
      builder: (sheetContext) {
        return AnimatedBuilder(
          animation: timer,
          builder: (context, _) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '睡眠定时',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: context.chromePrimaryText),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timer.isActive
                          ? '当前：${_sleepTimerStatusLabel(timer)}'
                          : '到时后自动暂停播放',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.chromeSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final minutes in const [15, 30, 45, 60])
                      SoundListRow(
                        key: ValueKey('now-playing-sleep-timer-$minutes'),
                        minHeight: context
                            .soundComponentProfile
                            .minimumInteractiveTarget,
                        padding: EdgeInsets.zero,
                        title: Text('$minutes 分钟'),
                        onTap: () {
                          timer.start(Duration(minutes: minutes));
                          Navigator.pop(sheetContext);
                          showSoundSnackBar(context, '已设置 $minutes 分钟后暂停');
                        },
                      ),
                    SoundListRow(
                      key: const ValueKey(
                        'now-playing-sleep-timer-end-of-track',
                      ),
                      minHeight: context
                          .soundComponentProfile
                          .minimumInteractiveTarget,
                      padding: EdgeInsets.zero,
                      enabled: playback.displayTrack != null,
                      title: const Text('播完当前歌曲'),
                      onTap: playback.displayTrack == null
                          ? null
                          : () {
                              timer.stopAfterCurrentTrack();
                              Navigator.pop(sheetContext);
                              showSoundSnackBar(context, '将在本曲结束后暂停');
                            },
                    ),
                    if (timer.isActive)
                      SoundListRow(
                        key: const ValueKey('now-playing-sleep-timer-cancel'),
                        minHeight: context
                            .soundComponentProfile
                            .minimumInteractiveTarget,
                        padding: EdgeInsets.zero,
                        title: Text(
                          '关闭睡眠定时',
                          style: TextStyle(color: context.soundColors.error),
                        ),
                        onTap: () {
                          timer.cancel();
                          Navigator.pop(sheetContext);
                          showSoundSnackBar(context, '已关闭睡眠定时');
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Position ticks use [positionListenable] so the rest of now-playing
    // (artwork gradient, vinyl, chrome) is not rebuilt ~20× per second.
    return AnimatedBuilder(
      animation: Listenable.merge([playback, playback.positionListenable]),
      builder: (context, _) {
        final enginePosition = playback.displayPosition;
        // Prefer live scrub preview so labels move while paused (no ticks).
        final position = _scrubPreview ?? enginePosition;
        final duration = playback.displayDuration;
        final visual = PlaybackVisualState.fromSnapshot(
          playback.snapshot,
          hasDisplayTrack: true,
        );
        final remaining = duration - position;
        final remainingLabel = duration > Duration.zero
            ? '-${formatDuration(remaining.isNegative ? Duration.zero : remaining)}'
            : '0:00';
        final mode = playback.playbackMode;
        final timerActive = sleepTimer?.isActive ?? false;
        final transportColor = context.chromePrimaryText.withValues(
          alpha: 0.72,
        );
        final secondaryControlColor = context.chromePrimaryText.withValues(
          alpha: 0.60,
        );
        final sideButtonStyle = IconButton.styleFrom(
          fixedSize: const Size.square(44),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
        );
        final primaryTransportIcon = switch (visual.primaryVisual) {
          PlaybackPrimaryVisual.play => KaitingIcons.playTransport,
          PlaybackPrimaryVisual.pause => KaitingIcons.pauseTransport,
          _ => visual.primaryIcon,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Horizontal 0 keeps track edges aligned with title; vertical hit
            // is expanded inside ProgressScrubber (minInteractiveHeight).
            ProgressScrubber(
              position: enginePosition,
              duration: duration,
              onSeek: playback.seek,
              onPreviewChanged: _onScrubPreviewChanged,
              activeColor: context.chromePrimaryText,
              inactiveColor: context.chromePrimaryText.withValues(alpha: 0.22),
              padding: EdgeInsets.zero,
              thumbRadius: 7,
              overlayRadius: 22,
              minInteractiveHeight: 44,
              trackVerticalOffset: 7,
            ),
            Row(
              children: [
                Text(
                  key: const ValueKey('now-playing-position-label'),
                  formatDuration(position),
                  style: _timeStyle(context),
                ),
                const Spacer(),
                Text(
                  key: const ValueKey('now-playing-remaining-label'),
                  remainingLabel,
                  style: _timeStyle(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Transform.translate(
                  offset: Offset(widget.edgeAlignTransport ? -10 : 0, 0),
                  child: IconButton(
                    key: const ValueKey('now-playing-mode-cycle'),
                    onPressed: () => _cycleMode(context),
                    tooltip: mode.label,
                    icon: Icon(mode.icon),
                    iconSize: 24,
                    color: secondaryControlColor,
                    style: sideButtonStyle,
                  ),
                ),
                IconButton(
                  onPressed: playback.previous,
                  tooltip: '上一首',
                  icon: const Icon(KaitingIcons.previousTransport),
                  iconSize: 30,
                  color: transportColor,
                  style: sideButtonStyle,
                ),
                IconButton(
                  onPressed: visual.primaryEnabled ? playback.toggle : null,
                  tooltip: visual.primaryTooltip,
                  icon: visual.busy && !visual.primaryEnabled
                      ? SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: transportColor,
                          ),
                        )
                      : Icon(
                          primaryTransportIcon,
                          size:
                              visual.primaryVisual ==
                                  PlaybackPrimaryVisual.pause
                              ? 40
                              : 48,
                        ),
                  color: transportColor,
                  style: IconButton.styleFrom(
                    fixedSize: const Size.square(56),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ),
                IconButton(
                  onPressed: playback.next,
                  tooltip: '下一首',
                  icon: const Icon(KaitingIcons.nextTransport),
                  iconSize: 30,
                  color: transportColor,
                  style: sideButtonStyle,
                ),
                Transform.translate(
                  offset: Offset(widget.edgeAlignTransport ? 10 : 0, 0),
                  child: IconButton(
                    key: const ValueKey('now-playing-sleep-timer'),
                    onPressed: () => unawaited(_openSleepTimer(context)),
                    tooltip: timerActive
                        ? '睡眠定时：${_sleepTimerStatusLabel(sleepTimer!)}'
                        : '睡眠定时',
                    icon: Icon(
                      timerActive
                          ? KaitingIcons.timerFilled
                          : KaitingIcons.timer,
                    ),
                    iconSize: 24,
                    color: timerActive
                        ? SoundColors.accent
                        : secondaryControlColor,
                    style: sideButtonStyle,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

String _sleepTimerStatusLabel(SleepTimerController timer) {
  return switch (timer.mode) {
    SleepTimerMode.off => '关闭',
    SleepTimerMode.endOfTrack => '播完当前歌曲',
    SleepTimerMode.duration => () {
      final minutes = timer.remaining.inMinutes;
      final seconds = timer.remaining.inSeconds
          .remainder(60)
          .toString()
          .padLeft(2, '0');
      return '$minutes:$seconds';
    }(),
  };
}

class _NowPlayingActions extends StatelessWidget {
  const _NowPlayingActions({
    required this.track,
    required this.userState,
    required this.lyricsSelected,
    required this.onToggleLyrics,
    super.key,
  });

  final Track track;
  final LibraryUserStateController? userState;
  final bool lyricsSelected;
  final VoidCallback? onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final state = userState;
    final isFavorite = state?.isFavorite(track.id) ?? false;
    final inactiveColor = context.chromePrimaryText.withValues(alpha: 0.64);
    const actionIconSize = 24.0;
    final buttonStyle = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      minimumSize: const Size.square(42),
      padding: const EdgeInsets.all(8),
    );
    final actions = <Widget>[
      if (state != null)
        IconButton(
          key: ValueKey('favorite-now-playing-${track.id}'),
          onPressed: () => unawaited(state.toggleFavorite(track)),
          tooltip: isFavorite ? '取消收藏' : '收藏歌曲',
          color: isFavorite ? SoundColors.accent : inactiveColor,
          iconSize: actionIconSize,
          style: buttonStyle,
          icon: Icon(
            isFavorite ? KaitingIcons.favoriteFilled : KaitingIcons.favorite,
          ),
        ),
      if (state != null)
        IconButton(
          key: ValueKey('add-now-playing-${track.id}-to-playlist'),
          onPressed: () =>
              showAddToPlaylistSheet(context, userState: state, track: track),
          tooltip: '添加到播放列表',
          color: inactiveColor,
          iconSize: actionIconSize,
          style: buttonStyle,
          icon: const Icon(KaitingIcons.playlistAdd),
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
          color: lyricsSelected ? SoundColors.accent : inactiveColor,
          iconSize: actionIconSize,
          style: buttonStyle,
          icon: Icon(
            lyricsSelected ? KaitingIcons.lyricsFilled : KaitingIcons.lyrics,
          ),
        ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          actions[index],
        ],
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
        child: SoundInlineStatus(
          key: const ValueKey('playback-error-banner'),
          tone: SoundStatusTone.error,
          title: failure.title,
          message: failure.message,
          actionLabel: '重试',
          onAction: onRetry,
          titleColor: context.chromePrimaryText,
          messageColor: context.chromeMutedText,
        ),
      ),
    );
  }
}

TextStyle _timeStyle(BuildContext context) => TextStyle(
  color: context.chromeSecondaryText,
  fontSize: 11,
  fontFeatures: const [FontFeature.tabularFigures()],
);

class _LyricsPanel extends StatefulWidget {
  const _LyricsPanel({
    required this.track,
    required this.positionListenable,
    required this.positionOf,
    required this.discontinuityRevision,
    required this.onSeek,
    this.compact = false,
    this.verticalControls = false,
    super.key,
  });

  final Track track;

  /// High-frequency clock ticks. The panel only [setState]s when the active
  /// **cue** changes; karaoke fill listens separately so 20–60 Hz position
  /// updates never rebuild the full line list.
  final Listenable positionListenable;
  final Duration Function() positionOf;
  final int discontinuityRevision;
  final Future<void> Function(Duration position) onSeek;
  final bool compact;
  final bool verticalControls;

  @override
  State<_LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends State<_LyricsPanel> {
  static const _offsetStep = Duration(milliseconds: 500);

  /// Soft scroll when the singing cue advances (not seeks / first open).
  static const _followDuration = Duration(milliseconds: 380);
  static const _lineStyleDuration = Duration(milliseconds: 260);
  static const _manualScrollPause = Duration(seconds: 3);

  final _scrollController = ScrollController();
  final _lyricsViewportKey = GlobalKey();
  late List<GlobalKey> _lineKeys;
  late LyricsTimeline _timeline;
  Duration _offset = Duration.zero;
  int? _activeIndex;
  int? _lastFollowedCue;
  bool _snapNextFollow = false;
  bool _showingPreamble = true;
  bool _autoFollowPaused = false;
  bool _compactUserScrolling = false;
  Timer? _manualScrollTimer;
  Duration _lastPositionSample = Duration.zero;

  Track get track => widget.track;
  Duration get _position => widget.positionOf();

  @override
  void initState() {
    super.initState();
    _lineKeys = _keysFor(track.lyrics.length);
    _timeline = LyricsTimeline.forTrack(track);
    _lastPositionSample = _position;
    _activeIndex = _timeline.isSynchronized
        ? _timeline.activeLineIndex(_position, offset: _offset)
        : null;
    widget.positionListenable.addListener(_onPositionTick);
    // Keys exist only after the first frame; follow must not rely on build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleFollowForCurrentActive(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant _LyricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionListenable != widget.positionListenable) {
      oldWidget.positionListenable.removeListener(_onPositionTick);
      widget.positionListenable.addListener(_onPositionTick);
    }
    if (oldWidget.track.id != track.id) {
      _manualScrollTimer?.cancel();
      _offset = Duration.zero;
      _activeIndex = null;
      _lastFollowedCue = null;
      _snapNextFollow = true;
      _showingPreamble = true;
      _autoFollowPaused = false;
      _lineKeys = _keysFor(track.lyrics.length);
      _timeline = LyricsTimeline.forTrack(track);
      _lastPositionSample = _position;
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _activeIndex = _timeline.isSynchronized
          ? _timeline.activeLineIndex(_position, offset: _offset)
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleFollowForCurrentActive(force: true);
      });
    } else if (!identical(oldWidget.track.lyrics, track.lyrics)) {
      // Lyrics often hydrate after the panel mounts — must re-follow.
      _lineKeys = _keysFor(track.lyrics.length);
      _timeline = LyricsTimeline.forTrack(track);
      _lastFollowedCue = null;
      _snapNextFollow = true;
      _activeIndex = _timeline.isSynchronized
          ? _timeline.activeLineIndex(_position, offset: _offset)
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scheduleFollowForCurrentActive(force: true);
      });
    } else if (widget.discontinuityRevision !=
        oldWidget.discontinuityRevision) {
      // Seeks and repeat-one wraps cancel any old follow animation.
      _manualScrollTimer?.cancel();
      _autoFollowPaused = false;
      _snapNextFollow = true;
      _lastFollowedCue = null;
      _syncActiveFromClock(forceFollow: true);
    }
  }

  @override
  void dispose() {
    widget.positionListenable.removeListener(_onPositionTick);
    _manualScrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPositionTick() {
    if (!mounted) return;
    final now = _position;
    // Large backward jump without discontinuity revision (edge engines).
    if (now + const Duration(milliseconds: 500) < _lastPositionSample) {
      _snapNextFollow = true;
      _lastFollowedCue = null;
    }
    _lastPositionSample = now;
    _syncActiveFromClock();
  }

  void _syncActiveFromClock({bool forceFollow = false}) {
    if (!_timeline.isSynchronized) return;
    final next = _timeline.activeLineIndex(_position, offset: _offset);
    final changed = next != _activeIndex;
    if (!changed && !forceFollow) return;
    if (changed) {
      setState(() => _activeIndex = next);
    }
    if (next != null) {
      // Animate on normal cue advances; only snap on seek / open / hydrate.
      _followActiveLine(next, force: forceFollow);
    } else {
      _followPreamble(force: forceFollow);
    }
  }

  void _scheduleFollowForCurrentActive({bool force = false}) {
    if (!_timeline.isSynchronized) return;
    final active =
        _activeIndex ?? _timeline.activeLineIndex(_position, offset: _offset);
    if (active != null) {
      if (_activeIndex != active) {
        setState(() => _activeIndex = active);
      }
      _followActiveLine(active, force: force);
    } else {
      _followPreamble(force: force);
    }
  }

  List<GlobalKey> _keysFor(int length) =>
      List.generate(length, (index) => GlobalKey(debugLabel: 'lyric-$index'));

  void _followActiveLine(int active, {bool force = false}) {
    final cueStart = _timeline.cueStartIndex(active);
    if (_autoFollowPaused) return;
    if (!force && _lastFollowedCue == cueStart) return;
    _showingPreamble = false;
    final snap = force || _snapNextFollow;
    _snapNextFollow = false;
    // Mark intent now; clear on failure so a later tick can retry.
    _lastFollowedCue = cueStart;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoFollowPaused || cueStart >= _lineKeys.length) {
        return;
      }
      final lineContext = _lineKeys[cueStart].currentContext;
      if (lineContext == null) {
        if (_lastFollowedCue == cueStart) {
          _lastFollowedCue = null;
        }
        return;
      }
      Scrollable.ensureVisible(
        lineContext,
        alignment: widget.compact ? 0.50 : 0.40,
        duration: snap ? Duration.zero : _followDuration,
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _followPreamble({bool force = false}) {
    if (_autoFollowPaused) return;
    if (!force && _showingPreamble) return;
    _showingPreamble = true;
    _lastFollowedCue = null;
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

  Future<void> _seekCompactCenterLine() async {
    if (!widget.compact || !_timeline.isSynchronized || !mounted) return;
    final viewport = _lyricsViewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.attached) return;
    final viewportTop = viewport.localToGlobal(Offset.zero).dy;
    final targetY = viewportTop + viewport.size.height / 2;

    int? closestIndex;
    var closestDistance = double.infinity;
    for (var index = 0; index < _lineKeys.length; index++) {
      if (!_timeline.isSeekable(index)) continue;
      final lineContext = _lineKeys[index].currentContext;
      final lineBox = lineContext?.findRenderObject();
      if (lineBox is! RenderBox || !lineBox.attached) continue;
      final lineTop = lineBox.localToGlobal(Offset.zero).dy;
      final distance = (lineTop + lineBox.size.height / 2 - targetY).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    if (closestIndex == null) return;
    await _seekToLine(closestIndex, track.lyrics[closestIndex]);
  }

  void _finishCompactUserScroll() {
    if (!_compactUserScrolling) return;
    setState(() => _compactUserScrolling = false);
    unawaited(_seekCompactCenterLine());
  }

  void _resumeAutoFollow() {
    _manualScrollTimer?.cancel();
    _manualScrollTimer = null;
    if (!mounted) return;
    setState(() {
      _autoFollowPaused = false;
      _snapNextFollow = true;
      _lastFollowedCue = null;
    });
    _syncActiveFromClock(forceFollow: true);
  }

  void _changeOffset(Duration delta) {
    setState(() {
      _offset += delta;
      _lastFollowedCue = null;
      _showingPreamble = false;
      _snapNextFollow = true;
    });
    _syncActiveFromClock(forceFollow: true);
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
          _lastFollowedCue = null;
          _snapNextFollow = true;
        });
        _syncActiveFromClock(forceFollow: true);
        return;
      case _LyricsMenuAction.advance:
        _changeOffset(_offsetStep);
        return;
    }
  }

  /// Compact header slot: ⋯ next to cover/title (not over the lyric list).
  Widget? compactTrailingMenu() {
    if (!widget.compact) return null;
    if (!_timeline.isSynchronized || !_timeline.hasTimedContent) return null;
    return _buildCompactLyricsMenu();
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
            icon: KaitingIcons.locate,
          ),
        SoundMenuAction(
          value: _LyricsMenuAction.delay,
          label: '歌词延后 0.5 秒',
          subtitle: '当前偏移 $_offsetLabel',
          icon: KaitingIcons.remove,
        ),
        SoundMenuAction(
          value: _LyricsMenuAction.reset,
          label: '重置歌词偏移',
          icon: KaitingIcons.refresh,
          enabled: _offset != Duration.zero,
        ),
        SoundMenuAction(
          value: _LyricsMenuAction.advance,
          label: '歌词提前 0.5 秒',
          subtitle: '当前偏移 $_offsetLabel',
          icon: KaitingIcons.add,
        ),
      ],
      onSelected: _handleLyricsMenuAction,
      child: SizedBox.square(
        dimension: 36,
        child: Center(
          child: Icon(
            KaitingIcons.moreHorizontal,
            size: 22,
            color: context.chromeMutedText,
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
              color: context.chromeMutedText,
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w600,
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
                  : () {
                      setState(() {
                        _offset = Duration.zero;
                        _lastFollowedCue = null;
                        _snapNextFollow = true;
                      });
                      _syncActiveFromClock(forceFollow: true);
                    },
              child: Text(
                _offsetLabel,
                style: TextStyle(
                  color: context.chromeMutedText.withValues(
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
      builder: (context, constraints) {
        final scroller = Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) _pauseAutoFollow();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _pauseAutoFollow();
                if (widget.compact && !_compactUserScrolling) {
                  setState(() => _compactUserScrolling = true);
                }
              } else if (notification is ScrollEndNotification &&
                  widget.compact) {
                _finishCompactUserScroll();
              }
              return false;
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                // Compact: clear the overlaid ⋯ menu; wide dual-pane keeps
                // a large top inset so the active cue sits mid-column.
                top: widget.verticalControls
                    ? math.max(88, constraints.maxHeight * 0.36)
                    : widget.compact
                    ? math.max(72, constraints.maxHeight * 0.45)
                    : 0,
                bottom: widget.compact
                    ? math.max(72, constraints.maxHeight * 0.50)
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
        );
        // Soft top/bottom edge so lines dissolve instead of hard-clipping.
        // ClipRect prevents 1px mask leaks; multi-stop top fade is longer.
        return Stack(
          key: _lyricsViewportKey,
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) {
                  final h = bounds.height;
                  if (h <= 1) {
                    return const LinearGradient(
                      colors: [Colors.black, Colors.black],
                    ).createShader(bounds);
                  }
                  // Layout-specific bands:
                  // - compact (phone): balanced top (⋯ lives on the title row)
                  // - desktop / foldable dual-pane: short top, longer bottom
                  final double topPx;
                  final double bottomPx;
                  if (widget.compact) {
                    topPx = math.min(h * 0.16, 80.0).clamp(36.0, 88.0);
                    bottomPx = math.min(h * 0.14, 72.0).clamp(32.0, 80.0);
                  } else if (widget.verticalControls) {
                    topPx = math.min(h * 0.10, 56.0).clamp(28.0, 64.0);
                    bottomPx = math.min(h * 0.22, 120.0).clamp(56.0, 132.0);
                  } else {
                    topPx = math.min(h * 0.14, 72.0).clamp(36.0, 80.0);
                    bottomPx = math.min(h * 0.16, 88.0).clamp(40.0, 96.0);
                  }
                  final t1 = (topPx * 0.30 / h).clamp(0.015, 0.10);
                  final t2 = (topPx * 0.65 / h).clamp(0.04, 0.16);
                  final t3 = (topPx / h).clamp(0.06, 0.28);
                  final b3 = (1.0 - bottomPx / h).clamp(0.62, 0.92);
                  final b2 = (1.0 - bottomPx * 0.55 / h).clamp(0.74, 0.96);
                  final b1 = (1.0 - bottomPx * 0.22 / h).clamp(0.86, 0.985);
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x66000000),
                      Color(0xFF000000),
                      Color(0xFF000000),
                      Color(0x99000000),
                      Color(0x00000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, t1, t2, t3, b3, b2, b1, 1.0],
                  ).createShader(bounds);
                },
                child: scroller,
              ),
            ),
            if (widget.compact && _compactUserScrolling)
              IgnorePointer(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const ValueKey('compact-lyrics-seek-guide'),
                    width: 34,
                    height: 2,
                    decoration: BoxDecoration(
                      color: context.chromePrimaryText.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Foldable dual-pane and compact sheets: slightly smaller type so
        // fewer "甩一字" wraps before balancing.
        final narrow = constraints.maxWidth < 340;
        final fontSize = isActive
            ? (narrow ? 20.0 : 22.0)
            : (narrow ? 18.0 : 20.0);
        final primary = context.chromePrimaryText;
        final style = TextStyle(
          color: primary.withValues(
            alpha: isActive
                ? 1
                : active != null && index < active
                ? 0.28
                : 0.5,
          ),
          fontSize: fontSize,
          height: synchronized ? 2.25 : 1.7,
          // Soft type: emphasis is color/size, not heavy weight.
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        );
        // Line-level LRC: fill from this cue to the next (karaoke wipe).
        // Karaoke starts the same frame as the cue; size/opacity ease separately.
        final karaoke = isActive && synchronized;
        final textAlign = widget.compact ? TextAlign.center : TextAlign.start;
        return GestureDetector(
          key: _lineKeys[index],
          behavior: HitTestBehavior.opaque,
          onTap: widget.compact || !_timeline.isSeekable(index)
              ? null
              : () => _seekToLine(index, line),
          child: KeyedSubtree(
            key: widget.compact ? ValueKey('compact-lyrics-line-$index') : null,
            child: AnimatedDefaultTextStyle(
              duration: synchronized ? _lineStyleDuration : Duration.zero,
              curve: Curves.easeOutCubic,
              style: style,
              textAlign: textAlign,
              // Read the lerped style so size/opacity actually animate.
              child: Builder(
                builder: (context) {
                  final animatedStyle = DefaultTextStyle.of(context).style;
                  if (karaoke) {
                    return KaraokeLyricText(
                      line.text,
                      style: animatedStyle,
                      textAlign: textAlign,
                      progressListenable: widget.positionListenable,
                      progressOf: () => _timeline.cueProgress(
                        widget.positionOf(),
                        lineIndex: index,
                        offset: _offset,
                      ),
                      fillColor: primary,
                      baseColor: primary.withValues(alpha: 0.34),
                    );
                  }
                  return BalancedLyricText(
                    line.text,
                    style: animatedStyle,
                    textAlign: textAlign,
                  );
                },
              ),
            ),
          ),
        );
      },
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
              color: context.chromeSecondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '这首歌曲没有内嵌歌词',
                style: TextStyle(color: context.chromeSecondaryText),
              ),
            ),
          ),
        ],
      );
    }
    final synchronized = _timeline.isSynchronized;
    final active = _activeIndex;
    if (widget.verticalControls) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(
              // Keep controls readable but reclaim width for lyric lines.
              right: synchronized && _timeline.hasTimedContent ? 56 : 0,
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
      // ⋯ menu is hosted on the cover/title row (see compactTrailingMenu).
      return _buildLyricsScroller(
        lyrics,
        active: active,
        synchronized: synchronized,
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
                color: context.chromeSecondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
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
                      : () {
                          setState(() {
                            _offset = Duration.zero;
                            _lastFollowedCue = null;
                            _snapNextFollow = true;
                          });
                          _syncActiveFromClock(forceFollow: true);
                        },
                  child: Text(
                    _offsetLabel,
                    style: TextStyle(
                      color: _offset == Duration.zero
                          ? context.chromeMutedText
                          : context.chromeSecondaryText,
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
        color: context.chromeControlSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                color: context.chromeSecondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
          icon: KaitingIcons.minimize,
          tooltip: '最小化',
          onTap: () => unawaited(minimizeWindow()),
        ),
        const SizedBox(width: 8),
        _WindowDot(
          icon: _maximized ? KaitingIcons.restore : KaitingIcons.maximize,
          tooltip: _maximized ? '向下还原' : '最大化',
          onTap: () => unawaited(_toggleMaximize()),
        ),
        const SizedBox(width: 8),
        _WindowDot(
          icon: KaitingIcons.close,
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
            color: context.chromeControlSurface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(icon, size: 11, color: context.chromeSecondaryText),
          ),
        ),
      ),
    );
  }
}
