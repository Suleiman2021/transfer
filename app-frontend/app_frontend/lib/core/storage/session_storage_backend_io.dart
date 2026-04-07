import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_runtime_config.dart';
import 'session_storage_backend.dart';

class _IoSessionStorageBackend implements SessionStorageBackend {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  String get _tokenKey => AppRuntimeConfig.sessionTokenKey;

  @override
  Future<void> saveToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  @override
  Future<String?> readToken() {
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _tokenKey);
  }
}

SessionStorageBackend createSessionStorageBackend() =>
    _IoSessionStorageBackend();
