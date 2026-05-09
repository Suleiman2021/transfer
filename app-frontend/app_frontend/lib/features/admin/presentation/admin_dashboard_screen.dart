import '../../../core/entities/app_models.dart';
import '../../../core/network/api_error_messages.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/utils/report_pdf.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/code_dialogs.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../features/auth/logic/auth_controller.dart';
import '../../../features/shared/presentation/screens/user_qr_screen.dart';
import '../data/admin_api.dart';
import 'screens/add_cashbox_screen.dart';
import 'screens/add_user_screen.dart';
import 'screens/admin_execute_screen.dart';
import 'screens/admin_user_report_screen.dart';
import 'screens/commission_settings_screen.dart';
import 'widgets/admin_home_tab.dart';
import 'widgets/admin_pending_tab.dart';
import 'widgets/admin_reports_tab.dart';
import 'widgets/admin_users_tab.dart';
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
  int _tab = 0;
  bool _loading = true;
  String? _error;
  String? _busyTransferId;
  DateTime? _fromDate;
  DateTime? _toDate;

  List<AppUser> _users = const [];
  List<CashboxModel> _cashboxes = const [];
  List<CommissionRuleModel> _commissions = const [];
  List<TransferModel> _pending = const [];
  List<TransferModel> _transfers = const [];
  List<DailyTransferReportRowModel> _daily = const [];

  double get _commissionRevenue =>
      _transfers.fold<double>(0, (sum, tx) => sum + tx.commissionValue);

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
      final users = await _api.fetchUsers(token, trackActivity: false);
      final cashboxes = await _api.fetchCashboxes(token, trackActivity: false);
      final commissions = await _api.fetchCommissions(
        token,
        trackActivity: false,
      );
      final pending = await _api.fetchPendingTransfers(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        trackActivity: false,
      );
      final transfers = await _api.fetchRecentTransfers(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        trackActivity: false,
      );
      final daily = await _api.fetchDailyReport(
        token,
        fromDate: _fromDate,
        toDate: _toDate,
        limitDays: 45,
        trackActivity: false,
      );
      if (!mounted) return;
      setState(() {
        _users = users;
        _cashboxes = cashboxes;
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
          emptyMessage: 'تعذر تحميل لوحة الأدمن.',
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

  Future<void> _createUser({
    required String username,
    required String fullName,
    required UserRole role,
    required String city,
    required String country,
    required String password,
  }) async {
    try {
      await _api.createUser(
        token: widget.session.token,
        username: username,
        fullName: fullName,
        role: role,
        city: city,
        country: country,
        password: password,
      );
      if (mounted) {
        AppNotifier.success(context, 'تم إنشاء المستخدم.');
        Navigator.of(context).pop();
      }
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _createCashbox({
    required String name,
    required String city,
    required String country,
    required String type,
    String? managerUserId,
    required String openingBalance,
  }) async {
    try {
      await _api.createCashbox(
        token: widget.session.token,
        name: name,
        city: city,
        country: country,
        type: type,
        managerUserId: managerUserId,
        openingBalance: openingBalance,
      );
      if (mounted) {
        AppNotifier.success(context, 'تم إنشاء الصندوق.');
        Navigator.of(context).pop();
      }
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _execute(AdminExecuteRequest request) async {
    try {
      final transfer = await _api.createTransfer(
        token: widget.session.token,
        fromCashboxId: request.fromCashboxId,
        toCashboxId: request.toCashboxId,
        amount: request.amount,
        operationType: request.operationType,
        commissionPercent: request.commissionPercent,
        note: request.note,
      );
      if (!mounted) return;
      await showTransferApprovalCodeDialog(context, transfer);
      if (mounted) {
        AppNotifier.success(context, 'تم إرسال العملية.');
        Navigator.of(context).pop();
      }
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _saveCommissions({
    required String accreditedInternal,
    required String accreditedExternal,
    required String accreditedProfitInternal,
    required String accreditedProfitExternal,
    required String agentInternal,
    required String agentExternal,
    required String agentProfitInternal,
    required String agentProfitExternal,
    required String treasuryToAccredited,
    required String treasuryToAgent,
    required String collectionFromAccredited,
    required String collectionFromAgent,
  }) async {
    try {
      await _api.saveCommission(
        token: widget.session.token,
        role: UserRole.accredited,
        internalFeePercent: accreditedInternal,
        externalFeePercent: accreditedExternal,
        agentTopupProfitInternalPercent: accreditedProfitInternal,
        agentTopupProfitExternalPercent: accreditedProfitExternal,
      );
      await _api.saveCommission(
        token: widget.session.token,
        role: UserRole.agent,
        internalFeePercent: agentInternal,
        externalFeePercent: agentExternal,
        agentTopupProfitInternalPercent: agentProfitInternal,
        agentTopupProfitExternalPercent: agentProfitExternal,
      );
      await _api.saveCommission(
        token: widget.session.token,
        role: UserRole.admin,
        internalFeePercent: '0',
        externalFeePercent: '0',
        agentTopupProfitInternalPercent: '0',
        agentTopupProfitExternalPercent: '0',
        treasuryToAccreditedFeePercent: treasuryToAccredited,
        treasuryToAgentFeePercent: treasuryToAgent,
        treasuryCollectionFromAccreditedFeePercent: collectionFromAccredited,
        treasuryCollectionFromAgentFeePercent: collectionFromAgent,
      );
      if (mounted) {
        AppNotifier.success(context, 'تم حفظ العمولات.');
        Navigator.of(context).pop();
      }
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _toggleUser(AppUser user) async {
    try {
      if (user.isActive) {
        await _api.deactivateUser(token: widget.session.token, userId: user.id);
      } else {
        await _api.activateUser(token: widget.session.token, userId: user.id);
      }
      if (mounted) AppNotifier.success(context, 'تم تحديث حالة المستخدم.');
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
        note: approve ? 'اعتماد من الأدمن' : 'رفض من الأدمن',
      );
      if (mounted) {
        AppNotifier.success(context, approve ? 'تم الاعتماد.' : 'تم الرفض.');
      }
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _busyTransferId = null);
    }
  }

  Future<void> _cancel(TransferModel transfer) async {
    setState(() => _busyTransferId = transfer.id);
    try {
      await _api.cancelTransfer(
        token: widget.session.token,
        transferId: transfer.id,
        note: 'إلغاء من الأدمن',
      );
      if (mounted) AppNotifier.success(context, 'تم إلغاء العملية.');
      await _loadData();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _busyTransferId = null);
    }
  }

  Future<void> _print() async {
    await printReportPdf(
      title: 'تقرير الأدمن',
      transfers: _transfers,
      dailyRows: _daily,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ResponsivePage(
        child: AppErrorView(
          title: 'تعذر التحميل',
          message: _error!,
          onRetry: _loadData,
        ),
      );
    }
    late final Widget tab;
    if (_tab == 0) {
      tab = AdminHomeTab(
        users: _users,
        cashboxes: _cashboxes,
        transfers: _transfers,
        pending: _pending,
        commissionRevenue: _commissionRevenue,
        onAddUser: () => _push(AddUserScreen(onSubmit: _createUser)),
        onAddCashbox: () =>
            _push(AddCashboxScreen(users: _users, onSubmit: _createCashbox)),
        onExecute: () => _push(
          AdminExecuteScreen(
            users: _users,
            cashboxes: _cashboxes,
            onSubmit: _execute,
          ),
        ),
        onCommissions: () => _push(
          CommissionSettingsScreen(
            rules: _commissions,
            onSave: _saveCommissions,
          ),
        ),
      );
    } else if (_tab == 1) {
      tab = AdminUsersTab(
        users: _users,
        onOpenReport: (user) => _push(
          AdminUserReportScreen(token: widget.session.token, user: user),
        ),
        onToggleActive: _toggleUser,
        onOpenQr: (user) => _push(UserQrScreen.fromUser(user)),
      );
    } else if (_tab == 2) {
      tab = AdminPendingTab(
        transfers: _pending,
        busyTransferId: _busyTransferId,
        onApprove: (transfer) => _review(transfer, true),
        onReject: (transfer) => _review(transfer, false),
      );
    } else {
      tab = AdminReportsTab(
        transfers: _transfers,
        dailyRows: _daily,
        fromDate: _fromDate,
        toDate: _toDate,
        onPickFrom: _pickFromDate,
        onPickTo: _pickToDate,
        onSearch: _loadData,
        onReset: _resetDates,
        onPrint: _print,
        onApprove: (transfer) => _review(transfer, true),
        onReject: (transfer) => _review(transfer, false),
        onCancel: _cancel,
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
        title: Text(widget.session.fullName),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _tab,
        onChanged: (index) => setState(() => _tab = index),
        items: [
          const AppBottomNavItem(icon: Icons.home_rounded, label: 'الرئيسية'),
          const AppBottomNavItem(
            icon: Icons.people_alt_rounded,
            label: 'المستخدمون',
          ),
          AppBottomNavItem(
            icon: Icons.pending_actions_rounded,
            label: 'الطلبات',
            badge: _pending.length.toString(),
          ),
          const AppBottomNavItem(
            icon: Icons.bar_chart_rounded,
            label: 'التقارير',
          ),
        ],
      ),
      body: AppBackground(child: _content()),
    );
  }
}
