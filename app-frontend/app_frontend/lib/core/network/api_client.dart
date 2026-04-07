import 'dart:async';
import 'dart:convert';

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
  static String get baseUrl => normalizeBaseUrl(kApiBaseUrl);

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

  static Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() {
      return http
          .post(
            _buildUri(path),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
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
    final response = await _send(() {
      return http
          .get(
            _buildUri(path),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final parsed = jsonDecode(response.body);
      if (parsed is List<dynamic>) {
        return parsed;
      }
      throw ApiException('استجابة غير متوقعة من الخادم.');
    }

    throw ApiException(_extractErrorMessage(response));
  }

  static Future<Map<String, dynamic>> getJson(
    String path, {
    String? token,
    bool trackActivity = true,
  }) async {
    final response = await _send(() {
      return http
          .get(
            _buildUri(path),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
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
    final response = await _send(() {
      return http
          .delete(
            _buildUri(path),
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
    }, trackActivity: trackActivity);

    return _decodeResponse(response);
  }

  static Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
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
      final parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      throw ApiException('استجابة الخادم غير متوقعة.');
    }

    throw ApiException(_extractErrorMessage(response));
  }

  static String _extractErrorMessage(http.Response response) {
    try {
      final parsed = jsonDecode(response.body);
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
      'Invalid or expired token':
          'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مجددًا.',
      'Invalid token payload':
          'جلسة الدخول غير صالحة. يرجى تسجيل الدخول مجددًا.',
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
      'Unsupported transfer type': 'نوع العملية غير مدعوم.',
      'Customer name and phone are required for customer cashout':
          'اسم العميل ورقم الهاتف مطلوبان لعملية صرف العميل.',
      'Customer cashout must start from one of your accredited cashboxes':
          'عملية صرف العميل يجب أن تبدأ من أحد صناديقك المعتمدة.',
      'Customer cashout must use the same accredited cashbox as destination':
          'في صرف العميل يجب أن تكون الوجهة نفس صندوق المعتمد.',
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
      'Collection must move from accredited cashbox to agent or treasury':
          'التحصيل يجب أن يكون من صندوق معتمد إلى وكيل أو خزنة.',
      'Agent funding must move from treasury to an agent cashbox':
          'تمويل الوكيل يجب أن يكون من الخزنة إلى صندوق وكيل.',
      'Agent collection must move from an agent cashbox to treasury':
          'تحصيل الوكيل يجب أن يكون من صندوق الوكيل إلى الخزنة.',
      'Agent cannot execute this direct transfer route':
          'هذا المسار غير مسموح للوكيل.',
      'Top-up request must target one of your accredited cashboxes':
          'يجب أن تستهدف التعبئة أحد صناديقك المعتمدة.',
      'Collection request must start from one of your accredited cashboxes':
          'يجب أن يبدأ التحصيل من أحد صناديقك المعتمدة.',
      'Invalid commission configuration for this transfer':
          'إعدادات العمولة لهذه العملية غير صالحة.',
      'Ledger entry must be balanced': 'خطأ محاسبي: قيد اليومية غير متوازن.',
    };

    return map[detail];
  }
}
