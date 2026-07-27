import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/library/persistence/library_database_location_io.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late Directory documents;
  late Directory support;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('kaiting-db-loc-');
    documents = Directory(p.join(tempRoot.path, 'Documents'));
    support = Directory(p.join(tempRoot.path, 'Application Support'));
    await documents.create(recursive: true);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('moves sqlite and WAL sidecars from Documents to Support', () async {
    await File(
      p.join(documents.path, 'sound_library.sqlite'),
    ).writeAsString('main-db');
    await File(
      p.join(documents.path, 'sound_library.sqlite-wal'),
    ).writeAsString('wal');
    await File(
      p.join(documents.path, 'sound_library.sqlite-shm'),
    ).writeAsString('shm');

    await migrateLegacyLibraryDatabaseFiles(
      documentsDir: documents,
      supportDir: support,
    );

    expect(
      await File(p.join(support.path, 'sound_library.sqlite')).readAsString(),
      'main-db',
    );
    expect(
      await File(
        p.join(support.path, 'sound_library.sqlite-wal'),
      ).readAsString(),
      'wal',
    );
    expect(
      await File(
        p.join(support.path, 'sound_library.sqlite-shm'),
      ).readAsString(),
      'shm',
    );
    expect(
      await File(p.join(documents.path, 'sound_library.sqlite')).exists(),
      isFalse,
    );
    expect(
      await File(p.join(documents.path, 'sound_library.sqlite-wal')).exists(),
      isFalse,
    );
  });

  test('keeps Support database when both locations exist', () async {
    await File(
      p.join(documents.path, 'sound_library.sqlite'),
    ).writeAsString('legacy');
    await support.create(recursive: true);
    await File(
      p.join(support.path, 'sound_library.sqlite'),
    ).writeAsString('current');

    await migrateLegacyLibraryDatabaseFiles(
      documentsDir: documents,
      supportDir: support,
    );

    expect(
      await File(p.join(support.path, 'sound_library.sqlite')).readAsString(),
      'current',
    );
    expect(
      await File(p.join(documents.path, 'sound_library.sqlite')).exists(),
      isFalse,
    );
  });

  test('no-ops when Documents and Support are the same path', () async {
    await File(
      p.join(documents.path, 'sound_library.sqlite'),
    ).writeAsString('same');

    await migrateLegacyLibraryDatabaseFiles(
      documentsDir: documents,
      supportDir: documents,
    );

    expect(
      await File(p.join(documents.path, 'sound_library.sqlite')).readAsString(),
      'same',
    );
  });

  test('is idempotent when Documents has no library files', () async {
    await migrateLegacyLibraryDatabaseFiles(
      documentsDir: documents,
      supportDir: support,
    );
    await migrateLegacyLibraryDatabaseFiles(
      documentsDir: documents,
      supportDir: support,
    );

    expect(await support.exists(), isTrue);
    expect(
      await File(p.join(support.path, 'sound_library.sqlite')).exists(),
      isFalse,
    );
  });
}
