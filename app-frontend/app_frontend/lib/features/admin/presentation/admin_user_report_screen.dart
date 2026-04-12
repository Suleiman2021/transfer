import '../../../core/entities/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/validation/app_validators.dart';
import '../../../core/utils/report_pdf.dart';
import '../../../core/widgets/app_load_error_card.dart';
import '../../../core/widgets/app_shell_background.dart';
import '../../../core/widgets/responsive_frame.dart';
import '../../../core/widgets/reveal_on_mount.dart';
import '../data/admin_api.dart';
import 'widgets/admin_dashboard_widgets.dart';
import 'package:flutter/material.dart';

class AdminUserReportScreen extends StatefulWidget {
  const AdminUserReportScreen({
    super.key,
    required this.token,
    required this.user,
  });

  final String token;
  final AppUser user;

  @override
  State<AdminUserReportScreen> createState() => _AdminUserReportScreenState();
}

class _AdminUserReportScreenState extends State<AdminUserReportScreen> {
  final AdminApi _api = AdminApi();

  bool _loading = true;
  String? _error;
  UserTransferReportModel? _report;
  List<CashboxModel> _allCashboxes = const [];
  bool _actionBusy = false;

  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _loadReport();
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
    if (selected != null && mounted) {
      setState(() => _fromDate = selected);
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
    if (selected != null && mounted) {
      setState(() => _toDate = selected);
    }
  }

