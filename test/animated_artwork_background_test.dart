import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/domain/library_models.dart';
import 'package:sound_player/presentation/widgets/animated_artwork_background.dart';

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

    final initial = _backgroundPainter(tester);
    final initialPhase = initial.phase;
    expect(initial.colors, hasLength(3));
    expect(initial.motionStrength, SoundSkinEffects.standard.motionStrength);
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
    expect(painter.motionStrength, SoundSkins.pure.effects.motionStrength);
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

double _hueDistance(double first, double second) {
  final direct = (first - second).abs();
  return direct > 180 ? 360 - direct : direct;
}
