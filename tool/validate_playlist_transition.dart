import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/playback/just_audio_playback_engine.dart';
import 'package:kaiting/playback/playback_controller.dart';
import 'package:kaiting/playback/playback_engine.dart';

const _firstPath = String.fromEnvironment('SOUND_VALIDATION_TRACK_ONE');
const _secondPath = String.fromEnvironment('SOUND_VALIDATION_TRACK_TWO');
const _seekFromEndSeconds = int.fromEnvironment(
  'SOUND_VALIDATION_SEEK_FROM_END_SECONDS',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());

  if (_firstPath.isEmpty || _secondPath.isEmpty) {
    stderr.writeln(
      'Set SOUND_VALIDATION_TRACK_ONE and SOUND_VALIDATION_TRACK_TWO.',
    );
    exit(64);
  }

  final tracks = [
    _track('native-transition-one', _firstPath),
    _track('native-transition-two', _secondPath),
  ];
  final engine = JustAudioPlaybackEngine();
  final controller = SoundPlaybackController(engine: engine);
  final snapshots = <PlaybackSnapshot>[];
  final subscription = engine.snapshots.listen(snapshots.add);

  var validationExitCode = 0;
  try {
    await controller.playTrack(tracks.first, queue: tracks);
    final duration = controller.snapshot.duration;
    if (duration <= Duration.zero) {
      throw StateError('The first track duration is too short: $duration');
    }
    if (_seekFromEndSeconds > 0) {
      final lead = Duration(seconds: _seekFromEndSeconds);
      if (duration <= lead) {
        throw StateError(
          'The first track is shorter than seek lead: $duration',
        );
      }
      await controller.seek(duration - lead);
    }
    await engine.snapshots
        .firstWhere(
          (snapshot) =>
              snapshot.track?.id == tracks[1].id && snapshot.isPlaying,
        )
        .timeout(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final secondSnapshots = snapshots
        .where((snapshot) => snapshot.track?.id == tracks[1].id)
        .toList();
    final firstCompleted = snapshots.where(
      (snapshot) =>
          snapshot.track?.id == tracks.first.id &&
          snapshot.phase == PlaybackPhase.completed,
    );
    final maxInitialSecondPosition = secondSnapshots
        .take(8)
        .map((snapshot) => snapshot.position)
        .fold(Duration.zero, (left, right) => left > right ? left : right);

    if (controller.currentTrack?.id != tracks[1].id ||
        controller.queueIndex != 1 ||
        firstCompleted.isNotEmpty ||
        maxInitialSecondPosition > const Duration(seconds: 4)) {
      throw StateError(
        'Invalid transition: track=${controller.currentTrack?.id}, '
        'index=${controller.queueIndex}, firstCompleted=${firstCompleted.length}, '
        'secondPosition=$maxInitialSecondPosition',
      );
    }

    stdout.writeln(
      'PLAYLIST_TRANSITION_OK '
      'gapless=${controller.supportsGaplessTransitions} '
      'firstDurationMs=${duration.inMilliseconds} '
      'secondPositionMs=${controller.snapshot.position.inMilliseconds}',
    );
  } catch (error, stackTrace) {
    validationExitCode = 1;
    stderr.writeln('PLAYLIST_TRANSITION_FAILED $error');
    stderr.writeln(stackTrace);
  } finally {
    await subscription.cancel();
    controller.dispose();
    engine.dispose();
  }
  exit(validationExitCode);
}

Track _track(String id, String path) => Track(
  id: id,
  title: id,
  artist: 'Sound validation',
  albumTitle: 'Native playlist transition',
  duration: const Duration(minutes: 30),
  source: SourceKind.local,
  mediaUri: Uri.file(path).toString(),
);
