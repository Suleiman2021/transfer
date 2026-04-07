import '../../../core/entities/app_models.dart';
import '../../../core/storage/session_storage.dart';
import '../data/auth_api.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  final SessionStorage _storage = const SessionStorage();
  final AuthApi _api = AuthApi();

  @override
  Future<AuthSession?> build() async {
    String? token;
    try {
      token = await _storage.readToken();
    } catch (_) {
      await _storage.clear();
      return null;
    }

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return await _api.me(token);
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    try {
      final session = await _api.login(username: username, password: password);
      await _storage.saveToken(session.token);
      state = AsyncData(session);
    } catch (error) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<void> adminLogin({
    required String username,
    required String password,
  }) async {
    try {
      final session = await _api.adminLogin(
        username: username,
        password: password,
      );
      await _storage.saveToken(session.token);
      state = AsyncData(session);
    } catch (error) {
      state = const AsyncData(null);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AsyncData(null);
  }
}
