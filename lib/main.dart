import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'app/sound_app.dart';
import 'playback/just_audio_playback_engine.dart';
import 'playback/sound_audio_handler.dart';
import 'sources/webdav/webdav_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final audioHandler = await AudioService.init(
    builder: SoundAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.soundplayer.sound_player.audio',
      androidNotificationChannelName: '音乐播放',
      androidNotificationChannelDescription: '播放控制和当前歌曲信息',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  WebDavCache? cache;
  if (!kIsWeb) {
    final cacheDir = Directory(
      '${(await getApplicationCacheDirectory()).path}/webdav',
    );
    cache = WebDavCache(cacheDir: cacheDir);
    await cache.init();
  }

  runApp(
    SoundApp(
      engine: JustAudioPlaybackEngine(webDavCache: cache),
      audioHandler: audioHandler,
    ),
  );
}
