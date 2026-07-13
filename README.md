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
- The playback validation screen opens a real local file or an authenticated
  WebDAV media URL without indexing it into the library.
- `PlaybackEngine` snapshots are the sole authority for playback position.
- Playback session generations reject callbacks from previously loaded tracks.
- Queue and position sessions are checkpointed during playback and flushed on
  backgrounding. Restart keeps the restored item visible without autoplay,
  then seeks before playback when the user resumes; authorization headers are
  never written to the session file.
- Mini-player and now-playing surfaces share one visual mapping for loading,
  buffering, ready, playing, paused, completed, and error states, including
  replay and retry actions.
- A Drift/SQLite v1 repository now persists sources, artists, albums, tracks,
  lyrics, and atomic scan state across native platforms and the development
  Web build.
- Local folder sources persist Android SAF tree grants and macOS
  security-scoped bookmarks across restarts; iPhone/iPad use the system Files
  picker and a restored bookmark; Windows and Linux restore normalized
  filesystem directory URIs. Revoked or missing access remains a visible,
  recoverable source state.
- A local scanner now indexes MP3/FLAC title, artist, album, track/disc number,
  duration, cover, genre, year, and embedded lyrics into one atomic repository
  batch. Android SAF scanning and deletion-aware rescanning pass on an Android
  16 ARM64 emulator.
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
- Background playback, system media controls, search, and the production
  WebDAV indexing flow remain unfinished. Repository-backed screens still need runtime
  regression on Windows and iPhone/iPad when suitable hosts/devices are
  available.

## Run

```sh
flutter pub get
flutter run -d macos
```

Open Settings -> Playback validation to choose a local audio file or enter a
WebDAV file URL. Use `flutter devices` to find Android targets. Windows builds
must be produced on Windows.

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
