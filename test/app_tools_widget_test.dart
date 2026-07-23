import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/simulated_playback_engine.dart';
import 'package:kaiting/presentation/app_shell.dart';
import 'package:kaiting/presentation/widgets/sound_components.dart';

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
    await _pumpUntilFound(tester, find.text('欢迎使用 开听'));

    expect(find.text('欢迎使用 开听'), findsOneWidget);
    expect(find.textContaining('本机文件夹或 WebDAV 目录'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SoundDialog),
        matching: find.byType(SoundGlassSurface),
      ),
      findsOneWidget,
    );
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
    final failureOverlay = AppFailureOverlayController();
    addTearDown(failureOverlay.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        builder: (context, child) => AppFailureOverlayHost(
          controller: failureOverlay,
          child: child ?? const SizedBox.shrink(),
        ),
        home: AppShell(
          playback: playback,
          libraryRepository: repository,
          failureOverlayController: failureOverlay,
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('global-failure-banner')),
    );

    expect(find.text('需要重新登录音乐来源'), findsOneWidget);
    expect(find.text('更新来源'), findsOneWidget);
    final titleFinder = find.text('需要重新登录音乐来源');
    final title = tester.widget<Text>(titleFinder);
    final titleStyle = DefaultTextStyle.of(
      tester.element(titleFinder),
    ).style.merge(title.style);
    expect(titleStyle.fontSize, lessThanOrEqualTo(18));
    expect(titleStyle.decoration, isNot(TextDecoration.underline));
    final failureSurface = tester.widget<SoundGlassSurface>(
      find.byKey(const ValueKey('global-failure-banner')),
    );
    expect(failureSurface.borderColor, Colors.transparent);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('global-failure-banner')))
          .height,
      lessThan(120),
    );

    final dialogFuture = showDialog<void>(
      context: tester.element(find.byType(AppShell)),
      builder: (context) => const AlertDialog(
        key: ValueKey('blocking-form-dialog'),
        title: Text('弹出表单'),
        content: Text('正在编辑连接信息'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('blocking-form-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('global-failure-action')));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('source-settings')),
    );
    expect(
      find.byKey(const ValueKey('global-failure-banner')),
      findsNothing,
      reason: '根级错误提示的按钮应当位于弹窗遮罩之上并可点击。',
    );

    Navigator.of(
      tester.element(find.byKey(const ValueKey('blocking-form-dialog'))),
    ).pop();
    await dialogFuture;

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
