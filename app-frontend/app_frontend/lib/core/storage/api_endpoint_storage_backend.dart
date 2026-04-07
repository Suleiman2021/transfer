abstract class ApiEndpointStorageBackend {
  Future<void> saveBaseUrl(String value);
  Future<String?> readBaseUrl();
  Future<void> clear();
}
