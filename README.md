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
- Production playback uses `JustAudioPlaybackEngine`, backed by ExoPlayer on
  Android, AVPlayer on Apple platforms, and WinRT MediaPlayer on Windows;
  widget tests inject `SimulatedPlaybackEngine`.
- The playback validation screen opens a real local file or an authenticated
  WebDAV media URL without adding either source to the demo library.
- `PlaybackEngine` snapshots are the sole authority for playback position.
- Playback session generations reject callbacks from previously loaded tracks.
- Local MP3 and FLAC playback plus a 120-second seek pass on macOS and Android;
  none of the recorded local runs regressed position.
- Authenticated WebDAV MP3 playback and byte-range seeking now pass with the
  just_audio adapter on macOS and Android. In the throttled fixture, a
  120-second seek opens a range near byte 5 MB and resumes in about 0.04 seconds
  on macOS and 0.7-1.0 seconds on Android.
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
