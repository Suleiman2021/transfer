enum UserRole { superAdmin, admin, accredited, agent, unknown }

UserRole roleFromString(String? value) {
  switch (value) {
    case 'super_admin':
      return UserRole.superAdmin;
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
    case UserRole.superAdmin:
      return 'super_admin';
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
    required this.phone,
    required this.username,
  });

  final String token;
  final String userId;
  final String fullName;
  final UserRole role;
  final String city;
  final String country;
  final String? phone;
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
      phone: json['phone'] as String?,
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
      phone: json['phone'] as String?,
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
    required this.phone,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String city;
  final String country;
  final String? phone;
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
      phone: json['phone'] as String?,
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
    required this.isActive,
    this.currencyBalances = const {},
  });

  final String id;
  final String name;
  final String city;
  final String country;
  final String type;
  final String? managerUserId;
  final String? managerName;
  final bool isActive;
  /// Per-currency balances: {"SYP": 500000.0, "USD": 200.0, ...}.
  /// Each currency keeps its own independent balance; there is no conversion.
  final Map<String, double> currencyBalances;

  /// Convenience accessor for the SYP balance (most screens default to SYP).
  double get balanceValue => currencyBalances['SYP'] ?? 0;
  bool get isTreasury => type == 'treasury';
  bool get isAccredited => type == 'accredited';
  bool get isAgent => type == 'agent';

  static Map<String, double> _parseCurrencyBalances(dynamic raw) {
    if (raw == null || raw is! Map) return const {};
    final result = <String, double>{};
    for (final e in raw.entries) {
      final v = double.tryParse(e.value.toString()) ?? 0;
      if (v != 0) result[e.key.toString()] = v;
    }
    return result;
  }

  factory CashboxModel.fromJson(Map<String, dynamic> json) {
    return CashboxModel(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '-',
      city: (json['city'] as String?) ?? '-',
      country: (json['country'] as String?) ?? '-',
      type: (json['type'] as String?) ?? '-',
      managerUserId: json['manager_user_id']?.toString(),
      managerName: json['manager_name'] as String?,
      isActive: (json['is_active'] as bool?) ?? false,
      currencyBalances: _parseCurrencyBalances(json['currency_balances']),
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
    required this.treasuryToAgentInternalFeePercent,
    required this.treasuryToAgentExternalFeePercent,
    required this.treasuryToAccreditedInternalFeePercent,
    required this.treasuryToAccreditedExternalFeePercent,
    required this.remittanceTreasuryPercent,
    required this.remittanceSenderPercent,
    required this.remittanceReceiverPercent,
  });

  final UserRole role;
  final String internalFeePercent;
  final String externalFeePercent;
  final String treasuryToAccreditedFeePercent;
  final String treasuryToAgentFeePercent;
  final String treasuryToAgentInternalFeePercent;
  final String treasuryToAgentExternalFeePercent;
  final String treasuryToAccreditedInternalFeePercent;
  final String treasuryToAccreditedExternalFeePercent;
  final String remittanceTreasuryPercent;
  final String remittanceSenderPercent;
  final String remittanceReceiverPercent;

  factory CommissionRuleModel.fromJson(Map<String, dynamic> json) {
    return CommissionRuleModel(
      role: roleFromString(json['role'] as String?),
      internalFeePercent: json['internal_fee_percent'].toString(),
      externalFeePercent: json['external_fee_percent'].toString(),
      treasuryToAccreditedFeePercent:
          json['treasury_to_accredited_fee_percent']?.toString() ?? '0',
      treasuryToAgentFeePercent:
          json['treasury_to_agent_fee_percent']?.toString() ?? '0',
      treasuryToAgentInternalFeePercent:
          json['treasury_to_agent_internal_fee_percent']?.toString() ?? '0',
      treasuryToAgentExternalFeePercent:
          json['treasury_to_agent_external_fee_percent']?.toString() ?? '0',
      treasuryToAccreditedInternalFeePercent:
          json['treasury_to_accredited_internal_fee_percent']?.toString() ?? '0',
      treasuryToAccreditedExternalFeePercent:
          json['treasury_to_accredited_external_fee_percent']?.toString() ?? '0',
      remittanceTreasuryPercent:
          json['remittance_treasury_percent']?.toString() ?? '0',
      remittanceSenderPercent:
          json['remittance_sender_percent']?.toString() ?? '0',
      remittanceReceiverPercent:
          json['remittance_receiver_percent']?.toString() ?? '0',
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
    required this.isCrossCountry,
    required this.performedById,
    required this.createdAt,
    required this.note,
    required this.state,
    required this.reviewRequired,
    required this.approvalCodeRequired,
    required this.approvalCode,
    required this.riskScore,
    this.sourceCurrency = 'SYP',
    this.senderName,
    this.senderPhone,
    this.senderCountry,
    this.senderCity,
    this.receiverName,
    this.receiverPhone,
    this.receiverCountry,
    this.receiverCity,
    this.receiverCommissionPercent = '0',
    this.receiverCommissionAmount = '0',
    this.senderCommissionPercent = '0',
    this.senderCommissionAmount = '0',
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
  final bool isCrossCountry;
  final String performedById;
  final String createdAt;
  final String? note;
  final String state;
  final bool reviewRequired;
  final bool approvalCodeRequired;
  final String? approvalCode;
  final String riskScore;
  final String sourceCurrency;
  final String? senderName;
  final String? senderPhone;
  final String? senderCountry;
  final String? senderCity;
  final String? receiverName;
  final String? receiverPhone;
  final String? receiverCountry;
  final String? receiverCity;
  final String receiverCommissionPercent;
  final String receiverCommissionAmount;
  final String senderCommissionPercent;
  final String senderCommissionAmount;

  double get amountValue => double.tryParse(amount) ?? 0;
  double get commissionValue => double.tryParse(commissionAmount) ?? 0;
  double get commissionPercentValue => double.tryParse(commissionPercent) ?? 0;
  double get agentProfitValue => double.tryParse(agentProfitAmount) ?? 0;
  double get agentProfitPercentValue =>
      double.tryParse(agentProfitPercent) ?? 0;
  double get riskValue => double.tryParse(riskScore) ?? 0;
  String get fromLabel => fromCashboxName ?? fromCashboxId;
  String get toLabel {
    if (operationType == 'remittance' &&
        (receiverName ?? '').trim().isNotEmpty) {
      return 'حوالة: ${receiverName!.trim()}';
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
      operationType: (json['operation_type'] as String?) ?? 'topup',
      amount: json['amount'].toString(),
      commissionPercent: json['commission_percent']?.toString() ?? '0',
      commissionAmount: json['commission_amount'].toString(),
      agentProfitPercent: json['agent_profit_percent']?.toString() ?? '0',
      agentProfitAmount: json['agent_profit_amount']?.toString() ?? '0',
      isCrossCountry: (json['is_cross_country'] as bool?) ?? false,
      performedById: json['performed_by_id'].toString(),
      createdAt: (json['created_at'] as String?) ?? '',
      note: json['note'] as String?,
      state: (json['state'] as String?) ?? 'completed',
      reviewRequired: (json['review_required'] as bool?) ?? false,
      approvalCodeRequired: (json['approval_code_required'] as bool?) ?? false,
      approvalCode: json['approval_code'] as String?,
      riskScore: json['risk_score']?.toString() ?? '0',
      sourceCurrency: (json['source_currency'] as String?) ?? 'SYP',
      senderName: json['sender_name'] as String?,
      senderPhone: json['sender_phone'] as String?,
      senderCountry: json['sender_country'] as String?,
      senderCity: json['sender_city'] as String?,
      receiverName: json['receiver_name'] as String?,
      receiverPhone: json['receiver_phone'] as String?,
      receiverCountry: json['receiver_country'] as String?,
      receiverCity: json['receiver_city'] as String?,
      receiverCommissionPercent:
          json['receiver_commission_percent']?.toString() ?? '0',
      receiverCommissionAmount:
          json['receiver_commission_amount']?.toString() ?? '0',
      senderCommissionPercent:
          json['sender_commission_percent']?.toString() ?? '0',
      senderCommissionAmount:
          json['sender_commission_amount']?.toString() ?? '0',
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
  });

  final String date;
  final int transfersCount;
  final int completedCount;
  final int pendingCount;
  final double totalAmount;
  final double totalCommission;
  final double totalAgentProfit;

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
    );
  }
}

