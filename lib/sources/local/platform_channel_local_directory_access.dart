import 'package:flutter/services.dart';

import 'local_directory_access.dart';

typedef LocalDirectoryMethodInvoker =
    Future<Object?> Function(String method, Map<String, Object?> arguments);

class PlatformChannelLocalDirectoryAccess implements LocalDirectoryAccess {
  PlatformChannelLocalDirectoryAccess({LocalDirectoryMethodInvoker? invoker})
    : _invoker = invoker ?? _invokePlatformMethod;

  static const _channel = MethodChannel(
    'com.kaiting.player/local_directory_access',
  );

  final LocalDirectoryMethodInvoker _invoker;

  @override
  Future<LocalDirectoryGrant?> pickDirectory() async {
    final result = await _invoker('pickDirectory', const {});
    return result == null ? null : _grantFromResult(result);
  }

  @override
  Future<LocalDirectoryGrant> restoreDirectory({
    required String rootUri,
    Uint8List? permissionToken,
  }) async {
    final result = await _invoker('restoreDirectory', {
      'rootUri': rootUri,
      'permissionToken': permissionToken,
    });
    if (result == null) {
      throw const FormatException('Missing directory restore result.');
    }
    return _grantFromResult(result);
  }

  @override
  Future<void> releaseDirectory(String rootUri) async {
    await _invoker('releaseDirectory', {'rootUri': rootUri});
  }

  static Future<Object?> _invokePlatformMethod(
    String method,
    Map<String, Object?> arguments,
  ) {
    return _channel.invokeMethod<Object?>(method, arguments);
  }

  LocalDirectoryGrant _grantFromResult(Object result) {
    if (result is! Map<Object?, Object?>) {
      throw FormatException('Invalid directory grant: $result');
    }
    final rootUri = result['rootUri'];
    final displayName = result['displayName'];
    final statusName = result['status'];
    final token = result['permissionToken'];
    if (rootUri is! String ||
        displayName is! String ||
        statusName is! String ||
        (token != null && token is! Uint8List)) {
      throw FormatException('Invalid directory grant fields: $result');
    }
    return LocalDirectoryGrant(
      rootUri: rootUri,
      displayName: displayName,
      status: LocalDirectoryAccessStatus.values.byName(statusName),
      permissionToken: token as Uint8List?,
      isStale: result['isStale'] == true,
    );
  }
}
