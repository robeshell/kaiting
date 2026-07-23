# 开听 architecture

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
offline
  protocol-neutral download queue, stored-media identity and storage totals
sources
  local folders, WebDAV and future protocol adapters
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
- Drag preview belongs to the progress widget. Releasing it sends exactly one
  seek request; the controller then exposes one provisional display position
  shared by the progress label and lyrics until the engine confirms it.
- Native positions remain unpublished while a seek is pending. A pure
  `NativePositionGate` confirms the target and rejects stale callbacks emitted
  while the native player settles.
- Every loaded item receives a session generation. Events from an older
  generation are ignored.
- Persistence observes controller state at a throttled cadence and never feeds
  progress back into a live session.
- Playback-session bootstrap finishes before the app exposes its single
  controller, so a late disk read cannot replace active playback. Native
  targets checkpoint at most once every two seconds and flush when the app is
  backgrounded; the development Web target uses an in-memory fallback.
- Session v3 stores queue structure separately from the high-frequency
  position checkpoint. Only the current track keeps lyrics as a restart
  fallback; the rest of the queue contains compact metadata. Track domain
  objects and session JSON never carry HTTP authorization headers. Restored
  positions are applied after load and before play.

The initial state machine is:

```text
idle -> loading -> ready -> playing
                  |        |   |
                  paused <-+   -> buffering
                  |             |
                  +----------> completed
any state -------------------> error
```

`PlaybackVisualState` is the single presentation mapping for that machine.
The mini player and now-playing screen share its labels, colors, busy signal,
and primary-action icon. Buffering also carries `playWhenReady`, so the UI can
offer pause while native playback is waiting for data. Loading disables the
primary action, completion restarts from zero, and errors expose an explicit
retry that reloads the current track.

## Library persistence

- `LibraryRepository` is the presentation-independent boundary for sources,
  artists, albums, tracks, lyrics, scan state, favorites, playback history,
  playlists, and ordered playlist membership.
- Drift manages the SQLite v3 schema. Catalog entity primary keys are stable
  text IDs supplied by source scanners; only lyric ordering uses a composite
  key. Favorite, history, and playlist-member rows deliberately avoid catalog
  foreign keys so catalog changes and temporary source loss cannot erase user
  state. Playlist membership does reference its owning playlist so an
  explicit playlist deletion cleans up its entries.
- A source scan is applied as a complete snapshot inside one transaction, but
  the repository diffs artists, albums, tracks, and lyrics first. Unchanged
  rows receive no write; additions, updates, and removals commit together.
  Failed constraints roll back metadata, lyrics, deletions, and the source scan
  revision together.
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

## Library scanning

- `LocalMediaCatalog` enumerates MP3 and FLAC without leaking platform storage
  details into the scanner. Desktop and Apple platforms use restored file
  URLs; Android walks the persisted SAF tree with `ContentResolver`.
- Android copies one SAF document at a time into an app-cache scratch file for
  pure-Dart metadata parsing, then deletes it immediately. The stored playback
  URI remains the original `content://` document URI.
- `audio_metadata_reader` parses MP3 ID3 and FLAC Vorbis metadata in a worker
  isolate. Parsed fields include title, track artist, album artist, album,
  track/disc number, compilation state, duration, year, genre, embedded cover,
  and embedded lyrics. Supplementary album-identity probing reads bounded tag
  regions rather than loading the whole audio file a second time.
- Local and WebDAV scanning call the same stable album grouping function.
  Explicit album artist and compilation tags disambiguate flat folders; a
  folder that matches the album title identifies a release, while CD/Disc
  child folders are removed from that identity. This keeps multi-disc releases
  together without merging unrelated same-title albums. Participating track
  artists remain on their individual track records.
- Local and WebDAV embedded lyrics use the same parser. LRC timestamps are
  removed from display text, metadata tags and global offsets are normalized,
  and synchronized lines are stored as ordered millisecond rows.
  Unsynchronized lyrics are stored as individual lines with a `-1` timestamp
  sentinel and exposed to the presentation model with a nullable timestamp.
  Legacy raw-LRC rows are normalized when the catalog or a playback session is
  restored, so existing libraries do not require an immediate rescan.
- `LyricsTimeline` is the only active-line selector for natural playback,
  progress seeks, and lyric-click seeks. Timestamped source text is never
  classified from wording; equal timestamps form one cue. Lyric selection is
  derived only from the shared playback position. A seek/track revision snaps
  any stale scroll animation, while natural cue changes use a fixed short
  follow animation. User wheel or touch scrolling pauses follow for three
  seconds and exposes an immediate return action.
- Local rescans compare path, file size, and modification time before metadata
  extraction. Unchanged files reuse persisted metadata and lyrics. A unique
  size/time match between one missing path and one new path is treated as a
  move: metadata is refreshed but the stable track ID is retained so favorites,
  history, and playlists continue to point at the song. Ambiguous matches are
  deliberately handled as remove/add instead of guessing.
- Local scans have a cooperative cancellation token checked around discovery,
  metadata extraction, artwork, and the final transaction. Cancelling from the
  source screen restores the previous source state and never advances the scan
  revision or replaces the last completed snapshot.