class UserTransferReportSummaryModel {
  const UserTransferReportSummaryModel({
    required this.cashboxesCount,
    required this.totalBalances,
    required this.transfersCount,
    required this.completedCount,
    required this.pendingCount,
    required this.rejectedCount,
    required this.totalAmount,
    required this.totalCommission,
    required this.totalAgentProfit,
    required this.fromDate,
    required this.toDate,
  });

  final int cashboxesCount;
  /// Per-currency balance totals across the user's cashboxes (no conversion).
  final Map<String, double> totalBalances;
  final int transfersCount;
  final int completedCount;
  final int pendingCount;
  final int rejectedCount;
  final double totalAmount;
  final double totalCommission;
  final double totalAgentProfit;
  final String? fromDate;
  final String? toDate;

  /// SYP total convenience accessor for screens that show a single figure.
  double get totalBalanceSyp => totalBalances['SYP'] ?? 0;

  factory UserTransferReportSummaryModel.fromJson(Map<String, dynamic> json) {
    double parseNum(dynamic value) => double.tryParse(value.toString()) ?? 0;
    int parseInt(dynamic value) => int.tryParse(value.toString()) ?? 0;
    String? parseDate(dynamic value) {
      final text = value?.toString();
      if (text == null || text.isEmpty || text == 'null') return null;
      return text;
    }

    Map<String, double> parseBalances(dynamic raw) {
      if (raw is! Map) return const {};
      final result = <String, double>{};
      for (final e in raw.entries) {
        result[e.key.toString()] = double.tryParse(e.value.toString()) ?? 0;
      }
      return result;
    }

    return UserTransferReportSummaryModel(
      cashboxesCount: parseInt(json['cashboxes_count']),
      totalBalances: parseBalances(json['total_balances']),
      transfersCount: parseInt(json['transfers_count']),
      completedCount: parseInt(json['completed_count']),
      pendingCount: parseInt(json['pending_count']),
      rejectedCount: parseInt(json['rejected_count']),
      totalAmount: parseNum(json['total_amount']),
      totalCommission: parseNum(json['total_commission']),
      totalAgentProfit: parseNum(json['total_agent_profit']),
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
    required this.currency,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final String currency;
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
      currency: (json['currency'] as String?) ?? 'SYP',
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
      return 'فشلت/ملغاة';
    default:
      return state;
  }
}

String transferTypeLabelAr(String type) {
  switch (type) {
    case 'topup':
      return 'تعبئة';
    case 'agent_funding':
      return 'تمويل وكيل';
    case 'remittance':
      return '\u062d\u0648\u0627\u0644\u0629 \u0639\u0645\u064a\u0644';
    default:
      return type;
  }
}

String transferTypeHintAr(String type) {
  switch (type) {
    case 'topup':
      return 'تعبئة صندوق معتمد من وكيل أو خزنة.';
    case 'agent_funding':
      return 'تمويل مباشر من الخزنة إلى صندوق وكيل.';
    case 'remittance':
      return '\u062d\u0648\u0627\u0644\u0629 \u0639\u0645\u064a\u0644 \u0645\u0646 \u0645\u0639\u062a\u0645\u062f \u0625\u0644\u0649 \u0645\u0639\u062a\u0645\u062f \u0622\u062e\u0631 \u0645\u0639 \u062a\u0642\u0633\u064a\u0645 \u0627\u0644\u0639\u0645\u0648\u0644\u0629.';
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
    case UserRole.superAdmin:
      return 'مدير رئيسي';
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
