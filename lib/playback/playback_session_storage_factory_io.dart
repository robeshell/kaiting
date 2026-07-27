import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'playback_session_storage_contract.dart';

const _sessionFileName = 'playback_session.json';
const _checkpointFileName = 'playback_session_checkpoint.json';

Future<PlaybackSessionStorage> createDefaultPlaybackSessionStorage() async {
  final support = await getApplicationSupportDirectory();
  final documents = await getApplicationDocumentsDirectory();
  await _migrateLegacySessionFiles(
    documentsDir: documents,
    supportDir: support,
  );
  await support.create(recursive: true);
  return FilePlaybackSessionStorage(support.path);
}

/// Moves session JSON from Documents → Application Support (macOS/Windows).
Future<void> _migrateLegacySessionFiles({
  required Directory documentsDir,
  required Directory supportDir,
}) async {
  if (p.equals(documentsDir.path, supportDir.path)) return;
  await supportDir.create(recursive: true);
  for (final name in [_sessionFileName, _checkpointFileName]) {
    final source = File(p.join(documentsDir.path, name));
    final destination = File(p.join(supportDir.path, name));
    if (!await source.exists()) continue;
    if (await destination.exists()) {
      try {
        await source.delete();
      } on FileSystemException {
        // ignore
      }
      continue;
    }
    try {
      await source.rename(destination.path);
    } on FileSystemException {
      await source.copy(destination.path);
      try {
        await source.delete();
      } on FileSystemException {
        // ignore
      }
    }
  }
}

PlaybackSessionStorage createPlaybackSessionStorageAt(String directory) {
  return FilePlaybackSessionStorage(directory);
}

class FilePlaybackSessionStorage implements PlaybackSessionStorage {
  FilePlaybackSessionStorage(this.directory);

  final String directory;

  File get _file => File(p.join(directory, _sessionFileName));
  File get _checkpointFile => File(p.join(directory, _checkpointFileName));

  @override
  Future<String?> read() async {
    final file = _file;
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<String?> readCheckpoint() async {
    final file = _checkpointFile;
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String value) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(value, flush: true);
  }

  @override
  Future<void> writeCheckpoint(String value) async {
    final file = _checkpointFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(value, flush: true);
  }

  @override
  Future<void> clear() async {
    final file = _file;
    if (await file.exists()) await file.delete();
    final checkpointFile = _checkpointFile;
    if (await checkpointFile.exists()) await checkpointFile.delete();
  }
}
