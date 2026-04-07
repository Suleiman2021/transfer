enum UserRole { admin, accredited, agent, unknown }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'admin':
      return UserRole.admin;
    case 'accredited':
      return UserRole.accredited;
    case 'agent':
      return UserRole.agent;
    default:
      return UserRole.unknown;
  }
}

String roleApiValue(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'admin';
    case UserRole.accredited:
      return 'accredited';
    case UserRole.agent:
      return 'agent';
    case UserRole.unknown:
      return 'agent';
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.city,
    required this.country,
    required this.username,
  });

  final String token;
  final String userId;
  final String fullName;
  final UserRole role;
  final String city;
  final String country;
  final String username;

  factory AuthSession.fromLoginJson(
    Map<String, dynamic> json,
    String username,
  ) {
    return AuthSession(
      token: json['access_token'] as String,
      userId: json['user_id'].toString(),
      fullName: (json['full_name'] as String?) ?? username,
      role: roleFromString(json['role'] as String?),
      city: (json['city'] as String?) ?? '-',
      country: (json['country'] as String?) ?? '-',
      username: username,
    );
  }

  factory AuthSession.fromMeJson(Map<String, dynamic> json, String token) {
    return AuthSession(
      token: token,
      userId: json['user_id'].toString(),
      fullName: (json['full_name'] as String?) ?? '-',
      role: roleFromString(json['role'] as String?),
      city: (json['city'] as String?) ?? '-',
      country: (json['country'] as String?) ?? '-',
      username: (json['username'] as String?) ?? '-',
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.city,
    required this.country,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String city;
  final String country;
  final bool isActive;
  final String createdAt;

  DateTime? get createdAtDate => DateTime.tryParse(createdAt);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'].toString(),
      username: (json['username'] as String?) ?? '-',
      fullName: (json['full_name'] as String?) ?? '-',
      role: roleFromString(json['role'] as String?),
      city: (json['city'] as String?) ?? '-',
      country: (json['country'] as String?) ?? '-',
      isActive: (json['is_active'] as bool?) ?? false,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

class CashboxModel {
  const CashboxModel({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.type,
    required this.managerUserId,
    required this.managerName,
    required this.balance,
    required this.isActive,
  });

  final String id;
  final String name;
  final String city;
  final String country;
  final String type;
  final String? managerUserId;
  final String? managerName;
  final String balance;
  final bool isActive;

  double get balanceValue => double.tryParse(balance) ?? 0;
  bool get isTreasury => type == 'treasury';
  bool get isAccredited => type == 'accredited';
  bool get isAgent => type == 'agent';

  factory CashboxModel.fromJson(Map<String, dynamic> json) {
    return CashboxModel(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '-',
      city: (json['city'] as String?) ?? '-',
      country: (json['country'] as String?) ?? '-',
      type: (json['type'] as String?) ?? '-',
      managerUserId: json['manager_user_id']?.toString(),
      managerName: json['manager_name'] as String?,
      balance: json['balance'].toString(),
      isActive: (json['is_active'] as bool?) ?? false,
    );
  }
}

class CommissionRuleModel {
  const CommissionRuleModel({
    required this.role,
    required this.internalFeePercent,
    required this.externalFeePercent,
    required this.treasuryToAccreditedFeePercent,
    required this.treasuryToAgentFeePercent,
    required this.treasuryCollectionFromAccreditedFeePercent,
    required this.treasuryCollectionFromAgentFeePercent,
    required this.agentTopupProfitInternalPercent,
    required this.agentTopupProfitExternalPercent,
  });

  final UserRole role;
  final String internalFeePercent;
  final String externalFeePercent;
  final String treasuryToAccreditedFeePercent;
  final String treasuryToAgentFeePercent;
  final String treasuryCollectionFromAccreditedFeePercent;
  final String treasuryCollectionFromAgentFeePercent;
  final String agentTopupProfitInternalPercent;
  final String agentTopupProfitExternalPercent;

  factory CommissionRuleModel.fromJson(Map<String, dynamic> json) {
    return CommissionRuleModel(
      role: roleFromString(json['role'] as String?),
      internalFeePercent: json['internal_fee_percent'].toString(),
      externalFeePercent: json['external_fee_percent'].toString(),
      treasuryToAccreditedFeePercent:
          json['treasury_to_accredited_fee_percent']?.toString() ?? '0',
      treasuryToAgentFeePercent:
          json['treasury_to_agent_fee_percent']?.toString() ?? '0',
      treasuryCollectionFromAccreditedFeePercent:
          json['treasury_collection_from_accredited_fee_percent']?.toString() ??
          '0',
      treasuryCollectionFromAgentFeePercent:
          json['treasury_collection_from_agent_fee_percent']?.toString() ?? '0',
      agentTopupProfitInternalPercent:
          json['agent_topup_profit_internal_percent']?.toString() ??
          json['agent_topup_profit_percent']?.toString() ??
          '0',
      agentTopupProfitExternalPercent:
          json['agent_topup_profit_external_percent']?.toString() ??
          json['agent_topup_profit_percent']?.toString() ??
          '0',
    );
  }
}

class TransferModel {
  const TransferModel({
    required this.id,
    required this.fromCashboxId,
    required this.toCashboxId,
    required this.fromCashboxName,
    required this.toCashboxName,
    required this.fromCashboxType,
    required this.toCashboxType,
    required this.operationType,
    required this.amount,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.agentProfitPercent,
    required this.agentProfitAmount,
    required this.cashoutProfitPercent,
    required this.cashoutProfitAmount,
    required this.isCrossCountry,
    required this.performedById,
    required this.createdAt,
    required this.note,
    required this.customerName,
    required this.customerPhone,
    required this.state,
    required this.reviewRequired,
    required this.riskScore,
  });

  final String id;
  final String fromCashboxId;
  final String toCashboxId;
  final String? fromCashboxName;
  final String? toCashboxName;
  final String? fromCashboxType;
  final String? toCashboxType;
  final String operationType;
  final String amount;
  final String commissionPercent;
  final String commissionAmount;
  final String agentProfitPercent;
  final String agentProfitAmount;
  final String cashoutProfitPercent;
  final String cashoutProfitAmount;
  final bool isCrossCountry;
  final String performedById;
  final String createdAt;
  final String? note;
  final String? customerName;
  final String? customerPhone;
  final String state;
  final bool reviewRequired;
  final String riskScore;

  double get amountValue => double.tryParse(amount) ?? 0;
  double get commissionValue => double.tryParse(commissionAmount) ?? 0;
  double get commissionPercentValue => double.tryParse(commissionPercent) ?? 0;
  double get agentProfitValue => double.tryParse(agentProfitAmount) ?? 0;
  double get agentProfitPercentValue =>
      double.tryParse(agentProfitPercent) ?? 0;
  double get cashoutProfitValue => double.tryParse(cashoutProfitAmount) ?? 0;
  double get cashoutProfitPercentValue =>
      double.tryParse(cashoutProfitPercent) ?? 0;
  double get riskValue => double.tryParse(riskScore) ?? 0;
  String get fromLabel => fromCashboxName ?? fromCashboxId;
  String get toLabel {
    if (operationType == 'customer_cashout' &&
        (customerName ?? '').trim().isNotEmpty) {
      return 'عميل: ${customerName!.trim()}';
    }
    return toCashboxName ?? toCashboxId;
  }

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id'].toString(),
      fromCashboxId: json['from_cashbox_id'].toString(),
      toCashboxId: json['to_cashbox_id'].toString(),
      fromCashboxName: json['from_cashbox_name'] as String?,
      toCashboxName: json['to_cashbox_name'] as String?,
      fromCashboxType: json['from_cashbox_type']?.toString(),
      toCashboxType: json['to_cashbox_type']?.toString(),
      operationType: (json['operation_type'] as String?) ?? 'network_transfer',
      amount: json['amount'].toString(),
      commissionPercent: json['commission_percent']?.toString() ?? '0',
      commissionAmount: json['commission_amount'].toString(),
      agentProfitPercent: json['agent_profit_percent']?.toString() ?? '0',
      agentProfitAmount: json['agent_profit_amount']?.toString() ?? '0',
      cashoutProfitPercent: json['cashout_profit_percent']?.toString() ?? '0',
      cashoutProfitAmount: json['cashout_profit_amount']?.toString() ?? '0',
      isCrossCountry: (json['is_cross_country'] as bool?) ?? false,
      performedById: json['performed_by_id'].toString(),
      createdAt: (json['created_at'] as String?) ?? '',
      note: json['note'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      state: (json['state'] as String?) ?? 'completed',
      reviewRequired: (json['review_required'] as bool?) ?? false,
      riskScore: json['risk_score']?.toString() ?? '0',
    );
  }
}

class DailyTransferReportRowModel {
  const DailyTransferReportRowModel({
    required this.date,
    required this.transfersCount,
    required this.completedCount,
    required this.pendingCount,
    required this.totalAmount,
    required this.totalCommission,
    required this.totalAgentProfit,
    required this.totalCashoutProfit,
  });

  final String date;
  final int transfersCount;
  final int completedCount;
  final int pendingCount;
  final double totalAmount;
  final double totalCommission;
  final double totalAgentProfit;
  final double totalCashoutProfit;

  factory DailyTransferReportRowModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) => double.tryParse(value.toString()) ?? 0;
    int parseInt(dynamic value) => int.tryParse(value.toString()) ?? 0;

    return DailyTransferReportRowModel(
      date: (json['date'] as String?) ?? '',
      transfersCount: parseInt(json['transfers_count']),
      completedCount: parseInt(json['completed_count']),
      pendingCount: parseInt(json['pending_count']),
      totalAmount: parseNum(json['total_amount']),
      totalCommission: parseNum(json['total_commission']),
      totalAgentProfit: parseNum(json['total_agent_profit']),
      totalCashoutProfit: parseNum(json['total_cashout_profit']),
    );
  }
}

