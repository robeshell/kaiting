import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WebDavCredentials {
  const WebDavCredentials({required this.username, required this.password});

  final String username;
  final String password;

  bool get isEmpty => username.isEmpty && password.isEmpty;

  String get basicHeaderValue =>
      'Basic ${base64Encode(utf8.encode('$username:$password'))}';

  String toJson() => jsonEncode({'username': username, 'password': password});

  static WebDavCredentials? fromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return WebDavCredentials(
        username: json['username'] as String,
        password: json['password'] as String,
      );
    } catch (_) {
      return null;
    }
  }
}

abstract interface class WebDavCredentialStore {
  Future<WebDavCredentials?> read(String connectionId);

  Future<void> write(String connectionId, WebDavCredentials credentials);

  Future<void> delete(String connectionId);
}

class SecureWebDavCredentialStore implements WebDavCredentialStore {
  SecureWebDavCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String connectionId) => 'sound.webdav.credentials.$connectionId';

  @override
  Future<WebDavCredentials?> read(String connectionId) async {
    return WebDavCredentials.fromJson(
      await _storage.read(key: _key(connectionId)),
    );
  }

  @override
  Future<void> write(String connectionId, WebDavCredentials credentials) async {
    await _storage.write(key: _key(connectionId), value: credentials.toJson());
  }

  @override
  Future<void> delete(String connectionId) async {
    await _storage.delete(key: _key(connectionId));
  }
}

class MemoryWebDavCredentialStore implements WebDavCredentialStore {
  final Map<String, WebDavCredentials> _values = {};

  @override
  Future<WebDavCredentials?> read(String connectionId) async {
    return _values[connectionId];
  }

  @override
  Future<void> write(String connectionId, WebDavCredentials credentials) async {
    _values[connectionId] = credentials;
  }

  @override
  Future<void> delete(String connectionId) async {
    _values.remove(connectionId);
  }
}
