import '../../../core/entities/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_activity_bus.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/validation/app_validators.dart';
import '../../../core/utils/report_pdf.dart';
import '../../../core/widgets/app_load_error_card.dart';
import '../../../core/widgets/app_shell_background.dart';
import '../../../core/widgets/dashboard_navigation.dart';
import '../../../core/widgets/dashboard_parts.dart';
import '../../../core/widgets/responsive_frame.dart';
import '../../../core/widgets/reveal_on_mount.dart';
import '../../auth/logic/auth_controller.dart';
import '../data/operations_api.dart';
import 'widgets/operations_transfer_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OperationsDashboardScreen extends ConsumerStatefulWidget {
  const OperationsDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  ConsumerState<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState
    extends ConsumerState<OperationsDashboardScreen> {
  final OperationsApi _api = OperationsApi();
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  bool _loading = true;
  bool _isUserActive = true;
  bool _inactiveNoticeShown = false;
  String? _loadError;
  String? _actingTransferId;

  List<CashboxModel> _cashboxes = const [];
  List<CommissionRuleModel> _commissionRules = const [];
  List<TransferModel> _transfers = const [];
  List<TransferModel> _pendingTransfers = const [];
  List<DailyTransferReportRowModel> _dailyReport = const [];

  DateTime? _fromDate;
  DateTime? _toDate;

  String _operationType = 'network_transfer';
  String? _fromCashboxId;
  String? _toCashboxId;

  final _operationFormKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _byNameUserSearchController = TextEditingController();
  final _byNameAmountController = TextEditingController();
  final _byNameNoteController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _cashoutProfitPercentController = TextEditingController(text: '0');
  String _byNameOperationType = 'network_transfer';
  String? _byNameOwnCashboxId;
  String? _byNameCounterpartyCashboxId;

  @override
  void initState() {
    super.initState();
    _operationType = widget.session.role == UserRole.agent
        ? 'topup'
        : 'network_transfer';
    _byNameOperationType = widget.session.role == UserRole.agent
        ? 'topup'
        : 'network_transfer';
    _loadData();
  }

  @override
  void dispose() {
    _revision.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _byNameUserSearchController.dispose();
    _byNameAmountController.dispose();
    _byNameNoteController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _cashoutProfitPercentController.dispose();
    super.dispose();
  }

  void _bumpRevision() => _revision.value++;

  void _setViewState(VoidCallback mutation) {
    if (!mounted) return;
    setState(mutation);
    _bumpRevision();
  }

  List<CashboxModel> get _myAccreditedCashboxes => _cashboxes
      .where((c) => c.isAccredited && c.managerUserId == widget.session.userId)
      .toList();

  List<CashboxModel> get _myAgentCashboxes => _cashboxes
      .where((c) => c.isAgent && c.managerUserId == widget.session.userId)
      .toList();

  List<CashboxModel> get _allAccreditedCashboxes =>
      _cashboxes.where((c) => c.isAccredited).toList();

  List<CashboxModel> get _treasuryCashboxes =>
      _cashboxes.where((c) => c.isTreasury).toList();

  List<CashboxModel> get _supportCashboxes =>
      _cashboxes.where((c) => c.isAgent || c.isTreasury).toList();

  List<String> get _availableOperationTypes {
    if (widget.session.role == UserRole.agent) {
      return const ['agent_funding', 'topup'];
    }
    return const ['network_transfer', 'topup', 'customer_cashout'];
  }

  List<CashboxModel> get _sourceOptions {
    switch (_operationType) {
      case 'network_transfer':
        return widget.session.role == UserRole.accredited
            ? _myAccreditedCashboxes
            : _allAccreditedCashboxes;
      case 'topup':
        return widget.session.role == UserRole.agent
            ? _myAgentCashboxes
            : _supportCashboxes;
      case 'agent_funding':
        return _treasuryCashboxes;
      case 'collection':
        return widget.session.role == UserRole.agent
            ? _allAccreditedCashboxes
            : _myAccreditedCashboxes;
      case 'customer_cashout':
        return _myAccreditedCashboxes;
      default:
        return const [];
    }
  }

  List<CashboxModel> get _destinationOptions {
    switch (_operationType) {
      case 'network_transfer':
        return _allAccreditedCashboxes
            .where((c) => c.id != _fromCashboxId)
            .toList();
      case 'topup':
        return widget.session.role == UserRole.agent
            ? _allAccreditedCashboxes
            : _myAccreditedCashboxes;
      case 'agent_funding':
        return _myAgentCashboxes;
      case 'collection':
        return widget.session.role == UserRole.agent
            ? _myAgentCashboxes
            : _supportCashboxes;
      case 'customer_cashout':
        return _myAccreditedCashboxes
            .where((c) => c.id == _fromCashboxId)
            .toList();
      default:
        return const [];
    }
  }

  String _inferByNameOperationType(CashboxModel? counterparty) {
    if (widget.session.role == UserRole.agent) {
      if (counterparty != null && counterparty.isTreasury) {
        return 'agent_funding';
      }
      return 'topup';
    }
    if (counterparty != null &&
        (counterparty.isAgent || counterparty.isTreasury)) {
      return 'topup';
    }
    return 'network_transfer';
  }

  List<CashboxModel> get _byNameOwnCashboxOptions {
    return widget.session.role == UserRole.agent
        ? _myAgentCashboxes
        : _myAccreditedCashboxes;
  }

  List<CashboxModel> get _byNameCounterpartyOptions {
    final term = _byNameUserSearchController.text.trim().toLowerCase();
    late final List<CashboxModel> base;
    if (widget.session.role == UserRole.agent) {
      base = [
        ..._allAccreditedCashboxes.where((cashbox) => cashbox.isActive),
        ..._treasuryCashboxes.where((cashbox) => cashbox.isActive),
      ];
    } else {
      final ownIds = _myAccreditedCashboxes
          .map((cashbox) => cashbox.id)
          .toSet();
      final accreditedTargets = _allAccreditedCashboxes
          .where((cashbox) => cashbox.isActive && !ownIds.contains(cashbox.id))
          .toList();
      final agentTargets = _cashboxes
          .where((cashbox) => cashbox.isAgent && cashbox.isActive)
          .toList();
      final treasuryTargets = _treasuryCashboxes
          .where((cashbox) => cashbox.isActive)
          .toList();
      base = [...accreditedTargets, ...agentTargets, ...treasuryTargets];
    }
    if (term.isEmpty) return base;
    return base.where((cashbox) {
      final manager = (cashbox.managerName ?? '').toLowerCase();
      final haystack =
          '$manager ${cashbox.name} ${cashbox.city} ${cashbox.country}'
              .toLowerCase();
      return haystack.contains(term);
    }).toList();
  }

  CashboxModel? get _byNameSelectedCounterparty {
    final selectedId = _byNameCounterpartyCashboxId;
    if (selectedId == null) return null;
    for (final cashbox in _cashboxes) {
      if (cashbox.id == selectedId) return cashbox;
    }
    return null;
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
      var isUserActive = true;
      var cashboxes = const <CashboxModel>[];
      var commissions = const <CommissionRuleModel>[];
      var pendingTransfers = const <TransferModel>[];

      try {
        cashboxes = await _api.fetchCashboxes(token);
        commissions = await _api.fetchCommissions(token);
        pendingTransfers = await _api.fetchPendingTransfers(
          token,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      } catch (error) {
        if (_isInactiveError(error)) {
          isUserActive = false;
        } else {
          rethrow;
        }
      }

      final transfersFuture = _api.fetchTransfers(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      final dailyFuture = _api.fetchDailyReport(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        limitDays: 45,
      );

      final transfers = await transfersFuture;
      final dailyRows = await dailyFuture;

      if (!mounted) return;
      setState(() {
        _isUserActive = isUserActive;
        _cashboxes = cashboxes;
        _commissionRules = commissions;
        _transfers = transfers;
        _pendingTransfers = pendingTransfers;
        _dailyReport = dailyRows;
        _syncSelections();
        _syncByNameSelections();
      });
      _bumpRevision();

      if (!isUserActive && !_inactiveNoticeShown) {
        _inactiveNoticeShown = true;
        AppNotifier.warning(
          context,
          'تم إلغاء تفعيل الحساب من قبل الإدارة. يمكنك عرض السجل والتقارير فقط.',
        );
      }
      if (isUserActive) {
        _inactiveNoticeShown = false;
      }
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

  bool _isInactiveError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('user is inactive') ||
        text.contains('الحساب غير مفعل') ||
        text.contains('إلغاء تفعيل');
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
      return 'تعذر تحميل البيانات بسبب صلاحيات الوصول. سجّل الدخول مجددًا.';
    }
    if (raw.isEmpty) {
      return 'حدث خطأ غير متوقع أثناء تحميل البيانات.';
    }
    return raw;
  }

  void _showInactiveBlockedMessage() {
    AppNotifier.warning(
      context,
      'الحساب غير مفعل حاليًا. لا يمكن تنفيذ العمليات إلى أن يتم تفعيله من الإدارة.',
    );
  }

  void _syncSelections() {
    final sources = _sourceOptions;
    if (_fromCashboxId == null || !sources.any((c) => c.id == _fromCashboxId)) {
      _fromCashboxId = sources.isEmpty ? null : sources.first.id;
    }

    final destinations = _destinationOptions;
    if (_toCashboxId == null ||
        !destinations.any((c) => c.id == _toCashboxId)) {
      _toCashboxId = destinations.isEmpty ? null : destinations.first.id;
    }
    if (_operationType == 'customer_cashout' && _fromCashboxId != null) {
      _toCashboxId = _fromCashboxId;
    }
  }

  void _syncByNameSelections() {
    final ownOptions = _byNameOwnCashboxOptions;
    if (_byNameOwnCashboxId == null ||
        !ownOptions.any((cashbox) => cashbox.id == _byNameOwnCashboxId)) {
      _byNameOwnCashboxId = ownOptions.isEmpty ? null : ownOptions.first.id;
    }

    final counterpartyOptions = _byNameCounterpartyOptions;
    if (_byNameCounterpartyCashboxId == null ||
        !counterpartyOptions.any(
          (cashbox) => cashbox.id == _byNameCounterpartyCashboxId,
        )) {
      _byNameCounterpartyCashboxId = counterpartyOptions.isEmpty
          ? null
          : counterpartyOptions.first.id;
    }
    _byNameOperationType = _inferByNameOperationType(
      _byNameSelectedCounterparty,
    );
  }

  CashboxModel? _cashboxById(String? id) {
    if (id == null) return null;
    for (final cashbox in _cashboxes) {
      if (cashbox.id == id) return cashbox;
    }
    return null;
  }

  CommissionRuleModel? _commissionRule(UserRole role) {
    for (final rule in _commissionRules) {
      if (rule.role == role) return rule;
    }
    return null;
  }

  double _parseNumber(String? value) {
    final raw = (value ?? '').trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  String _fmt2(double value) => value.toStringAsFixed(2);

  bool _isCrossCountry(CashboxModel? source, CashboxModel? destination) {
    if (source == null || destination == null) return false;
    return source.country.toLowerCase().trim() !=
        destination.country.toLowerCase().trim();
  }

  UserRole _commissionRoleFor(
    CashboxModel source,
    CashboxModel destination,
    String operationType,
  ) {
    if (operationType == 'network_transfer') return UserRole.accredited;
    if (operationType == 'customer_cashout') return UserRole.accredited;
    if (source.isTreasury && destination.isAccredited) {
      return UserRole.accredited;
    }
    if (source.isTreasury && destination.isAgent) return UserRole.agent;
    if (operationType == 'agent_funding' ||
        operationType == 'agent_collection') {
      return UserRole.agent;
    }
    if (source.isAgent || destination.isAgent) return UserRole.agent;
    return UserRole.admin;
  }

  bool _isTreasuryToUserFunding(
    CashboxModel source,
    CashboxModel destination, {
    String? operationType,
  }) {
    final currentOperationType = operationType ?? _operationType;
    return source.isTreasury &&
        (destination.isAccredited || destination.isAgent) &&
        (currentOperationType == 'topup' ||
            currentOperationType == 'agent_funding');
  }

  double _defaultCommissionPercentForCurrentFlow() {
    if (_operationType == 'customer_cashout') return 0;
    final source = _cashboxById(_fromCashboxId);
    final destination = _cashboxById(_toCashboxId);
    if (source == null || destination == null) return 0;

    if (_isTreasuryToUserFunding(source, destination)) {
      final adminRule = _commissionRule(UserRole.admin);
      if (destination.isAgent) {
        return _parseNumber(adminRule?.treasuryToAgentFeePercent);
      }
      return _parseNumber(adminRule?.treasuryToAccreditedFeePercent);
    }
    final isUserToTreasuryCollection =
        destination.isTreasury &&
        (source.isAccredited || source.isAgent) &&
        _operationType == 'collection';
    if (isUserToTreasuryCollection) {
      final adminRule = _commissionRule(UserRole.admin);
      if (source.isAgent) {
        return _parseNumber(adminRule?.treasuryCollectionFromAgentFeePercent);
      }
      return _parseNumber(
        adminRule?.treasuryCollectionFromAccreditedFeePercent,
      );
    }

    final role = _commissionRoleFor(source, destination, _operationType);
    final rule = _commissionRule(role);
    if (rule == null) return 0;
    final isCrossCountry = _isCrossCountry(source, destination);
    return isCrossCountry
        ? _parseNumber(rule.externalFeePercent)
        : _parseNumber(rule.internalFeePercent);
  }

  double _defaultSenderProfitPercentForCurrentFlow() {
    final source = _cashboxById(_fromCashboxId);
    final destination = _cashboxById(_toCashboxId);
    if (source == null || destination == null) return 0;

    final isAgentTopup =
        _operationType == 'topup' && source.isAgent && destination.isAccredited;
    final isAccreditedNetworkTransfer =
        _operationType == 'network_transfer' &&
        source.isAccredited &&
        destination.isAccredited;
    if (!isAgentTopup && !isAccreditedNetworkTransfer) return 0;

    final role = isAccreditedNetworkTransfer
        ? UserRole.accredited
        : UserRole.agent;
    final rule = _commissionRule(role);
    if (rule == null) return 0;
    final isCrossCountry = _isCrossCountry(source, destination);
    return isCrossCountry
        ? _parseNumber(rule.agentTopupProfitExternalPercent)
        : _parseNumber(rule.agentTopupProfitInternalPercent);
  }

  _TransferPreview _buildTransferPreview() {
    final source = _cashboxById(_fromCashboxId);
    final destination = _cashboxById(_toCashboxId);
    final requestedAmount = _round2(_parseNumber(_amountController.text));
    final commissionPercent = _isCustomerCashoutFlow()
        ? 0.0
        : _round2(_defaultCommissionPercentForCurrentFlow());
    final senderProfitPercent = _round2(
      _defaultSenderProfitPercentForCurrentFlow(),
    );
    final cashoutProfitPercent = _isCustomerCashoutFlow()
        ? _round2(_parseNumber(_cashoutProfitPercentController.text))
        : 0.0;

    final isTreasuryFunding =
        source != null &&
        destination != null &&
        _isTreasuryToUserFunding(source, destination);
    final isAgentTopup =
        source != null &&
        destination != null &&
        _operationType == 'topup' &&
        source.isAgent &&
        destination.isAccredited;
    final isAccreditedTransfer =
        source != null &&
        destination != null &&
        _operationType == 'network_transfer' &&
        source.isAccredited &&
        destination.isAccredited;
    final splitInput =
        isTreasuryFunding || isAgentTopup || isAccreditedTransfer;

    late final double netAmount;
    late final double commissionAmount;
    late final double senderProfitAmount;
    late final double cashoutProfitAmount;
    late final double senderDeduction;
    late final double recipientCredit;

    if (_isCustomerCashoutFlow()) {
      netAmount = requestedAmount;
      commissionAmount = 0;
      senderProfitAmount = 0;
      cashoutProfitAmount = _round2(netAmount * cashoutProfitPercent / 100);
      senderDeduction = requestedAmount;
      recipientCredit = netAmount;
    } else if (splitInput) {
      final denominator =
          1 + (commissionPercent / 100) + (senderProfitPercent / 100);
      netAmount = _round2(
        denominator <= 0 ? requestedAmount : requestedAmount / denominator,
      );
      commissionAmount = _round2(netAmount * commissionPercent / 100);
      senderProfitAmount = _round2(netAmount * senderProfitPercent / 100);
      cashoutProfitAmount = 0;
      senderDeduction = requestedAmount;
      recipientCredit = netAmount;
    } else {
      netAmount = requestedAmount;
      commissionAmount = _round2(netAmount * commissionPercent / 100);
      senderProfitAmount = 0;
      cashoutProfitAmount = 0;
      senderDeduction = _round2(requestedAmount + commissionAmount);
      recipientCredit = netAmount;
    }

    return _TransferPreview(
      sourceName: source?.name ?? '-',
      destinationName: _isCustomerCashoutFlow()
          ? ((_customerNameController.text.trim().isEmpty)
                ? 'عميل'
                : 'عميل: ${_customerNameController.text.trim()}')
          : (destination?.name ?? '-'),
      operationLabel: _operationLabel(_operationType),
      requestedAmount: requestedAmount,
      commissionPercent: commissionPercent,
      commissionAmount: commissionAmount,
      senderProfitPercent: senderProfitPercent,
      senderProfitAmount: senderProfitAmount,
      cashoutProfitPercent: cashoutProfitPercent,
      cashoutProfitAmount: cashoutProfitAmount,
      netAmount: netAmount,
      senderDeduction: senderDeduction,
      recipientCredit: recipientCredit,
      splitInput: splitInput,
    );
  }

  double _defaultCommissionPercentForNamedRoute(_ByNameTransferRoute route) {
    final source = _cashboxById(route.fromCashboxId);
    final destination = _cashboxById(route.toCashboxId);
    if (source == null || destination == null) return 0;

    if (_isTreasuryToUserFunding(
      source,
      destination,
      operationType: route.operationType,
    )) {
      final adminRule = _commissionRule(UserRole.admin);
      if (destination.isAgent) {
        return _parseNumber(adminRule?.treasuryToAgentFeePercent);
      }
      return _parseNumber(adminRule?.treasuryToAccreditedFeePercent);
    }
    final isUserToTreasuryCollection =
        destination.isTreasury &&
        (source.isAccredited || source.isAgent) &&
        route.operationType == 'collection';
    if (isUserToTreasuryCollection) {
      final adminRule = _commissionRule(UserRole.admin);
      if (source.isAgent) {
        return _parseNumber(adminRule?.treasuryCollectionFromAgentFeePercent);
      }
      return _parseNumber(
        adminRule?.treasuryCollectionFromAccreditedFeePercent,
      );
    }

    final role = _commissionRoleFor(source, destination, route.operationType);
    final rule = _commissionRule(role);
    if (rule == null) return 0;
    final isCrossCountry = _isCrossCountry(source, destination);
    return isCrossCountry
        ? _parseNumber(rule.externalFeePercent)
        : _parseNumber(rule.internalFeePercent);
  }

  double _defaultSenderProfitPercentForNamedRoute(_ByNameTransferRoute route) {
    final source = _cashboxById(route.fromCashboxId);
    final destination = _cashboxById(route.toCashboxId);
    if (source == null || destination == null) return 0;

    final isAgentTopup =
        route.operationType == 'topup' &&
        source.isAgent &&
        destination.isAccredited;
    final isAccreditedNetworkTransfer =
        route.operationType == 'network_transfer' &&
        source.isAccredited &&
        destination.isAccredited;
    if (!isAgentTopup && !isAccreditedNetworkTransfer) return 0;

    final role = isAccreditedNetworkTransfer
        ? UserRole.accredited
        : UserRole.agent;
    final rule = _commissionRule(role);
    if (rule == null) return 0;
    final isCrossCountry = _isCrossCountry(source, destination);
    return isCrossCountry
        ? _parseNumber(rule.agentTopupProfitExternalPercent)
        : _parseNumber(rule.agentTopupProfitInternalPercent);
  }

  _TransferPreview _buildTransferPreviewForNamedRoute(
    _ByNameTransferRoute route,
  ) {
    final source = _cashboxById(route.fromCashboxId);
    final destination = _cashboxById(route.toCashboxId);
    final requestedAmount = _round2(_parseNumber(route.amount));
    final commissionPercent = _round2(
      _defaultCommissionPercentForNamedRoute(route),
    );
    final senderProfitPercent = _round2(
      _defaultSenderProfitPercentForNamedRoute(route),
    );

    final isTreasuryFunding =
        source != null &&
        destination != null &&
        _isTreasuryToUserFunding(source, destination);
    final isAgentTopup =
        source != null &&
        destination != null &&
        route.operationType == 'topup' &&
        source.isAgent &&
        destination.isAccredited;
    final isAccreditedTransfer =
        source != null &&
        destination != null &&
        route.operationType == 'network_transfer' &&
        source.isAccredited &&
        destination.isAccredited;
    final splitInput =
        isTreasuryFunding || isAgentTopup || isAccreditedTransfer;

    late final double netAmount;
    late final double commissionAmount;
    late final double senderProfitAmount;
    late final double senderDeduction;
    late final double recipientCredit;

    if (splitInput) {
      final denominator =
          1 + (commissionPercent / 100) + (senderProfitPercent / 100);
      netAmount = _round2(
        denominator <= 0 ? requestedAmount : requestedAmount / denominator,
      );
      commissionAmount = _round2(netAmount * commissionPercent / 100);
      senderProfitAmount = _round2(netAmount * senderProfitPercent / 100);
      senderDeduction = requestedAmount;
      recipientCredit = netAmount;
    } else {
      netAmount = requestedAmount;
      commissionAmount = _round2(netAmount * commissionPercent / 100);
      senderProfitAmount = 0;
      senderDeduction = _round2(requestedAmount + commissionAmount);
      recipientCredit = netAmount;
    }

    return _TransferPreview(
      sourceName: source?.name ?? '-',
      destinationName: destination?.name ?? '-',
      operationLabel: _operationLabel(route.operationType),
      requestedAmount: requestedAmount,
      commissionPercent: commissionPercent,
      commissionAmount: commissionAmount,
      senderProfitPercent: senderProfitPercent,
      senderProfitAmount: senderProfitAmount,
      cashoutProfitPercent: 0,
      cashoutProfitAmount: 0,
      netAmount: netAmount,
      senderDeduction: senderDeduction,
      recipientCredit: recipientCredit,
      splitInput: splitInput,
    );
  }

  Future<bool> _confirmTransferPreview(_TransferPreview preview) async {
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
                  _previewLine('العملية', preview.operationLabel),
                  _previewLine('من', preview.sourceName),
                  _previewLine('إلى', preview.destinationName),
                  const Divider(height: 18),
                  _previewLine(
                    preview.splitInput
                        ? 'المبلغ الإجمالي المدخل'
                        : 'المبلغ المدخل',
                    moneyText(preview.requestedAmount),
                  ),
                  _previewLine(
                    'عمولة الخزنة',
                    '${moneyText(preview.commissionAmount)} (${_fmt2(preview.commissionPercent)}%)',
                  ),
                  if (preview.senderProfitAmount > 0)
                    _previewLine(
                      'ربح المرسل',
                      '${moneyText(preview.senderProfitAmount)} (${_fmt2(preview.senderProfitPercent)}%)',
                    ),
                  if (preview.cashoutProfitAmount > 0)
                    _previewLine(
                      'ربح صرف العميل',
                      '${moneyText(preview.cashoutProfitAmount)} (${_fmt2(preview.cashoutProfitPercent)}%)',
                    ),
                  _previewLine(
                    'الخصم من رصيد المرسل',
                    moneyText(preview.senderDeduction),
                  ),
                  _previewLine(
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

  Widget _previewLine(String label, String value, {bool emphasize = false}) {
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

  bool _isAgentFundingRequestFlow() =>
      widget.session.role == UserRole.agent &&
      _operationType == 'agent_funding';
  bool _isCustomerCashoutFlow() => _operationType == 'customer_cashout';

  bool _isGrossInputFlow() {
    if (_operationType == 'customer_cashout') {
      return false;
    }
    return _operationType == 'network_transfer' ||
        _operationType == 'topup' ||
        _operationType == 'agent_funding';
  }

  String _operationLabel(String type) {
    if (widget.session.role == UserRole.agent && type == 'agent_funding') {
      return 'طلب رصيد من المركز';
    }
    if (type == 'customer_cashout') {
      return 'صرف رصيد عميل';
    }
    return transferTypeLabelAr(type);
  }

  String _operationHint(String type) {
    if (widget.session.role == UserRole.agent && type == 'agent_funding') {
      return 'إرسال طلب تحويل رصيد من الخزنة المركزية إلى صندوق الوكيل بانتظار اعتماد الأدمن.';
    }
    if (widget.session.role == UserRole.agent && type == 'topup') {
      return 'أدخل المبلغ الإجمالي المقبوض من المعتمد. النظام يخصم عمولة الخزنة وربح الوكيل تلقائياً ويحوّل الصافي للمعتمد.';
    }
    if (widget.session.role == UserRole.accredited &&
        type == 'network_transfer') {
      return 'أدخل المبلغ الإجمالي. سيتم احتساب عمولة الخزنة وربح المعتمد تلقائياً ويصل الصافي للمعتمد الآخر.';
    }
    if (type == 'customer_cashout') {
      return 'أدخل اسم العميل وهاتفه ونسبة ربح الصرف الخاصة بك. الوجهة هي العميل مباشرة بدون صندوق وبدون موافقة الأدمن.';
    }
    return transferTypeHintAr(type);
  }

  bool _canCurrentUserReviewTransfer(TransferModel transfer) {
    if (widget.session.role == UserRole.admin) return false;
    return transfer.state == 'pending_review';
  }

  Future<void> _submitTransfer() async {
    if (!_isUserActive) {
      _showInactiveBlockedMessage();
      return;
    }

    if (!_operationFormKey.currentState!.validate()) {
      _show('تحقق من المدخلات المطلوبة.', isError: true);
      return;
    }

    if (_fromCashboxId == null || _toCashboxId == null) {
      _show('اختر الصندوقين أولاً.', isError: true);
      return;
    }
    final source = _cashboxById(_fromCashboxId);
    if (source == null) {
      _show('تعذر تحديد صندوق الإرسال.', isError: true);
      return;
    }

    if (_isCustomerCashoutFlow()) {
      final customerNameError = AppValidators.requiredText(
        _customerNameController.text,
      );
      if (customerNameError != null) {
        _show(customerNameError, isError: true);
        return;
      }
      final customerPhoneError = AppValidators.requiredText(
        _customerPhoneController.text,
      );
      if (customerPhoneError != null) {
        _show(customerPhoneError, isError: true);
        return;
      }
      final cashoutProfitError = AppValidators.percent(
        _cashoutProfitPercentController.text,
      );
      if (cashoutProfitError != null) {
        _show(cashoutProfitError, isError: true);
        return;
      }
    }

    final preview = _buildTransferPreview();
    if (!source.isTreasury &&
        _round2(source.balanceValue) < _round2(preview.senderDeduction)) {
      final shortage = _round2(preview.senderDeduction - source.balanceValue);
      _show(
        'الرصيد غير كافٍ لتنفيذ العملية.\n'
        'المتاح: ${moneyText(source.balanceValue)} - '
        'المطلوب مع الخصومات: ${moneyText(preview.senderDeduction)} - '
        'العجز: ${moneyText(shortage)}',
        isError: true,
      );
      return;
    }

    final confirmed = await _confirmTransferPreview(preview);
    if (!confirmed) return;

    try {
      final transfer = await _api.createTransfer(
        token: widget.session.token,
        fromCashboxId: _fromCashboxId!,
        toCashboxId: _isCustomerCashoutFlow() ? _fromCashboxId! : _toCashboxId!,
        amount: _amountController.text.trim(),
        operationType: _operationType,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        commissionPercent: _isCustomerCashoutFlow()
            ? null
            : _fmt2(_defaultCommissionPercentForCurrentFlow()),
        customerName: _isCustomerCashoutFlow()
            ? _customerNameController.text.trim()
            : null,
        customerPhone: _isCustomerCashoutFlow()
            ? _customerPhoneController.text.trim()
            : null,
        cashoutProfitPercent: _isCustomerCashoutFlow()
            ? _cashoutProfitPercentController.text.trim()
            : null,
      );

      _amountController.clear();
      _noteController.clear();
      if (_isCustomerCashoutFlow()) {
        _customerNameController.clear();
        _customerPhoneController.clear();
      }
      _show(
        transfer.state == 'pending_review'
            ? (_isAgentFundingRequestFlow()
                  ? 'تم إرسال طلب الرصيد من المركز بانتظار اعتماد الأدمن.'
                  : 'تم إرسال الطلب بانتظار الموافقة.')
            : 'تم تنفيذ العملية بنجاح.',
      );
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _show(error.toString(), isError: true);
    }
  }

  _ByNameTransferRoute? _resolveByNameTransferRoute() {
    final ownCashboxId = _byNameOwnCashboxId;
    final counterpartyCashboxId = _byNameCounterpartyCashboxId;
    if (ownCashboxId == null || counterpartyCashboxId == null) return null;
    final operationType = _inferByNameOperationType(
      _byNameSelectedCounterparty,
    );

    switch (operationType) {
      case 'network_transfer':
        return _ByNameTransferRoute(
          operationType: 'network_transfer',
          fromCashboxId: ownCashboxId,
          toCashboxId: counterpartyCashboxId,
          amount: _byNameAmountController.text.trim(),
          note: _byNameNoteController.text.trim(),
        );
      case 'topup':
        if (widget.session.role == UserRole.agent) {
          return _ByNameTransferRoute(
            operationType: 'topup',
            fromCashboxId: ownCashboxId,
            toCashboxId: counterpartyCashboxId,
            amount: _byNameAmountController.text.trim(),
            note: _byNameNoteController.text.trim(),
          );
        }
        return _ByNameTransferRoute(
          operationType: 'topup',
          fromCashboxId: counterpartyCashboxId,
          toCashboxId: ownCashboxId,
          amount: _byNameAmountController.text.trim(),
          note: _byNameNoteController.text.trim(),
        );
      case 'agent_funding':
        return _ByNameTransferRoute(
          operationType: 'agent_funding',
          fromCashboxId: counterpartyCashboxId,
          toCashboxId: ownCashboxId,
          amount: _byNameAmountController.text.trim(),
          note: _byNameNoteController.text.trim(),
        );
      default:
        return null;
    }
  }

  Future<void> _submitTransferByName() async {
    if (!_isUserActive) {
      _showInactiveBlockedMessage();
      return;
    }

    final amountError = AppValidators.amount(_byNameAmountController.text);
    if (amountError != null) {
      _show(amountError, isError: true);
      return;
    }

    final route = _resolveByNameTransferRoute();
    if (route == null) {
      _show(
        'تعذر تحديد مسار التحويل حسب الاسم. تحقق من المدخلات.',
        isError: true,
      );
      return;
    }

    final source = _cashboxById(route.fromCashboxId);
    if (source == null) {
      _show('تعذر تحديد صندوق الإرسال.', isError: true);
      return;
    }

    final preview = _buildTransferPreviewForNamedRoute(route);
    if (!source.isTreasury &&
        _round2(source.balanceValue) < _round2(preview.senderDeduction)) {
      final shortage = _round2(preview.senderDeduction - source.balanceValue);
      _show(
        'الرصيد غير كافٍ لتنفيذ العملية.\n'
        'المتاح: ${moneyText(source.balanceValue)} - '
        'المطلوب مع الخصومات: ${moneyText(preview.senderDeduction)} - '
        'العجز: ${moneyText(shortage)}',
        isError: true,
      );
      return;
    }

    final confirmed = await _confirmTransferPreview(preview);
    if (!confirmed) return;

    try {
      final transfer = await _api.createTransfer(
        token: widget.session.token,
        fromCashboxId: route.fromCashboxId,
        toCashboxId: route.toCashboxId,
        amount: route.amount,
        operationType: route.operationType,
        note: route.note.isEmpty ? null : route.note,
        commissionPercent: _fmt2(_defaultCommissionPercentForNamedRoute(route)),
      );
      _byNameAmountController.clear();
      _byNameNoteController.clear();
      _show(
        transfer.state == 'pending_review'
            ? 'تم إرسال الطلب بانتظار الموافقة.'
            : 'تم تنفيذ العملية بنجاح.',
      );
      await _loadData();
      _closeInputSectionIfOpen();
    } catch (error) {
      _show(error.toString(), isError: true);
    }
  }

  Future<void> _reviewTransfer(TransferModel transfer, bool approve) async {
    if (!_isUserActive) {
      _showInactiveBlockedMessage();
      return;
    }

    _setViewState(() => _actingTransferId = transfer.id);

    try {
      await _api.reviewTransfer(
        token: widget.session.token,
        transferId: transfer.id,
        approve: approve,
        note: approve ? 'اعتماد من لوحة الوكيل' : 'رفض من لوحة الوكيل',
      );
      _show(approve ? 'تم اعتماد الطلب.' : 'تم رفض الطلب.');
      await _loadData();
    } catch (error) {
      _show(error.toString(), isError: true);
    } finally {
      _setViewState(() => _actingTransferId = null);
    }
  }

  void _show(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppNotifier.error(context, message);
      return;
    }
    AppNotifier.success(context, message);
  }

  void _closeInputSectionIfOpen() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Future<void> _printReport() async {
    try {
      await printReportPdf(
        title: 'تقرير ${roleLabelAr(widget.session.role)}',
        transfers: _transfers,
        dailyRows: _dailyReport,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (error) {
      _show(error.toString(), isError: true);
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
          childBuilder: builder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myBoxes = widget.session.role == UserRole.agent
        ? _myAgentCashboxes
        : _myAccreditedCashboxes;
    final totalBalance = myBoxes.fold(0.0, (sum, c) => sum + c.balanceValue);
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
                    children: [
                      RevealOnMount(
                        delay: const Duration(milliseconds: 50),
                        child: DashboardHero(
                          title: 'لوحة ${roleLabelAr(widget.session.role)}',
                          subtitle:
                              'تنظيم احترافي للعمليات اليومية عبر أقسام واضحة وسريعة.',
                          caption:
                              '${widget.session.fullName} - ${widget.session.city} / ${widget.session.country}',
                          icon: widget.session.role == UserRole.agent
                              ? Icons.hub_rounded
                              : Icons.storefront_rounded,
                          trailing: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('تحديث'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .logout(),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('خروج'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white30),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: gap),
                      if (_loading)
                        const SizedBox.shrink()
                      else if (_loadError != null)
                        AppLoadErrorCard(
                          title: 'تعذر تحميل لوحة العمليات',
                          subtitle:
                              'يمكنك إعادة المحاولة بعد التأكد من الشبكة.',
                          message: _loadError!,
                          onRetry: _loadData,
                        )
                      else ...[
                        if (!_isUserActive)
                          Card(
                            color: const Color(0xFFFFF7ED),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.block_rounded,
                                    color: Color(0xFFB45309),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'الحساب غير مفعل. يمكنك عرض السجل والتقارير فقط.',
                                      style: TextStyle(
                                        color: Color(0xFF7C2D12),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!_isUserActive) SizedBox(height: gap),
                        _buildOverviewMetrics(myBoxes, totalBalance),
                        SizedBox(height: gap),
                        _buildMainSectionsCard(myBoxes, totalBalance),
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

  Widget _buildOverviewMetrics(
    List<CashboxModel> myBoxes,
    double totalBalance,
  ) {
    final mySourceCashboxIds = myBoxes.map((cashbox) => cashbox.id).toSet();
    final accreditedTransferProfit = widget.session.role == UserRole.accredited
        ? _transfers
              .where(
                (transfer) =>
                    transfer.state == 'completed' &&
                    mySourceCashboxIds.contains(transfer.fromCashboxId),
              )
              .fold<double>(
                0.0,
                (sum, transfer) => sum + transfer.agentProfitValue,
              )
        : 0.0;
    final accreditedCashoutProfit = widget.session.role == UserRole.accredited
        ? _transfers
              .where(
                (transfer) =>
                    transfer.state == 'completed' &&
                    mySourceCashboxIds.contains(transfer.fromCashboxId) &&
                    transfer.operationType == 'customer_cashout',
              )
              .fold<double>(
                0.0,
                (sum, transfer) => sum + transfer.cashoutProfitValue,
              )
        : 0.0;
    final agentProfit = widget.session.role == UserRole.agent
        ? _transfers
              .where(
                (transfer) =>
                    transfer.state == 'completed' &&
                    mySourceCashboxIds.contains(transfer.fromCashboxId),
              )
              .fold<double>(
                0.0,
                (sum, transfer) => sum + transfer.agentProfitValue,
              )
        : 0.0;
    final accreditedProfit = widget.session.role == UserRole.accredited
        ? accreditedTransferProfit + accreditedCashoutProfit
        : 0.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 760
            ? (constraints.maxWidth - 8) / 2
            : 112.0;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            SizedBox(
              width: width,
              child: DashboardMetricCard(
                label: 'صناديقي',
                value: myBoxes.length.toString(),
                hint: 'الصناديق التابعة لي',
                icon: Icons.inventory_2_rounded,
                accent: AppTheme.brandTeal,
              ),
            ),
            SizedBox(
              width: width,
              child: DashboardMetricCard(
                label: 'الرصيد',
                value: moneyText(totalBalance),
                hint: 'إجمالي الرصيد',
                icon: Icons.account_balance_wallet_rounded,
                accent: AppTheme.brandCoral,
              ),
            ),
            if (widget.session.role == UserRole.accredited)
              SizedBox(
                width: width,
                child: DashboardMetricCard(
                  label: 'ربح المعتمد',
                  value: moneyText(accreditedProfit),
                  hint:
                      'داخل التطبيق: ${moneyText(accreditedTransferProfit)}\n'
                      'صرف عميل (نقدي): ${moneyText(accreditedCashoutProfit)}',
                  icon: Icons.trending_up_rounded,
                  accent: AppTheme.brandTeal,
                ),
              ),
            if (widget.session.role == UserRole.agent)
              SizedBox(
                width: width,
                child: DashboardMetricCard(
                  label: 'ربح الوكيل',
                  value: moneyText(agentProfit),
                  hint: 'أرباح التحويلات المنفذة من صناديق الوكيل',
                  icon: Icons.trending_up_rounded,
                  accent: AppTheme.brandTeal,
                ),
              ),
            SizedBox(
              width: width,
              child: DashboardMetricCard(
                label: 'المعلقة',
                value: _pendingTransfers.length.toString(),
                hint: 'طلبات قيد المراجعة',
                icon: Icons.pending_actions_rounded,
                accent: AppTheme.brandGold,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMainSectionsCard(
    List<CashboxModel> myBoxes,
    double totalBalance,
  ) {
    return Column(
      children: [
        _buildMainGroup(
          title: 'العمليات اليومية',
          subtitle: 'كل وظيفة في شاشة منفصلة عبر زر واضح',
          actions: [
            _buildActionButton(
              icon: Icons.person_search_rounded,
              label: 'تنفيذ حسب الاسم',
              enabled: _isUserActive,
              onTap: () {
                if (!_isUserActive) {
                  _showInactiveBlockedMessage();
                  return;
                }
                _openSection(
                  title: 'تنفيذ حسب الاسم',
                  subtitle: 'أدخل الاسم وسيتم تحديد المسار المناسب تلقائيًا',
                  icon: Icons.person_search_rounded,
                  builder: (_) => _buildActionsByNameSection(),
                );
              },
            ),
            if (widget.session.role == UserRole.accredited)
              _buildActionButton(
                icon: Icons.account_balance_wallet_rounded,
                label: 'صرف رصيد لعميل',
                enabled: _isUserActive,
                onTap: () {
                  if (!_isUserActive) {
                    _showInactiveBlockedMessage();
                    return;
                  }
                  _setViewState(() {
                    _operationType = 'customer_cashout';
                    _syncSelections();
                  });
                  _openSection(
                    title: 'صرف رصيد لعميل',
                    subtitle:
                        'صرف للعميل مع الاسم والهاتف وربح الصرف النقدي الخاص بالمعتمد',
                    icon: Icons.account_balance_wallet_rounded,
                    builder: (_) => _buildActionsSection(),
                  );
                },
              ),
            _buildActionButton(
              icon: Icons.rule_rounded,
              label: 'الطلبات المعلقة',
              badge: _pendingTransfers.length.toString(),
              enabled: _isUserActive,
              onTap: () {
                if (!_isUserActive) {
                  _showInactiveBlockedMessage();
                  return;
                }
                _openSection(
                  title: 'الطلبات المعلقة',
                  subtitle: 'مراجعة الطلبات بانتظار القرار',
                  icon: Icons.rule_rounded,
                  builder: (_) => _buildPendingSection(),
                );
              },
            ),
            _buildActionButton(
              icon: Icons.history_rounded,
              label: 'سجل التحويلات',
              onTap: () => _openSection(
                title: 'سجل التحويلات',
                subtitle: 'آخر التحويلات ضمن الفترة المحددة',
                icon: Icons.history_rounded,
                builder: (_) => _buildTransfersSection(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildMainGroup(
          title: 'التقارير والمتابعة',
          subtitle: 'فلترة، تقرير يومي، وطباعة PDF',
          actions: [
            _buildActionButton(
              icon: Icons.space_dashboard_rounded,
              label: 'مؤشرات سريعة',
              onTap: () => _openSection(
                title: 'مؤشرات سريعة',
                subtitle: 'ملخص الأرقام الأساسية',
                icon: Icons.space_dashboard_rounded,
                builder: (_) => _buildMetricsSection(myBoxes, totalBalance),
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
          ],
        ),
        const SizedBox(height: 10),
        _buildMainGroup(
          title: 'الإعدادات',
          subtitle: 'معلومات الحساب وإعدادات سريعة',
          actions: [
            _buildActionButton(
              icon: Icons.settings_rounded,
              label: 'معلومات الحساب',
              onTap: () => _openSection(
                title: 'معلومات الحساب',
                subtitle: 'معلومات المستخدم والرابط الحالي',
                icon: Icons.settings_rounded,
                builder: (_) => _buildSettingsSection(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainGroup({
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return DashboardSectionCard(
      title: title,
      subtitle: subtitle,
      icon: Icons.widgets_rounded,
      child: Wrap(spacing: 8, runSpacing: 8, children: actions),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    String? badge,
  }) {
    return SizedBox(
      width: 165,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.62,
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
              if (!enabled) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock_outline_rounded, size: 13),
              ],
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
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
      ),
    );
  }

  Widget _buildMetricsSection(List<CashboxModel> myBoxes, double totalBalance) {
    return DashboardSectionCard(
      title: 'مؤشرات سريعة',
      subtitle: 'عرض مصغر للحالة الحالية',
      icon: Icons.space_dashboard_rounded,
      child: _buildOverviewMetrics(myBoxes, totalBalance),
    );
  }

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

  Widget _buildActionsSection() {
    final submitLabel = _isCustomerCashoutFlow()
        ? 'تنفيذ صرف العميل'
        : widget.session.role == UserRole.accredited &&
              _operationType != 'network_transfer'
        ? 'إرسال الطلب'
        : _isAgentFundingRequestFlow()
        ? 'إرسال طلب الرصيد'
        : 'تنفيذ العملية';
    final operationsDisabled = !_isUserActive;

    return DashboardSectionCard(
      title: 'تنفيذ عملية',
      subtitle: _operationHint(_operationType),
      icon: Icons.flash_on_rounded,
      child: Form(
        key: _operationFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _availableOperationTypes.map((type) {
                return ChoiceChip(
                  label: Text(_operationLabel(type)),
                  selected: _operationType == type,
                  onSelected: operationsDisabled
                      ? null
                      : (_) {
                          _setViewState(() {
                            _operationType = type;
                            _syncSelections();
                          });
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _fromCashboxId,
              decoration: const InputDecoration(labelText: 'من صندوق'),
              items: _sourceOptions
                  .map(
                    (cashbox) => DropdownMenuItem(
                      value: cashbox.id,
                      child: Text(
                        '${cashbox.name} - ${cashboxTypeLabelAr(cashbox.type)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: operationsDisabled
                  ? null
                  : (value) {
                      _setViewState(() {
                        _fromCashboxId = value;
                        _syncSelections();
                      });
                    },
            ),
            const SizedBox(height: 8),
            if (_isCustomerCashoutFlow())
              TextFormField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: '\u0627\u0644\u0648\u062c\u0647\u0629',
                  hintText: '\u0639\u0645\u064a\u0644',
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _toCashboxId,
                decoration: const InputDecoration(
                  labelText:
                      '\u0625\u0644\u0649 \u0635\u0646\u062f\u0648\u0642',
                ),
                items: _destinationOptions
                    .map(
                      (cashbox) => DropdownMenuItem(
                        value: cashbox.id,
                        child: Text(
                          '${cashbox.name} - ${cashboxTypeLabelAr(cashbox.type)}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: operationsDisabled
                    ? null
                    : (value) {
                        _setViewState(() {
                          _toCashboxId = value;
                          _syncSelections();
                        });
                      },
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              enabled: !operationsDisabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _isCustomerCashoutFlow()
                    ? 'المبلغ المطلوب صرفه'
                    : _isGrossInputFlow()
                    ? 'المبلغ الإجمالي'
                    : 'المبلغ',
              ),
              validator: AppValidators.amount,
            ),
            if (_isCustomerCashoutFlow()) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _customerNameController,
                enabled: !operationsDisabled,
                decoration: const InputDecoration(labelText: 'اسم العميل'),
                validator: AppValidators.requiredText,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _customerPhoneController,
                enabled: !operationsDisabled,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم هاتف العميل'),
                validator: AppValidators.requiredText,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cashoutProfitPercentController,
                enabled: !operationsDisabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'نسبة ربح الصرف %',
                ),
                validator: AppValidators.percent,
              ),
            ],
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              enabled: !operationsDisabled,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
              maxLength: 160,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: operationsDisabled ? null : _submitTransfer,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(submitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsByNameSection() {
    final operationsDisabled = !_isUserActive;
    final selectedCounterparty = _byNameSelectedCounterparty;
    final selectedCounterpartyName = selectedCounterparty == null
        ? '-'
        : (selectedCounterparty.isTreasury
              ? selectedCounterparty.name
              : (selectedCounterparty.managerName ??
                    selectedCounterparty.name));

    return DashboardSectionCard(
      title: 'تنفيذ حسب الاسم',
      subtitle: 'أدخل الاسم ليتم اختيار العملية والصندوق المناسبين تلقائيًا',
      icon: Icons.person_search_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _byNameUserSearchController,
            enabled: !operationsDisabled,
            decoration: const InputDecoration(
              labelText: 'اسم المستخدم أو الاسم الكامل',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (_) => _setViewState(_syncByNameSelections),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue:
                _byNameCounterpartyOptions.any(
                  (cashbox) => cashbox.id == _byNameCounterpartyCashboxId,
                )
                ? _byNameCounterpartyCashboxId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'الجهة المستهدفة'),
            items: _byNameCounterpartyOptions
                .map(
                  (cashbox) => DropdownMenuItem(
                    value: cashbox.id,
                    child: Text(
                      '${cashbox.managerName ?? cashbox.name} - ${cashbox.name}',
                    ),
                  ),
                )
                .toList(),
            onChanged: operationsDisabled
                ? null
                : (value) => _setViewState(() {
                    _byNameCounterpartyCashboxId = value;
                    _syncByNameSelections();
                  }),
          ),
          if (_byNameCounterpartyOptions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'لا توجد نتائج مطابقة لبحث الاسم.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ),
            ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'العملية المحددة تلقائيًا',
            ),
            child: Text(_operationLabel(_byNameOperationType)),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue:
                _byNameOwnCashboxOptions.any(
                  (cashbox) => cashbox.id == _byNameOwnCashboxId,
                )
                ? _byNameOwnCashboxId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'صندوق التنفيذ'),
            items: _byNameOwnCashboxOptions
                .map(
                  (cashbox) => DropdownMenuItem(
                    value: cashbox.id,
                    child: Text(
                      '${cashbox.name} - ${cashboxTypeLabelAr(cashbox.type)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: operationsDisabled
                ? null
                : (value) => _setViewState(() => _byNameOwnCashboxId = value),
          ),
          if (selectedCounterparty != null) ...[
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
                  Text(
                    'العملية المحددة تلقائيًا: ${_operationLabel(_byNameOperationType)}',
                  ),
                  Text('الاسم: $selectedCounterpartyName'),
                  Text('الصندوق: ${selectedCounterparty.name}'),
                  Text(
                    'النوع: ${cashboxTypeLabelAr(selectedCounterparty.type)}',
                  ),
                  Text(
                    'المدينة/الدولة: ${selectedCounterparty.city} - ${selectedCounterparty.country}',
                  ),
                  Text(
                    'الرصيد الحالي: ${moneyText(selectedCounterparty.balanceValue)}',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            controller: _byNameAmountController,
            enabled: !operationsDisabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ'),
            validator: AppValidators.amount,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _byNameNoteController,
            enabled: !operationsDisabled,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
            maxLength: 160,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: operationsDisabled ? null : _submitTransferByName,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('تنفيذ العملية'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection() {
    if (!_isUserActive) {
      return DashboardSectionCard(
        title: 'الطلبات المعلقة',
        subtitle: 'الحساب غير مفعل',
        icon: Icons.rule_rounded,
        child: const Text(
          'لا يمكن مراجعة أو تنفيذ الطلبات أثناء إلغاء التفعيل.',
        ),
      );
    }

    return DashboardSectionCard(
      title: 'الطلبات المعلقة',
      subtitle: widget.session.role == UserRole.agent
          ? 'طلبات مرتبطة بصندوق الوكيل.'
          : 'طلبات بانتظار الاعتماد أو التنفيذ.',
      icon: Icons.rule_rounded,
      child: _pendingTransfers.isEmpty
          ? const Text('لا توجد طلبات معلقة حالياً.')
          : Column(
              children: _pendingTransfers.map((transfer) {
                final busy = _actingTransferId == transfer.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OperationsTransferTile(
                    transfer: transfer,
                    busy: busy,
                    onApprove: !busy && _canCurrentUserReviewTransfer(transfer)
                        ? () => _reviewTransfer(transfer, true)
                        : null,
                    onReject: !busy && _canCurrentUserReviewTransfer(transfer)
                        ? () => _reviewTransfer(transfer, false)
                        : null,
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildTransfersSection() {
    return DashboardSectionCard(
      title: 'سجل التحويلات',
      subtitle: 'العمليات ضمن التاريخ المحدد.',
      icon: Icons.history_rounded,
      child: Column(
        children: [
          _buildDateFilterControls(),
          const SizedBox(height: 8),
          _buildPrintButton(label: 'طباعة سجل التحويلات PDF'),
          const SizedBox(height: 10),
          if (_transfers.isEmpty)
            const Align(
              alignment: Alignment.centerRight,
              child: Text('لا يوجد سجل عمليات.'),
            )
          else
            Column(
              children: _transfers.take(20).map((transfer) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OperationsTransferTile(transfer: transfer),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDailyReportSection() {
    return DashboardSectionCard(
      title: 'التقارير اليومية',
      subtitle: 'إجماليات كل يوم',
      icon: Icons.bar_chart_rounded,
      child: _dailyReport.isEmpty
          ? const Text('لا توجد بيانات يومية.')
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
                      trailing: Text(
                        moneyText(row.totalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildPrintButton({String label = 'طباعة التقرير PDF'}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _printReport,
        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
        label: Text(label),
      ),
    );
  }

  Widget _buildReportsSection() {
    return Column(
      children: [
        DashboardSectionCard(
          title: 'التقارير',
          subtitle: 'بحث بالتاريخ وطباعة PDF',
          icon: Icons.bar_chart_rounded,
          child: Column(
            children: [
              _buildDateFilterControls(),
              const SizedBox(height: 8),
              _buildPrintButton(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildDailyReportSection(),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return DashboardSectionCard(
      title: 'معلومات الحساب',
      subtitle: 'بيانات المستخدم وإعدادات الاتصال',
      icon: Icons.settings_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(widget.session.fullName),
            subtitle: Text(
              '${roleLabelAr(widget.session.role)} - ${widget.session.city}, ${widget.session.country}',
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isUserActive
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _isUserActive ? 'الحساب: مفعل' : 'الحساب: غير مفعل',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _isUserActive
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFFB45309),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'نوع العملية الافتراضي',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableOperationTypes.map((type) {
              return ChoiceChip(
                label: Text(_operationLabel(type)),
                selected: _operationType == type,
                onSelected: (_) {
                  _setViewState(() {
                    _operationType = type;
                    _syncSelections();
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TransferPreview {
  const _TransferPreview({
    required this.sourceName,
    required this.destinationName,
    required this.operationLabel,
    required this.requestedAmount,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.senderProfitPercent,
    required this.senderProfitAmount,
    required this.cashoutProfitPercent,
    required this.cashoutProfitAmount,
    required this.netAmount,
    required this.senderDeduction,
    required this.recipientCredit,
    required this.splitInput,
  });

  final String sourceName;
  final String destinationName;
  final String operationLabel;
  final double requestedAmount;
  final double commissionPercent;
  final double commissionAmount;
  final double senderProfitPercent;
  final double senderProfitAmount;
  final double cashoutProfitPercent;
  final double cashoutProfitAmount;
  final double netAmount;
  final double senderDeduction;
  final double recipientCredit;
  final bool splitInput;
}

class _ByNameTransferRoute {
  const _ByNameTransferRoute({
    required this.operationType,
    required this.fromCashboxId,
    required this.toCashboxId,
    required this.amount,
    required this.note,
  });

  final String operationType;
  final String fromCashboxId;
  final String toCashboxId;
  final String amount;
  final String note;
}
