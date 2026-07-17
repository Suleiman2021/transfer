import 'dart:math';

import '../../../core/entities/app_models.dart';
import '../../../core/network/api_client.dart';

class OperationsApi {
  Future<List<CashboxModel>> fetchCashboxes(String token) async {
    final list = await ApiClient.getList('/cashboxes', token: token);
    return list
        .map((e) => CashboxModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommissionRuleModel>> fetchCommissions(String token) async {
    final list = await ApiClient.getList('/commissions', token: token);
    return list
        .map((e) => CommissionRuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> resolveUserCode({
    required String token,
    required String code,
  }) async {
    final json = await ApiClient.getJson(
      '/auth/users/resolve-code?code=${Uri.encodeQueryComponent(code.trim())}',
      token: token,
    );
    return AppUser.fromJson(json);
  }

  Future<AuthSession> changePassword({
    required String token,
    required String currentPassword,
    required String newPassword,
  }) async {
    final json = await ApiClient.patchJson('/auth/me/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    }, token: token);
    return AuthSession.fromMeJson(json, token);
  }

  Future<List<TransferModel>> fetchTransfers(
    String token, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 120,
  }) async {
    final list = await ApiClient.getList(
      '/transfers?${_dateQuery(fromDate: fromDate, toDate: toDate, limit: limit)}',
      token: token,
    );
    return list
        .map((e) => TransferModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransferModel>> fetchPendingTransfers(
    String token, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final list = await ApiClient.getList(
      '/transfers/pending?${_dateQuery(fromDate: fromDate, toDate: toDate, limit: 120)}',
      token: token,
    );
    return list
        .map((e) => TransferModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DailyTransferReportRowModel>> fetchDailyReport(
    String token, {
    DateTime? fromDate,
    DateTime? toDate,
    int limitDays = 30,
  }) async {
    final parts = <String>['limit_days=$limitDays'];
    if (fromDate != null) {
      parts.add('from_date=${_yyyyMmDd(fromDate)}');
    }
    if (toDate != null) {
      parts.add('to_date=${_yyyyMmDd(toDate)}');
    }
    final list = await ApiClient.getList(
      '/transfers/reports/daily?${parts.join('&')}',
      token: token,
    );
    return list
        .map(
          (e) =>
              DailyTransferReportRowModel.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<TransferModel> createTransfer({
    required String token,
    required String fromCashboxId,
    required String toCashboxId,
    required String amount,
    required String operationType,
    String? note,
    String? commissionPercent,
    String sourceCurrency = 'SYP',
  }) async {
    final idempotencyKey =
        'tx-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0xFFFFFF)}';

    final body = <String, dynamic>{
      'from_cashbox_id': fromCashboxId,
      'to_cashbox_id': toCashboxId,
      'amount': amount,
      'operation_type': operationType,
      'note': note,
      'idempotency_key': idempotencyKey,
      'source_currency': sourceCurrency,
    };
    if ((commissionPercent ?? '').trim().isNotEmpty) {
      body['commission_percent'] = commissionPercent!.trim();
    }

    final json = await ApiClient.postJson('/transfers/', body, token: token);

    return TransferModel.fromJson(json);
  }

  Future<TransferModel> createRemittance({
    required String token,
    required String fromCashboxId,
    required String toCashboxId,
    required String amount,
    required String senderName,
    required String senderPhone,
    required String senderCountry,
    required String senderCity,
    required String receiverName,
    required String receiverPhone,
    required String receiverCountry,
    required String receiverCity,
    String? note,
    String sourceCurrency = 'SYP',
  }) async {
    final idempotencyKey =
        'rem-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0xFFFFFF)}';

    final json = await ApiClient.postJson('/transfers/remittance', {
      'from_cashbox_id': fromCashboxId,
      'to_cashbox_id': toCashboxId,
      'amount': amount,
      'sender_name': senderName.trim(),
      'sender_phone': senderPhone.trim(),
      'sender_country': senderCountry.trim(),
      'sender_city': senderCity.trim(),
      'receiver_name': receiverName.trim(),
      'receiver_phone': receiverPhone.trim(),
      'receiver_country': receiverCountry.trim(),
      'receiver_city': receiverCity.trim(),
      'idempotency_key': idempotencyKey,
      'source_currency': sourceCurrency,
      if ((note ?? '').trim().isNotEmpty) 'note': note!.trim(),
    }, token: token);

    return TransferModel.fromJson(json);
  }

  Future<TransferModel> reviewTransfer({
    required String token,
    required String transferId,
    required bool approve,
    String? note,
    String? approvalCode,
  }) async {
    final json = await ApiClient.postJson('/transfers/$transferId/review', {
      'action': approve ? 'approve' : 'reject',
      'note': note,
      if ((approvalCode ?? '').trim().isNotEmpty)
        'approval_code': approvalCode!.trim(),
    }, token: token);

    return TransferModel.fromJson(json);
  }

  static String _dateQuery({
    DateTime? fromDate,
    DateTime? toDate,
    required int limit,
  }) {
    final parts = <String>['limit=$limit'];
    if (fromDate != null) {
      parts.add('from_date=${_yyyyMmDd(fromDate)}');
    }
    if (toDate != null) {
      parts.add('to_date=${_yyyyMmDd(toDate)}');
    }
    return parts.join('&');
  }

  static String _yyyyMmDd(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
