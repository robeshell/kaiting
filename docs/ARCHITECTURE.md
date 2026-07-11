# Sound Next architecture

The rewrite starts from behavior contracts rather than the old Swift module
layout. No production playback, persistence, or scanning code is copied from
the prototype.

## First release targets

- Windows
- Android
- macOS and iOS remain build targets so the design can continue on Apple
  devices, but Windows and Android drive architectural decisions.

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
  macOS security-scoped bookmarks
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

## Vertical validation before feature development

The architecture is accepted only after the same small scenario works on
Windows and Android:

1. Scan one local MP3 and one local FLAC.
2. Read title, artist, album, duration, cover, and embedded lyrics.
3. Play, pause, seek, skip, and resume without progress jumps.
4. Stream one WebDAV item with authentication and seeking.
5. Keep playback alive in the Android background.
6. Publish metadata and transport controls to Android and Windows.

Large library, playlist, and visual-polish work starts only after this slice is
measured and repeatable.
