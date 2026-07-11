# Sound Next

Sound Next is a clean cross-platform rewrite of the original Sound music
player prototype. It keeps the artwork-first visual language and core screens,
while rebuilding playback, library scanning, persistence, and remote sources
from explicit platform-independent contracts.

## Current state

- Flutter hosts: Android, Windows, iOS, macOS, and a development-only Web
  preview.
- Retained UI: library, album detail, now playing/lyrics, source settings, and
  responsive mini player.
- Responsive layouts verified in desktop, compact web preview, and an Android
  16 arm64 emulator at 1080 x 2400.
- Production playback is wired through `MediaKitPlaybackEngine`; widget tests
  inject `SimulatedPlaybackEngine` instead.
- The playback validation screen opens a real local file or an authenticated
  WebDAV media URL without adding either source to the demo library.
- `PlaybackEngine` snapshots are the sole authority for playback position.
- Playback session generations reject callbacks from previously loaded tracks.
- Real MP3 and FLAC playback plus a 120-second seek pass on macOS and Android;
  none of the recorded runs regressed position.
- Source indexing, persistence, background playback, system media controls, and
  the production WebDAV flow remain intentionally unfinished.

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
```

## Documentation

- [Design foundation](docs/DESIGN_FOUNDATION.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Playback validation plan](docs/PLAYBACK_VALIDATION.md)
- [Desktop library reference](docs/screenshots/library-desktop.png)
- [Desktop now playing reference](docs/screenshots/now-playing-desktop.png)
- [Mobile library reference](docs/screenshots/library-mobile.png)
- [Mobile now playing reference](docs/screenshots/now-playing-mobile.png)
- [Android library](docs/screenshots/android-library.png)
- [Android now playing](docs/screenshots/android-now-playing.png)
- [Android sources](docs/screenshots/android-sources.png)
- [Android playback validation](docs/screenshots/android-playback-validation.png)
- [Android real MP3 playback](docs/screenshots/android-real-playback.png)

The previous Swift project is intentionally unchanged and remains a visual and
behavioral reference only.
