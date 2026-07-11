# Sound Next architecture

The rewrite starts from behavior contracts rather than the old Swift module
layout. No production playback, persistence, or scanning code is copied from
the prototype.

## First release targets

- Windows
- Android
- iPhone and iPad (minimum iOS/iPadOS 13, Universal device family)
- macOS remains a first-class development and regression target.

## Module boundaries

```text
presentation
  screens, responsive layout, visual components, view models
domain
  tracks, albums, sources, queue, playback snapshot
library
  scanning, metadata, search, SQLite repositories
playback
  playback controller, engine contract, just_audio adapter, position gate
sources
  local folders and WebDAV
platform
  background playback, media controls, file pickers, credentials,
  Apple security-scoped URLs and bookmarks
```

Dependencies point inward: platform implementations may depend on domain
contracts, while domain code never imports Flutter widgets or platform APIs.

## Playback invariants

The playback engine is the only authority for position, duration, buffering,
and completion.

`JustAudioPlaybackEngine` is the production adapter: it keeps one Dart contract
while using ExoPlayer on Android, AVPlayer on Apple platforms, and WinRT
MediaPlayer through `just_audio_windows`. Windows authentication headers are
forwarded by just_audio's range-preserving loopback proxy because the WinRT
plugin does not expose custom headers.

- `PlaybackEngine` exposes a stream of immutable `PlaybackSnapshot` values.
- `PlaybackController` owns the active queue and translates user intents into
  engine commands.
- Widgets subscribe to snapshots; they never advance time with their own timer.
- Scrubbing state belongs to the progress widget and is only a preview.
- Releasing a scrub sends exactly one seek request.
- Native positions remain unpublished while a seek is pending. A pure
  `NativePositionGate` confirms the target and rejects stale callbacks emitted
  while the native player settles.
- Every loaded item receives a session generation. Events from an older
  generation are ignored.
- Persistence observes controller state at a throttled cadence and never feeds
  progress back into a live session.

The initial state machine is:

```text
idle -> loading -> ready -> playing
                  |        |   |
                  paused <-+   -> buffering
                  |             |
                  +----------> completed
any state -------------------> error
```

## Library persistence

- `LibraryRepository` is the presentation-independent boundary for sources,
  artists, albums, tracks, lyrics, and scan state.
- Drift manages the SQLite v1 schema. Entity primary keys are stable text IDs
  supplied by source scanners; only lyric ordering uses a composite key.
- A source scan is replaced inside one transaction. Failed constraints roll
  back metadata, lyrics, deletions, and the source scan revision together.
- All persisted timestamps cross the repository boundary as UTC values.
- Native databases live in the application documents directory and can be
  shared across Flutter isolates. The development Web build uses the matching
  SQLite WASM module and Drift worker committed under `web/`.
- `drift_schemas/sound_library/` stores the versioned schema baseline. After
  every schema change, increment `schemaVersion` and run
  `dart run drift_dev make-migrations` before editing the generated migration.

Regenerate the type-safe database code and Web worker with:

```sh
dart run build_runner build
dart compile js -O4 -o web/drift_worker.dart.js tool/drift_worker.dart
```

The `web/sqlite3.wasm` binary must match the `sqlite3` version resolved in
`pubspec.lock`.

## Production data policy

- Screens consume `LibraryRepository`; production code must not seed a demo
  catalog, fake source, fake playlist, fake lyric, or fake current track.
- Empty, loading, unavailable, and error cases are explicit UI states. Missing
  content is never hidden by plausible-looking sample content.
- Deterministic fixtures and simulated playback belong under `test/`.
  Developer playback validation may exist in production sources only behind
  `kDebugMode` or explicit `SOUND_VALIDATION_*` build definitions.
- Visual artwork fallbacks may derive color and typography from real album
  metadata, but they do not invent library entities or playback state.

## Local directory access

- `LocalDirectoryAccess` is the platform-independent grant contract. A grant
  contains a canonical root URI, display name, availability state, and an
  optional opaque permission token.
- Android stores the `content://` tree URI returned by the Storage Access
  Framework and calls `takePersistableUriPermission`. Startup verifies that
  the read grant is still present and that the tree root is queryable.
- macOS stores a read-only security-scoped bookmark. Startup resolves the
  bookmark, refreshes stale bookmark data, and keeps security-scoped access
  active for the process lifetime.
- iPhone and iPad use `UIDocumentPickerViewController` to select a Files or
  iCloud directory. The returned security-scoped URL is bookmarked, restored,
  and held only for the process lifetime; the app remains a Universal target.
- Windows and Linux persist a normalized `file://` directory URI and check the
  directory on every restore. They do not require an opaque permission token.
- Application shutdown never revokes a durable grant. Explicitly removing a
  source releases the Android permission or active macOS access and deletes
  the repository record.
- Permission revocation and missing directories are stored as
  `permissionRequired` and `unavailable` states instead of being treated as
  empty libraries.

## Local library scanning

- `LocalMediaCatalog` enumerates MP3 and FLAC without leaking platform storage
  details into the scanner. Desktop and Apple platforms use restored file
  URLs; Android walks the persisted SAF tree with `ContentResolver`.
- Android copies one SAF document at a time into an app-cache scratch file for
  pure-Dart metadata parsing, then deletes it immediately. The stored playback
  URI remains the original `content://` document URI.
- `audio_metadata_reader` parses MP3 ID3 and FLAC Vorbis metadata in a worker
  isolate. Parsed fields include title, artist, album, track/disc number,
  duration, year, genre, embedded cover, and embedded lyrics.
- Embedded synchronized lyrics are normalized into ordered millisecond rows;
  unsynchronized lyrics remain one zero-timestamp record.
- Damaged files and artwork-write failures become scan warnings instead of
  discarding other valid tracks. A completed scan replaces the source batch in
  one existing Drift transaction, so removed files disappear atomically.

## Vertical validation before feature development

The architecture is accepted only after the same small scenario works on
Windows, Android, iPhone, and iPad:

1. Scan one local MP3 and one local FLAC.
2. Read title, artist, album, duration, cover, and embedded lyrics.
3. Play, pause, seek, skip, and resume without progress jumps.
4. Stream one WebDAV item with authentication and seeking.
5. Keep playback alive in the Android background.
6. Publish metadata and transport controls to Android and Windows.

Large library, playlist, and visual-polish work starts only after this slice is
measured and repeatable.
