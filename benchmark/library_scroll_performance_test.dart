import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/presentation/controllers/library_catalog_controller.dart';
import 'package:sound_player/presentation/screens/library_screen.dart';
import 'package:sound_player/presentation/widgets/album_art.dart';

import 'support/library_benchmark_fixture.dart';

void main() {
  testWidgets(
    'virtualizes a 1000 album and 10000 track library',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fixture = LibraryBenchmarkFixture.generate(
        10000,
        includeArtwork: false,
      );
      final repository = BenchmarkLibraryRepository(fixture);
      final catalog = LibraryCatalogController(repository: repository);
      await catalog.refresh();

      final initialStopwatch = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          theme: SoundTheme.dark,
          home: Scaffold(
            body: LibraryScreen(
              catalog: catalog,
              onOpenAlbum: (_) {},
              onManageSources: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      initialStopwatch.stop();

      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final initialAlbumArts = find.byType(AlbumArt).evaluate().length;
      expect(initialAlbumArts, lessThan(100));

      // The track sliver cannot estimate its full length before it is reached.
      // Advancing to the current end lets each sliver publish its final extent
      // without building all of its children.
      for (var attempt = 0; attempt < 4; attempt++) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();
      }
      expect(find.text('Song 09999'), findsOneWidget);
      final totalExtent = scrollable.position.maxScrollExtent;

      scrollable.position.jumpTo(0);
      await tester.pump();
      var maxLiveAlbumArts = 0;
      const sampledFrames = 40;
      final sweepStopwatch = Stopwatch()..start();
      for (var frame = 1; frame <= sampledFrames; frame++) {
        scrollable.position.jumpTo(totalExtent * frame / sampledFrames);
        await tester.pump(const Duration(milliseconds: 16));
        final liveAlbumArts = find.byType(AlbumArt).evaluate().length;
        if (liveAlbumArts > maxLiveAlbumArts) {
          maxLiveAlbumArts = liveAlbumArts;
        }
      }
      sweepStopwatch.stop();

      final metrics = {
        'tracks': fixture.tracks.length,
        'albums': fixture.albums.length,
        'viewport': '1440x900',
        'initialPumpMs': _milliseconds(initialStopwatch.elapsedMicroseconds),
        'sampledFrames': sampledFrames,
        'scrollSweepMs': _milliseconds(sweepStopwatch.elapsedMicroseconds),
        'initialLiveAlbumArts': initialAlbumArts,
        'maxLiveAlbumArts': maxLiveAlbumArts,
        'scrollExtent': double.parse(totalExtent.toStringAsFixed(1)),
        'processRssMiB': double.parse(
          (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(1),
        ),
      };
      stdout.writeln('SOUND_SCROLL_PERF ${jsonEncode(metrics)}');

      expect(maxLiveAlbumArts, lessThan(100));
      expect(initialStopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(sweepStopwatch.elapsed, lessThan(const Duration(seconds: 5)));

      await tester.pumpWidget(const SizedBox.shrink());
      catalog.dispose();
      await tester.pump();
      await repository.close();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

double _milliseconds(int microseconds) {
  return double.parse((microseconds / 1000).toStringAsFixed(2));
}
