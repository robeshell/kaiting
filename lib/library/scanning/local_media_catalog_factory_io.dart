import 'dart:io';

import 'file_system_local_media_catalog.dart';
import 'local_media_catalog.dart';
import 'platform_channel_local_media_catalog.dart';
import 'unsupported_local_media_catalog.dart';

LocalMediaCatalog createLocalMediaCatalog() {
  if (Platform.isAndroid) return PlatformChannelLocalMediaCatalog();
  if (Platform.isIOS ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isWindows) {
    return FileSystemLocalMediaCatalog();
  }
  return const UnsupportedLocalMediaCatalog();
}
