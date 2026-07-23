import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/scanning/audio_format_registry.dart';
import 'package:kaiting/playback/just_audio_playback_engine.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';
import 'package:kaiting/playback/playback_media_provider.dart';
import 'package:kaiting/sources/webdav/webdav_playback_media_provider.dart';

const _validationDirectory = String.fromEnvironment(
  'SOUND_FORMAT_VALIDATION_DIR',
);
const _validationBaseUrl = String.fromEnvironment(
  'SOUND_FORMAT_VALIDATION_BASE_URL',
);
const _validationUsername = String.fromEnvironment(
  'SOUND_FORMAT_VALIDATION_USERNAME',
);
const _validationPassword = String.fromEnvironment(
  'SOUND_FORMAT_VALIDATION_PASSWORD',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());

  if (_validationDirectory.isEmpty) {
    stderr.writeln('Set SOUND_FORMAT_VALIDATION_DIR.');
    exit(64);
  }
  final directory = Directory(_validationDirectory);
  if (!directory.existsSync()) {
    stderr.writeln('Validation directory does not exist: ${directory.path}');
    exit(66);
  }
  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((file) => isSupportedAudioPath(file.path))
          .toList(growable: false)
        ..sort((left, right) => left.path.compareTo(right.path));
  if (files.isEmpty) {
    stderr.writeln('No supported audio files found in ${directory.path}.');
    exit(65);
  }

  var failed = false;
  for (final file in files) {
    final engine = JustAudioPlaybackEngine(
      mediaProviders: PlaybackMediaProviderRegistry([
        WebDavPlaybackMediaProvider(),
        const DirectPlaybackMediaProvider(),
      ]),
    );
    final controller = SoundPlaybackController(engine: engine);
    final errors = <String>[];
    final subscription = engine.snapshots.listen((snapshot) {
      if (snapshot.phase == PlaybackPhase.error) {
        errors.add(snapshot.errorMessage ?? 'Unknown playback error');
      }
    });
    try {
      final remote = _validationBaseUrl.isNotEmpty;
      final mediaUri = remote
          ? Uri.parse(_validationBaseUrl)
                .resolve(Uri.encodeComponent(file.uri.pathSegments.last))
                .toString()
          : file.uri.toString();
      final headers = remote && _validationUsername.isNotEmpty
          ? <String, String>{
              HttpHeaders.authorizationHeader:
                  'Basic ${base64Encode(utf8.encode('$_validationUsername:$_validationPassword'))}',
            }
          : const <String, String>{};
      final track = Track(
        id: 'format:${file.path.hashCode}',
        title: file.uri.pathSegments.last,
        artist: 'Sound validation',
        albumTitle: 'Audio format validation',
        duration: Duration.zero,
        source: remote ? SourceKind.webDav : SourceKind.local,
        mediaUri: mediaUri,
      );
      if (remote) {
        controller.updatePlaybackMediaAccess([
          PlaybackMediaAccessRule(
            baseUri: Uri.parse(_validationBaseUrl),
            headers: headers,
          ),
        ]);
      }
      await controller.playTrack(track, queue: <Track>[track]);
      await engine.snapshots
          .firstWhere(
            (snapshot) =>
                snapshot.phase == PlaybackPhase.error ||
                (snapshot.isPlaying && snapshot.duration > Duration.zero),
          )
          .timeout(const Duration(seconds: 15));
      if (errors.isNotEmpty) throw StateError(errors.last);
      // Leave the synchronous playback event callback before issuing the next
      // native command. User gestures naturally occur on a later event turn.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final duration = controller.snapshot.duration;
      final seekTarget = duration > const Duration(seconds: 1)
          ? const Duration(milliseconds: 500)
          : duration ~/ 2;
      await controller.seek(seekTarget);
      if ((engine.current.position - seekTarget).abs() >
          const Duration(milliseconds: 300)) {
        await engine.snapshots
            .firstWhere(
              (snapshot) =>
                  snapshot.phase == PlaybackPhase.error ||
                  (snapshot.position - seekTarget).abs() <=
                      const Duration(milliseconds: 300),
            )
            .timeout(const Duration(seconds: 3));
      }
      if (errors.isNotEmpty) throw StateError(errors.last);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (controller.snapshot.isPlaying) await controller.toggle();
      stdout.writeln(
        'FORMAT_PLAYBACK_OK '
        'source=${remote ? 'webdav' : 'local'} '
        'file=${file.uri.pathSegments.last} '
        'durationMs=${duration.inMilliseconds} '
        'seekMs=${controller.displayPosition.inMilliseconds}',
      );
    } catch (error, stackTrace) {
      failed = true;
      stderr.writeln(
        'FORMAT_PLAYBACK_FAILED file=${file.path} error=$error\n$stackTrace',
      );
    } finally {
      await subscription.cancel();
      controller.dispose();
      engine.dispose();
    }
  }
  exit(failed ? 1 : 0);
}
