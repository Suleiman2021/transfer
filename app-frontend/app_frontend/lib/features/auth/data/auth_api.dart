import '../../../core/entities/app_models.dart';
import '../../../core/network/api_client.dart';

class AuthApi {
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final json = await ApiClient.postJson('/auth/login', {
      'username': username.trim().toLowerCase(),
      'password': password,
    }, trackActivity: false);

    return AuthSession.fromLoginJson(json, username.trim().toLowerCase());
  }

  Future<AuthSession> adminLogin({
    required String username,
    required String password,
  }) async {
    final json = await ApiClient.postJson('/auth/admin/login', {
      'username': username.trim().toLowerCase(),
      'password': password,
    }, trackActivity: false);

    return AuthSession.fromLoginJson(json, username.trim().toLowerCase());
  }

  Future<AuthSession> me(String token) async {
    final json = await ApiClient.getJson(
      '/auth/me',
      token: token,
      trackActivity: false,
    );
    return AuthSession.fromMeJson(json, token);
  }
}
