import 'session_storage_backend.dart';
import 'session_storage_backend_stub.dart'
    if (dart.library.html) 'session_storage_backend_web.dart'
    if (dart.library.io) 'session_storage_backend_io.dart';

class SessionStorage {
  const SessionStorage();

  static final SessionStorageBackend _backend = createSessionStorageBackend();

  Future<void> saveToken(String token) {
    return _backend.saveToken(token);
  }

  Future<String?> readToken() {
    return _backend.readToken();
  }

  Future<void> clear() {
    return _backend.clear();
  }
}
