import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/sources/local/file_system_local_directory_access.dart';
import 'package:kaiting/sources/local/local_directory_access.dart';
import 'package:kaiting/sources/local/platform_channel_local_directory_access.dart';

void main() {
  test('platform grant preserves a refreshed security bookmark', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final access = PlatformChannelLocalDirectoryAccess(
      invoker: (method, arguments) async {
        calls.add((method, arguments));
        return <Object?, Object?>{
          'rootUri': 'file:///Music/',
          'displayName': 'Music',
          'status': 'available',
          'permissionToken': Uint8List.fromList([4, 2]),
          'isStale': true,
        };
      },
    );

    final grant = await access.restoreDirectory(
      rootUri: 'file:///OldMusic/',
      permissionToken: Uint8List.fromList([1]),
    );

    expect(grant.rootUri, 'file:///Music/');
    expect(grant.displayName, 'Music');
    expect(grant.status, LocalDirectoryAccessStatus.available);
    expect(grant.permissionToken, [4, 2]);
    expect(grant.isStale, isTrue);
    expect(calls.single.$1, 'restoreDirectory');
    expect(calls.single.$2['rootUri'], 'file:///OldMusic/');
  });

  test('platform picker returns null when the user cancels', () async {
    final access = PlatformChannelLocalDirectoryAccess(
      invoker: (method, arguments) async => null,
    );

    expect(await access.pickDirectory(), isNull);
  });

  test('platform result rejects malformed grants', () async {
    final access = PlatformChannelLocalDirectoryAccess(
      invoker: (method, arguments) async => <Object?, Object?>{
        'rootUri': 'content://music',
      },
    );

    await expectLater(access.pickDirectory(), throwsFormatException);
  });

  test(
    'filesystem restore distinguishes existing and missing folders',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'sound-directory-access-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final access = FileSystemLocalDirectoryAccess();

      final available = await access.restoreDirectory(
        rootUri: temporaryDirectory.uri.toString(),
      );
      final unavailable = await access.restoreDirectory(
        rootUri: temporaryDirectory.uri.resolve('missing/').toString(),
      );

      expect(available.status, LocalDirectoryAccessStatus.available);
      expect(
        available.displayName,
        temporaryDirectory.uri.pathSegments.lastWhere(
          (segment) => segment.isNotEmpty,
        ),
      );
      expect(unavailable.status, LocalDirectoryAccessStatus.unavailable);
    },
  );
}
