import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';
import 'package:sound_player/presentation/screens/webdav_folder_picker.dart';
import 'package:sound_player/presentation/widgets/sound_components.dart';
import 'package:sound_player/sources/source_provider.dart';
import 'package:sound_player/sources/webdav/webdav_credentials.dart';
import 'package:sound_player/sources/webdav/webdav_discovery.dart';
import 'package:sound_player/sources/webdav/webdav_source_directory_browser.dart';

void main() {
  const credentials = WebDavCredentials(username: 'listener', password: 'pw');

  test(
    'maps WebDAV discovery into protocol-neutral directory entries',
    () async {
      String? requestedUrl;
      final browser = WebDavSourceDirectoryBrowser(
        baseUrl: 'https://dav.example.com/dav/music/',
        credentials: credentials,
        probe: (url, sentCredentials) async {
          requestedUrl = url;
          expect(sentCredentials.username, 'listener');
          return const WebDavDiscoveryResult(
            status: DiscoveryStatus.success,
            files: [
              WebDavFileEntry(
                href: '/dav/music/',
                displayName: 'music',
                isCollection: true,
                contentLength: 0,
              ),
              WebDavFileEntry(
                href: '/dav/music/Album/',
                displayName: 'Album',
                isCollection: true,
                contentLength: 0,
              ),
              WebDavFileEntry(
                href: '/dav/music/song.flac',
                displayName: 'Friendly song title',
                isCollection: false,
                contentLength: 42,
              ),
              WebDavFileEntry(
                href: '/dav/music/notes.txt',
                displayName: 'notes.txt',
                isCollection: false,
                contentLength: 12,
              ),
              WebDavFileEntry(
                href: 'https://other.example.com/music/',
                displayName: 'foreign',
                isCollection: true,
                contentLength: 0,
              ),
            ],
          );
        },
      );

      final entries = await browser.browse(browser.rootId);

      expect(requestedUrl, 'https://dav.example.com/dav/music/');
      expect(
        entries
            .map((entry) => (entry.id, entry.displayName, entry.isDirectory))
            .toList(),
        [
          ('/dav/music/Album/', 'Album', true),
          ('/dav/music/song.flac', 'Friendly song title', false),
        ],
      );
    },
  );

  test('exposes browse failures without leaking discovery types to the UI', () {
    final browser = WebDavSourceDirectoryBrowser(
      baseUrl: 'https://dav.example.com/music/',
      credentials: credentials,
      probe: (_, _) async => WebDavDiscoveryResult.error(
        WebDavConnectionError.authenticationFailed,
        message: '认证失败',
      ),
    );

    expect(
      () => browser.browse(browser.rootId),
      throwsA(
        isA<SourceBrowseException>().having(
          (error) => error.message,
          'message',
          '认证失败',
        ),
      ),
    );
  });

  testWidgets('folder picker browses a protocol-neutral directory tree', (
    tester,
  ) async {
    final browser = _FakeDirectoryBrowser();
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDialog<List<String>>(
                context: context,
                builder: (_) => WebDavFolderPicker(browser: browser),
              ),
              child: const Text('打开目录'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开目录'));
    await tester.pumpAndSettle();
    expect(find.text('Album'), findsOneWidget);
    expect(find.text('song.flac'), findsOneWidget);

    await tester.tap(find.byTooltip('选择此目录'));
    await tester.pump();
    expect(find.text('选择 1 个目录'), findsOneWidget);

    await tester.tap(find.text('Album'));
    await tester.pumpAndSettle();
    expect(find.text('disc-1'), findsOneWidget);
    expect(browser.requestedIds, ['/music/', '/music/Album/']);
  });

  testWidgets('compact folder picker uses a bottom sheet without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final browser = _FakeDirectoryBrowser();
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showSoundBottomSheet<List<String>>(
                context,
                builder: (_) =>
                    WebDavFolderPicker(browser: browser, bottomSheet: true),
              ),
              child: const Text('打开目录'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开目录'));
    await tester.pumpAndSettle();

    expect(find.byType(SoundBottomSheet), findsOneWidget);
    expect(find.byType(SoundDialog), findsNothing);
    expect(find.text('选择目录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeDirectoryBrowser implements SourceDirectoryBrowser {
  final List<String> requestedIds = [];

  @override
  String get rootId => '/music/';

  @override
  Future<List<SourceDirectoryEntry>> browse(String directoryId) async {
    requestedIds.add(directoryId);
    if (directoryId == rootId) {
      return const [
        SourceDirectoryEntry(
          id: '/music/Album/',
          displayName: 'Album',
          isDirectory: true,
        ),
        SourceDirectoryEntry(
          id: '/music/song.flac',
          displayName: 'song.flac',
          isDirectory: false,
        ),
      ];
    }
    return const [
      SourceDirectoryEntry(
        id: '/music/Album/disc-1/',
        displayName: 'disc-1',
        isDirectory: true,
      ),
    ];
  }
}
