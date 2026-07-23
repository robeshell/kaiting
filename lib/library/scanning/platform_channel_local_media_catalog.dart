import 'dart:io';

import 'package:flutter/services.dart';

import 'local_media_catalog.dart';

typedef LocalMediaMethodInvoker =
    Future<Object?> Function(String method, Map<String, Object?> arguments);

class PlatformChannelLocalMediaCatalog implements LocalMediaCatalog {
  PlatformChannelLocalMediaCatalog({LocalMediaMethodInvoker? invoker})
    : _invoker = invoker ?? _invokePlatformMethod;

  static const _channel = MethodChannel(
    'com.kaiting.player/local_directory_access',
  );

  final LocalMediaMethodInvoker _invoker;

  @override
  Future<List<LocalAudioFile>> listAudioFiles(String rootUri) async {
    final result = await _invoker('listAudioFiles', {'rootUri': rootUri});
    if (result is! List<Object?>) {
      throw FormatException('Invalid local audio listing: $result');
    }
    final files = result.map(_audioFileFromResult).toList(growable: false);
    files.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );
    return files;
  }

  @override
  Future<PreparedLocalAudioFile> prepareForMetadata(
    LocalAudioFile audioFile,
  ) async {
    final result = await _invoker('prepareAudioFile', {
      'mediaUri': audioFile.mediaUri,
      'relativePath': audioFile.relativePath,
    });
    if (result is! String || result.isEmpty) {
      throw FormatException('Invalid prepared audio path: $result');
    }
    return PreparedLocalAudioFile(
      File(result),
      onRelease: () => _invoker('releasePreparedAudioFile', {'path': result}),
    );
  }

  static Future<Object?> _invokePlatformMethod(
    String method,
    Map<String, Object?> arguments,
  ) {
    return _channel.invokeMethod<Object?>(method, arguments);
  }
}

LocalAudioFile _audioFileFromResult(Object? result) {
  if (result is! Map<Object?, Object?>) {
    throw FormatException('Invalid local audio file: $result');
  }
  final relativePath = result['relativePath'];
  final mediaUri = result['mediaUri'];
  final modifiedAtMs = result['modifiedAtMs'];
  final contentType = result['contentType'];
  final fileSize = result['fileSize'];
  if (relativePath is! String ||
      mediaUri is! String ||
      modifiedAtMs is! int ||
      (contentType != null && contentType is! String) ||
      (fileSize != null && fileSize is! int)) {
    throw FormatException('Invalid local audio file fields: $result');
  }
  return LocalAudioFile(
    relativePath: relativePath,
    mediaUri: mediaUri,
    modifiedAt: DateTime.fromMillisecondsSinceEpoch(modifiedAtMs, isUtc: true),
    contentType: contentType as String?,
    fileSize: fileSize as int?,
  );
}
