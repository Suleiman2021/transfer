import 'dart:async';
import 'dart:convert';

import '../storage/api_endpoint_storage.dart';
import '../ui/app_activity_bus.dart';
import 'api_config.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  static const ApiEndpointStorage _endpointStorage = ApiEndpointStorage();

  static String get baseUrl => normalizeBaseUrl(kApiBaseUrl);

  static Future<String> resolveBaseUrl() async {
    try {
      final savedBaseUrl = await _endpointStorage.readBaseUrl();
      if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
        return normalizeBaseUrl(savedBaseUrl);
      }
    } catch (_) {
      return baseUrl;
    }
    return baseUrl;
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim();
    if (normalized.isEmpty) {
      normalized = 'http://127.0.0.1:8000';
    }
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        // Required for ngrok free tier — without this header every request
        // receives an HTML interstitial page instead of JSON.
        'ngrok-skip-browser-warning': 'true',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() async {
      return http
          .post(
            await _buildUri(path),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() async {
      return http
          .patch(
            await _buildUri(path),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    return _decodeResponse(response);
  }

  static Future<List<dynamic>> getList(
    String path, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() async {
      return http
          .get(await _buildUri(path), headers: _headers(token: token))
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final parsed = _tryDecodeJson(response);
      if (parsed is List<dynamic>) {
        return parsed;
      }
      throw ApiException(
        _unexpectedResponseMessage(response, expected: 'قائمة بيانات'),
      );
    }

    throw ApiException(_extractErrorMessage(response));
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() async {
      return http
          .get(await _buildUri(path), headers: _headers(token: token))
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() async {
      return http
          .put(
            await _buildUri(path),
            headers: _headers(token: token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    return _decodeResponse(response);
  }

  static Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() async {
      return http
          .delete(await _buildUri(path), headers: _headers(token: token))
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    return _decodeResponse(response);
  }

  static Future<Uri> _buildUri(String path) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final currentBaseUrl = await resolveBaseUrl();
    return Uri.parse('$currentBaseUrl$normalizedPath');
  }

  static Future<http.Response> _send(
    Future<http.Response> Function() action, {
    bool trackActivity = true,
  }) async {
    if (trackActivity) {
      AppActivityBus.begin();
    }
    try {
      return await action();
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال بالخادم، حاول مرة أخرى.');
    } on ApiException {
      rethrow;
    } catch (error) {
      final text = error.toString().toLowerCase();
      if (text.contains('connection refused') ||
          text.contains('failed host lookup') ||
          text.contains('socketexception') ||
          text.contains('clientexception') ||
          text.contains('xmlhttprequest error') ||
          text.contains('errno = 111')) {
        throw ApiException(
          'تعذر الوصول إلى الخادم. تحقق من رابط API واتصال الشبكة.',
        );
      }
      throw ApiException('حدث خطأ أثناء الاتصال بالخادم.');
    } finally {
      if (trackActivity) {
        AppActivityBus.end();
      }
    }
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final parsed = _tryDecodeJson(response);
      // Treat an empty body (204-style) as an empty success object.
      if (parsed == null && response.body.trim().isEmpty) {
        return const {};
      }
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      throw ApiException(
        _unexpectedResponseMessage(response, expected: 'بيانات عملية'),
      );
    }

    throw ApiException(_extractErrorMessage(response));
  }

  static dynamic _tryDecodeJson(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _unexpectedResponseMessage(
    http.Response response, {
    required String expected,
  }) {
    final contentType = response.headers['content-type'] ?? 'غير معروف';
    final body = response.body.trim();
    if (body.isEmpty) {
      return 'رد الخادم فارغ. كان متوقعًا $expected.';
    }
    if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
      return 'رد الخادم صفحة HTML وليس بيانات API. تحقق من رابط API أو ngrok.';
    }
    return 'رد الخادم غير متوقع. كان متوقعًا $expected، ونوع الرد: $contentType.';
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final parsed = _tryDecodeJson(response);
      if (parsed is Map<String, dynamic>) {
        final detail = parsed['detail'];
        if (detail is String && detail.isNotEmpty) {
          final normalized = detail.trim();
          final translated = _translateServerDetail(normalized);
          if (translated != null) return translated;
          if (RegExp(r'[A-Za-z]').hasMatch(normalized)) {
            return 'حدث خطأ من الخادم أثناء تنفيذ الطلب.';
          }
          return normalized;
        }
      }
    } catch (_) {
      // ignore
    }
    return 'خطأ من الخادم (${response.statusCode}).';
  }

  static String? _translateServerDetail(String detail) {
    const map = <String, String>{
      'User is inactive':
          'تم إلغاء تفعيل الحساب من قبل الإدارة. يمكنك عرض السجل فقط.',
      'User is inactive or not found': 'الحساب غير مفعل أو غير موجود.',
      'Invalid credentials': 'اسم المستخدم أو كلمة المرور غير صحيحة.',
      'Admin must use /auth/admin/login endpoint':
          'هذا الحساب إداري. استخدم تسجيل دخول الأدمن.',
      'Only admin can use /auth/admin/login endpoint':
          'هذا الحساب ليس أدمن. استخدم تطبيق العمليات.',
      'Not authenticated':
          'الطلب وصل بدون بيانات الجلسة. يرجى تسجيل الدخول مجددًا.',
      'Invalid or expired token':
          'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجددًا.',
      'Invalid token payload':
          'جلسة الدخول غير صالحة. يرجى تسجيل الدخول مجددًا.',
      'User not found': 'لم يتم العثور على المستخدم.',
      'Cashbox not found': 'الصندوق غير موجود.',
      'Both cashboxes must be active': 'يجب أن يكون الصندوقان مفعّلين.',
      'Cashboxes involved in transfer must be active':
          'يجب أن تكون كل الصناديق المشاركة مفعّلة.',
      'Source and destination cashbox must be different':
          'يجب أن يكون صندوق الإرسال مختلفًا عن صندوق الاستلام.',
      'Insufficient source cashbox balance':
          'الرصيد غير كافٍ في صندوق الإرسال.',
      'Transfer is not pending review':
          'لا يمكن مراجعة هذا الطلب لأنه ليس بانتظار الموافقة.',
      'Transfer not found': 'طلب التحويل غير موجود.',
      'Invalid transfer approval code': 'رمز اعتماد الحوالة غير صحيح.',
      'Transfer approval code is required': 'رمز اعتماد الحوالة مطلوب.',
      'Only completed transfers can be cancelled':
          'يمكن إلغاء العمليات المكتملة فقط.',
      'Only admin can cancel completed transfers':
          'إلغاء العمليات المكتملة متاح للأدمن فقط.',
      'Cannot cancel transfer because destination balance is not enough':
          'لا يمكن إلغاء العملية لأن رصيد صندوق الاستلام غير كافٍ لعكسها.',
      'Cannot cancel transfer because treasury balance is not enough':
          'لا يمكن إلغاء العملية لأن رصيد الخزنة غير كافٍ لعكس العمولة.',
      'Unsupported transfer type': 'نوع العملية غير مدعوم.',
      'You are not allowed to perform this action':
          'ليست لديك صلاحية لتنفيذ هذا الإجراء.',
      'You are not allowed to review this request':
          'ليست لديك صلاحية مراجعة هذا الطلب.',
      'You are not allowed to view this transfer':
          'ليست لديك صلاحية عرض هذه الحوالة.',
      'Network transfers must move between accredited cashboxes':
          'التحويل بين المعتمدين يجب أن يكون بين صناديق معتمدة فقط.',
      'Top-up must move from agent or treasury to an accredited cashbox':
          'التعبئة يجب أن تكون من الوكيل أو الخزنة إلى صندوق معتمد.',
      'Agent funding must move from treasury to an agent cashbox':
          'تمويل الوكيل يجب أن يكون من الخزنة إلى صندوق وكيل.',
      'Agent cannot execute this direct transfer route':
          'هذا المسار غير مسموح للوكيل.',
      'Top-up request must target one of your accredited cashboxes':
          'يجب أن تستهدف التعبئة أحد صناديقك المعتمدة.',
      'Collection request must start from one of your accredited cashboxes':
          'يجب أن يبدأ التحصيل من أحد صناديقك المعتمدة.',
      'Only admin can move balances directly between treasury and agent cashboxes':
          'نقل الرصيد مباشرة بين الخزنة وصندوق الوكيل متاح للأدمن فقط.',
      'Invalid commission configuration for this transfer':
          'إعدادات العمولة لهذه العملية غير صالحة.',
      'Ledger entry must be balanced': 'خطأ محاسبي: قيد اليومية غير متوازن.',
    };

    return map[detail];
  }
}
