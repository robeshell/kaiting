import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract interface class MediaNotificationPermission {
  Future<bool> ensureGranted();
}

/// Requests Android 13+ notification access when playback first becomes
/// active. Other platforms expose system media controls without this runtime
/// permission.
class PlatformMediaNotificationPermission
    implements MediaNotificationPermission {
  static const _channel = MethodChannel(
    'com.kaiting.player/system_media',
  );

  Future<bool>? _request;

  @override
  Future<bool> ensureGranted() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return Future<bool>.value(true);
    }
    return _request ??= _requestAndroidPermission();
  }

  Future<bool> _requestAndroidPermission() async {
    try {
      return await _channel.invokeMethod<bool>(
            'ensureNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