- WebDAV PROPFIND requests content length, last-modified time, and ETag. Remote
  tracks persist the standard size/time fields already present in the shared
  track model, so a later rescan can reuse unchanged metadata and lyrics without
  another ranged audio GET. Legacy rows and servers that omit either reliable
  size or modified time are conservatively re-read instead of being treated as
  unchanged.
- WebDAV uses the same unambiguous size/time move matching as local scanning.
  A moved remote item refreshes metadata and changes its playback URL while
  retaining its track ID. Recursive discovery, per-file metadata reads, and the
  final transaction share a cooperative cancellation token. Cancelling a new
  folder removes its provisional source; cancelling an existing folder restores
  its previous source state and snapshot.
- Damaged files and artwork-write failures become scan warnings instead of
  discarding other valid tracks. A completed snapshot is diffed and committed
  in one Drift transaction, so removed files disappear atomically without
  rewriting unchanged rows.

## WebDAV connection management

- `WebDavConnectionService` owns connection identity and repository state;
  normalized URLs lowercase only scheme and host, preserve path case, remove
  default ports, and use a SHA-256 stable ID.
- WebDAV credentials are stored through `WebDavCredentialStore`. Production
  uses platform secure storage (Keychain on Apple platforms and the platform
  secure implementation elsewhere); SQLite never stores the username or
  password. Tests inject an in-memory store.
- Discovery first requires a successful OPTIONS response with a DAV header,
  then requires PROPFIND to return HTTP 207. Authentication, unreachable, and
  non-WebDAV failures remain distinct source states.
- PROPFIND XML is parsed by namespace-local element name instead of assuming a
  particular prefix. Standard size, last-modified, and ETag properties are
  exposed to the scanner, and discovery responses are capped at 4 MiB.
- Connection probes update availability without resetting scan revision or
  scan timestamps. Recursive indexing into the shared library belongs to the
  stable folder source derived from the parent connection and normalized path.
  A failed recursive scan marks that folder source as errored but does not
  replace or advance the last completed library snapshot.

## Remote-source and offline extensibility

Remote protocols are adapters, not product modes. Screens, albums and the
download center must never branch on WebDAV, SMB, S3 or a music-server brand.

- `OfflineMediaProvider` is the offline boundary. Each provider declares which
  tracks it supports and owns protocol-specific authentication, download,
  cancellation, removal and cache enumeration.
- `OfflineDownloadController` owns the shared queue, progress, retry, batch
  operations, library metadata mapping and aggregate storage totals. It only
  addresses content through an `OfflineMediaReference(providerId, resourceId)`.
- `WebDavOfflineMediaProvider` is the first implementation and wraps the
  existing WebDAV cache. TLS exceptions and authorization headers stay inside
  that adapter; the controller and UI never inspect them.
- `PlaybackMediaProvider` is the playback boundary. Providers resolve a Track
  into a URI, scoped request headers, TLS policy and an optional deferred cache
  action. `PlaybackMediaProviderRegistry` selects the adapter without exposing
  protocol types to the playback controller or `just_audio` engine.
- `WebDavPlaybackMediaProvider` owns WebDAV credential matching, local cache
  lookup, precise Apple FLAC preparation and background caching. The engine
  only consumes the resolved resource. A generic `HttpStreamAudioSource`
  handles range requests for explicitly trusted self-signed connections.
- Authentication is resolved from connection-scoped access rules inside the
  playback and offline providers. `Track` and `LibraryCatalogController` no
  longer transport credentials.
- Source identities are open string-backed values instead of closed enums.
  `SourceProviderRegistry` supplies product-facing names and capability
  declarations for local folders, WebDAV and future adapters. Unknown provider
  identifiers survive SQLite persistence and domain mapping, so adding a
  protocol does not require a database migration or a shared-model enum edit.
- `SourceScanProviderRegistry` routes rescans by provider identifier and returns
  one protocol-neutral change summary. Local and WebDAV adapters own record
  lookup, credentials, parent connection resolution, cancellation and scanner
  invocation; the settings screen no longer assembles WebDAV rescan requests.
- `SourceDirectoryBrowser` exposes a protocol-neutral directory tree. The
  shared picker owns navigation, selection, loading and error UI, while
  `WebDavSourceDirectoryBrowser` owns URL containment, credentials, discovery
  and audio-entry filtering.
- `SourceConnectionProviderRegistry` exposes protocol-neutral connection and
  indexed-catalog resources, probing, browser creation and removal. Remote
  source sections are rendered from adapter descriptors; only the add/edit
  form remains protocol-specific.
- Library and user-library source filters are derived from the `SourceKind`
  values present in real catalog data. They do not contain a local/WebDAV enum.
- Provider identifiers must be unique. Automated tests mount two independent
  providers at once and verify routing and storage aggregation.
- Adding another protocol requires four focused adapters: connection and
  credential management, catalog scanning, playback resource resolution, and
  `OfflineMediaProvider`. Shared library, player, offline and presentation code
  must not gain a new protocol-specific conditional.

Playback, offline, source-definition, connection, scanning and directory
boundaries are established. Protocol-specific connection forms still own their
fields and validation; they are intentionally not replaced with a dynamic
schema. A contract-only Subsonic-style adapter crosses connection, browsing,
scanning, playback and offline registries in one test without changing shared
controllers. Shipping a real second protocol is now feature work rather than a
prerequisite architecture rewrite.

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
