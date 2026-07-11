# Playback vertical-slice validation

Do not expand the product feature set until this slice passes on both Windows
and Android. Package choice remains provisional until the measurements below
are recorded.

## Evidence recorded so far

- [x] macOS: real MP3 loads, reports a 223.190-second duration, plays, and
      settles at 120.000 seconds after seek.
- [x] macOS: real FLAC loads, reports a 223.453-second duration, plays, and
      settles at 120.000 seconds after seek.
- [x] Android 16 arm64 emulator: debug APK installs and launches without a
      Flutter layout or native crash.
- [x] Android 16 arm64 emulator: real MP3 loads from app-private storage,
      reports a 223.190-second duration, plays, and advances 120.000 -> 121.250
      -> 122.000 seconds after seek without regression.
- [x] Android 16 arm64 emulator: real FLAC reports a 223.453-second duration
      and advances 120.000 -> 121.250 -> 122.000 seconds after seek without
      regression.
- [x] The late 119.861-second native callback observed after a 120.000-second
      macOS seek is filtered by `NativePositionGate` and covered by a unit test.
- [ ] Authenticated WebDAV, Windows, background playback, and
      system media controls still require validation.

## Fixtures

- One local MP3 with ID3 title, artist, album, cover, and embedded lyrics.
- One local FLAC with Vorbis comments, cover, and embedded lyrics.
- One authenticated WebDAV MP3.
- One authenticated WebDAV FLAC.
- A 30-minute or longer file for seek and resume testing.

## Required behavior

- [x] Local MP3 and FLAC load and begin playback on macOS and Android.
- [ ] Local MP3 and FLAC load and begin playback on Windows.
- [ ] WebDAV MP3 and FLAC stream without downloading the complete library
      during indexing.
- [ ] Play, pause, next, previous, and completion transitions are correct.
- [ ] Dragging previews time locally and sends one seek when released.
- [x] Engine position settles after seek without jumping back to the old time
      in the recorded macOS MP3/FLAC and Android MP3 runs.
- [ ] Rapid track changes never show progress from the previous track.
- [ ] Buffering is visually different from paused playback.
- [ ] Android continues playback with the screen off.
- [ ] Android notification controls and metadata stay synchronized.
- [ ] Windows system media controls and metadata stay synchronized.
- [ ] Relaunch restores the queue and saved position without autoplaying.

## Measurements

Record these for local and WebDAV playback on both platforms:

- Time to first audio.
- Seek settlement time at 10%, 50%, and 90%.
- Number of engine position regressions after 20 seeks.
- Bytes transferred before playback starts.
- Memory after scanning 1,000 and 10,000 tracks.
- CPU usage while playing with the now-playing screen visible and hidden.

## Acceptance rule

The media adapter is accepted only when all required behavior passes and no
position regression occurs during the 20-seek test. If a package cannot meet
the system-media-control or authenticated-seek requirements without invasive
forking, replace it behind `PlaybackEngine` rather than leaking workarounds
into UI code.
