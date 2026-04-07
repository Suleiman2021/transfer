import 'api_endpoint_storage_backend.dart';
import 'api_endpoint_storage_backend_stub.dart'
    if (dart.library.html) 'api_endpoint_storage_backend_web.dart'
    if (dart.library.io) 'api_endpoint_storage_backend_io.dart';

class ApiEndpointStorage {
  const ApiEndpointStorage();

  static final ApiEndpointStorageBackend _backend =
      createApiEndpointStorageBackend();

  Future<void> saveBaseUrl(String value) {
    return _backend.saveBaseUrl(value);
  }

  Future<String?> readBaseUrl() {
    return _backend.readBaseUrl();
  }

  Future<void> clear() {
    return _backend.clear();
  }
}
