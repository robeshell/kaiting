# Repeatable WebDAV playback fixture

This repository includes a development-only WebDAV server so remote playback
can be measured without depending on a particular NAS. It supports Basic Auth,
`OPTIONS`, `PROPFIND`, `HEAD`, `GET`, and single byte-range requests.

The fixture must point at a temporary directory outside the repository. Never
copy personal audio or real credentials into Git.

## Start the fixture

```sh
mkdir -p /tmp/kaiting-webdav-fixtures
cp /path/to/sample.mp3 /tmp/kaiting-webdav-fixtures/sample.mp3
cp /path/to/sample.flac /tmp/kaiting-webdav-fixtures/sample.flac

dart run tool/webdav_fixture_server.dart \
  --root /tmp/kaiting-webdav-fixtures \
  --host 0.0.0.0 \
  --port 8088 \
  --username sound \
  --password sound-test \
  --bytes-per-second 524288
```

These credentials are deliberately local and disposable. For macOS, use a URL
such as `http://127.0.0.1:8088/sample.mp3`. An Android emulator reaches the host
at `http://10.0.2.2:8088/sample.mp3`.

The optional throttle prevents a local fixture from transferring the whole file
before the automated two-second seek. A seekable format should open one or more
non-zero ranges for the target. The just_audio adapter does this for the
recorded MP3 on macOS and Android.

## Automated startup validation

The same startup harness used for local playback can attach Basic Auth headers:

```sh
flutter run -d macos \
  --dart-define=SOUND_PLAYBACK_TRACE=true \
  --dart-define=SOUND_VALIDATION_MUTED=true \
  --dart-define=SOUND_VALIDATION_MEDIA=http://127.0.0.1:8088/sample.mp3 \
  --dart-define=SOUND_VALIDATION_USERNAME=sound \
  --dart-define=SOUND_VALIDATION_PASSWORD=sound-test \
  --dart-define=SOUND_VALIDATION_SEEK_MS=120000
```

Normal builds leave all validation values empty. Do not use the compile-time
credential switches with real secrets; enter real NAS credentials through the
in-app validation dialog, where they live only for the current playback item.
