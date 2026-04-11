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
            title: const Text('طھط£ظƒظٹط¯ طھظ†ظپظٹط° ط§ظ„ط­ظˆط§ظ„ط©'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _routePreviewLine('ط§ظ„ط¹ظ…ظ„ظٹط©', preview.operationLabel),
                  _routePreviewLine('ظ…ظ†', preview.sourceName),
                  _routePreviewLine('ط¥ظ„ظ‰', preview.destinationName),
                  const Divider(height: 18),
                  _routePreviewLine(
                    preview.splitInput
                        ? 'ط§ظ„ظ…ط¨ظ„ط؛ ط§ظ„ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ظ…ط¯ط®ظ„'
                        : 'ط§ظ„ظ…ط¨ظ„ط؛ ط§ظ„ظ…ط¯ط®ظ„',
                    moneyText(preview.requestedAmount),
                  ),
                  _routePreviewLine(
                    'ط¹ظ…ظˆظ„ط© ط§ظ„ط®ط²ظ†ط©',
                    '${moneyText(preview.commissionAmount)} (${_fmt2(preview.commissionPercent)}%)',
                  ),
                  _routePreviewLine(
                    'ط§ظ„ط®طµظ… ظ…ظ† ط±طµظٹط¯ ط§ظ„ظ…ط±ط³ظ„',
                    moneyText(preview.senderDeduction),
                  ),
                  _routePreviewLine(
                    'ط§ظ„طµط§ظپظٹ ط§ظ„ظˆط§طµظ„ ظ„ظ„ظ…ط³طھظ„ظ…',
                    moneyText(preview.recipientCredit),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ط¥ظ„ط؛ط§ط،'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('طھط£ظƒظٹط¯ ط§ظ„طھظ†ظپظٹط°'),
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
    if (value == null) return 'ط؛ظٹط± ظ…ط­ط¯ط¯';
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
    if (text.contains('طھط¹ط°ط± ط§ظ„ظˆطµظˆظ„') ||
        text.contains('failed host lookup') ||
        text.contains('socket') ||
        text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('ظ…ظ‡ظ„ط©')) {
      return 'طھط¹ط°ط± ط§ظ„ط§طھطµط§ظ„ ط¨ط§ظ„ط´ط¨ظƒط© ط£ظˆ ط§ظ„ط®ط§ط¯ظ…. طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط¥ظ†طھط±ظ†طھ ظˆط±ط§ط¨ط· API ط«ظ… ط£ط¹ط¯ ط§ظ„ظ…ط­ط§ظˆظ„ط©.';
    }
    if (text.contains('401') || text.contains('403')) {
      return 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط¨ظٹط§ظ†ط§طھ ط§ظ„ط£ط¯ظ…ظ† ط¨ط³ط¨ط¨ طµظ„ط§ط­ظٹط§طھ ط§ظ„ظˆطµظˆظ„. ط³ط¬ظ‘ظ„ ط§ظ„ط¯ط®ظˆظ„ ظ…ط¬ط¯ط¯ظ‹ط§.';
    }
    if (raw.isEmpty) {
      return 'ط­ط¯ط« ط®ط·ط£ ط؛ظٹط± ظ…طھظˆظ‚ط¹ ط£ط«ظ†ط§ط، طھط­ظ…ظٹظ„ ط§ظ„ط¨ظٹط§ظ†ط§طھ.';
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
      _showSuccess('طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ظ…ط³طھط®ط¯ظ… ط¨ظ†ط¬ط§ط­');
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
        'طھظ… ط¥ظ„ط؛ط§ط، طھظپط¹ظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ… ظ…ط¹ ط§ظ„ط¥ط¨ظ‚ط§ط، ط¹ظ„ظ‰ ظƒظ„ ط§ظ„ط³ط¬ظ„ط§طھ ط§ظ„ظ…ط§ظ„ظٹط©.',
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
        title: const Text('ط¥ظ„ط؛ط§ط، طھظپط¹ظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ…'),
        content: Text(
          'ط³ظٹطھظ… ط¥ظ„ط؛ط§ط، طھظپط¹ظٹظ„ ط­ط³ط§ط¨ ${user.fullName} ط¯ظˆظ† ط­ط°ظپ ط³ط¬ظ„ط§طھظ‡ ط£ظˆ ط­ط±ظƒطھظ‡ ط§ظ„ظ…ط§ظ„ظٹط©. ظ‡ظ„ طھط±ظٹط¯ ط§ظ„ظ…طھط§ط¨ط¹ط©طں',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ط¥ظ„ط؛ط§ط،'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ط¥ظ„ط؛ط§ط، ط§ظ„طھظپط¹ظٹظ„'),
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
      _showSuccess('طھظ…طھ ط¥ط¹ط§ط¯ط© طھظپط¹ظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ… ط¨ظ†ط¬ط§ط­.');
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
        title: const Text('ط¥ط¹ط§ط¯ط© طھظپط¹ظٹظ„ ط§ظ„ظ…ط³طھط®ط¯ظ…'),
        content: Text(
          'ط³ظٹطھظ… ط¥ط¹ط§ط¯ط© طھظپط¹ظٹظ„ ط­ط³ط§ط¨ ${user.fullName}. ظ‡ظ„ طھط±ظٹط¯ ط§ظ„ظ…طھط§ط¨ط¹ط©طں',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ط¥ظ„ط؛ط§ط،'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('طھظپط¹ظٹظ„'),
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
      _showError(
        'ط§ط®طھط± ظ…ط³ط¤ظˆظ„ظ‹ط§ ظ…ط·ط§ط¨ظ‚ظ‹ط§ ظ„ظ„ط¯ظˆط± ط§ظ„ظ…ط­ط¯ط¯.',
      );
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
      _showSuccess('طھظ… ط¥ظ†ط´ط§ط، ط§ظ„طµظ†ط¯ظˆظ‚ ط¨ظ†ط¬ط§ط­');
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
      _showSuccess('طھظ… ط­ظپط¸ ط§ظ„ط¹ظ…ظˆظ„ط§طھ');
      await _loadData();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _createTreasuryRoute() async {
    if (_treasury == null) {
      return _showError('ط§ظ„ط®ط²ظ†ط© ط؛ظٹط± ظ…طھظˆظپط±ط©');
    }
    if (_routeTargetCashboxId == null) {
      return _showError('ط§ط®طھط± ط§ظ„طµظ†ط¯ظˆظ‚ ط§ظ„ظ‡ط¯ظپ ط£ظˆظ„ط§ظ‹');
    }
    final amountError = AppValidators.amount(_routeAmount.text);
    if (amountError != null) return _showError(amountError);
    final commissionError = AppValidators.percent(_routeCommissionPercent.text);
    if (commissionError != null) return _showError(commissionError);
    final endpoints = _resolveRouteEndpoints(_routeType, _routeTargetCashboxId);
    if (endpoints == null) {
      return _showError('ظ†ظˆط¹ ط§ظ„ط¹ظ…ظ„ظٹط© ط؛ظٹط± ظ…ط¹ط±ظˆظپ');
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
            ? 'طھظ… ط¥ط±ط³ط§ظ„ ط§ظ„ط·ظ„ط¨ ط¨ط§ظ†طھط¸ط§ط± ظ…ظˆط§ظپظ‚ط© ط§ظ„ظ…ط³طھظ„ظ….'
            : 'طھظ… طھظ†ظپظٹط° ط§ظ„ط¹ظ…ظ„ظٹط© ط¨ظ†ط¬ط§ط­.',
      );
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _createTreasuryRouteByName() async {
    if (_treasury == null) {
      return _showError('ط§ظ„ط®ط²ظ†ط© ط؛ظٹط± ظ…طھظˆظپط±ط©');
    }
    if (_routeByNameUserId == null) {
      return _showError('ط§ط®طھط± ط§ظ„ظ…ط³طھط®ط¯ظ… ط£ظˆظ„ط§ظ‹');
    }
    if (_routeByNameCashboxId == null) {
      return _showError(
        'ظ„ظ… ظٹطھظ… طھط­ط¯ظٹط¯ طµظ†ط¯ظˆظ‚ طµط§ط­ط¨ ط§ظ„ط§ط³ظ….',
      );
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
      return _showError('ظ†ظˆط¹ ط§ظ„ط¹ظ…ظ„ظٹط© ط؛ظٹط± ظ…ط¹ط±ظˆظپ');
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
            ? 'طھظ… ط¥ط±ط³ط§ظ„ ط§ظ„ط·ظ„ط¨ ط¨ط§ظ†طھط¸ط§ط± ظ…ظˆط§ظپظ‚ط© ط§ظ„ظ…ط³طھظ„ظ….'
            : 'طھظ… طھظ†ظپظٹط° ط§ظ„ط¹ظ…ظ„ظٹط© ط¨ظ†ط¬ط§ط­.',
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
        note: approve
            ? 'ط§ط¹طھظ…ط§ط¯ ظ…ظ† ط§ظ„ظ…ط¯ظٹط±'
            : 'ط±ظپط¶ ظ…ظ† ط§ظ„ظ…ط¯ظٹط±',
      );
      _showSuccess(approve ? 'طھظ… ط§ظ„ط§ط¹طھظ…ط§ط¯' : 'طھظ… ط§ظ„ط±ظپط¶');
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
        title: 'طھظ‚ط±ظٹط± ط§ظ„ظ…ط¯ظٹط±',
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
                title: 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ط¨ظٹط§ظ†ط§طھ ط§ظ„ظ‚ط³ظ…',
                subtitle:
                    'طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط´ط¨ظƒط© ط«ظ… ط£ط¹ط¯ ط§ظ„ظ…ط­ط§ظˆظ„ط©.',
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
                          title: 'ظ„ظˆط­ط© ط§ظ„ظ…ط¯ظٹط±',
                          subtitle:
                              'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†طŒ ط§ظ„ط¹ظ…ظˆظ„ط§طھطŒ ط§ظ„طھظ‚ط§ط±ظٹط±طŒ ظˆظ…ط³ط§ط±ط§طھ ط§ظ„ط®ط²ظ†ط© ط¨ظˆط§ط¬ظ‡ط© ظ…ظ†ط¸ظ…ط©.',
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
                          title: 'ط¬ط§ط±ظٹ ط§ظ„طھط­ظ…ظٹظ„',
                          subtitle:
                              'ظٹطھظ… ط¬ظ„ط¨ ط¨ظٹط§ظ†ط§طھ ظ„ظˆط­ط© ط§ظ„ظ…ط¯ظٹط± ط§ظ„ط¢ظ†',
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
                          title: 'طھط¹ط°ط± طھط­ظ…ظٹظ„ ظ„ظˆط­ط© ط§ظ„ظ…ط¯ظٹط±',
                          subtitle:
                              'طھط­ظ‚ظ‚ ظ…ظ† ط§ظ„ط§طھطµط§ظ„ ط«ظ… ط£ط¹ط¯ طھط­ظ…ظٹظ„ ط§ظ„ط¨ظٹط§ظ†ط§طھ.',
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
                label: 'ط§ظ„ظ…ط³طھط®ط¯ظ…ظˆظ†',
                value: _users.length.toString(),
                hint: 'ط¬ظ…ظٹط¹ ط§ظ„ط­ط³ط§ط¨ط§طھ',
                icon: Icons.people_alt_rounded,
                accent: AppTheme.brandTeal,
              ),
            ),
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'ط§ظ„طµظ†ط§ط¯ظٹظ‚',
                value: _cashboxes.length.toString(),
                hint: 'ط®ط²ظ†ط© ظˆظ…ط¹طھظ…ط¯ ظˆظˆظƒظٹظ„',
                icon: Icons.inventory_2_rounded,
                accent: AppTheme.brandCoral,
              ),
            ),
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'ط±طµظٹط¯ ط§ظ„ط´ط¨ظƒط©',
                value: moneyText(_networkBalance),
                hint: 'ط¨ط¯ظˆظ† ط±طµظٹط¯ ط§ظ„ط®ط²ظ†ط©',
                icon: Icons.account_balance_wallet_rounded,
                accent: AppTheme.brandGold,
              ),
            ),
            SizedBox(
              width: width,
              child: AdminMetricCard(
                label: 'ط¥ظٹط±ط§ط¯ ط§ظ„ط¹ظ…ظˆظ„ط©',
                value: moneyText(_commissionRevenue),
                hint: 'ظ…ظ† ط¯ظ„ظٹظ„ ط§ظ„ظ‚ظٹظˆط¯',
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
            title: 'ط¥ط¯ط§ط±ط© ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
            subtitle:
                'ظƒظ„ ظˆط¸ظٹظپط© ط¶ظ…ظ† ط´ط§ط´ط© ظ…ط³طھظ‚ظ„ط© ط¹ط¨ط± ط²ط± ظ…ط®طµطµ',
            actions: [
              _buildActionButton(
                icon: Icons.search_rounded,
                label: 'ط¨ط­ط« ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
                onTap: () => _openSection(
                  title: 'ط¨ط­ط« ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
                  subtitle:
                      'ظپظ„طھط±ط© ظˆط¨ط­ط« ظ…ط¹ ط¨ط·ط§ظ‚ط© ظ…ط³طھط®ط¯ظ… طھظپطµظٹظ„ظٹط©',
                  icon: Icons.search_rounded,
                  builder: (_) => _buildUserFilterSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.person_add_alt_1_rounded,
                label: 'ط¥ط¶ط§ظپط© ظ…ط³طھط®ط¯ظ…',
                onTap: () => _openSection(
                  title: 'ط¥ط¶ط§ظپط© ظ…ط³طھط®ط¯ظ…',
                  subtitle: 'ط¥ظ†ط´ط§ط، ط­ط³ط§ط¨ ط¬ط¯ظٹط¯',
                  icon: Icons.person_add_alt_1_rounded,
                  builder: (_) => _buildUserForm(),
                ),
              ),
              _buildActionButton(
                icon: Icons.add_business_rounded,
                label: 'ط¥ط¶ط§ظپط© طµظ†ط¯ظˆظ‚',
                onTap: () => _openSection(
                  title: 'ط¥ط¶ط§ظپط© طµظ†ط¯ظˆظ‚',
                  subtitle:
                      'ط¥ظ†ط´ط§ط، طµظ†ط¯ظˆظ‚ ظ…ط¹طھظ…ط¯ ط£ظˆ ظˆظƒظٹظ„ ط£ظˆ ط®ط²ظ†ط©',
                  icon: Icons.add_business_rounded,
                  builder: (_) => _buildCashboxForm(),
                ),
              ),
              _buildActionButton(
                icon: Icons.people_alt_rounded,
                label: 'ظ‚ط§ط¦ظ…ط© ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
                onTap: () => _openSection(
                  title: 'ظ‚ط§ط¦ظ…ط© ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
                  subtitle: 'ظ†طھط§ط¦ط¬ ط§ظ„ط¨ط­ط« ظˆط§ظ„ظپظ„طھط±ط©',
                  icon: Icons.people_alt_rounded,
                  builder: (_) => _buildUsersList(),
                ),
              ),
              _buildActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'ظ‚ط§ط¦ظ…ط© ط§ظ„طµظ†ط§ط¯ظٹظ‚',
                onTap: () => _openSection(
                  title: 'ظ‚ط§ط¦ظ…ط© ط§ظ„طµظ†ط§ط¯ظٹظ‚',
                  subtitle: 'ط¹ط±ط¶ ط§ظ„طµظ†ط§ط¯ظٹظ‚ ط§ظ„ظ…ط³ط¬ظ„ط©',
                  icon: Icons.account_balance_wallet_rounded,
                  builder: (_) => _buildCashboxesList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMainGroup(
            title: 'ط§ظ„ط¹ظ…ظ„ظٹط§طھ',
            subtitle:
                'ظƒظ„ ظ‚ط³ظ… طھط´ط؛ظٹظ„ظٹ ط¨ظˆط§ط¬ظ‡ط© طھظپطµظٹظ„ظٹط© ظ…ط³طھظ‚ظ„ط©',
            actions: [
              _buildActionButton(
                icon: Icons.account_balance_rounded,
                label: 'ظ…ط³ط§ط±ط§طھ ط§ظ„ط®ط²ظ†ط©',
                onTap: () => _openSection(
                  title: 'ظ…ط³ط§ط±ط§طھ ط§ظ„ط®ط²ظ†ط©',
                  subtitle: 'طھظ…ظˆظٹظ„ ظˆطھط­طµظٹظ„ ط§ظ„طµظ†ط§ط¯ظٹظ‚',
                  icon: Icons.account_balance_rounded,
                  builder: (_) => _buildTreasuryRoutesSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.person_search_rounded,
                label: 'طھظ†ظپظٹط° ط­ط³ط¨ ط§ظ„ط§ط³ظ…',
                onTap: () => _openSection(
                  title: 'طھظ†ظپظٹط° ط­ط³ط¨ ط§ظ„ط§ط³ظ…',
                  subtitle:
                      'ط¨ط­ط« ط¹ظ† ط§ظ„ظ…ط³طھظ„ظ… ظˆطھظ†ظپظٹط° ظ…ط³ط§ط± ط§ظ„ط®ط²ظ†ط© ظ…ط¨ط§ط´ط±ط©',
                  icon: Icons.person_search_rounded,
                  builder: (_) => _buildTreasuryRouteByNameSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.pending_actions_rounded,
                label: 'ط§ظ„ط·ظ„ط¨ط§طھ ط§ظ„ظ…ط¹ظ„ظ‚ط©',
                badge: _pendingTransfers.length.toString(),
                onTap: () => _openSection(
                  title: 'ط§ظ„ط·ظ„ط¨ط§طھ ط§ظ„ظ…ط¹ظ„ظ‚ط©',
                  subtitle: 'ط§ط¹طھظ…ط§ط¯ ط£ظˆ ط±ظپط¶ ط§ظ„ط·ظ„ط¨ط§طھ',
                  icon: Icons.pending_actions_rounded,
                  builder: (_) => _buildPendingRequests(),
                ),
              ),
              _buildActionButton(
                icon: Icons.history_rounded,
                label: 'ط³ط¬ظ„ ط§ظ„طھط­ظˆظٹظ„ط§طھ',
                onTap: () => _openSection(
                  title: 'ط³ط¬ظ„ ط§ظ„طھط­ظˆظٹظ„ط§طھ',
                  subtitle:
                      'ظ†طھط§ط¦ط¬ ط§ظ„طھط­ظˆظٹظ„ط§طھ ط¶ظ…ظ† ط§ظ„ظپطھط±ط© ط§ظ„ط­ط§ظ„ظٹط©',
                  icon: Icons.history_rounded,
                  builder: (_) => _buildRecentTransfers(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildMainGroup(
            title: 'ط§ظ„طھظ‚ط§ط±ظٹط± ظˆط§ظ„ط¥ط¹ط¯ط§ط¯ط§طھ',
            subtitle:
                'ظپظ„طھط±ط©طŒ طھظ‚ط§ط±ظٹط± ظٹظˆظ…ظٹط©طŒ PDFطŒ ظˆط¶ط¨ط· ط§ظ„ط¹ظ…ظˆظ„ط§طھ',
            actions: [
              _buildActionButton(
                icon: Icons.space_dashboard_rounded,
                label: 'ظ…ط¤ط´ط±ط§طھ ط³ط±ظٹط¹ط©',
                onTap: () => _openSection(
                  title: 'ظ…ط¤ط´ط±ط§طھ ط³ط±ظٹط¹ط©',
                  subtitle: 'ظ…ظ„ط®طµ ط§ظ„ط£ط±ظ‚ط§ظ… ط§ظ„ط£ط³ط§ط³ظٹط©',
                  icon: Icons.space_dashboard_rounded,
                  builder: (_) => _buildMetricsSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.bar_chart_rounded,
                label: 'ط§ظ„طھظ‚ط§ط±ظٹط±',
                onTap: () => _openSection(
                  title: 'ط§ظ„طھظ‚ط§ط±ظٹط±',
                  subtitle:
                      'ط¨ط­ط« ط¨ط§ظ„طھط§ط±ظٹط® ظˆطھظ‚ط§ط±ظٹط± ظٹظˆظ…ظٹط© ظˆط·ط¨ط§ط¹ط© PDF',
                  icon: Icons.bar_chart_rounded,
                  builder: (_) => _buildReportsSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.percent_rounded,
                label: 'ط¶ط¨ط· ط§ظ„ط¹ظ…ظˆظ„ط§طھ',
                onTap: () => _openSection(
                  title: 'ط¶ط¨ط· ط§ظ„ط¹ظ…ظˆظ„ط§طھ',
                  subtitle:
                      'ط¹ظ…ظˆظ„ط§طھ ط¯ط§ط®ظ„ظٹط© ظˆط®ط§ط±ط¬ظٹط© ظˆط±ط¨ط­ ط§ظ„ظˆظƒظٹظ„',
                  icon: Icons.percent_rounded,
                  builder: (_) => _buildCommissionSettingsSection(),
                ),
              ),
              _buildActionButton(
                icon: Icons.settings_rounded,
                label: 'ظ…ط¹ظ„ظˆظ…ط§طھ ط§ظ„ظ†ط¸ط§ظ…',
                onTap: () => _openSection(
                  title: 'ظ…ط¹ظ„ظˆظ…ط§طھ ط§ظ„ظ†ط¸ط§ظ…',
                  subtitle: 'ط¨ظٹط§ظ†ط§طھ ط§ظ„ط­ط³ط§ط¨ ط§ظ„ط­ط§ظ„ظٹ',
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
    title: 'ظ…ط¤ط´ط±ط§طھ ط³ط±ظٹط¹ط©',
    subtitle: 'ط£ظ‡ظ… ط£ط±ظ‚ط§ظ… ط§ظ„ط´ط¨ظƒط© ط¨ط´ظƒظ„ ظ…طµط؛ط±',
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
                label: Text('ظ…ظ†: ${_dateText(_fromDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickToDate,
                icon: const Icon(Icons.event_note_rounded, size: 18),
                label: Text('ط¥ظ„ظ‰: ${_dateText(_toDate)}'),
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
                label: const Text('ط¨ط­ط«'),
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
                label: const Text('ط¥ط¹ط§ط¯ط© طھط¹ظٹظٹظ†'),
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
          title: 'ظ†طھط§ط¦ط¬ ط§ظ„ط¨ط­ط«',
          subtitle: hasAnyFilter
              ? 'طھظ… ط§ظ„ط¹ط«ظˆط± ط¹ظ„ظ‰ ${users.length} ظ…ط³طھط®ط¯ظ… ط¶ظ…ظ† ط§ظ„ظپظ„طھط±ط© ط§ظ„ط­ط§ظ„ظٹط©'
              : 'ط£ط¯ط®ظ„ ط§ط³ظ…ظ‹ط§ ط£ظˆ ط§ط®طھط± ط¯ظˆط±ظ‹ط§ ط£ظˆ طھط§ط±ظٹط® ط¥ط¶ط§ظپط© ظ„ظ„ط¨ط¯ط،',
          users: users,
          emptyText: hasAnyFilter
              ? 'ظ„ط§ طھظˆط¬ط¯ ظ†طھط§ط¦ط¬ ظ…ط·ط§ط¨ظ‚ط© ظ„ظ„ظپظ„طھط±ط© ط§ظ„ط­ط§ظ„ظٹط©.'
              : 'ط§ظƒطھط¨ ظ†طµ ط§ظ„ط¨ط­ط« ط£ظˆ ط§ط³طھط®ط¯ظ… ظپظ„طھط±ط© ط§ظ„ط¯ظˆط±/طھط§ط±ظٹط® ط§ظ„ط¥ط¶ط§ظپط©.',
        ),
      ],
    );
  }

  Widget _buildUsersFilterCard({required bool showSearchField}) {
    return AdminSectionCard(
      title: 'ط¨ط­ط« ظˆظپظ„طھط±ط© ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
      subtitle:
          'ظپظ„طھط±ط© ط­ط³ط¨ ط§ظ„ط¯ظˆط± ط£ظˆ طھط§ط±ظٹط® ط§ظ„ط¥ط¶ط§ظپط© ظ…ط¹ ط§ظ„ط¨ط­ط« ط§ظ„ظ†طµظٹ',
      child: Column(
        children: [
          if (showSearchField) ...[
            TextField(
              controller: _userSearch,
              decoration: const InputDecoration(
                labelText:
                    'ط¨ط­ط« ط¨ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ط£ظˆ ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„',
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
                label: const Text('ط§ظ„ظƒظ„'),
                selected: _userFilterRole == null,
                onSelected: (_) => _setViewState(() => _userFilterRole = null),
              ),
              ChoiceChip(
                label: const Text('ظ…ط¹طھظ…ط¯'),
                selected: _userFilterRole == UserRole.accredited,
                onSelected: (_) =>
                    _setViewState(() => _userFilterRole = UserRole.accredited),
              ),
              ChoiceChip(
                label: const Text('ظˆظƒظٹظ„'),
                selected: _userFilterRole == UserRole.agent,
                onSelected: (_) =>
                    _setViewState(() => _userFilterRole = UserRole.agent),
              ),
              ChoiceChip(
                label: const Text('ظ…ط¯ظٹط±'),
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
                  label: Text('ظ…ظ†: ${_dateText(_userCreatedFromDate)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickUserCreatedToDate,
                  icon: const Icon(Icons.event_note_rounded, size: 18),
                  label: Text('ط¥ظ„ظ‰: ${_dateText(_userCreatedToDate)}'),
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
                  label: const Text('طھط·ط¨ظٹظ‚ ط§ظ„ظپظ„طھط±ط©'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetUserFilters,
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('ط¥ط¹ط§ط¯ط© طھط¹ظٹظٹظ†'),
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
    if (date == null) return 'ط؛ظٹط± ظ…ط­ط¯ط¯';
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
                    Text('ط§ظ„ظ…ط¯ظٹظ†ط©: ${user.city}'),
                    Text('ط§ظ„ط¯ظˆظ„ط©: ${user.country}'),
                    Text(
                      'طھط§ط±ظٹط® ط§ظ„ط¥ط¶ط§ظپط©: ${_userCreatedDateText(user)}',
                    ),
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
                          label: const Text(
                            'ط¹ط±ط¶ ظƒط§ظ…ظ„ ط§ظ„ظ…ط¹ظ„ظˆظ…ط§طھ',
                          ),
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
                            label: const Text('ط¥ظ„ط؛ط§ط، ط§ظ„طھظپط¹ظٹظ„'),
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
                            label: const Text('طھظپط¹ظٹظ„'),
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

  Widget _buildPrintButton({String label = 'ط·ط¨ط§ط¹ط© ط§ظ„طھظ‚ط±ظٹط± PDF'}) {
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
          title: 'ط§ظ„طھظ‚ط§ط±ظٹط±',
          subtitle:
              'ط¨ط­ط« ط¨ط§ظ„طھط§ط±ظٹط® ظˆط·ط¨ط§ط¹ط© PDF ظ…ط¹ ظ…ظ„ط®طµ ظٹظˆظ…ظٹ',
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
      title: 'ط¥ط¶ط§ظپط© ظ…ط³طھط®ط¯ظ…',
      subtitle: 'ظ…ط¯ظٹط± ط£ظˆ ظ…ط¹طھظ…ط¯ ط£ظˆ ظˆظƒظٹظ„',
      child: Form(
        key: _userFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _uUsername,
              decoration: const InputDecoration(
                labelText: 'ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ…',
              ),
              validator: AppValidators.username,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uFullName,
              decoration: const InputDecoration(
                labelText: 'ط§ظ„ط§ط³ظ… ط§ظ„ظƒط§ظ…ظ„',
              ),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserRole>(
              initialValue: _uRole,
              decoration: const InputDecoration(labelText: 'ط§ظ„ط¯ظˆط±'),
              items: const [
                DropdownMenuItem(
                  value: UserRole.agent,
                  child: Text('ظˆظƒظٹظ„'),
                ),
                DropdownMenuItem(
                  value: UserRole.accredited,
                  child: Text('ظ…ط¹طھظ…ط¯'),
                ),
                DropdownMenuItem(
                  value: UserRole.admin,
                  child: Text('ظ…ط¯ظٹط±'),
                ),
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
                    decoration: const InputDecoration(
                      labelText: 'ط§ظ„ظ…ط¯ظٹظ†ط©',
                    ),
                    validator: AppValidators.requiredText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _uCountry,
                    decoration: const InputDecoration(
                      labelText: 'ط§ظ„ط¯ظˆظ„ط©',
                    ),
                    validator: AppValidators.requiredText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _uPassword,
              decoration: const InputDecoration(
                labelText: 'ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط£ظˆظ„ظٹط©',
              ),
              obscureText: true,
              validator: AppValidators.password,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createUser,
                child: const Text('ط¥ظ†ط´ط§ط، ط§ظ„ظ…ط³طھط®ط¯ظ…'),
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
      title: 'ط¥ط¶ط§ظپط© طµظ†ط¯ظˆظ‚',
      subtitle: 'طµظ†ط¯ظˆظ‚ ظ…ط¹طھظ…ط¯ ط£ظˆ ظˆظƒظٹظ„ ط£ظˆ ط®ط²ظ†ط©',
      child: Form(
        key: _cashboxFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            TextFormField(
              controller: _cName,
              decoration: const InputDecoration(
                labelText: 'ط§ط³ظ… ط§ظ„طµظ†ط¯ظˆظ‚',
              ),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _cType,
              decoration: const InputDecoration(labelText: 'ط§ظ„ظ†ظˆط¹'),
              items: const [
                DropdownMenuItem(
                  value: 'accredited',
                  child: Text('طµظ†ط¯ظˆظ‚ ظ…ط¹طھظ…ط¯'),
                ),
                DropdownMenuItem(
                  value: 'agent',
                  child: Text('طµظ†ط¯ظˆظ‚ ظˆظƒظٹظ„'),
                ),
                DropdownMenuItem(
                  value: 'treasury',
                  child: Text('ط§ظ„ط®ط²ظ†ط©'),
                ),
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
                    decoration: const InputDecoration(
                      labelText: 'ط§ظ„ظ…ط¯ظٹظ†ط©',
                    ),
                    validator: AppValidators.requiredText,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _cCountry,
                    decoration: const InputDecoration(
                      labelText: 'ط§ظ„ط¯ظˆظ„ط©',
                    ),
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
                  labelText: 'ط¨ط­ط« ط¹ظ† ط§ظ„ظ…ط³ط¤ظˆظ„',
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
                decoration: const InputDecoration(labelText: 'ط§ظ„ظ…ط³ط¤ظˆظ„'),
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
                    return 'ظ„ط§ ظٹظˆط¬ط¯ ظ…ط³ط¤ظˆظ„ظˆظ† ظ…ط·ط§ط¨ظ‚ظˆظ† ظ„ظ„ط¯ظˆط± ط£ظˆ ط§ظ„ط¨ط­ط«.';
                  }
                  return (v == null || v.isEmpty)
                      ? 'ط§ط®طھط± ظ…ط³ط¤ظˆظ„ط§ظ‹'
                      : null;
                },
              ),
              if (managerOptions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ظ„ط§ ظٹظˆط¬ط¯ ظ…ط³ط¤ظˆظ„ظˆظ† ظ…ط·ط§ط¨ظ‚ظˆظ† ط­ط§ظ„ظٹط§ظ‹.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _cOpening,
              decoration: const InputDecoration(
                labelText: 'ط§ظ„ط±طµظٹط¯ ط§ظ„ط§ظپطھطھط§ط­ظٹ',
              ),
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
                child: const Text('ط¥ظ†ط´ط§ط، ط§ظ„طµظ†ط¯ظˆظ‚'),
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
          title: 'ظ‚ط§ط¦ظ…ط© ط§ظ„ظ…ط³طھط®ط¯ظ…ظٹظ†',
          subtitle:
              'ظ‚ط§ط¦ظ…ط© ظ…ظپظ„طھط±ط© ط­ط³ط¨ ط§ظ„ط¯ظˆط± ط£ظˆ طھط§ط±ظٹط® ط§ظ„ط¥ط¶ط§ظپط©',
          users: users.take(30).toList(),
          emptyText: 'ظ„ط§ طھظˆط¬ط¯ ظ†طھط§ط¦ط¬ ظ…ط·ط§ط¨ظ‚ط©.',
        ),
      ],
    );
  }

  Widget _buildCashboxesList() {
    return AdminSectionCard(
      title: 'ظ‚ط§ط¦ظ…ط© ط§ظ„طµظ†ط§ط¯ظٹظ‚',
      subtitle:
          'ط¹ط±ط¶ ظ…ط®طھطµط± ظ„ظ„طµظ†ط§ط¯ظٹظ‚ ظˆط§ظ„ظ…ط¯ظٹط± ط§ظ„ظ…ط³ط¤ظˆظ„',
      child: Column(
        children: _cashboxes.take(18).map((c) {
          final trailing = c.isTreasury
              ? 'ظ…ظپطھظˆط­ط©'
              : moneyText(c.balanceValue);
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
        ? 'طµظ†ط¯ظˆظ‚ ط§ظ„ظˆظƒظٹظ„'
        : 'ط§ظ„طµظ†ط¯ظˆظ‚ ط§ظ„ظ…ط¹طھظ…ط¯';
    return AdminSectionCard(
      title: 'ظ…ط³ط§ط±ط§طھ ط§ظ„ط®ط²ظ†ط©',
      subtitle: transferTypeHintAr(_routeType),
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in const [
                ('topup', 'طھط¹ط¨ط¦ط© ظ…ط¹طھظ…ط¯'),
                ('collection', 'طھط­طµظٹظ„ ظ…ظ† ظ…ط¹طھظ…ط¯'),
                ('agent_funding', 'طھظ…ظˆظٹظ„ ظˆظƒظٹظ„'),
                ('agent_collection', 'طھط­طµظٹظ„ ظ…ظ† ظˆظƒظٹظ„'),
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
            decoration: const InputDecoration(labelText: 'ط§ظ„ظ…ط¨ظ„ط؛'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeCommissionPercent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'ظ†ط³ط¨ط© ط¹ظ…ظˆظ„ط© ط§ظ„ط®ط²ظ†ط© %',
              helperText:
                  'ط§ظ„ظ‚ظٹظ…ط© ط§ظ„ط§ظپطھط±ط§ط¶ظٹط© ظ…ظ† ط¶ط¨ط· ط§ظ„ط¹ظ…ظˆظ„ط§طھ ظˆظٹظ…ظƒظ† طھط¹ط¯ظٹظ„ظ‡ط§ ظ„ظ‡ط°ظ‡ ط§ظ„ط¹ظ…ظ„ظٹط© ظپظ‚ط·',
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
              label: const Text(
                'ط§ط³طھط¹ط§ط¯ط© ط§ظ„ط¹ظ…ظˆظ„ط© ط§ظ„ط§ظپطھط±ط§ط¶ظٹط©',
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _routeNote,
            decoration: const InputDecoration(labelText: 'ظ…ظ„ط§ط­ط¸ط©'),
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
      title: 'ط§ظ„طھظ‚ط§ط±ظٹط± ط§ظ„ظٹظˆظ…ظٹط©',
      subtitle:
          'ط¥ط¬ظ…ط§ظ„ظٹ ط§ظ„ط¹ظ…ظ„ظٹط§طھ ظˆط§ظ„ط¹ظ…ظˆظ„ط§طھ ظˆط§ظ„ط£ط±ط¨ط§ط­ ظ„ظƒظ„ ظٹظˆظ…',
      child: _dailyReport.isEmpty
          ? const Text(
              'ظ„ط§ طھظˆط¬ط¯ ط¨ظٹط§ظ†ط§طھ ظٹظˆظ…ظٹط© ط¶ظ…ظ† ط§ظ„ظپطھط±ط© ط§ظ„ظ…ط®طھط§ط±ط©.',
            )
          : Column(
              children: _dailyReport
                  .map(
                    (row) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.date),
                      subtitle: Text(
                        'ط§ظ„ط¹ظ…ظ„ظٹط§طھ: ${row.transfersCount} - ط§ظ„ظ…ظƒطھظ…ظ„ط©: ${row.completedCount} - ط§ظ„ظ…ط¹ظ„ظ‚ط©: ${row.pendingCount}',
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ط§ظ„ط¥ط¬ظ…ط§ظ„ظٹ ${moneyText(row.totalAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'ط¹ظ…ظˆظ„ط© ${moneyText(row.totalCommission)} / ط±ط¨ط­ ظˆظƒظٹظ„ ${moneyText(row.totalAgentProfit)}',
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
      title: 'ط·ظ„ط¨ط§طھ ط¨ط§ظ†طھط¸ط§ط± ط§ظ„ظ‚ط±ط§ط±',
      subtitle:
          'ط§ط¹طھظ…ط§ط¯ ط£ظˆ ط±ظپط¶ ط·ظ„ط¨ط§طھ ط§ظ„طھط¹ط¨ط¦ط© ظˆط§ظ„طھط­طµظٹظ„',
      child: _pendingTransfers.isEmpty
          ? const Text('ظ„ط§ طھظˆط¬ط¯ ط·ظ„ط¨ط§طھ ظ…ط¹ظ„ظ‚ط© ط­ط§ظ„ظٹط§ظ‹.')
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
      title: 'ط³ط¬ظ„ ط§ظ„طھط­ظˆظٹظ„ط§طھ',
      subtitle:
          'ظ†طھط§ط¦ط¬ ط§ظ„ط³ط¬ظ„ ط¶ظ…ظ† ط§ظ„ظپطھط±ط© ط§ظ„ط²ظ…ظ†ظٹط© ط§ظ„ط­ط§ظ„ظٹط©',
      child: Column(
        children: [
          _buildDateFilterControls(),
          const SizedBox(height: 8),
          _buildPrintButton(label: 'ط·ط¨ط§ط¹ط© ط³ط¬ظ„ ط§ظ„طھط­ظˆظٹظ„ط§طھ PDF'),
          const SizedBox(height: 10),
          if (_recentTransfers.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text('ظ„ط§ طھظˆط¬ط¯ ط³ط¬ظ„ط§طھ.'),
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
      title: 'ط¶ط¨ط· ط§ظ„ط¹ظ…ظˆظ„ط§طھ',
      subtitle:
          'طھط­ط¯ظٹط¯ ط¹ظ…ظˆظ„ط© ط§ظ„طھط­ظˆظٹظ„ ط§ظ„ط¯ط§ط®ظ„ظٹط© ظˆط§ظ„ط®ط§ط±ط¬ظٹط© ظ…ط¹ ط£ط±ط¨ط§ط­ ط§ظ„ظˆظƒظٹظ„ ظˆط§ظ„ظ…ط¹طھظ…ط¯.',
      child: Column(
        children: [
          _buildCommissionEditor(
            title: 'ط¹ظ…ظˆظ„ط§طھ ط§ظ„ظ…ط¹طھظ…ط¯',
            internalController: _accreditedInternal,
            externalController: _accreditedExternal,
            showAgentProfit: true,
            agentProfitInternalController: _accreditedTransferProfitInternal,
            agentProfitExternalController: _accreditedTransferProfitExternal,
            agentProfitInternalLabel: 'ط±ط¨ط­ ط§ظ„ظ…ط¹طھظ…ط¯ ط¯ط§ط®ظ„ظٹ %',
            agentProfitExternalLabel: 'ط±ط¨ط­ ط§ظ„ظ…ط¹طھظ…ط¯ ط®ط§ط±ط¬ظٹ %',
          ),
          const SizedBox(height: 10),
          _buildCommissionEditor(
            title: 'ط¹ظ…ظˆظ„ط§طھ ط§ظ„ظˆظƒظٹظ„',
            internalController: _agentInternal,
            externalController: _agentExternal,
            showAgentProfit: true,
            agentProfitInternalController: _agentTopupProfitInternal,
            agentProfitExternalController: _agentTopupProfitExternal,
            agentProfitInternalLabel: 'ط±ط¨ط­ ط§ظ„ظˆظƒظٹظ„ ط¯ط§ط®ظ„ظٹ %',
            agentProfitExternalLabel: 'ط±ط¨ط­ ط§ظ„ظˆظƒظٹظ„ ط®ط§ط±ط¬ظٹ %',
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
                  'ط¹ظ…ظˆظ„ط§طھ ظ…ط³ط§ط±ط§طھ ط§ظ„ط®ط²ظ†ط©',
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
                          labelText:
                              'ظ…ظ† ط§ظ„ط®ط²ظ†ط© ط¥ظ„ظ‰ ط§ظ„ظ…ط¹طھظ…ط¯ %',
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
                          labelText: 'ظ…ظ† ط§ظ„ط®ط²ظ†ط© ط¥ظ„ظ‰ ط§ظ„ظˆظƒظٹظ„ %',
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
                          labelText:
                              'طھط­طµظٹظ„ ظ…ظ† ط§ظ„ظ…ط¹طھظ…ط¯ ط¥ظ„ظ‰ ط§ظ„ط®ط²ظ†ط© %',
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
                          labelText:
                              'طھط­طµظٹظ„ ظ…ظ† ط§ظ„ظˆظƒظٹظ„ ط¥ظ„ظ‰ ط§ظ„ط®ط²ظ†ط© %',
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
              child: const Text('ط­ظپط¸ ط§ظ„ط¹ظ…ظˆظ„ط§طھ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoSection() {
    return AdminSectionCard(
      title: 'ظ…ط¹ظ„ظˆظ…ط§طھ ط§ظ„ظ†ط¸ط§ظ…',
      subtitle: 'ط¨ظٹط§ظ†ط§طھ ط§ظ„ط­ط³ط§ط¨ ط§ظ„ط­ط§ظ„ظٹ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(widget.session.fullName),
            subtitle: Text(
              'ظ…ط¯ظٹط± - ${widget.session.city}, ${widget.session.country} - ${widget.session.username}',
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
                    labelText: 'ط¹ظ…ظˆظ„ط© ط¯ط§ط®ظ„ظٹط© %',
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
                    labelText: 'ط¹ظ…ظˆظ„ط© ط®ط§ط±ط¬ظٹط© %',
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
                          agentProfitInternalLabel ??
                          'ط±ط¨ط­ طھط¹ط¨ط¦ط© ط¯ط§ط®ظ„ظٹ %',
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
                          agentProfitExternalLabel ??
                          'ط±ط¨ط­ طھط¹ط¨ط¦ط© ط®ط§ط±ط¬ظٹ %',
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
