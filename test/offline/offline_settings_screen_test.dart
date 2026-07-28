import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/offline/offline_media_provider.dart';
import 'package:kaiting/presentation/controllers/offline_download_controller.dart';
import 'package:kaiting/presentation/screens/settings_screen.dart';

void main() {
  testWidgets(
    'download center cancels, retries, and removes individual items',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _FakeDownloadsController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: SoundTheme.light,
          home: Scaffold(
            body: OfflineSettingsView(offline: controller, onBack: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('下载与离线内容'), findsOneWidget);
      expect(find.text('Downloading'), findsOneWidget);
      expect(find.text('Failed'), findsOneWidget);
      expect(find.text('Downloaded'), findsOneWidget);

      await tester.tap(
        find.byKey(
          ValueKey('offline-cancel-${_reference('download').storageKey}'),
        ),
      );
      await tester.pump();
      expect(controller.cancelledUrl, 'download');
      expect(find.text('Downloading'), findsNothing);

      await tester.tap(
        find.byKey(
          ValueKey('offline-retry-${_reference('failed').storageKey}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.retriedUrl, 'failed');

      await tester.tap(
        find.byKey(
          ValueKey('offline-dismiss-${_reference('failed').storageKey}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Failed'), findsNothing);

      await tester.tap(
        find.byKey(
          ValueKey('offline-remove-${_reference('downloaded').storageKey}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('移除离线下载？'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, '移除'));
      await tester.pumpAndSettle();
      expect(controller.removedUrl, 'downloaded');
      expect(find.text('Downloaded'), findsNothing);
    },
  );

  testWidgets('compact download center uses one action menu per media row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _FakeDownloadsController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Scaffold(
          body: OfflineSettingsView(offline: controller, onBack: () {}),
        ),
      ),
    );
    await tester.pump();

    final storageKey = _reference('downloaded').storageKey;
    await tester.ensureVisible(
      find.byKey(ValueKey('offline-item-$storageKey')),
    );
    await tester.pump();
    expect(
      tester.getSize(find.byKey(ValueKey('offline-item-$storageKey'))).height,
      64,
    );
    expect(find.byKey(ValueKey('offline-actions-$storageKey')), findsOneWidget);
    expect(find.byKey(ValueKey('offline-remove-$storageKey')), findsNothing);
  });
}

class _FakeDownloadsController extends OfflineDownloadController {
  _FakeDownloadsController() : super(providers: const []);

  String? cancelledUrl;
  String? retriedUrl;
  String? removedUrl;

  final List<OfflineDownloadItem> _items = [
    OfflineDownloadItem(
      reference: _reference('download'),
      providerLabel: 'WebDAV',
      title: 'Downloading',
      artist: 'Artist',
      albumTitle: 'Album',
      size: 1024,
      pinned: false,
      accessedAt: null,
      task: const OfflineDownloadTask(
        state: OfflineDownloadTaskState.downloading,
        progress: 0.5,
        receivedBytes: 1024,
        totalBytes: 2048,
      ),
      track: _downloadingTrack,
    ),
    OfflineDownloadItem(
      reference: _reference('failed'),
      providerLabel: 'WebDAV',
      title: 'Failed',
      artist: 'Artist',
      albumTitle: 'Album',
      size: 0,
      pinned: false,
      accessedAt: null,
      task: const OfflineDownloadTask(
        state: OfflineDownloadTaskState.failed,
        error: '连接超时',
      ),
      track: _failedTrack,
    ),
    OfflineDownloadItem(
      reference: _reference('downloaded'),
      providerLabel: 'WebDAV',
      title: 'Downloaded',
      artist: 'Artist',
      albumTitle: 'Album',
      size: 4096,
      pinned: true,
      accessedAt: DateTime.fromMillisecondsSinceEpoch(1),
      task: null,
      track: _downloadedTrack,
    ),
  ];

  @override
  List<OfflineDownloadItem> get offlineItems => List.unmodifiable(_items);

  @override
  OfflineStorageStats get stats => const OfflineStorageStats(
    totalBytes: 4096,
    pinnedBytes: 4096,
    transientBytes: 0,
    totalEntries: 1,
    pinnedEntries: 1,
  );

  @override
  bool cancelReference(OfflineMediaReference reference) {
    cancelledUrl = reference.resourceId;
    _items.removeWhere((item) => item.reference == reference);
    notifyListeners();
    return true;
  }

  @override
  Future<void> retry(OfflineMediaReference reference) async {
    retriedUrl = reference.resourceId;
  }

  @override
  Future<void> removeReference(OfflineMediaReference reference) async {
    removedUrl = reference.resourceId;
    _items.removeWhere((item) => item.reference == reference);
    notifyListeners();
  }
}

OfflineMediaReference _reference(String id) =>
    OfflineMediaReference(providerId: 'webdav', resourceId: id);

const _downloadingTrack = Track(
  id: 'download',
  title: 'Downloading',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 3),
  source: SourceKind.webDav,
  mediaUri: 'https://example.test/download.flac',
);

const _failedTrack = Track(
  id: 'failed',
  title: 'Failed',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 3),
  source: SourceKind.webDav,
  mediaUri: 'https://example.test/failed.flac',
);

const _downloadedTrack = Track(
  id: 'downloaded',
  title: 'Downloaded',
  artist: 'Artist',
  albumTitle: 'Album',
  duration: Duration(minutes: 3),
  source: SourceKind.webDav,
  mediaUri: 'https://example.test/downloaded.flac',
);
