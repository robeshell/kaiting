import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/library/library_records.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/playback/playback_controller.dart';
import 'package:sound_player/playback/simulated_playback_engine.dart';
import 'package:sound_player/presentation/app_shell.dart';

void main() {
  testWidgets('first run guides an empty library into source settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    addTearDown(repository.close);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: AppShell(
          playback: playback,
          libraryRepository: repository,
          enableFirstRunGuide: true,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('欢迎使用 Reverie'));

    expect(find.text('欢迎使用 Reverie'), findsOneWidget);
    expect(find.text('本地文件夹'), findsOneWidget);
    expect(find.text('WebDAV'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('first-run-manage-sources')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('source-settings')),
    );
    expect(find.byKey(const ValueKey('source-settings')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    playback.dispose();
    engine.dispose();
  });

  testWidgets('settings exposes sleep timer and diagnostics', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    addTearDown(repository.close);
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('settings-sleep-timer-row')),
    );

    expect(
      find.byKey(const ValueKey('settings-sleep-timer-row')),
      findsOneWidget,
    );
    for (final group in const ['playback', 'library', 'operation', 'about']) {
      expect(find.byKey(ValueKey('settings-group-$group')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('settings-sleep-timer-row')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sleep-timer-15')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sleep-timer-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-group-operation')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-diagnostics-row')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('diagnostics-settings')),
    );
    expect(find.byKey(const ValueKey('diagnostics-settings')), findsOneWidget);
    expect(find.text('当前没有已记录的问题'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    playback.dispose();
    engine.dispose();
  });

  testWidgets('source failures present a safe recovery action', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _repository();
    addTearDown(repository.close);
    final now = DateTime.utc(2026, 7, 15);
    await repository.upsertSource(
      LibrarySourceRecord(
        id: 'webdav:unavailable',
        type: LibrarySourceType.webDav,
        displayName: 'Public WebDAV',
        rootUri: 'https://example.test/dav/',
        status: LibrarySourceStatus.permissionRequired,
        lastError: '认证失败（HTTP 401）',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final engine = SimulatedPlaybackEngine();
    final playback = SoundPlaybackController(engine: engine);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: AppShell(playback: playback, libraryRepository: repository),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('global-failure-banner')),
    );

    expect(find.text('需要重新登录音乐来源'), findsOneWidget);
    expect(find.text('更新来源'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('global-failure-action')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('source-settings')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    playback.dispose();
    engine.dispose();
  });
}

DriftLibraryRepository _repository() {
  return DriftLibraryRepository(LibraryDatabase(NativeDatabase.memory()));
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}
