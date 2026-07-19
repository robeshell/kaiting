import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates the default HTTP client for native platforms (IO-based).
http.Client createDefaultWebDavClient() {
  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  return IOClient(httpClient);
}

/// Creates a lenient HTTP client that accepts self-signed certificates.
http.Client createLenientWebDavClient() {
  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..badCertificateCallback = (_, _, _) => true;
  return IOClient(httpClient);
}

/// Parses an HTTP-date string (RFC 1123 / 7231) into [DateTime].
DateTime? parseHttpDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return HttpDate.parse(value).toUtc();
  } on FormatException {
    return null;
  }
}

/// Returns a user-friendly TLS error message when [error] is a [TlsException],
/// or `null` when the error is not TLS-related.
String? tryGetTlsFriendlyMessage(Object error) {
  if (error is! TlsException) return null;
  final text = error.message.toLowerCase();
  if (text.contains('certificate') &&
      (text.contains('verify') || text.contains('unknown'))) {
    return '服务器使用的是自签名证书，请勾选「允许自签名证书」后重试';
  }
  if (text.contains('handshake')) {
    return '无法建立安全连接，请确认服务器地址以 https 开头，或者服务器可能未启用 SSL';
  }
  return 'SSL/TLS 连接失败：${error.message}';
}
