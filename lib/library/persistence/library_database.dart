import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'library_database.g.dart';

class LibrarySources extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get displayName => text()();
  TextColumn get rootUri => text()();
  BlobColumn get permissionBookmark => blob().nullable()();
  TextColumn get status => text()();
  IntColumn get scanRevision => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastScanStartedAt => dateTime().nullable()();
  DateTimeColumn get lastScanCompletedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {type, rootUri},
  ];
}

class LibraryArtists extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId =>
      text().references(LibrarySources, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get sortName => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, sortName},
  ];
}

class LibraryAlbums extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId =>
      text().references(LibrarySources, #id, onDelete: KeyAction.cascade)();
  TextColumn get artistId => text().nullable().references(
    LibraryArtists,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get title => text()();
  TextColumn get sortTitle => text()();
  TextColumn get albumArtist => text()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get artworkKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, albumArtist, sortTitle},
  ];
}

class LibraryTracks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceId =>
      text().references(LibrarySources, #id, onDelete: KeyAction.cascade)();
  TextColumn get albumId => text().nullable().references(
    LibraryAlbums,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get artistId => text().nullable().references(
    LibraryArtists,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get relativePath => text()();
  TextColumn get mediaUri => text()();
  TextColumn get title => text()();
  TextColumn get artistName => text()();
  TextColumn get albumTitle => text()();
  IntColumn get durationMs => integer()();
  IntColumn get trackNumber => integer().withDefault(const Constant(0))();
  IntColumn get discNumber => integer().withDefault(const Constant(0))();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get contentType => text().nullable()();
  IntColumn get fileSize => integer().nullable()();
  DateTimeColumn get modifiedAt => dateTime()();
  TextColumn get artworkKey => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {sourceId, relativePath},
  ];
}

class LibraryLyrics extends Table {
  TextColumn get trackId =>
      text().references(LibraryTracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get sequence => integer()();
  IntColumn get timestampMs => integer()();
  TextColumn get content => text().named('text')();

  @override
  Set<Column<Object>> get primaryKey => {trackId, sequence};
}

/// User state deliberately has no foreign key to [LibraryTracks]. A source
/// rescan atomically replaces its catalog rows, while favorites must survive
/// that temporary deletion and reconnect through the stable track ID.
class LibraryFavoriteTracks extends Table {
  TextColumn get trackId => text()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {trackId};
}

/// Append-only playback events. Missing catalog tracks are retained so a
/// later source recovery can make the history visible again.
class LibraryPlayHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackId => text()();
  DateTimeColumn get playedAt => dateTime()();
}

class LibraryPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Playlist membership survives catalog rescans for the same reason as
/// favorites. Only the playlist itself is referenced so deleting it can clean
/// up membership without coupling user data to transient catalog rows.
class LibraryPlaylistTracks extends Table {
  IntColumn get playlistId => integer().references(
    LibraryPlaylists,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get trackId => text()();
  IntColumn get position => integer()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {playlistId, trackId};
}

@DriftDatabase(
  tables: [
    LibrarySources,
    LibraryArtists,
    LibraryAlbums,
    LibraryTracks,
    LibraryLyrics,
    LibraryFavoriteTracks,
    LibraryPlayHistory,
    LibraryPlaylists,
    LibraryPlaylistTracks,
  ],
)
class LibraryDatabase extends _$LibraryDatabase {
  LibraryDatabase(super.executor);

  LibraryDatabase.defaults()
    : super(
        driftDatabase(
          name: 'sound_library',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.dart.js'),
          ),
          native: const DriftNativeOptions(shareAcrossIsolates: true),
        ),
      );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(libraryFavoriteTracks);
        await migrator.createTable(libraryPlayHistory);
      }
      if (from < 3) {
        await migrator.createTable(libraryPlaylists);
        await migrator.createTable(libraryPlaylistTracks);
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
