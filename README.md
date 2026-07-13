# Sound Next

Sound Next is a clean cross-platform rewrite of the original Sound music
player prototype. It keeps the artwork-first visual language and core screens,
while rebuilding playback, library scanning, persistence, and remote sources
from explicit platform-independent contracts.

## Current state

- First-class Flutter targets: Android, Windows, iPhone, iPad, and macOS, plus
  a development-only Web preview. The Apple mobile target is Universal and
  supports iOS/iPadOS 13 or later.
- Retained UI: library, album detail, now playing/lyrics, source settings, and
  responsive mini player.
- Responsive layouts verified in desktop, compact web preview, and an Android
  16 arm64 emulator at 1080 x 2400.
- Production playback uses `JustAudioPlaybackEngine`, backed by ExoPlayer on
  Android, AVPlayer on Apple platforms, and WinRT MediaPlayer on Windows;
  widget tests inject `SimulatedPlaybackEngine`.
- Production navigation exposes real albums, artists, genres, songs,
  favorites, recent plays, full playback history, and editable playlists
  without demo screens.
- Desktop navigation supports visible keyboard focus, Tab/arrow/Enter
  traversal, Space and media-key playback, previous/next shortcuts, direct
  library/search/settings shortcuts, Esc back/close behavior, and a built-in
  shortcut reference. Playback shortcuts are isolated from text input.
- `PlaybackEngine` snapshots are the sole authority for playback position.
- Playback session generations reject callbacks from previously loaded tracks.
- Queue and position sessions are checkpointed during playback and flushed on
  backgrounding. Restart keeps the restored item visible without autoplay,
  then seeks before playback when the user resumes; authorization headers are
  never written to the session file.
- Mini-player and now-playing surfaces share one visual mapping for loading,
  buffering, ready, playing, paused, completed, and error states, including
  replay and retry actions.
- A Drift/SQLite v3 repository persists sources, artists, albums, tracks,
  lyrics, favorites, playback history, editable playlists, and atomic scan
  state across native platforms and the development Web build. User state
  survives catalog rescans because it is linked through stable track IDs
  without scan-time cascading deletes.
- Local folder sources persist Android SAF tree grants and macOS
  security-scoped bookmarks across restarts; iPhone/iPad use the system Files
  picker and a restored bookmark; Windows and Linux restore normalized
  filesystem directory URIs. Revoked or missing access remains a visible,
  recoverable source state.
- Local and WebDAV scanners share release grouping based on explicit album
  artist, compilation metadata, normalized release folders, and disc folders.
  They keep participating track artists intact, separate unrelated same-title
  releases, and merge CD/Disc subfolders into one multi-disc album. The album
  page displays disc sections and plays in disc/track order.
- A local scanner indexes MP3/FLAC title, track and album artist, album,
  track/disc number, duration, cover, genre, year, compilation state, and
  embedded lyrics into one atomic repository batch. Android SAF scanning and
  deletion-aware rescanning pass on an Android 16 ARM64 emulator.
- Library and album-detail screens now consume the persisted repository. Real
  media URIs, artwork, metadata, and lyrics flow into playback; loading, empty,
  and repository-error states replace the former built-in demo catalog.
- Local MP3 and FLAC playback plus a 120-second seek pass on macOS and Android;
  none of the recorded local runs regressed position.
- Authenticated WebDAV MP3 playback and byte-range seeking now pass with the
  just_audio adapter on macOS and Android. In the throttled fixture, a
  120-second seek opens a range near byte 5 MB and resumes in about 0.04 seconds
  on macOS and 0.7-1.0 seconds on Android.
- Source settings can add, edit, probe, and remove WebDAV servers. Discovery
  requires advertised DAV capability and a 207 PROPFIND response, while
  credentials live in platform secure storage instead of the library database.
- Background playback and system media controls still need the remaining
  physical-device regression matrix. Repository-backed screens also need
  runtime regression on Windows and iPhone/iPad when suitable hosts/devices
  are available.

## Run

```sh
flutter pub get
flutter run -d macos
```

Open Settings to add a local folder or WebDAV source, scan it, and play from
the real library screens. On desktop, open the keyboard reference from the
sidebar or with `Command/Ctrl + /`. Use `flutter devices` to find Android
targets. Windows builds must be produced on Windows.

## Verify

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build macos --debug
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

The macOS Keychain entitlement requires a development-signed app. Sign in to a
matching Apple developer account in Xcode before running the normal macOS build.
An unsigned Xcode build can check compilation, but it cannot validate Keychain
behavior.

## Documentation

- [Development kanban](docs/KANBAN.md)
- [Design foundation](docs/DESIGN_FOUNDATION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Playback validation plan](docs/PLAYBACK_VALIDATION.md)
- [Repeatable WebDAV fixture](docs/WEBDAV_FIXTURE.md)
- [Desktop library reference](docs/screenshots/library-desktop.png)
- [Desktop now playing reference](docs/screenshots/now-playing-desktop.png)
- [Mobile library reference](docs/screenshots/library-mobile.png)
- [Mobile now playing reference](docs/screenshots/now-playing-mobile.png)
- [Android library](docs/screenshots/android-library.png)
- [Android now playing](docs/screenshots/android-now-playing.png)
- [Android sources](docs/screenshots/android-sources.png)
- [Android playback validation](docs/screenshots/android-playback-validation.png)
- [Android real MP3 playback](docs/screenshots/android-real-playback.png)
- [Android lowered mini player](docs/screenshots/android-mini-player-lowered.png)

The previous Swift project is intentionally unchanged and remains a visual and
behavioral reference only.
