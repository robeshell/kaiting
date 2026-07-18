import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/library/persistence/drift_library_repository.dart';
import 'package:sound_player/library/persistence/library_database.dart';
import 'package:sound_player/presentation/screens/webdav_add_dialog.dart';
import 'package:sound_player/presentation/widgets/sound_components.dart';
import 'package:sound_player/sources/webdav/webdav_connection_service.dart';
import 'package:sound_player/sources/webdav/webdav_credentials.dart';
import 'package:sound_player/sources/webdav/webdav_discovery.dart';

void main() {
  late DriftLibraryRepository repository;
  late MemoryWebDavCredentialStore credentialStore;
  late WebDavConnectionService service;

  setUp(() {
    repository = DriftLibraryRepository(
      LibraryDatabase(NativeDatabase.memory()),
    );
    credentialStore = MemoryWebDavCredentialStore();
    service = WebDavConnectionService(
      repository: repository,
      discovery: _SuccessfulDiscoveryService(),
      credentialStore: credentialStore,
    );
  });

  tearDown(() => repository.close());

  testWidgets('add dialog rejects non-HTTP WebDAV URLs', (tester) async {
    await tester.pumpWidget(_DialogHost(service: service));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '服务器地址'),
      'ftp://nas.local/music',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '显示名称'), 'NAS');
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pump();

    expect(find.text('WebDAV 地址必须是有效的 HTTP(S) URL'), findsOneWidget);
    expect(await service.listConnections(), isEmpty);
  });

  testWidgets('edit dialog keeps the stored password when left blank', (
    tester,
  ) async {
    await service.addConnection(
      url: 'https://nas.local/music',
      displayName: 'Old NAS',
      credentials: const WebDavCredentials(
        username: 'alice',
        password: 'keep-me',
      ),
    );
    final connection = (await service.listConnections()).single;
    await tester.pumpWidget(
      _DialogHost(service: service, connection: connection),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('编辑 WebDAV 连接'), findsOneWidget);
    final username = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, '用户名'),
    );
    expect(username.controller?.text, 'alice');
    await tester.enterText(
      find.widgetWithText(TextFormField, '显示名称'),
      'Renamed NAS',
    );
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    expect(find.text('编辑 WebDAV 连接'), findsNothing);
    final updated = (await service.listConnections()).single;
    expect(updated.displayName, 'Renamed NAS');
    final stored = await credentialStore.read(updated.id);
    expect(stored?.password, 'keep-me');
  });

  testWidgets('compact connection form uses a bottom sheet without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showSoundBottomSheet<WebDavDiscoveryResult>(
                context,
                builder: (_) =>
                    WebDavAddDialog(service: service, bottomSheet: true),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(SoundBottomSheet), findsOneWidget);
    expect(find.byType(SoundDialog), findsNothing);
    expect(find.text('添加 WebDAV 连接'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DialogHost extends StatelessWidget {
  const _DialogHost({required this.service, this.connection});

  final WebDavConnectionService service;
  final WebDavConnectionRecord? connection;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) =>
                  WebDavAddDialog(service: service, connection: connection),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

class _SuccessfulDiscoveryService extends WebDavDiscoveryService {
  @override
  Future<WebDavDiscoveryResult> probe(
    String url, {
    required WebDavCredentials credentials,
  }) async {
    return const WebDavDiscoveryResult(status: DiscoveryStatus.success);
  }
}
