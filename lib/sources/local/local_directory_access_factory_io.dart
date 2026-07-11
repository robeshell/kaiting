import 'dart:io';

import 'file_system_local_directory_access.dart';
import 'local_directory_access.dart';
import 'platform_channel_local_directory_access.dart';
import 'unsupported_local_directory_access.dart';

LocalDirectoryAccess createLocalDirectoryAccess() {
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    return PlatformChannelLocalDirectoryAccess();
  }
  if (Platform.isWindows || Platform.isLinux) {
    return FileSystemLocalDirectoryAccess();
  }
  return const UnsupportedLocalDirectoryAccess();
}
