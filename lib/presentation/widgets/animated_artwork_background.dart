import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import 'artwork_image_provider.dart';

/// A restrained, content-aware background for the now-playing screen.
///
/// Colors are extracted from the same artwork provider used by the album art.
/// Motion is a soft multi-layer drift + breath (not a linear spin): glows ease
/// in and out while centers wander slowly. Playback raises the energy; pause
/// keeps a quiet ambient pulse so the surface still feels alive.
class AnimatedArtworkBackground extends StatefulWidget {
  const AnimatedArtworkBackground({
    required this.album,
    required this.position,
    required this.isPlaying,
    this.isActive = true,
    super.key,
  });

  final Album album;
  final Duration position;
  final bool isPlaying;

  /// When false (mobile now-playing still sliding), freeze motion so the open
  /// transition is not fighting continuous gradient tickers.
  final bool isActive;

  /// Starts the bounded artwork decode and palette extraction before the
  /// now-playing route is opened. The route can still paint its deterministic
  /// fallback immediately when this future has not completed yet.
  static Future<void> prewarm({
    required Album album,
    required Brightness brightness,
  }) async {
    await colorSchemeForAlbum(album: album, brightness: brightness);
  }

  /// Returns the cached Material color scheme extracted from [album]'s cover.
  /// Album pages and the now-playing background share this path so opening one
  /// surface also warms the other without decoding the artwork twice.
  static Future<ColorScheme?> colorSchemeForAlbum({
    required Album album,
    required Brightness brightness,
  }) async {
    final artworkUri = album.artworkUri?.trim();
    if (artworkUri == null || artworkUri.isEmpty) return null;
    final provider = artworkImageProvider(
      artworkUri,
      cacheWidth: artworkPaletteCacheExtent,
      cacheHeight: artworkPaletteCacheExtent,
    );
    if (provider == null) return null;
    final requestKey = '$artworkUri|${brightness.name}';
    return _AnimatedArtworkBackgroundState._cachedScheme(
      requestKey,
      provider,
      brightness,
    );
  }

  @visibleForTesting
  static bool debugHasPrewarmed({
    required Album album,
    required Brightness brightness,
  }) {
    final artworkUri = album.artworkUri?.trim();
    if (artworkUri == null || artworkUri.isEmpty) return false;
    return _AnimatedArtworkBackgroundState._schemeCache.containsKey(
      '$artworkUri|${brightness.name}',
    );
  }

  @override
  State<AnimatedArtworkBackground> createState() =>
      _AnimatedArtworkBackgroundState();
}

