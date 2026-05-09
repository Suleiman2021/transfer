String apiErrorText(Object error) {
  return error.toString().replaceFirst('ApiException:', '').trim();
}

bool isConnectivityOrServerError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('تعذر الوصول') ||
      text.contains('failed host lookup') ||
      text.contains('socket') ||
      text.contains('connection') ||
      text.contains('timeout') ||
      text.contains('مهلة') ||
      text.contains('xmlhttprequest error');
}

bool isInactiveAccountError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('user is inactive') ||
      text.contains('الحساب غير مفعل') ||
      text.contains('إلغاء تفعيل');
}

String friendlyDataLoadError(
  Object error, {
  required String connectivityMessage,
  required String emptyMessage,
  String? authorizationMessage,
}) {
  final raw = apiErrorText(error);
  final text = raw.toLowerCase();

  if (isConnectivityOrServerError(error)) {
    return connectivityMessage;
  }
  if (authorizationMessage != null &&
      (text.contains('401') || text.contains('403'))) {
    return authorizationMessage;
  }
  if (raw.isEmpty) {
    return emptyMessage;
  }
  return raw;
}
