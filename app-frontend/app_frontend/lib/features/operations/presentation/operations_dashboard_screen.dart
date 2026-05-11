import '../../../core/entities/app_models.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/utils/dashboard_formatters.dart';
import '../../../core/utils/report_pdf.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/code_dialogs.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../features/shared/presentation/screens/account_security_screen.dart';
import '../data/operations_api.dart';
import 'operations_form_models.dart';
import 'screens/operations_history_screen.dart';
import 'screens/operations_reports_screen.dart';
import 'widgets/operations_account_tab.dart';
import 'widgets/operations_helpers.dart';
import 'widgets/operations_home_tab.dart';
import 'widgets/operations_pending_tab.dart';
import 'widgets/operations_transfer_tab.dart';
import 'package:flutter/material.dart';

class OperationsDashboardScreen extends StatefulWidget {
  const OperationsDashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<OperationsDashboardScreen> createState() =>
      _OperationsDashboardScreenState();
}

class _OperationsDashboardScreenState extends State<OperationsDashboardScreen> {
  final OperationsApi _api = OperationsApi();
  int _tab = 0;
  bool _loading = true;
  bool _isActive = true;
  String? _error;
  String? _busyTransferId;
  DateTime? _fromDate;
  DateTime? _toDate;

  List<CashboxModel> _cashboxes = const [];
  List<CommissionRuleModel> _commissions = const [];
  List<TransferModel> _transfers = const [];
  List<TransferModel> _pending = const [];
  List<DailyTransferReportRowModel> _daily = const [];

  List<CashboxModel> get _myCashboxes =>
      userCashboxes(widget.session, _cashboxes);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = widget.session.token;
      var active = true;
      var boxes = const <CashboxModel>[];
      var commissions = const <CommissionRuleModel>[];
      var pending = const <TransferModel>[];
      try {
        boxes = await _api.fetchCashboxes(token);
        commissions = await _api.fetchCommissions(token);
        pending = await _api.fetchPendingTransfers(
          token,
          fromDate: _fromDate,
          toDate: _toDate,
        );
      } catch (error) {
        if (isInactiveAccountError(error)) {
          active = false;
        } else {
          rethrow;
        }
      }
      final transfers = await _api.fetchTransfers(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      final daily = await _api.fetchDailyReport(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        limitDays: 45,
      );
      if (!mounted) return;
      setState(() {
        _isActive = active;
        _cashboxes = boxes;
        _commissions = commissions;
        _pending = pending;
        _transfers = transfers;
        _daily = daily;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = friendlyDataLoadError(
          error,
          connectivityMessage: 'تعذر الاتصال بالخادم. تحقق من الشبكة أو ngrok.',
          authorizationMessage: 'انتهت صلاحية الجلسة. سجل الدخول مجددًا.',
          emptyMessage: 'حدث خطأ غير متوقع أثناء تحميل البيانات.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDate: _fromDate ?? now,
    );
    if (selected != null) setState(() => _fromDate = selected);
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDate: _toDate ?? _fromDate ?? now,
    );
    if (selected != null) setState(() => _toDate = selected);
  }

  void _resetDates() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _loadData();
  }

  double _commissionPercentFor(OperationsTransferRequest request) {
    if (request.operationType == 'customer_cashout') return 0;
    final source = _cashboxes
        .where((box) => box.id == request.fromCashboxId)
        .firstOrNull;
    final destination = _cashboxes
        .where((box) => box.id == request.toCashboxId)
        .firstOrNull;
    if (source == null || destination == null) return 0;
    final rule = _commissions.where((rule) {
      if (request.operationType == 'agent_funding' || destination.isAgent) {
        return rule.role == UserRole.agent;
      }
      return rule.role == UserRole.accredited;
    }).firstOrNull;
    if (rule == null) return 0;
    final cross =
        source.country.toLowerCase() != destination.country.toLowerCase();
    return parseInputNumber(
      cross ? rule.externalFeePercent : rule.internalFeePercent,
    );
  }