class UserTransferReportSummaryModel {
  const UserTransferReportSummaryModel({
    required this.cashboxesCount,
    required this.totalBalance,
    required this.transfersCount,
    required this.completedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.totalAmount,
    required this.totalCommission,
    required this.totalAgentProfit,
    required this.totalCashoutProfit,
    required this.fromDate,
    required this.toDate,
  });

  final int cashboxesCount;
  final double totalBalance;
  final int transfersCount;
  final int completedCount;
  final int pendingCount;
  final int rejectedCount;
  final double totalAmount;
  final double totalCommission;
  final double totalAgentProfit;
  final double totalCashoutProfit;
  final String? fromDate;
  final String? toDate;

  factory UserTransferReportSummaryModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) => double.tryParse(value.toString()) ?? 0;
    int parseInt(dynamic value) => int.tryParse(value.toString()) ?? 0;
    String? parseDate(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty || text == 'null') return null;
      return text;
    }

    return UserTransferReportSummaryModel(
      cashboxesCount: parseInt(json['cashboxes_count']),
      totalBalance: parseNum(json['total_balance']),
      transfersCount: parseInt(json['transfers_count']),
      completedCount: parseInt(json['completed_count']),
      pendingCount: parseInt(json['pending_count']),
      rejectedCount: parseInt(json['rejected_count']),
      totalAmount: parseNum(json['total_amount']),
      totalCommission: parseNum(json['total_commission']),
      totalAgentProfit: parseNum(json['total_agent_profit']),
      totalCashoutProfit: parseNum(json['total_cashout_profit']),
      fromDate: parseDate(json['from_date']),
      toDate: parseDate(json['to_date']),
    );
  }
}

