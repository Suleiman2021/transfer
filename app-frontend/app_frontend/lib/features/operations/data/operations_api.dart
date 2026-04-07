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
    String? customerName,
    String? customerPhone,
    String? cashoutProfitPercent,
  }) async {
    final idempotencyKey = 'tx-${DateTime.now().microsecondsSinceEpoch}';

    final body = <String, dynamic>{
      'from_cashbox_id': fromCashboxId,
      'to_cashbox_id': toCashboxId,
      'amount': amount,
      'operation_type': operationType,
      'note': note,
      'idempotency_key': idempotencyKey,
      'source_currency': 'SYP',
      'destination_currency': 'SYP',
      'exchange_rate': '1',
    };
    if ((customerName ?? '').trim().isNotEmpty) {
      body['customer_name'] = customerName!.trim();
    }
    if ((commissionPercent ?? '').trim().isNotEmpty) {
      body['commission_percent'] = commissionPercent!.trim();
    }
    if ((customerPhone ?? '').trim().isNotEmpty) {
      body['customer_phone'] = customerPhone!.trim();
    }
    if ((cashoutProfitPercent ?? '').trim().isNotEmpty) {
      body['cashout_profit_percent'] = cashoutProfitPercent!.trim();
    }

    final json = await ApiClient.postJson('/transfers/', body, token: token);

    return TransferModel.fromJson(json);
  }

  Future<TransferModel> reviewTransfer({
    required String token,
    required String transferId,
    required bool approve,
    String? note,
  }) async {
    final json = await ApiClient.postJson('/transfers/$transferId/review', {
      'action': approve ? 'approve' : 'reject',
      'note': note,
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
