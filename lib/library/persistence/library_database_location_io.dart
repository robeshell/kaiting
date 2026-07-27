import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Drift file name without directory (`sound_library.sqlite`).
const libraryDatabaseFileName = 'sound_library.sqlite';

/// SQLite sidecar suffixes produced by WAL / rollback journal modes.
const _libraryDatabaseSidecars = <String>['-wal', '-shm', '-journal'];

/// Resolves the production library DB path under Application Support.
///
/// On macOS (sandboxed):
/// `~/Library/Containers/<id>/Data/Library/Application Support/.../sound_library.sqlite`
///
/// On Windows:
/// `%APPDATA%/<org>/<app>/sound_library.sqlite` (Roaming AppData via
/// `path_provider`), not the user "Documents" / “文档” folder.
///
/// One-shot migration: older installs wrote the DB under Documents; files are
/// moved here before the first open. If relocation fails, the Documents path
/// is kept so the library is not dropped.
Future<String> resolveLibraryDatabaseFilePath() async {
  final documents = await getApplicationDocumentsDirectory();
  final support = await getApplicationSupportDirectory();
  final supportDb = File(p.join(support.path, libraryDatabaseFileName));
  final documentsDb = File(p.join(documents.path, libraryDatabaseFileName));

  try {
    await migrateLegacyLibraryDatabaseFiles(
      documentsDir: documents,
      supportDir: support,
    );
  } on Object {
    // Best-effort; fall through to path selection below.
  }

  if (await supportDb.exists()) {
    return supportDb.path;
  }
  if (await documentsDb.exists()) {
    // Migration did not move the main file; keep serving the legacy location.
    return documentsDb.path;
  }

  await support.create(recursive: true);
  return supportDb.path;
}

/// Moves legacy Documents-based Drift files into [supportDir].
///
/// Safe to call repeatedly. If the support file already exists, leftover
/// Documents copies are deleted so the app does not keep two libraries.
///
/// Uses copy+delete when [File.rename] fails (cross-volume on some Windows
/// setups).
Future<void> migrateLegacyLibraryDatabaseFiles({
  required Directory documentsDir,
  required Directory supportDir,
  String fileName = libraryDatabaseFileName,
}) async {
  if (p.equals(documentsDir.path, supportDir.path)) return;

  await supportDir.create(recursive: true);

  final names = <String>[
    fileName,
    for (final suffix in _libraryDatabaseSidecars) '$fileName$suffix',
  ];

  for (final name in names) {
    final source = File(p.join(documentsDir.path, name));
    final destination = File(p.join(supportDir.path, name));
    await _relocateFilePreferringDestination(source, destination);
  }
}

Future<void> _relocateFilePreferringDestination(
  File source,
  File destination,
) async {
  if (!await source.exists()) return;

  if (await destination.exists()) {
    try {
      await source.delete();
    } on FileSystemException {
      // Best-effort cleanup; opening the support DB still succeeds.
    }
    return;
  }

  try {
    await source.rename(destination.path);
    return;
  } on FileSystemException {
    // Fall through to copy+delete (e.g. different volumes on Windows).
  }

  await source.copy(destination.path);
  try {
    await source.delete();
  } on FileSystemException {
    // Destination is authoritative; orphaned source is cleaned on next launch
    // via the "prefer destination" branch.
  }
}