class UserTransferReportModel {
  const UserTransferReportModel({
    required this.user,
    required this.cashboxes,
    required this.transfers,
    required this.dailyRows,
    required this.summary,
  });

  final AppUser user;
  final List<CashboxModel> cashboxes;
  final List<TransferModel> transfers;
  final List<DailyTransferReportRowModel> dailyRows;
  final UserTransferReportSummaryModel summary;

  factory UserTransferReportModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? const {};
    final cashboxesJson = json['cashboxes'] as List<dynamic>? ?? const [];
    final transfersJson = json['transfers'] as List<dynamic>? ?? const [];
    final dailyRowsJson = json['daily_rows'] as List<dynamic>? ?? const [];
    final summaryJson = json['summary'] as Map<String, dynamic>? ?? const {};

    return UserTransferReportModel(
      user: AppUser.fromJson(userJson),
      cashboxes: cashboxesJson
          .map((e) => CashboxModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      transfers: transfersJson
          .map((e) => TransferModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyRows: dailyRowsJson
          .map(
            (e) =>
                DailyTransferReportRowModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      summary: UserTransferReportSummaryModel.fromJson(summaryJson),
    );
  }
}

class RiskAlertModel {
  const RiskAlertModel({
    required this.id,
    required this.transferId,
    required this.userId,
    required this.code,
    required this.severity,
    required this.message,
    required this.requiresReview,
    required this.resolved,
    required this.createdAt,
  });

  final String id;
  final String transferId;
  final String userId;
  final String code;
  final String severity;
  final String message;
  final bool requiresReview;
  final bool resolved;
  final String createdAt;

  factory RiskAlertModel.fromJson(Map<String, dynamic> json) {
    return RiskAlertModel(
      id: json['id'].toString(),
      transferId: json['transfer_id'].toString(),
      userId: json['user_id'].toString(),
      code: (json['code'] as String?) ?? '-',
      severity: (json['severity'] as String?) ?? 'low',
      message: (json['message'] as String?) ?? '-',
      requiresReview: (json['requires_review'] as bool?) ?? false,
      resolved: (json['resolved'] as bool?) ?? false,
      createdAt: (json['created_at'] as String?) ?? '',
    );
  }
}

class TrialBalanceRowModel {
  const TrialBalanceRowModel({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final double debit;
  final double credit;
  final double balance;

  factory TrialBalanceRowModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) => double.tryParse(value.toString()) ?? 0;

    return TrialBalanceRowModel(
      accountId: json['account_id'].toString(),
      accountCode: (json['account_code'] as String?) ?? '-',
      accountName: (json['account_name'] as String?) ?? '-',
      accountType: (json['account_type'] as String?) ?? '-',
      debit: parseNum(json['debit']),
      credit: parseNum(json['credit']),
      balance: parseNum(json['balance']),
    );
  }
}

String moneyText(num value) => value.toStringAsFixed(2);

String transferStateLabelAr(String state) {
  switch (state) {
    case 'initiated':
      return 'تم التسجيل';
    case 'pending_review':
      return 'بانتظار الموافقة';
    case 'approved':
      return 'تمت الموافقة';
    case 'completed':
      return 'مكتملة';
    case 'rejected':
      return 'مرفوضة';
    case 'failed':
      return 'فشلت';
    default:
      return state;
  }
}

String transferTypeLabelAr(String type) {
  switch (type) {
    case 'network_transfer':
      return 'تحويل بين المعتمدين';
    case 'topup':
      return 'تعبئة';
    case 'collection':
      return 'تحصيل';
    case 'agent_funding':
      return 'تمويل وكيل';
    case 'agent_collection':
      return 'تحصيل من وكيل';
    case 'customer_cashout':
      return '\u0635\u0631\u0641 \u0631\u0635\u064a\u062f \u0639\u0645\u064a\u0644';
    default:
      return type;
  }
}

String transferTypeHintAr(String type) {
  switch (type) {
    case 'network_transfer':
      return 'تحويل مباشر بين صندوقين معتمدين.';
    case 'topup':
      return 'تعبئة صندوق معتمد من وكيل أو خزنة.';
    case 'collection':
      return 'تحصيل من صندوق معتمد إلى وكيل أو خزنة.';
    case 'agent_funding':
      return 'تمويل مباشر من الخزنة إلى صندوق وكيل.';
    case 'agent_collection':
      return 'إرجاع سيولة من الوكيل إلى الخزنة.';
    case 'customer_cashout':
      return '\u0635\u0631\u0641 \u0631\u0635\u064a\u062f \u0644\u0639\u0645\u064a\u0644 \u0645\u0639 \u062a\u062d\u062f\u064a\u062f \u0639\u0645\u0648\u0644\u0629 \u062e\u0627\u0635\u0629 \u0628\u0627\u0644\u0645\u0639\u062a\u0645\u062f.';
    default:
      return '';
  }
}

String transferSummaryAr(TransferModel transfer) {
  return '${transfer.fromLabel} -> ${transfer.toLabel}';
}

String riskSeverityLabelAr(String severity) {
  switch (severity) {
    case 'high':
      return 'عالية';
    case 'medium':
      return 'متوسطة';
    case 'low':
      return 'منخفضة';
    default:
      return severity;
  }
}

String riskCodeLabelAr(String code) {
  switch (code) {
    case 'SINGLE_HARD_LIMIT':
      return 'تجاوز الحد الأعلى للعملية';
    case 'SINGLE_SOFT_LIMIT':
      return 'قريب من الحد الأعلى للعملية';
    case 'DAILY_COUNT_LIMIT':
      return 'عدد العمليات اليومية مرتفع';
    case 'DAILY_AMOUNT_LIMIT':
      return 'إجمالي المبالغ اليومية مرتفع';
    case 'CROSS_CITY_PATTERN':
      return 'عملية بين مدينتين مختلفتين';
    default:
      return code;
  }
}

String cashboxTypeLabelAr(String type) {
  switch (type) {
    case 'treasury':
      return 'الخزنة';
    case 'accredited':
      return 'صندوق معتمد';
    case 'agent':
      return 'صندوق وكيل';
    default:
      return type;
  }
}

String roleLabelAr(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'مدير';
    case UserRole.accredited:
      return 'معتمد';
    case UserRole.agent:
      return 'وكيل';
    case UserRole.unknown:
      return 'غير معروف';
  }
}
