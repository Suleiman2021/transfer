// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import '../config/app_runtime_config.dart';
import 'session_storage_backend.dart';

class _WebSessionStorageBackend implements SessionStorageBackend {
  String get _tokenKey => AppRuntimeConfig.sessionTokenKey;

  @override
  Future<void> saveToken(String token) async {
    html.window.localStorage[_tokenKey] = token;
  }

  @override
  Future<String?> readToken() async {
    return html.window.localStorage[_tokenKey];
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_tokenKey);
  }
}

SessionStorageBackend createSessionStorageBackend() =>
    _WebSessionStorageBackend();
