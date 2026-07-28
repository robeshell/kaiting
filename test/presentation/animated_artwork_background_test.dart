import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/presentation/widgets/animated_artwork_background.dart';

void main() {
  late Directory directory;
  late File artwork;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('sound-palette-test-');
    artwork = File('${directory.path}/cover.png');
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 16, 16),
      Paint()..color = const Color(0xFF1B8F78),
    );
    final image = await recorder.endRecording().toImage(16, 16);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await artwork.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });

  tearDownAll(() async {
    await directory.delete(recursive: true);
  });

  test('artwork palettes do not reuse generated complementary colors', () {
    final brownScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF885113),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final cyanScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006A67),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );

    final brown = artworkGradientColorsFromScheme(
      brownScheme,
      Brightness.light,
    );
    final cyan = artworkGradientColorsFromScheme(cyanScheme, Brightness.light);
    final brownHue = HSLColor.fromColor(brown.first).hue;
    final cyanHue = HSLColor.fromColor(cyan.first).hue;

    expect(_hueDistance(brownHue, cyanHue), greaterThan(80));
    for (final color in brown.skip(1)) {
      expect(
        _hueDistance(HSLColor.fromColor(color).hue, brownHue),
        lessThan(35),
      );
    }
    for (final color in cyan.skip(1)) {
      expect(
        _hueDistance(HSLColor.fromColor(color).hue, cyanHue),
        lessThan(35),
      );
    }
  });

  test('artwork foreground follows the background hue with safe contrast', () {
    const blueBackground = [
      Color(0xFFB9C9F5),
      Color(0xFFC7D4F2),
      Color(0xFFA6BAEB),
    ];
    const warmBackground = [
      Color(0xFFF0CAB4),
      Color(0xFFF4D8C4),
      Color(0xFFE6B593),
    ];
    final blue = ArtworkPagePalette.fromBackground(blueBackground);
    final warm = ArtworkPagePalette.fromBackground(warmBackground);
    final blueSample = _paletteSample(blueBackground);
    final warmSample = _paletteSample(warmBackground);

    expect(blue.useLightText, isFalse);
    expect(warm.useLightText, isFalse);
    expect(
      _hueDistance(
        HSLColor.fromColor(blue.primaryText).hue,
        HSLColor.fromColor(blueSample).hue,
      ),
      lessThan(1.5),
    );
    expect(
      _hueDistance(
        HSLColor.fromColor(warm.primaryText).hue,
        HSLColor.fromColor(warmSample).hue,
      ),
      lessThan(1.5),
    );
    expect(
      _hueDistance(
        HSLColor.fromColor(blue.primaryText).hue,
        HSLColor.fromColor(warm.primaryText).hue,
      ),
      greaterThan(60),
    );
    expect(_contrastRatio(blue.primaryText, blueSample), greaterThan(4.5));
    expect(_contrastRatio(warm.primaryText, warmSample), greaterThan(4.5));
  });

  testWidgets('now-playing background uses album colors and moves', (
    tester,
  ) async {
    final album = Album(
      id: 'fallback-album',
      title: 'Fallback Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFF176B58), Color(0xFF102A25)],
      tracks: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: AnimatedArtworkBackground(
            album: album,
            position: Duration.zero,
            isPlaying: true,
          ),
        ),
      ),
    );

    // Motion starts on a post-frame callback so the first open layout can settle.
    await tester.pump();
    final initial = _backgroundPainter(tester);
    final initialPhase = initial.phase;
    expect(initial.colors, hasLength(3));
    // Playing boosts motion so the breath is readable (~1.15× skin base).
    expect(
      initial.motionStrength,
      closeTo(SoundSkinEffects.standard.motionStrength * 1.15, 0.01),
    );
    expect(
      initial.primaryGlowOpacity,
      SoundSkinEffects.standard.primaryGlowOpacity,
    );

    await tester.pump(const Duration(seconds: 1));
    final moved = _backgroundPainter(tester);
    expect(moved.phase, isNot(initialPhase));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('artwork background can stay dark in a light app theme', (
    tester,
  ) async {
    final album = Album(
      id: 'forced-dark-album',
      title: 'Forced Dark Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFFE8D7A4), Color(0xFFA7DDE2)],
      tracks: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: AnimatedArtworkBackground(
            album: album,
            position: Duration.zero,
            isPlaying: false,
            paletteBrightness: Brightness.dark,
          ),
        ),
      ),
    );

    final painter = _backgroundPainter(tester);
    expect(painter.brightness, Brightness.dark);
    final backgroundLightness = painter.colors
        .map((color) => HSLColor.fromColor(color).lightness)
        .toList();
    expect(
      backgroundLightness,
      everyElement(inInclusiveRange(0.135, 0.27)),
    );
    final palette = ArtworkPagePalette.fromBackground(painter.colors);
    final sample = _paletteSample(painter.colors);
    final primaryHsl = HSLColor.fromColor(palette.primaryText);
    final secondaryHsl = HSLColor.fromColor(palette.secondaryText);
    final mutedHsl = HSLColor.fromColor(palette.mutedText);
    expect(palette.useLightText, isTrue);
    expect(
      _hueDistance(
        primaryHsl.hue,
        HSLColor.fromColor(sample).hue,
      ),
      lessThanOrEqualTo(15),
    );
    expect(secondaryHsl.saturation, greaterThan(primaryHsl.saturation));
    expect(mutedHsl.saturation, greaterThan(secondaryHsl.saturation));
    expect(primaryHsl.lightness, greaterThan(secondaryHsl.lightness));
    expect(secondaryHsl.lightness, greaterThan(mutedHsl.lightness));
    expect(_contrastRatio(palette.primaryText, sample), greaterThan(4.5));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('static artwork background is a top-to-bottom gradient', (
    tester,
  ) async {
    final album = Album(
      id: 'static-gradient-album',
      title: 'Static Gradient Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFFB85C4D), Color(0xFF437C78)],
      tracks: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: AnimatedArtworkBackground(
            album: album,
            position: Duration.zero,
            isPlaying: true,
            paletteBrightness: Brightness.dark,
            staticVerticalGradient: true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('now-playing-background-base')),
      findsNothing,
    );
    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('now-playing-background-static')),
    );
    final decoration = box.decoration as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(
      gradient.colors.first.computeLuminance(),
      greaterThan(gradient.colors.last.computeLuminance()),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('artwork background consumes skin material and motion tokens', (
    tester,
  ) async {
    final album = Album(
      id: 'skin-effects-album',
      title: 'Skin Effects Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFF58736E), Color(0xFF26312F)],
      tracks: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.forSkin(SoundSkins.pure),
        home: Scaffold(
          body: AnimatedArtworkBackground(
            album: album,
            position: Duration.zero,
            isPlaying: true,
          ),
        ),
      ),
    );

    final painter = _backgroundPainter(tester);
    // Quiet skins are floored so breath remains visible on ProMotion displays.
    expect(painter.motionStrength, greaterThan(SoundSkins.pure.effects.motionStrength));
    expect(
      painter.primaryGlowOpacity,
      SoundSkins.pure.effects.primaryGlowOpacity,
    );
    expect(painter.lightVeilOpacity, SoundSkins.pure.effects.lightVeilOpacity);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mini-player warmup caches a bounded artwork palette', (
    tester,
  ) async {
    final album = Album(
      id: 'prewarmed-album',
      title: 'Prewarmed Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFF1B8F78), Color(0xFF102A25)],
      tracks: const [],
      artworkUri: artwork.uri.toString(),
    );

    await tester.runAsync(
      () => AnimatedArtworkBackground.prewarm(
        album: album,
        brightness: Brightness.light,
      ),
    );

    expect(artworkPaletteCacheExtent, 256);
    expect(
      AnimatedArtworkBackground.debugHasPrewarmed(
        album: album,
        brightness: Brightness.light,
      ),
      isTrue,
    );
  });

  testWidgets('track changes blend from the current background palette', (
    tester,
  ) async {
    final firstAlbum = Album(
      id: 'first-transition-album',
      title: 'First Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFF8B4D32), Color(0xFF3D2018)],
      tracks: const [],
    );
    final secondAlbum = Album(
      id: 'second-transition-album',
      title: 'Second Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFF285E89), Color(0xFF162D4A)],
      tracks: const [],
    );

    Widget player(Album album) => MaterialApp(
      theme: SoundTheme.light,
      home: Scaffold(
        body: AnimatedArtworkBackground(
          album: album,
          position: Duration.zero,
          isPlaying: false,
        ),
      ),
    );

    await tester.pumpWidget(player(firstAlbum));
    final initial = _backgroundPainter(tester).colors;

    await tester.pumpWidget(player(secondAlbum));
    await tester.pump();
    expect(_backgroundPainter(tester).colors, orderedEquals(initial));

    await tester.pump(const Duration(milliseconds: 210));
    final midway = _backgroundPainter(tester).colors;
    final target = artworkFallbackGradientColors(secondAlbum, Brightness.light);
    expect(midway, isNot(orderedEquals(initial)));
    expect(midway, isNot(orderedEquals(target)));

    await tester.pump(const Duration(milliseconds: 240));
    expect(_backgroundPainter(tester).colors, orderedEquals(target));
  });

  testWidgets('now-playing background honors reduced motion', (tester) async {
    final album = Album(
      id: 'fallback-album',
      title: 'Fallback Album',
      artist: 'Artist',
      source: SourceKind.local,
      palette: const [Color(0xFF456A74), Color(0xFF1F3035)],
      tracks: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AnimatedArtworkBackground(
              album: album,
              position: Duration.zero,
              isPlaying: true,
            ),
          ),
        ),
      ),
    );

    final initial = _backgroundPainter(tester);
    await tester.pump(const Duration(seconds: 1));
    final unchanged = _backgroundPainter(tester);
    expect(unchanged.phase, initial.phase);
    expect(tester.takeException(), isNull);
  });
}

ArtworkGradientPainter _backgroundPainter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('now-playing-background-base')),
  );
  return paint.painter! as ArtworkGradientPainter;
}

Color _paletteSample(List<Color> colors) {
  return Color.lerp(
    Color.lerp(colors.first, colors[1], 0.58),
    colors.last,
    0.24,
  )!;
}

double _contrastRatio(Color foreground, Color background) {
  final composited = Color.alphaBlend(foreground, background);
  final lighter = math.max(
    composited.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    composited.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

double _hueDistance(double first, double second) {
  final direct = (first - second).abs();
  return direct > 180 ? 360 - direct : direct;
}
