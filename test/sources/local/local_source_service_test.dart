import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/library/persistence/drift_library_repository.dart';
import 'package:kaiting/library/persistence/library_database.dart';
import 'package:kaiting/sources/local/local_directory_access.dart';
import 'package:kaiting/sources/local/local_source_service.dart';

void main() {
  test(
    'persists, restores, refreshes, and releases a directory grant',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sound-local-source-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/library.sqlite');
      final pickedToken = Uint8List.fromList([1, 2, 3]);
      final refreshedToken = Uint8List.fromList([4, 5, 6]);
      final access = _FakeDirectoryAccess(
        picked: LocalDirectoryGrant(
          rootUri: 'file:///Music/',
          displayName: 'Music',
          status: LocalDirectoryAccessStatus.available,
          permissionToken: pickedToken,
        ),
        restored: LocalDirectoryGrant(
          rootUri: 'file:///MovedMusic/',
          displayName: 'Moved Music',
          status: LocalDirectoryAccessStatus.available,
          permissionToken: refreshedToken,
          isStale: true,
        ),
      );
      final now = DateTime.utc(2026, 7, 11, 12);

      var repository = _repository(file);
      var service = LocalSourceService(
        repository: repository,
        directoryAccess: access,
        clock: () => now,
      );
      final added = await service.addLocalFolder();
      expect(added, isNotNull);
      expect(added!.id, stableLocalSourceId('file:///Music/'));
      expect(added.permissionBookmark, [1, 2, 3]);
      await repository.close();

      repository = _repository(file);
      service = LocalSourceService(
        repository: repository,
        directoryAccess: access,
        clock: () => now.add(const Duration(minutes: 1)),
      );
      await service.restoreLocalFolders();

      final restored = await repository.getSource(added.id);
      expect(restored, isNotNull);
      expect(restored!.rootUri, 'file:///MovedMusic/');
      expect(restored.displayName, 'Moved Music');
      expect(restored.permissionBookmark, [4, 5, 6]);
      expect(restored.status, LibrarySourceStatus.available);
      expect(access.restoredRootUri, 'file:///Music/');
      expect(access.restoredToken, [1, 2, 3]);

      await service.removeLocalFolder(restored);
      expect(access.releasedRootUri, 'file:///MovedMusic/');
      expect(await repository.getSource(added.id), isNull);
      await repository.close();
    },
  );
}

DriftLibraryRepository _repository(File file) {
  return DriftLibraryRepository(LibraryDatabase(NativeDatabase(file)));
}

class _FakeDirectoryAccess implements LocalDirectoryAccess {
  _FakeDirectoryAccess({required this.picked, required this.restored});

  final LocalDirectoryGrant? picked;
  final LocalDirectoryGrant restored;
  String? restoredRootUri;
  Uint8List? restoredToken;
  String? releasedRootUri;

  @override
  Future<LocalDirectoryGrant?> pickDirectory() async => picked;

  @override
  Future<LocalDirectoryGrant> restoreDirectory({
    required String rootUri,
    Uint8List? permissionToken,
  }) async {
    restoredRootUri = rootUri;
    restoredToken = permissionToken;
    return restored;
  }

  @override
  Future<void> releaseDirectory(String rootUri) async {
    releasedRootUri = rootUri;
  }
}
