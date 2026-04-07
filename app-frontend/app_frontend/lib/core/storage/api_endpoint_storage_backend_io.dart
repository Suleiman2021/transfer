import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_endpoint_storage_backend.dart';

class _IoApiEndpointStorageBackend implements ApiEndpointStorageBackend {
  static const _baseUrlKey = 'api_base_url';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> saveBaseUrl(String value) {
    return _storage.write(key: _baseUrlKey, value: value);
  }

  @override
  Future<String?> readBaseUrl() {
    return _storage.read(key: _baseUrlKey);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: _baseUrlKey);
  }
}

ApiEndpointStorageBackend createApiEndpointStorageBackend() {
  return _IoApiEndpointStorageBackend();
}
