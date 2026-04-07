// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'api_endpoint_storage_backend.dart';

class _WebApiEndpointStorageBackend implements ApiEndpointStorageBackend {
  static const _baseUrlKey = 'api_base_url';

  @override
  Future<void> saveBaseUrl(String value) async {
    html.window.localStorage[_baseUrlKey] = value;
  }

  @override
  Future<String?> readBaseUrl() async {
    return html.window.localStorage[_baseUrlKey];
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_baseUrlKey);
  }
}

ApiEndpointStorageBackend createApiEndpointStorageBackend() {
  return _WebApiEndpointStorageBackend();
}
