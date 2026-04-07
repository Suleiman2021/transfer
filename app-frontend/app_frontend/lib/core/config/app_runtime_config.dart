enum ClientAppType { admin, operations }

class AppRuntimeConfig {
  AppRuntimeConfig._();

  static ClientAppType _appType = ClientAppType.operations;

  static void initialize(ClientAppType type) {
    _appType = type;
  }

  static ClientAppType get appType => _appType;

  static bool get isAdminApp => _appType == ClientAppType.admin;

  static String get sessionTokenKey =>
      isAdminApp ? 'session_token_admin_app' : 'session_token_operations_app';

  static String get appTitle =>
      isAdminApp ? 'لوحة تحكم الأدمن' : 'تطبيق المعتمدين والوكلاء';
}
