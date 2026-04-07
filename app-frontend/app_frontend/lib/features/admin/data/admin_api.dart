import '../../../core/entities/app_models.dart';
import '../../../core/network/api_client.dart';

class AdminApi {
  Future<List<AppUser>> fetchUsers(
    String token, {
    UserRole? role,
    String? search,
    bool trackActivity = true,
  }) async {
    final query = <String>[];
    if (role != null && role != UserRole.unknown) {
      query.add('role=${roleApiValue(role)}');
    }
    final searchValue = (search ?? '').trim();
    if (searchValue.isNotEmpty) {
      query.add('search=${Uri.encodeQueryComponent(searchValue)}');
    }
    final path = query.isEmpty
        ? '/admin/users'
        : '/admin/users?${query.join('&')}';
    final list = await ApiClient.getList(
      path,
      token: token,
      trackActivity: trackActivity,
    );
    return list
        .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppUser> createUser({
    required String token,
    required String username,
    required String fullName,
    required UserRole role,
    required String city,
    required String country,
    required String password,
  }) async {
    final json = await ApiClient.postJson('/admin/users', {
      'username': username.trim().toLowerCase(),
      'full_name': fullName.trim(),
      'role': roleApiValue(role),
      'city': city.trim().toLowerCase(),
      'country': country.trim().toLowerCase(),
      'password': password,
    }, token: token);
    return AppUser.fromJson(json);
  }

  Future<AppUser> deactivateUser({
    required String token,
    required String userId,
  }) async {
    final json = await ApiClient.deleteJson(
      '/admin/users/$userId',
      token: token,
    );
    return AppUser.fromJson(json);
  }

  Future<AppUser> activateUser({
    required String token,
    required String userId,
  }) async {
    final json = await ApiClient.postJson(
      '/admin/users/$userId/activate',
      const <String, dynamic>{},
      token: token,
    );
    return AppUser.fromJson(json);
  }

  Future<UserTransferReportModel> fetchUserReport(
    String token, {
    required String userId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 200,
    int limitDays = 45,
  }) async {
    final query = <String>['limit=$limit', 'limit_days=$limitDays'];
    if (fromDate != null) {
      query.add('from_date=${_yyyyMmDd(fromDate)}');
    }
    if (toDate != null) {
      query.add('to_date=${_yyyyMmDd(toDate)}');
    }
    final path = '/admin/users/$userId/report?${query.join('&')}';
    final json = await ApiClient.getJson(path, token: token);
    return UserTransferReportModel.fromJson(json);
  }

  Future<List<CashboxModel>> fetchCashboxes(
    String token, {
    bool trackActivity = true,
  }) async {
    final list = await ApiClient.getList(
      '/admin/cashboxes',
      token: token,
      trackActivity: trackActivity,
    );
    return list
        .map((e) => CashboxModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CashboxModel> createCashbox({
    required String token,
    required String name,
    required String city,
    required String country,
    required String type,
    String? managerUserId,
    required String openingBalance,
  }) async {
    final json = await ApiClient.postJson('/admin/cashboxes', {
      'name': name.trim(),
      'city': city.trim().toLowerCase(),
      'country': country.trim().toLowerCase(),
      'type': type,
      'manager_user_id': managerUserId,
      'opening_balance': openingBalance,
    }, token: token);
    return CashboxModel.fromJson(json);
  }

  Future<List<CommissionRuleModel>> fetchCommissions(
    String token, {
    bool trackActivity = true,
  }) async {
    final list = await ApiClient.getList(
      '/admin/commissions',
      token: token,
      trackActivity: trackActivity,
    );
    return list
        .map((e) => CommissionRuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CommissionRuleModel> saveCommission({
    required String token,
    required UserRole role,
    required String internalFeePercent,
    required String externalFeePercent,
    required String agentTopupProfitInternalPercent,
    required String agentTopupProfitExternalPercent,
    String? treasuryToAccreditedFeePercent,
    String? treasuryToAgentFeePercent,
    String? treasuryCollectionFromAccreditedFeePercent,
    String? treasuryCollectionFromAgentFeePercent,
  }) async {
    final body = <String, dynamic>{
      'role': roleApiValue(role),
      'internal_fee_percent': internalFeePercent.trim(),
      'external_fee_percent': externalFeePercent.trim(),
      'agent_topup_profit_internal_percent': agentTopupProfitInternalPercent
          .trim(),
      'agent_topup_profit_external_percent': agentTopupProfitExternalPercent
          .trim(),
    };
    if ((treasuryToAccreditedFeePercent ?? '').trim().isNotEmpty) {
      body['treasury_to_accredited_fee_percent'] =
          treasuryToAccreditedFeePercent!.trim();
    }
    if ((treasuryToAgentFeePercent ?? '').trim().isNotEmpty) {
      body['treasury_to_agent_fee_percent'] = treasuryToAgentFeePercent!.trim();
    }
    if ((treasuryCollectionFromAccreditedFeePercent ?? '').trim().isNotEmpty) {
      body['treasury_collection_from_accredited_fee_percent'] =
          treasuryCollectionFromAccreditedFeePercent!.trim();
    }
    if ((treasuryCollectionFromAgentFeePercent ?? '').trim().isNotEmpty) {
      body['treasury_collection_from_agent_fee_percent'] =
          treasuryCollectionFromAgentFeePercent!.trim();
    }
    final json = await ApiClient.postJson(
      '/admin/commissions',
      body,
      token: token,
    );
    return CommissionRuleModel.fromJson(json);
  }

  Future<List<TransferModel>> fetchPendingTransfers(
    String token, {
    DateTime? fromDate,
    DateTime? toDate,
    bool trackActivity = true,
  }) async {
    final list = await ApiClient.getList(
      '/transfers/pending?${_dateQuery(fromDate: fromDate, toDate: toDate, limit: 120)}',
      token: token,
      trackActivity: trackActivity,
    );
    return list
        .map((e) => TransferModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TransferModel>> fetchRecentTransfers(
    String token, {
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 200,
    bool trackActivity = true,
  }) async {
    final list = await ApiClient.getList(
      '/transfers?${_dateQuery(fromDate: fromDate, toDate: toDate, limit: limit)}',
      token: token,
      trackActivity: trackActivity,
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
    bool trackActivity = true,
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
      trackActivity: trackActivity,
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

  Future<List<RiskAlertModel>> fetchRiskAlerts(
    String token, {
    bool trackActivity = true,
  }) async {
    final list = await ApiClient.getList(
      '/risk/alerts?resolved=false&limit=200',
      token: token,
      trackActivity: trackActivity,
    );
    return list
        .map((e) => RiskAlertModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TrialBalanceRowModel>> fetchTrialBalance(
    String token, {
    bool trackActivity = true,
  }) async {
    final list = await ApiClient.getList(
      '/ledger/trial-balance',
      token: token,
      trackActivity: trackActivity,
    );
    return list
        .map((e) => TrialBalanceRowModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
