import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/library/scanning/local_library_scanner.dart';
import 'package:kaiting/library/scanning/unsupported_local_media_catalog.dart';
import 'package:kaiting/presentation/screens/source_settings_screen.dart';
import 'package:kaiting/sources/local/local_source_service.dart';
import 'package:kaiting/sources/local/unsupported_local_directory_access.dart';
import 'package:kaiting/sources/source_provider.dart';

void main() {
  test('formats persisted source URIs as readable locations', () {
    expect(
      formatSourceLocation(
        'file:///Users/test/%E9%9F%B3%E4%B9%90/%E5%91%A8%E6%9D%B0%E4%BC%A6',
      ),
      '/Users/test/音乐/周杰伦',
    );
    expect(
      formatSourceLocation(
        'https://dav.example.com/Music/%E5%91%A8%E6%9D%B0%E4%BC%A6/',
      ),
      'dav.example.com/Music/周杰伦',
    );
    expect(
      formatSourceLocation(
        'content://com.android.externalstorage.documents/'
        'tree/primary%3AMusic%2F%E5%91%A8%E6%9D%B0%E4%BC%A6',
      ),
      '内部存储 / Music/周杰伦',
    );
    expect(
      formatSourceLocation('/dav/Music/%E5%91%A8%E6%9D%B0%E4%BC%A6/'),
      '/dav/Music/周杰伦',
    );
  });

  testWidgets('remote directories render inside their owning connection tree', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = LibraryDatabase(NativeDatabase.memory());
    final repository = DriftLibraryRepository(database);
    final localSources = LocalSourceService(
      repository: repository,
      directoryAccess: const UnsupportedLocalDirectoryAccess(),
    );
    final scanner = LocalLibraryScanner(
      repository: repository,
      catalog: const UnsupportedLocalMediaCatalog(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: SourceSettingsScreen(
            localSources: localSources,
            scanner: scanner,
            remoteAdapters: [
              RemoteSourceSettingsAdapter(
                definition: const SourceProviderDefinition(
                  type: LibrarySourceType.webDav,
                  displayName: 'WebDAV',
                  addActionLabel: '添加 WebDAV',
                  sectionDescription: '服务器连接和目录',
                  capabilities: {
                    SourceProviderCapability.connectionManagement,
                    SourceProviderCapability.directoryBrowsing,
                    SourceProviderCapability.scanning,
                  },
                ),
                connections: const _Connections(),
                scanner: const _Scanner(),
                openEditor: (_, _) async {},
                scanDirectories: (_, _) async =>
                    const SourceScanSummary(indexedTracks: 0),
                color: SoundColors.webDav,
                connectionIcon: Icons.cloud_outlined,
                catalogIcon: Icons.folder_outlined,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本机'), findsOneWidget);
    expect(find.text('远程连接'), findsOneWidget);
    expect(find.text('添加文件夹'), findsOneWidget);
    expect(find.text('添加连接'), findsOneWidget);
    expect(find.textContaining('选择 开听 要索引'), findsNothing);

    final tree = find.byKey(const ValueKey('source-connection-tree-nas'));
    expect(tree, findsOneWidget);
    expect(
      find.descendant(
        of: tree,
        matching: find.byKey(const ValueKey('source-directory-music')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await repository.close();
  });
}

class _Connections implements SourceConnectionProvider {
  const _Connections();

  @override
  LibrarySourceType get type => LibrarySourceType.webDav;

  @override
  Stream<List<SourceManagedResource>> watchResources() => Stream.value(const [
    SourceManagedResource(
      id: 'nas',
      type: LibrarySourceType.webDav,
      kind: SourceManagedResourceKind.connection,
      displayName: '家庭 NAS',
      location: 'https://nas.local/dav/',
      status: SourceManagedStatus.available,
    ),
    SourceManagedResource(
      id: 'music',
      type: LibrarySourceType.webDav,
      kind: SourceManagedResourceKind.catalog,
      displayName: '音乐',
      location: '/dav/music/',
      status: SourceManagedStatus.available,
      parentConnectionId: 'nas',
    ),
  ]);

  @override
  Future<SourceDirectoryBrowser> openBrowser(String connectionId) {
    throw UnimplementedError();
  }

  @override
  Future<SourceManagedResource> probe(String connectionId) {
    throw UnimplementedError();
  }

  @override
  Future<void> remove(String resourceId) async {}
}

class _Scanner implements SourceScanProvider {
  const _Scanner();

  @override
  LibrarySourceType get type => LibrarySourceType.webDav;

  @override
  bool cancel(String sourceId) => false;

  @override
  bool isScanning(String sourceId) => false;

  @override
  Future<SourceScanSummary> rescan(String sourceId) async =>
      const SourceScanSummary(indexedTracks: 0);
}
