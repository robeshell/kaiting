enum AppFailureKind {
  offline,
  timeout,
  authentication,
  notFound,
  serverUnavailable,
  permission,
  damagedMedia,
  storage,
  database,
  unknown,
}

enum AppFailureAction { retry, editSource, locateFile, manageStorage, none }

class AppFailure {
  const AppFailure({
    required this.kind,
    required this.title,
    required this.message,
    required this.action,
    required this.rawMessage,
  });

  factory AppFailure.from(Object error, {String? fallbackMessage}) {
    final raw = error.toString().trim();
    return AppFailure.fromMessage(
      raw.isEmpty ? fallbackMessage ?? '发生未知错误' : raw,
    );
  }

  factory AppFailure.fromMessage(String message) {
    final raw = message.trim().isEmpty ? '发生未知错误' : message.trim();
    final value = raw.toLowerCase();

    if (_containsAny(value, const [
      '401',
      '403',
      'unauthorized',
      'forbidden',
      'authentication',
      '认证失败',
      '凭据',
    ])) {
      return AppFailure(
        kind: AppFailureKind.authentication,
        title: '需要重新登录音乐来源',
        message: '服务器拒绝了当前凭据，请在音乐来源中更新用户名或密码。',
        action: AppFailureAction.editSource,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const ['timeout', 'timed out', '连接超时', '请求超时'])) {
      return AppFailure(
        kind: AppFailureKind.timeout,
        title: '连接音乐来源超时',
        message: '服务器暂时没有响应，可以检查网络后重试。',
        action: AppFailureAction.retry,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const [
      'network is unreachable',
      'network unreachable',
      'not connected to internet',
      'internet connection appears to be offline',
      'no address associated with hostname',
      'failed host lookup',
      '网络不可用',
      '没有网络',
      '已离线',
    ])) {
      return AppFailure(
        kind: AppFailureKind.offline,
        title: '当前处于离线状态',
        message: '联网后可从原位置继续；已下载的歌曲仍可播放。',
        action: AppFailureAction.retry,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const [
      '404',
      '410',
      'not found',
      'no such file',
      '文件不存在',
    ])) {
      return AppFailure(
        kind: AppFailureKind.notFound,
        title: '找不到这首歌曲',
        message: '文件可能已移动或删除，请重新扫描对应音乐来源。',
        action: AppFailureAction.locateFile,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const [
      '500',
      '502',
      '503',
      '504',
      'connection refused',
      'connection reset',
      'connection closed',
      'socketexception',
      'clientexception',
      '服务器不可用',
      '无法连接',
    ])) {
      return AppFailure(
        kind: AppFailureKind.serverUnavailable,
        title: '音乐来源暂时不可用',
        message: '应用会保留资料库和播放位置，服务器恢复后可以重试。',
        action: AppFailureAction.retry,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const [
      'permission denied',
      'operation not permitted',
      'security-scoped',
      '权限',
      '授权失效',
    ])) {
      return AppFailure(
        kind: AppFailureKind.permission,
        title: '音乐文件权限已失效',
        message: '请在音乐来源中重新选择或授权该文件夹。',
        action: AppFailureAction.editSource,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const [
      'codec',
      'decoder',
      'malformed',
      'corrupt',
      'unsupported format',
      '无法解码',
      '文件损坏',
      '格式不支持',
    ])) {
      return AppFailure(
        kind: AppFailureKind.damagedMedia,
        title: '无法播放这个音频文件',
        message: '文件可能损坏，或者当前平台不支持它的编码格式。',
        action: AppFailureAction.none,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const [
      'no space left',
      'disk full',
      'storage',
      '磁盘空间',
      '存储空间',
    ])) {
      return AppFailure(
        kind: AppFailureKind.storage,
        title: '存储空间不足',
        message: '请清理临时缓存或释放设备空间后重试。',
        action: AppFailureAction.manageStorage,
        rawMessage: raw,
      );
    }
    if (_containsAny(value, const ['sqlite', 'database', 'drift', '数据库'])) {
      return AppFailure(
        kind: AppFailureKind.database,
        title: '无法读取资料库',
        message: '资料库发生异常，歌曲文件本身不会被删除。',
        action: AppFailureAction.retry,
        rawMessage: raw,
      );
    }
    return AppFailure(
      kind: AppFailureKind.unknown,
      title: '操作没有完成',
      message: '可以重试；如果问题持续出现，请检查网络与音乐来源设置。',
      action: AppFailureAction.retry,
      rawMessage: raw,
    );
  }

  final AppFailureKind kind;
  final String title;
  final String message;
  final AppFailureAction action;
  final String rawMessage;

  bool get isTransient => switch (kind) {
    AppFailureKind.offline ||
    AppFailureKind.timeout ||
    AppFailureKind.serverUnavailable => true,
    _ => false,
  };

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