  Future<void> _loadReport() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final reportFuture = _api.fetchUserReport(
        widget.token,
        userId: widget.user.id,
        fromDate: _fromDate,
        toDate: _toDate,
      );
      final cashboxesFuture = _api.fetchCashboxes(
        widget.token,
        trackActivity: false,
      );
      final report = await reportFuture;
      final cashboxes = await cashboxesFuture;
      if (!mounted) return;
      setState(() {
        _report = report;
        _allCashboxes = cashboxes;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyLoadError(error));
      AppNotifier.error(context, _error ?? 'تعذر تحميل التقرير');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
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
      return 'تعذر الاتصال بالشبكة أو الخادم أثناء تحميل التقرير.';
    }
    if (raw.isEmpty) {
      return 'حدث خطأ غير متوقع أثناء تحميل التقرير.';
    }
    return raw;
  }

  Future<void> _printReport() async {
    final report = _report;
    if (report == null) return;
    try {
      await printUserReportPdf(report: report);
    } catch (error) {
      if (!mounted) return;
      AppNotifier.error(context, error.toString());
    }
  }

  CashboxModel? get _treasuryCashbox {
    for (final cashbox in _allCashboxes) {
      if (cashbox.isTreasury && cashbox.isActive) {
        return cashbox;
      }
    }
    return null;
  }

  String _fundingOperationType(CashboxModel cashbox) {
    return cashbox.isAgent ? 'agent_funding' : 'topup';
  }

  String _collectionOperationType(CashboxModel cashbox) {
    return cashbox.isAgent ? 'agent_collection' : 'collection';
  }

  Future<void> _toggleUserActivation({
    required AppUser user,
    required bool activate,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      if (activate) {
        await _api.activateUser(token: widget.token, userId: user.id);
      } else {
        await _api.deactivateUser(token: widget.token, userId: user.id);
      }
      if (!mounted) return;
      AppNotifier.success(
        context,
        activate ? 'تمت إعادة تفعيل المستخدم.' : 'تم إلغاء تفعيل المستخدم.',
      );
      await _loadReport();
    } catch (error) {
      if (!mounted) return;
      AppNotifier.error(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<_UserTreasuryOperationInput?> _promptTreasuryOperationInput({
    required String operationLabel,
    required String sourceName,
    required String destinationName,
  }) async {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final commissionController = TextEditingController(text: '0');
    final noteController = TextEditingController();
    try {
      final result = await showDialog<_UserTreasuryOperationInput>(
        context: context,
        builder: (context) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('تنفيذ عملية للمستخدم'),
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$operationLabel\n$sourceName -> $destinationName',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                      validator: AppValidators.amount,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: commissionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'عمولة الخزنة %',
                      ),
                      validator: AppValidators.percent,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'ملاحظة'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إغلاق'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(context).pop(
                      _UserTreasuryOperationInput(
                        amount: amountController.text.trim(),
                        commissionPercent: commissionController.text.trim(),
                        note: noteController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('تنفيذ'),
                ),
              ],
            ),
          );
        },
      );
      return result;
    } finally {
      amountController.dispose();
      commissionController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _runTreasuryOperationForUserCashbox({
    required CashboxModel cashbox,
    required String operationType,
  }) async {
    if (_actionBusy) return;
    final treasury = _treasuryCashbox;
    if (treasury == null) {
      AppNotifier.error(context, 'لا توجد خزنة مركزية مفعلة.');
      return;
    }

    final fromCashboxId =
        (operationType == 'topup' || operationType == 'agent_funding')
        ? treasury.id
        : cashbox.id;
    final toCashboxId =
        (operationType == 'topup' || operationType == 'agent_funding')
        ? cashbox.id
        : treasury.id;

    final input = await _promptTreasuryOperationInput(
      operationLabel: transferTypeLabelAr(operationType),
      sourceName:
          _allCashboxes
              .where((box) => box.id == fromCashboxId)
              .firstOrNull
              ?.name ??
          '-',
      destinationName:
          _allCashboxes
              .where((box) => box.id == toCashboxId)
              .firstOrNull
              ?.name ??
          '-',
    );
    if (input == null) return;

    setState(() => _actionBusy = true);
    try {
      final transfer = await _api.createTransfer(
        token: widget.token,
        fromCashboxId: fromCashboxId,
        toCashboxId: toCashboxId,
        amount: input.amount,
        operationType: operationType,
        note: input.note?.isEmpty == true ? null : input.note,
        commissionPercent: input.commissionPercent,
      );
      if (!mounted) return;
      AppNotifier.success(
        context,
        transfer.state == 'pending_review'
            ? 'تم إرسال الطلب بانتظار الموافقة.'
            : 'تم تنفيذ العملية بنجاح.',
      );
      await _loadReport();
    } catch (error) {
      if (!mounted) return;
      AppNotifier.error(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          visualDensity: VisualDensity.compact,
          tooltip: 'رجوع',
        ),
        const SizedBox(width: 2),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.brandSky.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.badge_rounded, size: 19),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تقرير المستخدم',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.user.fullName} - @${widget.user.username}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterCard() {
    return AdminSectionCard(
      title: 'الفلترة والطباعة',
      subtitle: 'حدد الفترة الزمنية ثم اطبع تقرير المستخدم PDF',
      child: Column(
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
                  onPressed: _loadReport,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('تحديث التقرير'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _printReport,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('طباعة PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(UserTransferReportModel report) {
    return AdminSectionCard(
      title: 'ملخص سريع',
      subtitle: 'أرقام الرصيد والحركة للمستخدم',
      child: LayoutBuilder(
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
                  label: 'الرصيد',
                  value: moneyText(report.summary.totalBalance),
                  hint: 'مجموع الصناديق',
                  icon: Icons.account_balance_wallet_rounded,
                  accent: AppTheme.brandGold,
                ),
              ),
              SizedBox(
                width: width,
                child: AdminMetricCard(
                  label: 'الصناديق',
                  value: report.summary.cashboxesCount.toString(),
                  hint: 'كل الصناديق التابعة',
                  icon: Icons.inventory_2_rounded,
                  accent: AppTheme.brandCoral,
                ),
              ),
              SizedBox(
                width: width,
                child: AdminMetricCard(
                  label: 'السجلات',
                  value: report.summary.transfersCount.toString(),
                  hint: 'إجمالي العمليات',
                  icon: Icons.receipt_long_rounded,
                  accent: AppTheme.brandTeal,
                ),
              ),
              SizedBox(
                width: width,
                child: AdminMetricCard(
                  label: 'عمولة الشبكة',
                  value: moneyText(report.summary.totalCommission),
                  hint: 'إجمالي العمولات',
                  icon: Icons.paid_rounded,
                  accent: AppTheme.brandPlum,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserInfo(UserTransferReportModel report) {
    final user = report.user;
    return AdminSectionCard(
      title: 'معلومات المستخدم',
      subtitle: 'البيانات الأساسية للحساب',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              Text('المعرف: @${user.username}'),
              Text('الدور: ${roleLabelAr(user.role)}'),
              Text('المدينة: ${user.city}'),
              Text('الدولة: ${user.country}'),
              Text('الحالة: ${user.isActive ? 'فعال' : 'غير فعال'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminActions(UserTransferReportModel report) {
    final user = report.user;
    final treasury = _treasuryCashbox;
    return AdminSectionCard(
      title: 'صلاحيات الأدمن على هذا المستخدم',
      subtitle: 'تنفيذ عمليات مباشرة لهذا المستخدم من نفس الشاشة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _actionBusy
                      ? null
                      : () => _toggleUserActivation(
                          user: user,
                          activate: !user.isActive,
                        ),
                  icon: Icon(
                    user.isActive
                        ? Icons.person_off_rounded
                        : Icons.verified_user_rounded,
                    size: 18,
                  ),
                  label: Text(
                    user.isActive ? 'إلغاء التفعيل' : 'إعادة التفعيل',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (treasury == null)
            const Text(
              'تعذر تنفيذ عمليات الخزنة لأن الخزنة المركزية غير مفعلة.',
            )
          else if (report.cashboxes.isEmpty)
            const Text('لا توجد صناديق تابعة لهذا المستخدم لتنفيذ العمليات.')
          else
            Column(
              children: report.cashboxes.map((cashbox) {
                final fundingType = _fundingOperationType(cashbox);
                final collectionType = _collectionOperationType(cashbox);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.panel.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.brandInk.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cashbox.name} - ${cashboxTypeLabelAr(cashbox.type)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرصيد الحالي: ${moneyText(cashbox.balanceValue)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _actionBusy || !user.isActive
                                ? null
                                : () => _runTreasuryOperationForUserCashbox(
                                    cashbox: cashbox,
                                    operationType: fundingType,
                                  ),
                            icon: const Icon(
                              Icons.south_west_rounded,
                              size: 18,
                            ),
                            label: Text(transferTypeLabelAr(fundingType)),
                          ),
                          OutlinedButton.icon(
                            onPressed: _actionBusy || !user.isActive
                                ? null
                                : () => _runTreasuryOperationForUserCashbox(
                                    cashbox: cashbox,
                                    operationType: collectionType,
                                  ),
                            icon: const Icon(
                              Icons.north_east_rounded,
                              size: 18,
                            ),
                            label: Text(transferTypeLabelAr(collectionType)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCashboxes(UserTransferReportModel report) {
    return AdminSectionCard(
      title: 'أرصدة الصناديق التابعة',
      subtitle: 'كل صندوق مرتبط بالمستخدم مع رصيده الحالي',
      child: report.cashboxes.isEmpty
          ? const Text('لا توجد صناديق مرتبطة بهذا المستخدم.')
          : Column(
              children: report.cashboxes
                  .map(
                    (cashbox) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(cashbox.name),
                      subtitle: Text(
                        '${cashboxTypeLabelAr(cashbox.type)} - ${cashbox.city}, ${cashbox.country}',
                      ),
                      trailing: Text(
                        moneyText(cashbox.balanceValue),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildDailyRows(UserTransferReportModel report) {
    return AdminSectionCard(
      title: 'التقارير اليومية',
      subtitle: 'ملخص يومي لسجل المستخدم',
      child: report.dailyRows.isEmpty
          ? const Text('لا توجد بيانات يومية ضمن الفترة المحددة.')
          : Column(
              children: report.dailyRows
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

  Widget _buildTransfers(UserTransferReportModel report) {
    return AdminSectionCard(
      title: 'سجل المستخدم',
      subtitle: 'تفاصيل التحويلات المرتبطة بهذا المستخدم',
      child: report.transfers.isEmpty
          ? const Text('لا توجد سجلات تحويل ضمن الفترة المحددة.')
          : Column(
              children: report.transfers
                  .take(30)
                  .map(
                    (transfer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AdminTransferTile(transfer: transfer),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppShellBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadReport,
            child: ListView(
              children: [
                ResponsiveFrame(
                  child: Column(
                    children: [
                      RevealOnMount(
                        delay: const Duration(milliseconds: 50),
                        child: _buildHeader(),
                      ),
                      const SizedBox(height: 10),
                      RevealOnMount(
                        delay: const Duration(milliseconds: 110),
                        child: _buildFilterCard(),
                      ),
                      const SizedBox(height: 8),
                      if (_loading)
                        const SizedBox.shrink()
                      else if (_error != null)
                        AppLoadErrorCard(
                          title: 'تعذر تحميل التقرير',
                          subtitle: 'حدث خطأ أثناء جلب بيانات المستخدم',
                          message: _error!,
                          onRetry: _loadReport,
                        )
                      else if (_report != null) ...[
                        _buildSummary(_report!),
                        _buildUserInfo(_report!),
                        _buildAdminActions(_report!),
                        _buildCashboxes(_report!),
                        _buildDailyRows(_report!),
                        _buildTransfers(_report!),
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
}

class _UserTreasuryOperationInput {
  const _UserTreasuryOperationInput({
    required this.amount,
    required this.commissionPercent,
    this.note,
  });

  final String amount;
  final String commissionPercent;
  final String? note;
}