  Future<bool> _confirm(OperationsTransferRequest request) async {
    final percent =
        request.commissionPercent ??
        formatFixed2(_commissionPercentFor(request));
    final amount = parseInputNumber(request.amount);
    final commission = amount * parseInputNumber(percent) / 100;
    final isSplitFee =
        request.operationType == 'network_transfer' ||
        request.operationType == 'topup' ||
        request.operationType == 'agent_funding';
    final net = isSplitFee ? amount - commission : amount;
    final deducted = isSplitFee ? amount : amount + commission;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('العملية: ${transferTypeLabelAr(request.operationType)}'),
            Text('المبلغ: ${request.amount}'),
            Text('عمولة الخزنة: $percent%'),
            Text('قيمة العمولة: ${moneyText(commission)}'),
            Text('الصافي الواصل: ${moneyText(net)}'),
            Text('المخصوم من المرسل: ${moneyText(deducted)}'),
            if ((request.customerName ?? '').isNotEmpty)
              Text('العميل: ${request.customerName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تنفيذ'),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  Future<void> _submitTransfer(OperationsTransferRequest request) async {
    if (!_isActive) {
      AppNotifier.warning(context, 'الحساب غير مفعل ولا يمكن تنفيذ العمليات.');
      return;
    }
    if (!await _confirm(request)) return;
    try {
      final transfer = await _api.createTransfer(
        token: widget.session.token,
        fromCashboxId: request.fromCashboxId,
        toCashboxId: request.toCashboxId,
        amount: request.amount,
        operationType: request.operationType,
        note: request.note,
        commissionPercent:
            request.commissionPercent ??
            formatFixed2(_commissionPercentFor(request)),
        customerName: request.customerName,
        customerPhone: request.customerPhone,
        cashoutProfitPercent: request.cashoutProfitPercent,
      );
      if (!mounted) return;
      await showTransferApprovalCodeDialog(context, transfer);
      if (!mounted) return;
      AppNotifier.success(
        context,
        transfer.state == 'pending_review'
            ? 'تم إرسال الطلب بانتظار الموافقة.'
            : 'تم تنفيذ العملية بنجاح.',
      );
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _review(TransferModel transfer, bool approve) async {
    String? code;
    if (approve && transfer.approvalCodeRequired) {
      code = await promptTransferApprovalCode(context, transfer);
      if (code == null || code.isEmpty) return;
    }
    setState(() => _busyTransferId = transfer.id);
    try {
      await _api.reviewTransfer(
        token: widget.session.token,
        transferId: transfer.id,
        approve: approve,
        approvalCode: code,
        note: approve ? 'اعتماد من تطبيق العمليات' : 'رفض من تطبيق العمليات',
      );
      if (!mounted) return;
      AppNotifier.success(context, approve ? 'تم الاعتماد.' : 'تم الرفض.');
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _busyTransferId = null);
    }
  }

  Future<void> _printReport() async {
    await printReportPdf(
      title: 'تقرير ${roleLabelAr(widget.session.role)}',
      transfers: _transfers,
      dailyRows: _daily,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _openHistory() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OperationsHistoryScreen(
        transfers: _transfers,
        fromDate: _fromDate,
        toDate: _toDate,
        onPickFrom: _pickFromDate,
        onPickTo: _pickToDate,
        onSearch: _loadData,
        onReset: _resetDates,
        onPrint: _printReport,
      ),
    ),
  );

  void _openReports() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OperationsReportsScreen(
        rows: _daily,
        fromDate: _fromDate,
        toDate: _toDate,
        onPickFrom: _pickFromDate,
        onPickTo: _pickToDate,
        onSearch: _loadData,
        onReset: _resetDates,
        onPrint: _printReport,
      ),
    ),
  );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ResponsivePage(
        child: AppErrorView(
          title: 'تعذر تحميل لوحة العمليات',
          message: _error!,
          onRetry: _loadData,
        ),
      );
    }
    if (_myCashboxes.isEmpty) {
      return const ResponsivePage(
        child: AppEmptyState(
          title: 'لا توجد صناديق',
          subtitle: 'لم يتم العثور على صناديق تابعة لهذا الحساب.',
        ),
      );
    }
    late final Widget tab;
    if (_tab == 0) {
      tab = OperationsHomeTab(
        session: widget.session,
        myCashboxes: _myCashboxes,
        transfers: _transfers,
        pending: _pending,
        onTransfer: () => setState(() => _tab = 1),
        onPending: () => setState(() => _tab = 2),
        onHistory: _openHistory,
        onReports: _openReports,
      );
    } else if (_tab == 1) {
      tab = OperationsTransferTab(
        session: widget.session,
        cashboxes: _cashboxes,
        myCashboxes: _myCashboxes,
        enabled: _isActive,
        onSubmit: _submitTransfer,
      );
    } else if (_tab == 2) {
      tab = OperationsPendingTab(
        transfers: _pending,
        busyTransferId: _busyTransferId,
        onApprove: (transfer) => _review(transfer, true),
        onReject: (transfer) => _review(transfer, false),
      );
    } else {
      tab = OperationsAccountTab(
        session: widget.session,
        isActive: _isActive,
        onHistory: _openHistory,
        onReports: _openReports,
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(children: [ResponsivePage(child: tab)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(roleLabelAr(widget.session.role)),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountSecurityScreen(session: widget.session),
              ),
            ),
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tab,
        onChanged: (index) => setState(() => _tab = index),
        items: [
          const AppBottomNavItem(icon: Icons.home_rounded, label: 'الرئيسية'),
          const AppBottomNavItem(icon: Icons.send_rounded, label: 'تحويل'),
          AppBottomNavItem(
            icon: Icons.pending_actions_rounded,
            label: 'الطلبات',
            badge: _pending.length.toString(),
          ),
          const AppBottomNavItem(icon: Icons.person_rounded, label: 'الحساب'),
        ],
      ),
      body: AppBackground(child: _body()),
    );
  }
}
