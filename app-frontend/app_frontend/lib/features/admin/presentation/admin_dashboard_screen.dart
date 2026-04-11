import '../../../core/entities/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_activity_bus.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/validation/app_validators.dart';
import '../../../core/utils/report_pdf.dart';
import '../../../core/widgets/app_load_error_card.dart';
import '../../../core/widgets/app_shell_background.dart';
import '../../../core/widgets/dashboard_navigation.dart';
import '../../../core/widgets/responsive_frame.dart';
import '../../../core/widgets/reveal_on_mount.dart';
import '../../auth/logic/auth_controller.dart';
import '../data/admin_api.dart';
import 'admin_user_report_screen.dart';
import 'widgets/admin_dashboard_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key, required this.session});
  final AuthSession session;
  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  final AdminApi _api = AdminApi();
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  bool _loading = true;
  String? _loadError;
  String? _reviewingTransferId;

  List<AppUser> _users = const [];
  List<CashboxModel> _cashboxes = const [];
  List<TransferModel> _pendingTransfers = const [];
  List<TransferModel> _recentTransfers = const [];
  List<TrialBalanceRowModel> _trialBalanceRows = const [];
  List<DailyTransferReportRowModel> _dailyReport = const [];

  DateTime? _fromDate;
  DateTime? _toDate;

  final _userFormKey = GlobalKey<FormState>();
  final _uUsername = TextEditingController();
  final _uFullName = TextEditingController();
  final _uCity = TextEditingController();
  final _uCountry = TextEditingController(text: 'syria');
  final _uPassword = TextEditingController();
  UserRole _uRole = UserRole.agent;

  final _cashboxFormKey = GlobalKey<FormState>();
  final _cName = TextEditingController();
  final _cCity = TextEditingController();
  final _cCountry = TextEditingController(text: 'syria');
  final _cOpening = TextEditingController(text: '0');
  final _cManagerSearch = TextEditingController();
  String _cType = 'accredited';
  String? _cManagerId;

  final _userSearch = TextEditingController();
  UserRole? _userFilterRole;
  DateTime? _userCreatedFromDate;
  DateTime? _userCreatedToDate;
  String? _deletingUserId;
  String? _activatingUserId;

  final _routeAmount = TextEditingController();
  final _routeNote = TextEditingController();
  final _routeCommissionPercent = TextEditingController(text: '0');
  String _routeType = 'topup';
  String? _routeTargetCashboxId;
  bool _routeCommissionManuallyEdited = false;
  final _routeByNameSearch = TextEditingController();
  final _routeByNameAmount = TextEditingController();
  final _routeByNameNote = TextEditingController();
  final _routeByNameCommissionPercent = TextEditingController(text: '0');
  String _routeByNameType = 'topup';
  String? _routeByNameUserId;
  String? _routeByNameCashboxId;
  bool _routeByNameCommissionManuallyEdited = false;

  final _accreditedInternal = TextEditingController();
  final _accreditedExternal = TextEditingController();
  final _agentInternal = TextEditingController();
  final _agentExternal = TextEditingController();
  final _agentTopupProfitInternal = TextEditingController();
  final _agentTopupProfitExternal = TextEditingController();
  final _accreditedTransferProfitInternal = TextEditingController();
  final _accreditedTransferProfitExternal = TextEditingController();
  final _treasuryToAccreditedFee = TextEditingController(text: '0');
  final _treasuryToAgentFee = TextEditingController(text: '0');
  final _treasuryCollectionFromAccreditedFee = TextEditingController(text: '0');
  final _treasuryCollectionFromAgentFee = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _revision.dispose();
    _uUsername.dispose();
    _uFullName.dispose();
    _uCity.dispose();
    _uCountry.dispose();
    _uPassword.dispose();
    _cName.dispose();
    _cCity.dispose();
    _cCountry.dispose();
    _cOpening.dispose();
    _cManagerSearch.dispose();
    _userSearch.dispose();
    _routeAmount.dispose();
    _routeNote.dispose();
    _routeCommissionPercent.dispose();
    _routeByNameSearch.dispose();
    _routeByNameAmount.dispose();
    _routeByNameNote.dispose();
    _routeByNameCommissionPercent.dispose();
    _accreditedInternal.dispose();
    _accreditedExternal.dispose();
    _agentInternal.dispose();
    _agentExternal.dispose();
    _agentTopupProfitInternal.dispose();
    _agentTopupProfitExternal.dispose();
    _accreditedTransferProfitInternal.dispose();
    _accreditedTransferProfitExternal.dispose();
    _treasuryToAccreditedFee.dispose();
    _treasuryToAgentFee.dispose();
    _treasuryCollectionFromAccreditedFee.dispose();
    _treasuryCollectionFromAgentFee.dispose();
    super.dispose();
  }

  void _bumpRevision() => _revision.value++;

  void _setViewState(VoidCallback mutation) {
    if (!mounted) return;
    setState(mutation);
    _bumpRevision();
  }

  List<AppUser> get _accreditedUsers =>
      _users.where((u) => u.role == UserRole.accredited).toList();
  List<AppUser> get _agentUsers =>
      _users.where((u) => u.role == UserRole.agent).toList();
  List<CashboxModel> get _accreditedCashboxes =>
      _cashboxes.where((c) => c.isAccredited).toList();
  List<CashboxModel> get _agentCashboxes =>
      _cashboxes.where((c) => c.isAgent).toList();
  CashboxModel? get _treasury => _cashboxes.where((c) => c.isTreasury).isEmpty
      ? null
      : _cashboxes.firstWhere((c) => c.isTreasury);
  List<AppUser> get _cashboxManagerCandidates {
    if (_cType == 'accredited') return _accreditedUsers;
    if (_cType == 'agent') return _agentUsers;
    return const <AppUser>[];
  }

  List<AppUser> get _filteredCashboxManagerCandidates {
    final term = _cManagerSearch.text.trim().toLowerCase();
    final options = _cashboxManagerCandidates;
    if (term.isEmpty) return options;
    return options.where((u) {
      final haystack = '${u.fullName} ${u.username} ${u.city} ${u.country}'
          .toLowerCase();
      return haystack.contains(term);
    }).toList();
  }

  List<CashboxModel> get _routeTargets {
    switch (_routeType) {
      case 'topup':
      case 'collection':
        return _accreditedCashboxes;
      case 'agent_funding':
      case 'agent_collection':
        return _agentCashboxes;
      default:
        return const [];
    }
  }

  CashboxModel? get _routeTargetCashbox {
    final targetId = _routeTargetCashboxId;
    if (targetId == null) return null;
    for (final cashbox in _cashboxes) {
      if (cashbox.id == targetId) return cashbox;
    }
    return null;
  }

  UserRole _routeTargetRoleFor(String routeType) {
    switch (routeType) {
      case 'topup':
      case 'collection':
        return UserRole.accredited;
      case 'agent_funding':
      case 'agent_collection':
        return UserRole.agent;
      default:
        return UserRole.unknown;
    }
  }

  String _routeTargetCashboxTypeFor(String routeType) {
    switch (routeType) {
      case 'topup':
      case 'collection':
        return 'accredited';
      case 'agent_funding':
      case 'agent_collection':
        return 'agent';
      default:
        return '';
    }
  }

  List<AppUser> get _routeByNameUserOptions {
    final role = _routeTargetRoleFor(_routeByNameType);
    final cashboxType = _routeTargetCashboxTypeFor(_routeByNameType);
    final term = _routeByNameSearch.text.trim().toLowerCase();
    return _users.where((user) {
      if (!user.isActive) return false;
      if (user.role != role) return false;
      final hasManagedCashbox = _cashboxes.any(
        (cashbox) =>
            cashbox.isActive &&
            cashbox.managerUserId == user.id &&
            cashbox.type == cashboxType,
      );
      if (!hasManagedCashbox) return false;
      if (term.isEmpty) return true;
      final haystack =
          '${user.fullName} ${user.username} ${user.city} ${user.country}'
              .toLowerCase();
      return haystack.contains(term);
    }).toList();
  }

  AppUser? get _routeByNameSelectedUser {
    final userId = _routeByNameUserId;
    if (userId == null) return null;
    for (final user in _users) {
      if (user.id == userId) return user;
    }
    return null;
  }

  List<CashboxModel> get _routeByNameCashboxOptions {
    final userId = _routeByNameUserId;
    if (userId == null) return const [];
    final expectedType = _routeTargetCashboxTypeFor(_routeByNameType);
    return _cashboxes.where((cashbox) {
      return cashbox.isActive &&
          cashbox.managerUserId == userId &&
          cashbox.type == expectedType;
    }).toList();
  }

  CashboxModel? get _routeByNameCashbox {
    final cashboxId = _routeByNameCashboxId;
    if (cashboxId == null) return null;
    for (final cashbox in _cashboxes) {
      if (cashbox.id == cashboxId) return cashbox;
    }
    return null;
  }

  double _parseNumber(String? value) {
    final raw = (value ?? '').trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  double _round2(double value) => double.parse(value.toStringAsFixed(2));
  String _fmt2(double value) => value.toStringAsFixed(2);

  double _defaultRouteCommissionPercentForType(String routeType) {
    switch (routeType) {
      case 'topup':
        return _parseNumber(_treasuryToAccreditedFee.text);
      case 'agent_funding':
        return _parseNumber(_treasuryToAgentFee.text);
      case 'collection':
        return _parseNumber(_treasuryCollectionFromAccreditedFee.text);
      case 'agent_collection':
        return _parseNumber(_treasuryCollectionFromAgentFee.text);
      default:
        return 0;
    }
  }

  double _defaultRouteCommissionPercent() {
    final treasury = _treasury;
    final target = _routeTargetCashbox;
    if (treasury == null || target == null) return 0;
    return _defaultRouteCommissionPercentForType(_routeType);
  }

  void _applyDefaultRouteCommissionPercent({bool force = false}) {
    if (force || !_routeCommissionManuallyEdited) {
      _routeCommissionPercent.text = _fmt2(_defaultRouteCommissionPercent());
    }
  }

  void _applyDefaultRouteByNameCommissionPercent({bool force = false}) {
    if (force || !_routeByNameCommissionManuallyEdited) {
      _routeByNameCommissionPercent.text = _fmt2(
        _defaultRouteCommissionPercentForType(_routeByNameType),
      );
    }
  }

  void _syncRouteByNameSelection() {
    if (!_routeByNameUserOptions.any((user) => user.id == _routeByNameUserId)) {
      _routeByNameUserId = _routeByNameUserOptions.isEmpty
          ? null
          : _routeByNameUserOptions.first.id;
    }

    if (!_routeByNameCashboxOptions.any(
      (cashbox) => cashbox.id == _routeByNameCashboxId,
    )) {
      _routeByNameCashboxId = _routeByNameCashboxOptions.isEmpty
          ? null
          : _routeByNameCashboxOptions.first.id;
    }

    _applyDefaultRouteByNameCommissionPercent();
  }

  _AdminRoutePreview _buildRoutePreviewFor({
    required String routeType,
    required String? targetCashboxId,
    required String amountText,
    required String commissionPercentText,
  }) {
    final treasury = _treasury;
    final target = _cashboxes
        .where((cashbox) => cashbox.id == targetCashboxId)
        .firstOrNull;
    final requestedAmount = _round2(_parseNumber(amountText));
    final commissionPercent = _round2(_parseNumber(commissionPercentText));
    final splitInput = routeType == 'topup' || routeType == 'agent_funding';

    final sourceName = (routeType == 'topup' || routeType == 'agent_funding')
        ? (treasury?.name ?? '-')
        : (target?.name ?? '-');
    final destinationName =
        (routeType == 'topup' || routeType == 'agent_funding')
        ? (target?.name ?? '-')
        : (treasury?.name ?? '-');

    late final double netAmount;
    late final double commissionAmount;
    late final double senderDeduction;
    late final double recipientCredit;

    if (splitInput) {
      final denominator = 1 + (commissionPercent / 100);
      netAmount = _round2(
        denominator <= 0 ? requestedAmount : requestedAmount / denominator,
      );
      commissionAmount = _round2(netAmount * commissionPercent / 100);
      senderDeduction = requestedAmount;
      recipientCredit = netAmount;
    } else {
      netAmount = requestedAmount;
      commissionAmount = _round2(netAmount * commissionPercent / 100);
      senderDeduction = _round2(requestedAmount + commissionAmount);
      recipientCredit = netAmount;
    }

    return _AdminRoutePreview(
      operationLabel: transferTypeLabelAr(routeType),
      sourceName: sourceName,
      destinationName: destinationName,
      requestedAmount: requestedAmount,
      commissionPercent: commissionPercent,
      commissionAmount: commissionAmount,
      senderDeduction: senderDeduction,
      recipientCredit: recipientCredit,
      splitInput: splitInput,
    );
  }

  _AdminRoutePreview _buildRoutePreview() {
    return _buildRoutePreviewFor(
      routeType: _routeType,
      targetCashboxId: _routeTargetCashboxId,
      amountText: _routeAmount.text,
      commissionPercentText: _routeCommissionPercent.text,
    );
  }

  _AdminRouteResolution? _resolveRouteEndpoints(
    String routeType,
    String? targetCashboxId,
  ) {
    final treasury = _treasury;
    if (treasury == null || targetCashboxId == null) return null;
    switch (routeType) {
      case 'topup':
      case 'agent_funding':
        return _AdminRouteResolution(
          fromCashboxId: treasury.id,
          toCashboxId: targetCashboxId,
        );
      case 'collection':
      case 'agent_collection':
        return _AdminRouteResolution(
          fromCashboxId: targetCashboxId,
          toCashboxId: treasury.id,
        );
      default:
        return null;
    }
  }

  Future<bool> _confirmRoutePreview(_AdminRoutePreview preview) async {
    FocusScope.of(context).unfocus();
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تأكيد تنفيذ الحوالة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _routePreviewLine('العملية', preview.operationLabel),
                  _routePreviewLine('من', preview.sourceName),
                  _routePreviewLine('إلى', preview.destinationName),
                  const Divider(height: 18),
                  _routePreviewLine(
                    preview.splitInput
                        ? 'المبلغ الإجمالي المدخل'
                        : 'المبلغ المدخل',
                    moneyText(preview.requestedAmount),
                  ),
                  _routePreviewLine(
                    'عمولة الخزنة',
                    '${moneyText(preview.commissionAmount)} (${_fmt2(preview.commissionPercent)}%)',
                  ),
                  _routePreviewLine(
                    'الخصم من رصيد المرسل',
                    moneyText(preview.senderDeduction),
                  ),
                  _routePreviewLine(
                    'الصافي الواصل للمستلم',
                    moneyText(preview.recipientCredit),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('تأكيد التنفيذ'),
              ),
            ],
          ),
        );
      },
    );
    return approved ?? false;
  }

  Widget _routePreviewLine(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              color: emphasize ? AppTheme.brandTeal : AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }

  List<AppUser> get _visibleUsers {
    final term = _userSearch.text.trim().toLowerCase();
    return _users.where((u) {
      if (_userFilterRole != null && u.role != _userFilterRole) return false;
      final created = u.createdAtDate?.toLocal();
      if (_userCreatedFromDate != null || _userCreatedToDate != null) {
        if (created == null) return false;
        final createdDate = DateTime(created.year, created.month, created.day);
        if (_userCreatedFromDate != null) {
          final fromDate = DateTime(
            _userCreatedFromDate!.year,
            _userCreatedFromDate!.month,
            _userCreatedFromDate!.day,
          );
          if (createdDate.isBefore(fromDate)) return false;
        }
        if (_userCreatedToDate != null) {
          final toDate = DateTime(
            _userCreatedToDate!.year,
            _userCreatedToDate!.month,
            _userCreatedToDate!.day,
          );
          if (createdDate.isAfter(toDate)) return false;
        }
      }
      if (term.isEmpty) return true;
      final haystack = '${u.fullName} ${u.username} ${u.city} ${u.country}'
          .toLowerCase();
      return haystack.contains(term);
    }).toList();
  }

  double get _networkBalance => _cashboxes
      .where((c) => !c.isTreasury)
      .fold(0, (sum, c) => sum + c.balanceValue);
  double get _commissionRevenue {
    if (_dailyReport.isNotEmpty) {
      return _dailyReport.fold(0.0, (sum, row) => sum + row.totalCommission);
    }
    final row = _trialBalanceRows.where(
      (r) => r.accountCode == 'REV_COMMISSION',
    );
    if (row.isEmpty) return 0;
    return row.first.credit - row.first.debit;
  }

  String _dateText(DateTime? value) {
    if (value == null) return 'غير محدد';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDate: _fromDate ?? now,
    );
    if (selected != null) {
      _setViewState(() => _fromDate = selected);
    }
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDate: _toDate ?? _fromDate ?? now,
    );
    if (selected != null) {
      _setViewState(() => _toDate = selected);
    }
  }

  Future<void> _pickUserCreatedFromDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 8),
      lastDate: DateTime(now.year + 1),
      initialDate: _userCreatedFromDate ?? now,
    );
    if (selected != null) {
      _setViewState(() => _userCreatedFromDate = selected);
    }
  }

  Future<void> _pickUserCreatedToDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 8),
      lastDate: DateTime(now.year + 1),
      initialDate: _userCreatedToDate ?? _userCreatedFromDate ?? now,
    );
    if (selected != null) {
      _setViewState(() => _userCreatedToDate = selected);
    }
  }

  void _resetUserFilters() {
    _setViewState(() {
      _userFilterRole = null;
      _userCreatedFromDate = null;
      _userCreatedToDate = null;
      _userSearch.clear();
    });
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
      _bumpRevision();
    }

    try {
      final token = widget.session.token;
      final usersFuture = _api.fetchUsers(token, trackActivity: false);
      final cashboxesFuture = _api.fetchCashboxes(token, trackActivity: false);
      final commissionsFuture = _api.fetchCommissions(
        token,
        trackActivity: false,
      );
      final pendingFuture = _api.fetchPendingTransfers(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        trackActivity: false,
      );
      final recentFuture = _api.fetchRecentTransfers(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        trackActivity: false,
      );
      final dailyFuture = _api.fetchDailyReport(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        limitDays: 45,
        trackActivity: false,
      );
      final trialFuture = _api.fetchTrialBalance(token, trackActivity: false);

      final users = await usersFuture;
      final cashboxes = await cashboxesFuture;
      final commissions = await commissionsFuture;
      final pendingTransfers = await pendingFuture;
      final recentTransfers = await recentFuture;
      final dailyRows = await dailyFuture;
      final trialBalanceRows = await trialFuture;

      CommissionRuleModel? accreditedRule;
      CommissionRuleModel? agentRule;
      CommissionRuleModel? adminRule;
      for (final rule in commissions) {
        if (rule.role == UserRole.accredited) accreditedRule = rule;
        if (rule.role == UserRole.agent) agentRule = rule;
        if (rule.role == UserRole.admin) adminRule = rule;
      }

      if (!mounted) return;
      setState(() {
        _users = users;
        _cashboxes = cashboxes;
        _pendingTransfers = pendingTransfers;
        _recentTransfers = recentTransfers;
        _dailyReport = dailyRows;
        _trialBalanceRows = trialBalanceRows;

        _accreditedInternal.text = accreditedRule?.internalFeePercent ?? '1.25';
        _accreditedExternal.text = accreditedRule?.externalFeePercent ?? '1.75';
        _accreditedTransferProfitInternal.text =
            accreditedRule?.agentTopupProfitInternalPercent ?? '0.50';
        _accreditedTransferProfitExternal.text =
            accreditedRule?.agentTopupProfitExternalPercent ?? '0.75';
        _agentInternal.text = agentRule?.internalFeePercent ?? '2.00';
        _agentExternal.text = agentRule?.externalFeePercent ?? '2.50';
        _agentTopupProfitInternal.text =
            agentRule?.agentTopupProfitInternalPercent ?? '0.75';
        _agentTopupProfitExternal.text =
            agentRule?.agentTopupProfitExternalPercent ?? '1.00';
        _treasuryToAccreditedFee.text =
            adminRule?.treasuryToAccreditedFeePercent ?? '0';
        _treasuryToAgentFee.text = adminRule?.treasuryToAgentFeePercent ?? '0';
        _treasuryCollectionFromAccreditedFee.text =
            adminRule?.treasuryCollectionFromAccreditedFeePercent ?? '0';
        _treasuryCollectionFromAgentFee.text =
            adminRule?.treasuryCollectionFromAgentFeePercent ?? '0';

        if (!_routeTargets.any((c) => c.id == _routeTargetCashboxId)) {
          _routeTargetCashboxId = _routeTargets.isEmpty
              ? null
              : _routeTargets.first.id;
        }
        _applyDefaultRouteCommissionPercent(force: true);
        _syncRouteByNameSelection();
      });
      _bumpRevision();
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = _friendlyLoadError(error));
        _bumpRevision();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _bumpRevision();
      }
    }
  }

  String _friendlyLoadError(Object error) {
    final raw = error.toString().replaceFirst('ApiException:', '').trim();
    final text = raw.toLowerCase();
    if (text.contains('تعذر الوصول') ||
        text.contains('failed host lookup') ||
        text.contains('socket') ||
        text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('مهلة')) {
      return 'تعذر الاتصال بالشبكة أو الخادم. تحقق من الإنترنت ورابط API ثم أعد المحاولة.';
    }
    if (text.contains('401') || text.contains('403')) {
      return 'تعذر تحميل بيانات الأدمن بسبب صلاحيات الوصول. سجّل الدخول مجددًا.';
    }
    if (raw.isEmpty) {
      return 'حدث خطأ غير متوقع أثناء تحميل البيانات.';
    }
    return raw;
  }

  void _showError(String message) {
    if (!mounted) return;
    AppNotifier.error(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AppNotifier.success(context, message);
  }

  void _closeInputSectionIfOpen() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _createUser() async {
    if (!_userFormKey.currentState!.validate()) return;
    try {
      await _api.createUser(
        token: widget.session.token,
        username: _uUsername.text,
        fullName: _uFullName.text,
        role: _uRole,
        city: _uCity.text,
        country: _uCountry.text,
        password: _uPassword.text,
      );
      _uUsername.clear();
      _uFullName.clear();
      _uCity.clear();
      _uPassword.clear();
      _showSuccess('تم إنشاء المستخدم بنجاح');
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _deactivateUser(AppUser user) async {
    _setViewState(() => _deletingUserId = user.id);
    try {
      await _api.deactivateUser(token: widget.session.token, userId: user.id);
      _showSuccess(
        'تم إلغاء تفعيل المستخدم مع الإبقاء على كل السجلات المالية.',
      );
      await _loadData();
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        _setViewState(() => _deletingUserId = null);
      }
    }
  }

  Future<void> _confirmDeactivateUser(AppUser user) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء تفعيل المستخدم'),
        content: Text(
          'سيتم إلغاء تفعيل حساب ${user.fullName} دون حذف سجلاته أو حركته المالية. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إلغاء التفعيل'),
          ),
        ],
      ),
    );
    if (approved == true) {
      await _deactivateUser(user);
    }
  }

  Future<void> _activateUser(AppUser user) async {
    _setViewState(() => _activatingUserId = user.id);
    try {
      await _api.activateUser(token: widget.session.token, userId: user.id);
      _showSuccess('تمت إعادة تفعيل المستخدم بنجاح.');
      await _loadData();
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        _setViewState(() => _activatingUserId = null);
      }
    }
  }

  Future<void> _confirmActivateUser(AppUser user) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تفعيل المستخدم'),
        content: Text(
          'سيتم إعادة تفعيل حساب ${user.fullName}. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );
    if (approved == true) {
      await _activateUser(user);
    }
  }

  Future<void> _createCashbox() async {
    if (!_cashboxFormKey.currentState!.validate()) return;
    final validManagerId =
        _cashboxManagerCandidates.any((u) => u.id == _cManagerId)
        ? _cManagerId
        : null;
    if (_cType != 'treasury' && validManagerId == null) {
      _showError('اختر مسؤولًا مطابقًا للدور المحدد.');
      return;
    }
    try {
      await _api.createCashbox(
        token: widget.session.token,
        name: _cName.text,
        city: _cCity.text,
        country: _cCountry.text,
        type: _cType,
        managerUserId: _cType == 'treasury' ? null : validManagerId,
        openingBalance: _cOpening.text,
      );
      _cName.clear();
      _cCity.clear();
      _cOpening.text = '0';
      _setViewState(() => _cManagerId = null);
      _showSuccess('تم إنشاء الصندوق بنجاح');
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _saveCommissions() async {
    final checks = <String?>[
      AppValidators.percent(_accreditedInternal.text),
      AppValidators.percent(_accreditedExternal.text),
      AppValidators.percent(_accreditedTransferProfitInternal.text),
      AppValidators.percent(_accreditedTransferProfitExternal.text),
      AppValidators.percent(_agentInternal.text),
      AppValidators.percent(_agentExternal.text),
      AppValidators.percent(_agentTopupProfitInternal.text),
      AppValidators.percent(_agentTopupProfitExternal.text),
      AppValidators.percent(_treasuryToAccreditedFee.text),
      AppValidators.percent(_treasuryToAgentFee.text),
      AppValidators.percent(_treasuryCollectionFromAccreditedFee.text),
      AppValidators.percent(_treasuryCollectionFromAgentFee.text),
    ];
    final firstError = checks.whereType<String>().firstOrNull;
    if (firstError != null) {
      _showError(firstError);
      return;
    }
    try {
      await _api.saveCommission(
        token: widget.session.token,
        role: UserRole.accredited,
        internalFeePercent: _accreditedInternal.text,
        externalFeePercent: _accreditedExternal.text,
        agentTopupProfitInternalPercent: _accreditedTransferProfitInternal.text,
        agentTopupProfitExternalPercent: _accreditedTransferProfitExternal.text,
      );
      await _api.saveCommission(
        token: widget.session.token,
        role: UserRole.agent,
        internalFeePercent: _agentInternal.text,
        externalFeePercent: _agentExternal.text,
        agentTopupProfitInternalPercent: _agentTopupProfitInternal.text,
        agentTopupProfitExternalPercent: _agentTopupProfitExternal.text,
      );
      await _api.saveCommission(
        token: widget.session.token,
        role: UserRole.admin,
        internalFeePercent: '0',
        externalFeePercent: '0',
        agentTopupProfitInternalPercent: '0',
        agentTopupProfitExternalPercent: '0',
        treasuryToAccreditedFeePercent: _treasuryToAccreditedFee.text,
        treasuryToAgentFeePercent: _treasuryToAgentFee.text,
        treasuryCollectionFromAccreditedFeePercent:
            _treasuryCollectionFromAccreditedFee.text,
        treasuryCollectionFromAgentFeePercent:
            _treasuryCollectionFromAgentFee.text,
      );
      _showSuccess('تم حفظ العمولات');
      await _loadData();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _createTreasuryRoute() async {
    if (_treasury == null) {
      return _showError('الخزنة غير متوفرة');
    }
    if (_routeTargetCashboxId == null) {
      return _showError('اختر الصندوق الهدف أولاً');
    }
    final amountError = AppValidators.amount(_routeAmount.text);
    if (amountError != null) return _showError(amountError);
    final commissionError = AppValidators.percent(_routeCommissionPercent.text);
    if (commissionError != null) return _showError(commissionError);
    final endpoints = _resolveRouteEndpoints(_routeType, _routeTargetCashboxId);
    if (endpoints == null) {
      return _showError('نوع العملية غير معروف');
    }

    final confirmed = await _confirmRoutePreview(_buildRoutePreview());
    if (!confirmed) return;

    try {
      final transfer = await _api.createTransfer(
        token: widget.session.token,
        fromCashboxId: endpoints.fromCashboxId,
        toCashboxId: endpoints.toCashboxId,
        amount: _routeAmount.text.trim(),
        operationType: _routeType,
        note: _routeNote.text.trim().isEmpty ? null : _routeNote.text.trim(),
        commissionPercent: _routeCommissionPercent.text.trim(),
      );
      _routeAmount.clear();
      _routeNote.clear();
      _showSuccess(
        transfer.state == 'pending_review'
            ? 'تم إرسال الطلب بانتظار موافقة المستلم.'
            : 'تم تنفيذ العملية بنجاح.',
      );
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _createTreasuryRouteByName() async {
    if (_treasury == null) {
      return _showError('الخزنة غير متوفرة');
    }
    if (_routeByNameUserId == null) {
      return _showError('اختر المستخدم أولاً');
    }
    if (_routeByNameCashboxId == null) {
      return _showError('لم يتم تحديد صندوق صاحب الاسم.');
    }
    final amountError = AppValidators.amount(_routeByNameAmount.text);
    if (amountError != null) return _showError(amountError);
    final commissionError = AppValidators.percent(
      _routeByNameCommissionPercent.text,
    );
    if (commissionError != null) return _showError(commissionError);

    final endpoints = _resolveRouteEndpoints(
      _routeByNameType,
      _routeByNameCashboxId,
    );
    if (endpoints == null) {
      return _showError('نوع العملية غير معروف');
    }

    final preview = _buildRoutePreviewFor(
      routeType: _routeByNameType,
      targetCashboxId: _routeByNameCashboxId,
      amountText: _routeByNameAmount.text,
      commissionPercentText: _routeByNameCommissionPercent.text,
    );
    final confirmed = await _confirmRoutePreview(preview);
    if (!confirmed) return;

    try {
      final transfer = await _api.createTransfer(
        token: widget.session.token,
        fromCashboxId: endpoints.fromCashboxId,
        toCashboxId: endpoints.toCashboxId,
        amount: _routeByNameAmount.text.trim(),
        operationType: _routeByNameType,
        note: _routeByNameNote.text.trim().isEmpty
            ? null
            : _routeByNameNote.text.trim(),
        commissionPercent: _routeByNameCommissionPercent.text.trim(),
      );
      _routeByNameAmount.clear();
      _routeByNameNote.clear();
      _showSuccess(
        transfer.state == 'pending_review'
            ? 'تم إرسال الطلب بانتظار موافقة المستلم.'
            : 'تم تنفيذ العملية بنجاح.',
      );
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _reviewTransfer(TransferModel transfer, bool approve) async {
    _setViewState(() => _reviewingTransferId = transfer.id);
    try {
      await _api.reviewTransfer(
        token: widget.session.token,
        transferId: transfer.id,
        approve: approve,
        note: approve ? 'اعتماد من المدير' : 'رفض من المدير',
      );
      _showSuccess(approve ? 'تم الاعتماد' : 'تم الرفض');
      await _loadData();
    } catch (error) {
      _showError(error.toString());
    } finally {
      _setViewState(() => _reviewingTransferId = null);
    }
  }

  Future<void> _printReports() async {
    try {
      await printReportPdf(
        title: 'تقرير المدير',
        transfers: _recentTransfers,
        dailyRows: _dailyReport,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _openSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required WidgetBuilder builder,
  }) {
    AppActivityBus.begin();
    Future<void>.delayed(const Duration(milliseconds: 220), AppActivityBus.end);
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DashboardSectionScreen(
          title: title,
          subtitle: subtitle,
          icon: icon,
          revisionListenable: _revision,
          onRefresh: _loadData,
          childBuilder: (sectionContext) {
            if (_loadError != null) {
              return AppLoadErrorCard(
                title: 'تعذر تحميل بيانات القسم',
                subtitle: 'تحقق من الشبكة ثم أعد المحاولة.',
                message: _loadError!,
                onRetry: _loadData,
              );
            }
            return builder(sectionContext);
          },
        ),
      ),
    );
  }

  Future<void> _openUserReport(AppUser user) {
    AppActivityBus.begin();
    Future<void>.delayed(const Duration(milliseconds: 220), AppActivityBus.end);
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AdminUserReportScreen(token: widget.session.token, user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gap = ResponsiveFrame.sectionGap(context);

    return Scaffold(
      body: AppShellBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              children: [
                ResponsiveFrame(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RevealOnMount(
                        delay: const Duration(milliseconds: 50),
                        child: AdminHeroHeader(
                          title: 'لوحة المدير',
                          subtitle:
                              'إدارة المستخدمين، العمولات، التقارير، ومسارات الخزنة بواجهة منظمة.',
                          userLine:
                              '${widget.session.fullName} - ${widget.session.city} / ${widget.session.country}',
                          onLogout: () => ref
                              .read(authControllerProvider.notifier)
                              .logout(),
                        ),
                      ),
                      SizedBox(height: gap),
                      if (_loading)
                        const AdminSectionCard(
                          title: 'جاري التحميل',
                          subtitle: 'يتم جلب بيانات لوحة المدير الآن',
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                              ),
                            ),
                          ),
                        )
                      else if (_loadError != null)
                        AppLoadErrorCard(
                          title: 'تعذر تحميل لوحة المدير',
                          subtitle: 'تحقق من الاتصال ثم أعد تحميل البيانات.',
                          message: _loadError!,
                          onRetry: _loadData,
                        )
                      else ...[
                        _buildOverviewMetrics(),
                        SizedBox(height: gap),
                        _buildMainSectionsCard(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewMetrics() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 760
            ? (constraints.maxWidth - 8) / 2
            : 108.0;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'المستخدمون',
                value: _users.length.toString(),
                hint: 'جميع الحسابات',
                icon: Icons.people_alt_rounded,
                accent: AppTheme.brandTeal,
              ),
            ),
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'الصناديق',
                value: _cashboxes.length.toString(),
                hint: 'خزنة ومعتمد ووكيل',
                icon: Icons.inventory_2_rounded,
                accent: AppTheme.brandCoral,
              ),
            ),
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'رصيد الشبكة',
                value: moneyText(_networkBalance),
                hint: 'بدون رصيد الخزنة',
                icon: Icons.account_balance_wallet_rounded,
                accent: AppTheme.brandGold,
              ),
            ),
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'إيراد العمولة',
                value: moneyText(_commissionRevenue),
                hint: 'من دليل القيود',
                icon: Icons.paid_rounded,
                accent: AppTheme.brandPlum,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainSectionsCard() {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMainGroup(
            title: 'إدارة المستخدمين',
            subtitle: 'كل وظيفة ضمن شاشة مستقلة عبر زر مخصص',
            actions: [
              _buildActionButton(
                icon: Icons.search_rounded,
                label: 'بحث المستخدمين',
                onTap: () => _openSection(
                  title: 'بحث المستخدمين',
                  subtitle: 'فلترة وبحث مع بطاقة مستخدم تفصيلية',
                  icon: Icons.search_rounded,
                  builder: (_) => _buildUserFilterSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'إضافة مستخدم',
                onTap: () => _openSection(
                  title: 'إضافة مستخدم',
                  subtitle: 'إنشاء حساب جديد',
                  icon: Icons.person_add_alt_1_rounded,
                  builder: (_) => _buildUserForm(),
                ),
              ),
              _buildActionButton(
                icon: Icons.add_business_rounded,
                label: 'إضافة صندوق',
                onTap: () => _openSection(
                  title: 'إضافة صندوق',
                  subtitle: 'إنشاء صندوق معتمد أو وكيل أو خزنة',
                  icon: Icons.add_business_rounded,
                  builder: (_) => _buildCashboxForm(),
                ),
              ),
              _buildActionButton(
                icon: Icons.people_alt_rounded,
                label: 'قائمة المستخدمين',
                onTap: () => _openSection(
                  title: 'قائمة المستخدمين',
                  subtitle: 'نتائج البحث والفلترة',
                  icon: Icons.people_alt_rounded,
                  builder: (_) => _buildUsersList(),
                ),
              ),
              _buildActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'قائمة الصناديق',
                onTap: () => _openSection(
                  title: 'قائمة الصناديق',
                  subtitle: 'عرض الصناديق المسجلة',
                  icon: Icons.account_balance_wallet_rounded,
                  builder: (_) => _buildCashboxesList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMainGroup(
            title: 'العمليات',
            subtitle: 'كل قسم تشغيلي بواجهة تفصيلية مستقلة',
            actions: [
              _buildActionButton(
                icon: Icons.account_balance_rounded,
                label: 'مسارات الخزنة',
                onTap: () => _openSection(
                  title: 'مسارات الخزنة',
                  subtitle: 'تمويل وتحصيل الصناديق',
                  icon: Icons.account_balance_rounded,
                  builder: (_) => _buildTreasuryRoutesSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.person_search_rounded,
                label: 'تنفيذ حسب الاسم',
                onTap: () => _openSection(
                  title: 'تنفيذ حسب الاسم',
                  subtitle: 'بحث عن المستلم وتنفيذ مسار الخزنة مباشرة',
                  icon: Icons.person_search_rounded,
                  builder: (_) => _buildTreasuryRouteByNameSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.pending_actions_rounded,
                label: 'الطلبات المعلقة',
                badge: _pendingTransfers.length.toString(),
                onTap: () => _openSection(
                  title: 'الطلبات المعلقة',
                  subtitle: 'اعتماد أو رفض الطلبات',
                  icon: Icons.pending_actions_rounded,
                  builder: (_) => _buildPendingRequests(),
                ),
              ),
              _buildActionButton(
                icon: Icons.history_rounded,
                label: 'سجل التحويلات',
                onTap: () => _openSection(
                  title: 'سجل التحويلات',
                  subtitle: 'نتائج التحويلات ضمن الفترة الحالية',
                  icon: Icons.history_rounded,
                  builder: (_) => _buildRecentTransfers(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMainGroup(
            title: 'التقارير والإعدادات',
            subtitle: 'فلترة، تقارير يومية، PDF، وضبط العمولات',
            actions: [
              _buildActionButton(
                icon: Icons.space_dashboard_rounded,
                label: 'مؤشرات سريعة',
                onTap: () => _openSection(
                  title: 'مؤشرات سريعة',
                  subtitle: 'ملخص الأرقام الأساسية',
                  icon: Icons.space_dashboard_rounded,
                  builder: (_) => _buildMetricsSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.bar_chart_rounded,
                label: 'التقارير',
                onTap: () => _openSection(
                  title: 'التقارير',
                  subtitle: 'بحث بالتاريخ وتقارير يومية وطباعة PDF',
                  icon: Icons.bar_chart_rounded,
                  builder: (_) => _buildReportsSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.percent_rounded,
                label: 'ضبط العمولات',
                onTap: () => _openSection(
                  title: 'ضبط العمولات',
                  subtitle: 'عمولات داخلية وخارجية وربح الوكيل',
                  icon: Icons.percent_rounded,
                  builder: (_) => _buildCommissionSettingsSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.settings_rounded,
                label: 'معلومات النظام',
                onTap: () => _openSection(
                  title: 'معلومات النظام',
                  subtitle: 'بيانات الحساب الحالي',
                  icon: Icons.settings_rounded,
                  builder: (_) => _buildSystemInfoSection(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainGroup({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AdminSectionCard(
        title: title,
        subtitle: subtitle,
        child: Wrap(spacing: 8, runSpacing: 8, children: actions),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return SizedBox(
      width: 165,
      child: OutlinedButton(
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.brandCoral.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() => AdminSectionCard(
    title: 'مؤشرات سريعة',
    subtitle: 'أهم أرقام الشبكة بشكل مصغر',
    child: _buildOverviewMetrics(),
  );

  Widget _buildDateFilterControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromDate,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text('من: ${_dateText(_fromDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickToDate,
                icon: const Icon(Icons.event_note_rounded, size: 18),
                label: Text('إلى: ${_dateText(_toDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('بحث'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _setViewState(() {
                    _fromDate = null;
                    _toDate = null;
                  });
                  _loadData();
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('إعادة تعيين'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserFilterSection() {
    final hasAnyFilter =
        _userFilterRole != null ||
        _userCreatedFromDate != null ||
        _userCreatedToDate != null ||
        _userSearch.text.trim().isNotEmpty;
    final users = hasAnyFilter
        ? _visibleUsers.take(20).toList()
        : const <AppUser>[];

    return Column(
      children: [
        _buildUsersFilterCard(showSearchField: true),
        const SizedBox(height: 10),
        _buildUsersResultCard(
          title: 'نتائج البحث',
          subtitle: hasAnyFilter
              ? 'تم العثور على ${users.length} مستخدم ضمن الفلترة الحالية'
              : 'أدخل اسمًا أو اختر دورًا أو تاريخ إضافة للبدء',
          users: users,
          emptyText: hasAnyFilter
              ? 'لا توجد نتائج مطابقة للفلترة الحالية.'
              : 'اكتب نص البحث أو استخدم فلترة الدور/تاريخ الإضافة.',
        ),
      ],
    );
  }

  Widget _buildUsersFilterCard({required bool showSearchField}) {
    return AdminSectionCard(
      title: 'بحث وفلترة المستخدمين',
      subtitle: 'فلترة حسب الدور أو تاريخ الإضافة مع البحث النصي',
      child: Column(
        children: [
          if (showSearchField) ...[
            TextField(
              controller: _userSearch,
              decoration: const InputDecoration(
                labelText: 'بحث باسم المستخدم أو الاسم الكامل',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('الكل'),
                selected: _userFilterRole == null,
                onSelected: (_) => _setViewState(() => _userFilterRole = null),
              ),
              ChoiceChip(
                label: const Text('معتمد'),
                selected: _userFilterRole == UserRole.accredited,
                onSelected: (_) =>
                    _setViewState(() => _userFilterRole = UserRole.accredited),
              ),
              ChoiceChip(
                label: const Text('وكيل'),
                selected: _userFilterRole == UserRole.agent,
                onSelected: (_) =>
                    _setViewState(() => _userFilterRole = UserRole.agent),
              ),
              ChoiceChip(
                label: const Text('مدير'),
                selected: _userFilterRole == UserRole.admin,
                onSelected: (_) =>
                    _setViewState(() => _userFilterRole = UserRole.admin),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickUserCreatedFromDate,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text('من: ${_dateText(_userCreatedFromDate)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickUserCreatedToDate,
                  icon: const Icon(Icons.event_note_rounded, size: 18),
                  label: Text('إلى: ${_dateText(_userCreatedToDate)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _setViewState(() {}),
                  icon: const Icon(Icons.filter_alt_rounded, size: 18),
                  label: const Text('تطبيق الفلترة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetUserFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('إعادة تعيين'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersResultCard({
    required String title,
    required String subtitle,
    required List<AppUser> users,
    required String emptyText,
  }) {
    if (users.isEmpty) {
      return AdminSectionCard(
        title: title,
        subtitle: subtitle,
        child: Text(emptyText),
      );
    }

    return AdminSectionCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: users.map((user) => _buildUserCard(user)).toList(),
      ),
    );
  }

  String _userCreatedDateText(AppUser user) {
    final date = user.createdAtDate?.toLocal();
    if (date == null) return 'غير محدد';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Widget _buildUserCard(AppUser user) {
    final canDeactivate =
        user.role != UserRole.admin &&
        user.id != widget.session.userId &&
        user.isActive;
    final canActivate =
        user.role != UserRole.admin &&
        user.id != widget.session.userId &&
        !user.isActive;
    final isDeleting = _deletingUserId == user.id;
    final isActivating = _activatingUserId == user.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openUserReport(user),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.panel.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.brandInk.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.brandSky.withValues(alpha: 0.7),
                      child: Text(
                        user.fullName.isEmpty ? '-' : user.fullName[0],
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandSky.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        roleLabelAr(user.role),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text('المدينة: ${user.city}'),
                    Text('الدولة: ${user.country}'),
                    Text('تاريخ الإضافة: ${_userCreatedDateText(user)}'),
                    Text(
                      '\u0627\u0644\u062d\u0627\u0644\u0629: ${user.isActive ? '\u0641\u0639\u0627\u0644' : '\u063a\u064a\u0631 \u0641\u0639\u0627\u0644'}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 430;
                    final buttonStyle = compact
                        ? OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null;
                    final iconSize = compact ? 14.0 : 16.0;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          style: buttonStyle,
                          onPressed: () => _openUserReport(user),
                          icon: Icon(Icons.badge_rounded, size: iconSize),
                          label: const Text('عرض كامل المعلومات'),
                        ),
                        if (canDeactivate)
                          OutlinedButton.icon(
                            style: buttonStyle,
                            onPressed: isDeleting
                                ? null
                                : () => _confirmDeactivateUser(user),
                            icon: Icon(
                              Icons.person_off_rounded,
                              size: iconSize,
                            ),
                            label: const Text('إلغاء التفعيل'),
                          )
                        else if (canActivate)
                          OutlinedButton.icon(
                            style: buttonStyle,
                            onPressed: isActivating
                                ? null
                                : () => _confirmActivateUser(user),
                            icon: Icon(
                              Icons.verified_user_rounded,
                              size: iconSize,
                            ),
                            label: const Text('تفعيل'),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrintButton({String label = 'طباعة التقرير PDF'}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _printReports,
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildReportsSection() {
    return Column(
      children: [
        AdminSectionCard(
          title: 'التقارير',
          subtitle: 'بحث بالتاريخ وطباعة PDF مع ملخص يومي',
          child: Column(
            children: [
              _buildDateFilterControls(),
              const SizedBox(height: 8),
              _buildPrintButton(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildDailyReportCard(),
      ],
    );
  }

  Widget _buildUserForm() {
    return AdminSectionCard(
      title: 'إضافة مستخدم',
      subtitle: 'مدير أو معتمد أو وكيل',
      child: Form(
        key: _userFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _uUsername,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              validator: AppValidators.username,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uFullName,
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserRole>(
              initialValue: _uRole,
              decoration: const InputDecoration(labelText: 'الدور'),
              items: const [
                DropdownMenuItem(value: UserRole.agent, child: Text('وكيل')),
                DropdownMenuItem(
                  value: UserRole.accredited,
                  child: Text('معتمد'),
                ),
                DropdownMenuItem(value: UserRole.admin, child: Text('مدير')),
              ],
              onChanged: (value) =>
                  _setViewState(() => _uRole = value ?? UserRole.agent),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _uCity,
                    decoration: const InputDecoration(labelText: 'المدينة'),
                    validator: AppValidators.requiredText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _uCountry,
                    decoration: const InputDecoration(labelText: 'الدولة'),
                    validator: AppValidators.requiredText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uPassword,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الأولية',
              ),
              obscureText: true,
              validator: AppValidators.password,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createUser,
                child: const Text('إنشاء المستخدم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashboxForm() {
    final seenManagerIds = <String>{};
    final managerOptions = _filteredCashboxManagerCandidates
        .where((u) => seenManagerIds.add(u.id))
        .toList();
    final selectedManagerId = managerOptions.any((u) => u.id == _cManagerId)
        ? _cManagerId
        : null;

    return AdminSectionCard(
      title: 'إضافة صندوق',
      subtitle: 'صندوق معتمد أو وكيل أو خزنة',
      child: Form(
        key: _cashboxFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _cName,
              decoration: const InputDecoration(labelText: 'اسم الصندوق'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _cType,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: const [
                DropdownMenuItem(
                  value: 'accredited',
                  child: Text('صندوق معتمد'),
                ),
                DropdownMenuItem(value: 'agent', child: Text('صندوق وكيل')),
                DropdownMenuItem(value: 'treasury', child: Text('الخزنة')),
              ],
              onChanged: (value) => _setViewState(() {
                _cType = value ?? 'accredited';
                _cManagerId = null;
                _cManagerSearch.clear();
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cCity,
                    decoration: const InputDecoration(labelText: 'المدينة'),
                    validator: AppValidators.requiredText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cCountry,
                    decoration: const InputDecoration(labelText: 'الدولة'),
                    validator: AppValidators.requiredText,
                  ),
                ),
              ],
            ),
            if (_cType != 'treasury') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _cManagerSearch,
                decoration: const InputDecoration(
                  labelText: 'بحث عن المسؤول',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) {
                  _setViewState(() {
                    if (!_filteredCashboxManagerCandidates.any(
                      (u) => u.id == _cManagerId,
                    )) {
                      _cManagerId = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedManagerId,
                decoration: const InputDecoration(labelText: 'المسؤول'),
                items: managerOptions
                    .map(
                      (u) => DropdownMenuItem(
                        value: u.id,
                        child: Text('${u.fullName} (${u.username})'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _setViewState(() => _cManagerId = value),
                validator: (v) {
                  if (managerOptions.isEmpty) {
                    return 'لا يوجد مسؤولون مطابقون للدور أو البحث.';
                  }
                  return (v == null || v.isEmpty) ? 'اختر مسؤولاً' : null;
                },
              ),
              if (managerOptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'لا يوجد مسؤولون مطابقون حالياً.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _cOpening,
              decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: AppValidators.nonNegativeAmount,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createCashbox,
                child: const Text('إنشاء الصندوق'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _visibleUsers;
    return Column(
      children: [
        _buildUsersFilterCard(showSearchField: true),
        const SizedBox(height: 10),
        _buildUsersResultCard(
          title: 'قائمة المستخدمين',
          subtitle: 'قائمة مفلترة حسب الدور أو تاريخ الإضافة',
          users: users.take(30).toList(),
          emptyText: 'لا توجد نتائج مطابقة.',
        ),
      ],
    );
  }

  Widget _buildCashboxesList() {
    return AdminSectionCard(
      title: 'قائمة الصناديق',
      subtitle: 'عرض مختصر للصناديق والمدير المسؤول',
      child: Column(
        children: _cashboxes.take(18).map((c) {
          final trailing = c.isTreasury ? 'مفتوحة' : moneyText(c.balanceValue);
          final subtitle =
              '${cashboxTypeLabelAr(c.type)} - ${c.city}, ${c.country}${c.managerName == null ? '' : ' - ${c.managerName}'}';
          return ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(c.name),
            subtitle: Text(subtitle),
            trailing: Text(
              trailing,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTreasuryRoutesSection() {
    final targetLabel =
        (_routeType == 'agent_funding' || _routeType == 'agent_collection')
        ? 'صندوق الوكيل'
        : 'الصندوق المعتمد';
    return AdminSectionCard(
      title: 'مسارات الخزنة',
      subtitle: transferTypeHintAr(_routeType),
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in const [
                ('topup', 'تعبئة معتمد'),
                ('collection', 'تحصيل من معتمد'),
                ('agent_funding', 'تمويل وكيل'),
                ('agent_collection', 'تحصيل من وكيل'),
              ])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: _routeType == option.$1,
                  onSelected: (_) => _setViewState(() {
                    _routeType = option.$1;
                    _routeCommissionManuallyEdited = false;
                    _routeTargetCashboxId = _routeTargets.isEmpty
                        ? null
                        : _routeTargets.first.id;
                    _applyDefaultRouteCommissionPercent(force: true);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _routeTargetCashboxId,
            isExpanded: true,
            decoration: InputDecoration(labelText: targetLabel),
            items: _routeTargets
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.name} - ${c.city}, ${c.country}'),
                  ),
                )
                .toList(),
            onChanged: (value) => _setViewState(() {
              _routeTargetCashboxId = value;
              _applyDefaultRouteCommissionPercent();
            }),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeAmount,
            decoration: const InputDecoration(labelText: 'المبلغ'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeCommissionPercent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'نسبة عمولة الخزنة %',
              helperText:
                  'القيمة الافتراضية من ضبط العمولات ويمكن تعديلها لهذه العملية فقط',
            ),
            validator: AppValidators.percent,
            onChanged: (_) => _routeCommissionManuallyEdited = true,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _setViewState(() {
                _routeCommissionManuallyEdited = false;
                _applyDefaultRouteCommissionPercent(force: true);
              }),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('استعادة العمولة الافتراضية'),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeNote,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createTreasuryRoute,
              child: Text(transferTypeLabelAr(_routeType)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreasuryRouteByNameSection() {
    final selectedUser = _routeByNameSelectedUser;
    final selectedCashbox = _routeByNameCashbox;
    final targetLabel =
        (_routeByNameType == 'agent_funding' ||
            _routeByNameType == 'agent_collection')
        ? 'صندوق الوكيل'
        : 'صندوق المعتمد';

    return AdminSectionCard(
      title: 'تنفيذ حسب الاسم',
      subtitle: 'ابحث عن اسم المستخدم، وسيتم تحديد صندوقه تلقائيًا',
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in const [
                ('topup', 'تعبئة معتمد'),
                ('collection', 'تحصيل من معتمد'),
                ('agent_funding', 'تمويل وكيل'),
                ('agent_collection', 'تحصيل من وكيل'),
              ])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: _routeByNameType == option.$1,
                  onSelected: (_) => _setViewState(() {
                    _routeByNameType = option.$1;
                    _routeByNameCommissionManuallyEdited = false;
                    _syncRouteByNameSelection();
                    _applyDefaultRouteByNameCommissionPercent(force: true);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _routeByNameSearch,
            decoration: const InputDecoration(
              labelText: 'بحث باسم المستخدم أو الاسم الكامل',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => _setViewState(_syncRouteByNameSelection),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue:
                _routeByNameUserOptions.any(
                  (user) => user.id == _routeByNameUserId,
                )
                ? _routeByNameUserId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'المستخدم'),
            items: _routeByNameUserOptions
                .map(
                  (user) => DropdownMenuItem(
                    value: user.id,
                    child: Text(
                      '${user.fullName} (${user.username}) - ${roleLabelAr(user.role)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => _setViewState(() {
              _routeByNameUserId = value;
              _syncRouteByNameSelection();
            }),
          ),
          if (_routeByNameUserOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'لا توجد نتائج مطابقة لبحث الاسم ضمن نوع العملية الحالي.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
            ),
          if (selectedUser != null && selectedCashbox != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.panel.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandInk.withValues(alpha: 0.08),
                ),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  Text('الاسم: ${selectedUser.fullName}'),
                  Text('المعرف: @${selectedUser.username}'),
                  Text('الدور: ${roleLabelAr(selectedUser.role)}'),
                  Text(
                    'المدينة/الدولة: ${selectedUser.city} - ${selectedUser.country}',
                  ),
                  Text('$targetLabel: ${selectedCashbox.name}'),
                  Text(
                    'الرصيد الحالي: ${moneyText(selectedCashbox.balanceValue)}',
                  ),
                ],
              ),
            ),
          ],
          if (_routeByNameCashboxOptions.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue:
                  _routeByNameCashboxOptions.any(
                    (cashbox) => cashbox.id == _routeByNameCashboxId,
                  )
                  ? _routeByNameCashboxId
                  : null,
              decoration: InputDecoration(labelText: targetLabel),
              isExpanded: true,
              items: _routeByNameCashboxOptions
                  .map(
                    (cashbox) => DropdownMenuItem(
                      value: cashbox.id,
                      child: Text(
                        '${cashbox.name} - ${cashbox.city}, ${cashbox.country}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) =>
                  _setViewState(() => _routeByNameCashboxId = value),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeByNameAmount,
            decoration: const InputDecoration(labelText: 'المبلغ'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: AppValidators.amount,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeByNameCommissionPercent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'نسبة عمولة الخزنة %',
              helperText: 'قابلة للتعديل لهذه العملية فقط',
            ),
            validator: AppValidators.percent,
            onChanged: (_) => _routeByNameCommissionManuallyEdited = true,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _setViewState(() {
                _routeByNameCommissionManuallyEdited = false;
                _applyDefaultRouteByNameCommissionPercent(force: true);
              }),
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('استعادة العمولة الافتراضية'),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeByNameNote,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _createTreasuryRouteByName,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(transferTypeLabelAr(_routeByNameType)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportCard() {
    return AdminSectionCard(
      title: 'التقارير اليومية',
      subtitle: 'إجمالي العمليات والعمولات والأرباح لكل يوم',
      child: _dailyReport.isEmpty
          ? const Text('لا توجد بيانات يومية ضمن الفترة المختارة.')
          : Column(
              children: _dailyReport
                  .map(
                    (row) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.date),
                      subtitle: Text(
                        'العمليات: ${row.transfersCount} - المكتملة: ${row.completedCount} - المعلقة: ${row.pendingCount}',
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'الإجمالي ${moneyText(row.totalAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'عمولة ${moneyText(row.totalCommission)} / ربح وكيل ${moneyText(row.totalAgentProfit)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildPendingRequests() {
    return AdminSectionCard(
      title: 'طلبات بانتظار القرار',
      subtitle: 'اعتماد أو رفض طلبات التعبئة والتحصيل',
      child: _pendingTransfers.isEmpty
          ? const Text('لا توجد طلبات معلقة حالياً.')
          : Column(
              children: _pendingTransfers.map((transfer) {
                final busy = _reviewingTransferId == transfer.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AdminTransferTile(
                    transfer: transfer,
                    busy: busy,
                    onApprove: busy
                        ? null
                        : () => _reviewTransfer(transfer, true),
                    onReject: busy
                        ? null
                        : () => _reviewTransfer(transfer, false),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildRecentTransfers() {
    return AdminSectionCard(
      title: 'سجل التحويلات',
      subtitle: 'نتائج السجل ضمن الفترة الزمنية الحالية',
      child: Column(
        children: [
          _buildDateFilterControls(),
          const SizedBox(height: 8),
          _buildPrintButton(label: 'طباعة سجل التحويلات PDF'),
          const SizedBox(height: 10),
          if (_recentTransfers.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text('لا توجد سجلات.'),
            )
          else
            Column(
              children: _recentTransfers
                  .take(20)
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdminTransferTile(transfer: t),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCommissionSettingsSection() {
    return AdminSectionCard(
      title: 'ضبط العمولات',
      subtitle:
          'تحديد عمولة التحويل الداخلية والخارجية مع أرباح الوكيل والمعتمد.',
      child: Column(
        children: [
          _buildCommissionEditor(
            title: 'عمولات المعتمد',
            internalController: _accreditedInternal,
            externalController: _accreditedExternal,
            showAgentProfit: true,
            agentProfitInternalController: _accreditedTransferProfitInternal,
            agentProfitExternalController: _accreditedTransferProfitExternal,
            agentProfitInternalLabel: 'ربح المعتمد داخلي %',
            agentProfitExternalLabel: 'ربح المعتمد خارجي %',
          ),
          const SizedBox(height: 10),
          _buildCommissionEditor(
            title: 'عمولات الوكيل',
            internalController: _agentInternal,
            externalController: _agentExternal,
            showAgentProfit: true,
            agentProfitInternalController: _agentTopupProfitInternal,
            agentProfitExternalController: _agentTopupProfitExternal,
            agentProfitInternalLabel: 'ربح الوكيل داخلي %',
            agentProfitExternalLabel: 'ربح الوكيل خارجي %',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.brandInk.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عمولات مسارات الخزنة',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _treasuryToAccreditedFee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'من الخزنة إلى المعتمد %',
                        ),
                        validator: AppValidators.percent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _treasuryToAgentFee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'من الخزنة إلى الوكيل %',
                        ),
                        validator: AppValidators.percent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _treasuryCollectionFromAccreditedFee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'تحصيل من المعتمد إلى الخزنة %',
                        ),
                        validator: AppValidators.percent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _treasuryCollectionFromAgentFee,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'تحصيل من الوكيل إلى الخزنة %',
                        ),
                        validator: AppValidators.percent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveCommissions,
              child: const Text('حفظ العمولات'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoSection() {
    return AdminSectionCard(
      title: 'معلومات النظام',
      subtitle: 'بيانات الحساب الحالي',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(widget.session.fullName),
            subtitle: Text(
              'مدير - ${widget.session.city}, ${widget.session.country} - ${widget.session.username}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionEditor({
    required String title,
    required TextEditingController internalController,
    required TextEditingController externalController,
    required bool showAgentProfit,
    TextEditingController? agentProfitInternalController,
    TextEditingController? agentProfitExternalController,
    String? agentProfitInternalLabel,
    String? agentProfitExternalLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.brandInk.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: internalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عمولة داخلية %',
                  ),
                  validator: AppValidators.percent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: externalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'عمولة خارجية %',
                  ),
                  validator: AppValidators.percent,
                ),
              ),
            ],
          ),
          if (showAgentProfit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: agentProfitInternalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          agentProfitInternalLabel ?? 'ربح تعبئة داخلي %',
                    ),
                    validator: AppValidators.percent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: agentProfitExternalController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          agentProfitExternalLabel ?? 'ربح تعبئة خارجي %',
                    ),
                    validator: AppValidators.percent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminRoutePreview {
  const _AdminRoutePreview({
    required this.operationLabel,
    required this.sourceName,
    required this.destinationName,
    required this.requestedAmount,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.senderDeduction,
    required this.recipientCredit,
    required this.splitInput,
  });

  final String operationLabel;
  final String sourceName;
  final String destinationName;
  final double requestedAmount;
  final double commissionPercent;
  final double commissionAmount;
  final double senderDeduction;
  final double recipientCredit;
  final bool splitInput;
}

class _AdminRouteResolution {
  const _AdminRouteResolution({
    required this.fromCashboxId,
    required this.toCashboxId,
  });

  final String fromCashboxId;
  final String toCashboxId;
}
