import 'package:flutter/material.dart';

import '../core/sound_theme.dart';
import '../domain/library_models.dart';
import '../playback/playback_controller.dart';
import '../playback/playback_engine.dart';
import '../presentation/app_shell.dart';

class SoundApp extends StatefulWidget {
  const SoundApp({required this.engine, super.key});

  final PlaybackEngine engine;

  @override
  State<SoundApp> createState() => _SoundAppState();
}

class _SoundAppState extends State<SoundApp> {
  static const _validationMedia = String.fromEnvironment(
    'SOUND_VALIDATION_MEDIA',
  );
  static const _validationSeekMs = int.fromEnvironment(
    'SOUND_VALIDATION_SEEK_MS',
    defaultValue: -1,
  );

  late final PlaybackEngine _engine;
  late final SoundPlaybackController _playback;

  @override
  void initState() {
    super.initState();
    _engine = widget.engine;
    _playback = SoundPlaybackController(engine: _engine);
    if (_validationMedia.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final uri = Uri.tryParse(_validationMedia);
        final isRemote = uri?.hasScheme == true && uri?.scheme != 'file';
        final filename = isRemote
            ? uri!.pathSegments.lastOrNull ?? '验证音频'
            : _validationMedia.split('/').last;
        final track = Track(
          id: 'startup-validation:${_validationMedia.hashCode}',
          title: filename,
          artist: isRemote ? '远程验证' : '本地验证',
          albumTitle: '播放验证',
          duration: Duration.zero,
          source: isRemote ? SourceKind.webDav : SourceKind.local,
          mediaUri: _validationMedia,
        );
        await _playback.playTrack(track, queue: [track]);
        if (_validationSeekMs >= 0) {
          await Future<void>.delayed(const Duration(seconds: 2));
          if (mounted) {
            await _playback.seek(Duration(milliseconds: _validationSeekMs));
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _playback.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sound',
      debugShowCheckedModeBanner: false,
      theme: SoundTheme.light,
      darkTheme: SoundTheme.dark,
      themeMode: ThemeMode.dark,
      home: AppShell(playback: _playback),
    );
  }
}