class _AnimatedArtworkBackgroundState extends State<AnimatedArtworkBackground>
    with TickerProviderStateMixin {
  static final Map<String, Future<ColorScheme>> _schemeCache = {};
  static const _cacheLimit = 64;

  late List<Color> _fromColors;
  late List<Color> _targetColors;
  late final AnimationController _motionController;
  late final AnimationController _paletteController;
  Brightness? _brightness;
  String? _requestKey;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _targetColors = artworkFallbackGradientColors(
      widget.album,
      Brightness.light,
    );
    _fromColors = List<Color>.of(_targetColors);
    // Drift loop (~12s). Breath uses a higher harmonic so one inhale/exhale
    // is about 4–5s — slow enough to feel calm, fast enough to notice.
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
      value: 0,
    );
    _motionController.value = _positionPhase(widget.position);
    _paletteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    final effects = context.soundSkinEffects;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _reduceMotion = reduceMotion;
    // Keep a readable pace even when a skin asks for a very long period.
    final baseMs = effects.motionDuration.inMilliseconds;
    _motionController.duration = Duration(
      milliseconds: baseMs.clamp(10000, 18000),
    );
    _paletteController.duration = effects.paletteTransitionDuration;
    if (_brightness != brightness) {
      _brightness = brightness;
      _loadArtworkColors();
    }
    _syncMotion();
  }

  @override
  void didUpdateWidget(AnimatedArtworkBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.artworkUri != widget.album.artworkUri ||
        oldWidget.album.id != widget.album.id) {
      _loadArtworkColors();
    }
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.isActive != widget.isActive) {
      _syncMotion();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _loadArtworkColors();
  }

  void _syncMotion() {
    if (_reduceMotion || !widget.isActive) {
      _motionController.stop();
      if (_reduceMotion) _motionController.value = 0;
      return;
    }
    // Defer the continuous ticker one frame so the first open / expand layout
    // can settle before we start painting every display refresh.
    if (_motionController.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reduceMotion || !widget.isActive) return;
      if (!_motionController.isAnimating) _motionController.repeat();
    });
  }

  double _positionPhase(Duration position) {
    final period = _motionController.duration?.inMilliseconds ?? 22000;
    if (period <= 0) return 0;
    return position.inMilliseconds.remainder(period) / period;
  }

  Future<void> _loadArtworkColors() async {
    final brightness = _brightness ?? Theme.of(context).brightness;
    final artworkUri = widget.album.artworkUri?.trim();
    final fallback = artworkFallbackGradientColors(widget.album, brightness);
    final requestKey = '${artworkUri ?? widget.album.id}|${brightness.name}';
    _requestKey = requestKey;

    if (artworkUri == null || artworkUri.isEmpty) {
      if (mounted) _transitionTo(fallback);
      return;
    }

    // Always paint fallback first; palette extraction is expensive and must
    // not block the first now-playing frame after a reload.
    if (!listEquals(_targetColors, fallback) &&
        !AnimatedArtworkBackground.debugHasPrewarmed(
          album: widget.album,
          brightness: brightness,
        )) {
      _fromColors = List<Color>.of(fallback);
      _targetColors = List<Color>.of(fallback);
      _paletteController.value = 1;
    }

    try {
      final scheme = await AnimatedArtworkBackground.colorSchemeForAlbum(
        album: widget.album,
        brightness: brightness,
      );
      if (scheme == null) {
        if (mounted && _requestKey == requestKey) _transitionTo(fallback);
        return;
      }
      if (!mounted || _requestKey != requestKey) return;
      _transitionTo(artworkGradientColorsFromScheme(scheme, brightness));
    } catch (error) {
      // Broken, unavailable, or unsupported artwork keeps the deterministic
      // album fallback. Playback should never fail because palette extraction
      // could not complete.
      if (kDebugMode) {
        debugPrint('Artwork palette extraction failed for $artworkUri: $error');
      }
      if (mounted && _requestKey == requestKey) _transitionTo(fallback);
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

  static Future<ColorScheme> _cachedScheme(
    String key,
    ImageProvider<Object> provider,
    Brightness brightness,
  ) async {
    final cached = _schemeCache[key];
    if (cached != null) return cached;

    if (_schemeCache.length >= _cacheLimit) {
      _schemeCache.remove(_schemeCache.keys.first);
    }
    final future = ColorScheme.fromImageProvider(
      provider: provider,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    _schemeCache[key] = future;
    try {
      return await future;
    } catch (_) {
      _schemeCache.remove(key);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? Theme.of(context).brightness;
    final effects = context.soundSkinEffects;

    // Floor strength so quiet skins still show a clear pulse; pause softens.
    final strengthScale = widget.isPlaying ? 1.15 : 0.55;
    final motionStrength =
        (effects.motionStrength.clamp(0.45, 1.0) * strengthScale)
            .clamp(0.35, 1.25)
            .toDouble();
    return RepaintBoundary(
      key: const ValueKey('now-playing-artwork-background'),
      child: AnimatedBuilder(
        animation: Listenable.merge([_paletteController, _motionController]),
        builder: (context, _) => CustomPaint(
          key: const ValueKey('now-playing-background-base'),
          painter: ArtworkGradientPainter(
            colors: _interpolatedColors,
            motion: _motionController,
            reduceMotion: _reduceMotion,
            brightness: brightness,
            motionStrength: motionStrength,
            primaryGlowOpacity: effects.primaryGlowOpacity,
            secondaryGlowOpacity: effects.secondaryGlowOpacity,
            lightVeilOpacity: effects.lightVeilOpacity,
            darkVeilOpacity: effects.darkVeilOpacity,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _motionController.dispose();
    _paletteController.dispose();
    super.dispose();
  }
}

/// Palette generation never needs the full-resolution cover. Keeping this
/// bounded avoids decoding a multi-megapixel image during route animation.
@visibleForTesting
const artworkPaletteCacheExtent = 256;

@visibleForTesting
class ArtworkGradientPainter extends CustomPainter {
  const ArtworkGradientPainter({
    required this.colors,
    required this.motion,
    required this.reduceMotion,
    required this.brightness,
    this.motionStrength = 1,
    this.primaryGlowOpacity = 0.90,
    this.secondaryGlowOpacity = 0.72,
    this.lightVeilOpacity = 0.04,
    this.darkVeilOpacity = 0.12,
  }) : super(repaint: motion);

  final List<Color> colors;
  final Animation<double> motion;
  final bool reduceMotion;
  final Brightness brightness;
  final double motionStrength;
  final double primaryGlowOpacity;
  final double secondaryGlowOpacity;
  final double lightVeilOpacity;
  final double darkVeilOpacity;

  /// Linear loop phase in radians (tests assert this advances while playing).
  double get phase => reduceMotion ? 0 : motion.value * math.pi * 2;

  /// Soft multi-harmonic wander — not a single constant-speed orbit.
  static double _drift(double radians) {
    return math.sin(radians) * 0.70 +
        math.sin(radians * 1.61 + 0.85) * 0.22 +
        math.sin(radians * 0.47 + 2.0) * 0.12;
  }

  /// 0…1 ease-in-out breath.
  static double _breath(double radians) => 0.5 + 0.5 * math.sin(radians);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final s = reduceMotion ? 0.0 : motionStrength.clamp(0.0, 1.3);
    final t = phase;

    // ~2.4 breaths per drift loop → about 4–5s inhale+exhale at 12s loop.
    final breathA = _breath(t * 2.4);
    final breathB = _breath(t * 2.05 + 1.3);
    final breathC = _breath(t * 1.7 + 2.5);

    // Base wash: visible color shift + drifting axis.
    final base = LinearGradient(
      begin: Alignment(
        -0.85 + _drift(t * 0.55) * 0.32 * s,
        -0.92 + _drift(t * 0.48 + 0.7) * 0.22 * s,
      ),
      end: Alignment(
        0.88 + _drift(t * 0.52 + 1.5) * 0.30 * s,
        0.90 + _drift(t * 0.44 + 2.1) * 0.22 * s,
      ),
      colors: [
        Color.lerp(colors[0], colors[2], breathA * 0.34 * s)!,
        Color.lerp(colors[1], colors[0], breathB * 0.22 * s)!,
        Color.lerp(colors[2], colors[1], breathC * 0.28 * s)!,
      ],
      stops: [
        0.0,
        (0.42 + (breathA - 0.5) * 0.14 * s).clamp(0.28, 0.58),
        1.0,
      ],
    );
    canvas.drawRect(rect, Paint()..shader = base.createShader(rect));

    // Primary glow: radius and opacity swing hard enough to read as "breath".
    final primaryAlpha =
        (primaryGlowOpacity * (0.38 + breathA * 0.72)).clamp(0.12, 1.0);
    final first = RadialGradient(
      center: Alignment(
        -0.40 + _drift(t * 0.72) * 0.42 * s,
        -0.48 + _drift(t * 0.61 + 1.0) * 0.36 * s,
      ),
      radius: 0.58 + breathA * 0.48 * s,
      colors: [
        colors[2].withValues(alpha: primaryAlpha),
        colors[2].withValues(alpha: primaryAlpha * 0.35),
        colors[2].withValues(alpha: 0),
      ],
      stops: const [0.0, 0.38, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = first.createShader(rect));

    // Secondary glow, offset phase — light "flows" across the field.
    final secondaryAlpha =
        (secondaryGlowOpacity * (0.32 + breathB * 0.78)).clamp(0.10, 1.0);
    final second = RadialGradient(
      center: Alignment(
        0.46 + _drift(t * 0.68 + 2.0) * 0.40 * s,
        0.40 + _drift(t * 0.76 + 0.5) * 0.38 * s,
      ),
      radius: 0.62 + breathB * 0.46 * s,
      colors: [
        colors[0].withValues(alpha: secondaryAlpha),
        colors[0].withValues(alpha: secondaryAlpha * 0.32),
        colors[0].withValues(alpha: 0),
      ],
      stops: const [0.0, 0.40, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = second.createShader(rect));

    // Mid bloom for depth.
    final midAlpha = (0.22 + breathC * 0.28) *
        s *
        (brightness == Brightness.light ? 0.65 : 1.0);
    if (midAlpha > 0.04) {
      final third = RadialGradient(
        center: Alignment(
          _drift(t * 0.38 + 3.1) * 0.34 * s,
          0.05 + _drift(t * 0.34 + 1.8) * 0.32 * s,
        ),
        radius: 0.82 + breathC * 0.30 * s,
        colors: [
          colors[1].withValues(alpha: midAlpha.clamp(0.0, 0.48)),
          colors[1].withValues(alpha: 0),
        ],
      );
      canvas.drawRect(rect, Paint()..shader = third.createShader(rect));
    }

    // Whole-screen veil pulse — the easiest "breath" to notice.
    final veilBoost = 1.0 + (breathA - 0.5) * 0.55 * s;
    canvas.drawRect(
      rect,
      Paint()
        ..color = brightness == Brightness.light
            ? Colors.white.withValues(
                alpha: (lightVeilOpacity * 1.6 * veilBoost).clamp(0.0, 0.16),
              )
            : Colors.black.withValues(
                alpha: (darkVeilOpacity * 1.35 * veilBoost).clamp(0.0, 0.28),
              ),
    );
  }

  @override
  bool shouldRepaint(ArtworkGradientPainter oldDelegate) {
    return oldDelegate.brightness != brightness ||
        oldDelegate.reduceMotion != reduceMotion ||
        oldDelegate.motionStrength != motionStrength ||
        oldDelegate.primaryGlowOpacity != primaryGlowOpacity ||
        oldDelegate.secondaryGlowOpacity != secondaryGlowOpacity ||
        oldDelegate.lightVeilOpacity != lightVeilOpacity ||
        oldDelegate.darkVeilOpacity != darkVeilOpacity ||
        oldDelegate.motion != motion ||
        !listEquals(oldDelegate.colors, colors);
  }
}

List<Color> artworkGradientColorsFromScheme(
  ColorScheme scheme,
  Brightness brightness,
) {
  // Material's generated tertiary color is intentionally complementary. That
  // is useful for controls, but makes unrelated covers converge on the same
  // pair of hues (for example brown -> cyan and cyan -> brown). Keep all three
  // background stops in the artwork's dominant color family instead.
  final blended = Color.lerp(scheme.primary, scheme.secondary, 0.48)!;
  final analogous = _shiftHue(scheme.primary, 24);
  if (brightness == Brightness.light) {
    return [
      _tone(scheme.primary, saturation: 0.52, lightness: 0.77),
      _tone(blended, saturation: 0.34, lightness: 0.86),
      _tone(analogous, saturation: 0.52, lightness: 0.66),
    ];
  }
  return [
    _tone(scheme.primary, saturation: 0.48, lightness: 0.14),
    _tone(blended, saturation: 0.32, lightness: 0.10),
    _tone(analogous, saturation: 0.50, lightness: 0.24),
  ];
}

Color _shiftHue(Color color, double degrees) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor();
}

List<Color> artworkFallbackGradientColors(Album album, Brightness brightness) {
  final palette = album.palette.isEmpty
      ? const [Color(0xFF5E7774), Color(0xFF25302F)]
      : album.palette;
  final first = palette.first;
  final last = palette.last;
  final middle = Color.lerp(first, last, 0.42)!;
  if (brightness == Brightness.light) {
    return [
      _tone(first, saturation: 0.34, lightness: 0.82),
      _tone(middle, saturation: 0.24, lightness: 0.88),
      _tone(last, saturation: 0.38, lightness: 0.76),
    ];
  }
  return [
    _tone(first, saturation: 0.34, lightness: 0.14),
    _tone(middle, saturation: 0.22, lightness: 0.10),
    _tone(last, saturation: 0.38, lightness: 0.22),
  ];
}

/// Contrast-safe colors shared by artwork-led detail pages.
@immutable
class ArtworkPagePalette {
  const ArtworkPagePalette({
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.divider,
    required this.controlSurface,
    required this.useLightText,
  });

  factory ArtworkPagePalette.fromBackground(List<Color> colors) {
    final sample = Color.lerp(
      Color.lerp(colors.first, colors[1], 0.58),
      colors.last,
      0.24,
    )!;
    final useLightText = sample.computeLuminance() < 0.34;
    final primary = useLightText
        ? Colors.white.withValues(alpha: 0.94)
        : const Color(0xEC17171C);
    final secondary = useLightText
        ? Colors.white.withValues(alpha: 0.76)
        : Colors.black.withValues(alpha: 0.64);
    final muted = useLightText
        ? Colors.white.withValues(alpha: 0.60)
        : Colors.black.withValues(alpha: 0.49);
    return ArtworkPagePalette(
      primaryText: primary,
      secondaryText: secondary,
      mutedText: muted,
      divider: primary.withValues(alpha: useLightText ? 0.15 : 0.10),
      controlSurface: primary.withValues(alpha: useLightText ? 0.13 : 0.075),
      useLightText: useLightText,
    );
  }

  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color divider;
  final Color controlSurface;
  final bool useLightText;
}

/// Softens extracted artwork colors into a restrained page background.
List<Color> artworkPageBackgroundColors(
  List<Color> source,
  Brightness brightness,
) {
  final safeSource = source.isEmpty
      ? const [Color(0xFF5E7774), Color(0xFF42514F), Color(0xFF25302F)]
      : source;
  final targetLightness = brightness == Brightness.light
      ? const [0.78, 0.83, 0.74]
      : const [0.18, 0.13, 0.23];
  return List<Color>.generate(3, (index) {
    final hsl = HSLColor.fromColor(safeSource[index % safeSource.length]);
    final saturation = brightness == Brightness.light
        ? (hsl.saturation * 0.52).clamp(0.12, 0.34).toDouble()
        : (hsl.saturation * 0.62).clamp(0.14, 0.42).toDouble();
    return hsl
        .withSaturation(saturation)
        .withLightness(targetLightness[index])
        .toColor();
  });
}

Color _tone(
  Color color, {
  required double saturation,
  required double lightness,
}) {
  final hsl = HSLColor.fromColor(color);
  final sourceSaturation = hsl.saturation.clamp(0.12, 0.64).toDouble();
  return hsl
      .withSaturation((sourceSaturation * 0.55 + saturation * 0.45).clamp(0, 1))
      .withLightness(lightness)
      .toColor();
}
