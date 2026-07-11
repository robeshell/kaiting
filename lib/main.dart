import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'app/sound_app.dart';
import 'playback/media_kit_playback_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(SoundApp(engine: MediaKitPlaybackEngine()));
}
