abstract class SessionStorageBackend {
  Future<void> saveToken(String token);
  Future<String?> readToken();
  Future<void> clear();
}
