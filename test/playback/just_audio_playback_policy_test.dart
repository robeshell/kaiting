import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:kaiting/playback/just_audio_playback_engine.dart';
import 'package:kaiting/playback/playback_media_provider.dart';

void main() {
  group('app-managed HTTP stream policy', () {
    test('uses the app stream for authenticated iOS media', () {
      expect(
        shouldUseAppManagedHttpStream(
          resource: _resource(headers: const {'Authorization': 'Basic test'}),
          platform: TargetPlatform.iOS,
          platformRequiresProxy: false,
        ),
        isTrue,
      );
    });

    test('keeps public iOS and authenticated Android media native', () {
      expect(
        shouldUseAppManagedHttpStream(
          resource: _resource(),
          platform: TargetPlatform.iOS,
          platformRequiresProxy: false,
        ),
        isFalse,
      );
      expect(
        shouldUseAppManagedHttpStream(
          resource: _resource(headers: const {'Authorization': 'Basic test'}),
          platform: TargetPlatform.android,
          platformRequiresProxy: false,
        ),
        isFalse,
      );
    });

    test('uses the app stream for custom TLS or a platform proxy', () {
      expect(
        shouldUseAppManagedHttpStream(
          resource: _resource(allowBadCertificate: true),
          platform: TargetPlatform.android,
          platformRequiresProxy: false,
        ),
        isTrue,
      );
      expect(
        shouldUseAppManagedHttpStream(
          resource: _resource(),
          platform: TargetPlatform.windows,
          platformRequiresProxy: true,
        ),
        isTrue,
      );
    });
  });

  test('recognizes an Apple media-services reset', () {
    expect(
      isDarwinMediaServicesResetError(
        just_audio.PlayerException(-11819, 'Cannot Complete Action', 1),
      ),
      isTrue,
    );
    expect(
      isDarwinMediaServicesResetError(
        just_audio.PlayerException(-1009, 'Offline', 1),
      ),
      isFalse,
    );
  });
}

PlaybackMediaResource _resource({
  Map<String, String> headers = const {},
  bool allowBadCertificate = false,
}) {
  return PlaybackMediaResource(
    uri: Uri.parse('https://example.test/music/song.flac'),
    headers: headers,
    allowBadCertificate: allowBadCertificate,
  );
}
