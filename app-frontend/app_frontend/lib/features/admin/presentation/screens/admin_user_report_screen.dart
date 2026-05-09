import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/utils/report_pdf.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/code_dialogs.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/transfer_details_sheet.dart';
import '../../../../core/widgets/transfer_tile.dart';
import '../../../shared/presentation/screens/user_qr_screen.dart';
import '../../data/admin_api.dart';
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
  String? _busyTransferId;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await _api.fetchUserReport(
        widget.token,
        userId: widget.user.id,
      );
      final cashboxes = await _api.fetchCashboxes(
        widget.token,
        trackActivity: false,
      );
      if (mounted) {
        setState(() {
          _report = report;
          _allCashboxes = cashboxes;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyDataLoadError(
            error,
            connectivityMessage: 'تعذر الاتصال بالخادم.',
            emptyMessage: 'تعذر تحميل تقرير المستخدم.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive() async {
    final user = _report?.user ?? widget.user;
    try {
      if (user.isActive) {
        await _api.deactivateUser(token: widget.token, userId: user.id);
      } else {
        await _api.activateUser(token: widget.token, userId: user.id);
      }
      if (mounted) AppNotifier.success(context, 'تم تحديث حالة المستخدم.');
      await _load();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  CashboxModel? get _treasury => _allCashboxes
      .where((cashbox) => cashbox.isTreasury && cashbox.isActive)
      .firstOrNull;

  String _fundingType(CashboxModel cashbox) =>
      cashbox.isAgent ? 'agent_funding' : 'topup';

  String _collectionType(CashboxModel cashbox) =>
      cashbox.isAgent ? 'agent_collection' : 'collection';

  Future<void> _runTreasuryOperation(
    CashboxModel cashbox,
    String operationType,
  ) async {
    final treasury = _treasury;
    if (treasury == null) {
      AppNotifier.error(context, 'لا توجد خزنة مفعلة.');
      return;
    }
    final input = await showDialog<_TreasuryInput>(
      context: context,
      builder: (context) => _TreasuryOperationDialog(
        title: transferTypeLabelAr(operationType),
        fromName: operationType == 'topup' || operationType == 'agent_funding'
            ? treasury.name
            : cashbox.name,
        toName: operationType == 'topup' || operationType == 'agent_funding'
            ? cashbox.name
            : treasury.name,
      ),
    );
    if (input == null) return;

    final fromId = operationType == 'topup' || operationType == 'agent_funding'
        ? treasury.id
        : cashbox.id;
    final toId = operationType == 'topup' || operationType == 'agent_funding'
        ? cashbox.id
        : treasury.id;

    setState(() => _actionBusy = true);
    try {
      final transfer = await _api.createTransfer(
        token: widget.token,
        fromCashboxId: fromId,
        toCashboxId: toId,
        amount: input.amount,
        operationType: operationType,
        commissionPercent: input.commissionPercent,
        note: input.note,
        trackActivity: false,
      );
      if (!mounted) return;
      await showTransferApprovalCodeDialog(context, transfer);
      if (mounted) {
        AppNotifier.success(
          context,
          transfer.state == 'pending_review'
              ? 'تم إرسال العملية بانتظار الموافقة.'
              : 'تم تنفيذ العملية.',
        );
      }
      await _load();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _actionBusy = false);
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
        token: widget.token,
        transferId: transfer.id,
        approve: approve,
        approvalCode: code,
        note: approve ? 'اعتماد من تقرير المستخدم' : 'رفض من تقرير المستخدم',
      );
      if (mounted) {
        AppNotifier.success(context, approve ? 'تم الاعتماد.' : 'تم الرفض.');
      }
      await _load();
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
        token: widget.token,
        transferId: transfer.id,
        note: 'إلغاء من تقرير المستخدم',
      );
      if (mounted) AppNotifier.success(context, 'تم إلغاء العملية.');
      await _load();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _busyTransferId = null);
    }
  }

  Future<void> _print() async {
    final report = _report;
    if (report == null) return;
    await printUserReportPdf(report: report);
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user.fullName),
        actions: [
          IconButton(
            onPressed: _print,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserQrScreen.fromUser(widget.user),
              ),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
        ],
      ),
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            children: [
              ResponsivePage(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? AppErrorView(
                        title: 'تعذر التحميل',
                        message: _error!,
                        onRetry: _load,
                      )
                    : report == null
                    ? const AppEmptyState(
                        title: 'لا توجد بيانات',
                        subtitle: 'التقرير فارغ.',
                      )
                    : Column(
                        children: [
                          AppSectionCard(
                            title: 'ملخص المستخدم',
                            icon: Icons.analytics_rounded,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final width = (constraints.maxWidth - 8) / 2;
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    SizedBox(
                                      width: width,
                                      child: MetricCard(
                                        label: 'الرصيد',
                                        value: moneyText(
                                          report.summary.totalBalance,
                                        ),
                                        icon: Icons.wallet_rounded,
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: MetricCard(
                                        label: 'الصناديق',
                                        value: report.summary.cashboxesCount
                                            .toString(),
                                        icon: Icons.inventory_rounded,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppSectionCard(
                            title: 'صلاحيات الأدمن',
                            icon: Icons.admin_panel_settings_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_actionBusy) ...[
                                  const LinearProgressIndicator(minHeight: 3),
                                  const SizedBox(height: 10),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _actionBusy
                                            ? null
                                            : _toggleActive,
                                        icon: Icon(
                                          report.user.isActive
                                              ? Icons.person_off_rounded
                                              : Icons.verified_rounded,
                                        ),
                                        label: Text(
                                          report.user.isActive
                                              ? 'إيقاف المستخدم'
                                              : 'تفعيل المستخدم',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (_treasury == null)
                                  const Text(
                                    'لا يمكن تنفيذ عمليات الخزنة لأن الخزنة غير متاحة.',
                                  )
                                else if (report.cashboxes.isEmpty)
                                  const Text(
                                    'لا توجد صناديق تابعة لتنفيذ عمليات عليها.',
                                  )
                                else
                                  Column(
                                    children: report.cashboxes
                                        .map(
                                          (cashbox) => _UserCashboxActionCard(
                                            cashbox: cashbox,
                                            enabled:
                                                report.user.isActive &&
                                                !_actionBusy,
                                            onFund: () => _runTreasuryOperation(
                                              cashbox,
                                              _fundingType(cashbox),
                                            ),
                                            onCollect: () =>
                                                _runTreasuryOperation(
                                                  cashbox,
                                                  _collectionType(cashbox),
                                                ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          AppSectionCard(
                            title: 'الصناديق التابعة',
                            icon: Icons.inventory_2_rounded,
                            child: report.cashboxes.isEmpty
                                ? const Text('لا توجد صناديق.')
                                : Column(
                                    children: report.cashboxes
                                        .map(
                                          (box) => ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(box.name),
                                            subtitle: Text(
                                              cashboxTypeLabelAr(box.type),
                                            ),
                                            trailing: Text(
                                              moneyText(box.balanceValue),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          AppSectionCard(
                            title: 'سجل المستخدم',
                            icon: Icons.receipt_long_rounded,
                            child: report.transfers.isEmpty
                                ? const Text('لا توجد عمليات.')
                                : Column(
                                    children: report.transfers
                                        .map(
                                          (transfer) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: TransferTile(
                                              transfer: transfer,
                                              busy:
                                                  _busyTransferId ==
                                                  transfer.id,
                                              onTap: () =>
                                                  showTransferDetailsSheet(
                                                    context,
                                                    transfer: transfer,
                                                    busy:
                                                        _busyTransferId ==
                                                        transfer.id,
                                                    onApprove:
                                                        transfer.state ==
                                                            'pending_review'
                                                        ? () => _review(
                                                            transfer,
                                                            true,
                                                          )
                                                        : null,
                                                    onReject:
                                                        transfer.state ==
                                                            'pending_review'
                                                        ? () => _review(
                                                            transfer,
                                                            false,
                                                          )
                                                        : null,
                                                    onCancel:
                                                        transfer.state ==
                                                            'completed'
                                                        ? () =>
                                                              _cancel(transfer)
                                                        : null,
                                                  ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCashboxActionCard extends StatelessWidget {
  const _UserCashboxActionCard({
    required this.cashbox,
    required this.enabled,
    required this.onFund,
    required this.onCollect,
  });

  final CashboxModel cashbox;
  final bool enabled;
  final VoidCallback onFund;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${cashbox.name} - ${cashboxTypeLabelAr(cashbox.type)}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text('الرصيد الحالي: ${moneyText(cashbox.balanceValue)} SYP'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: enabled ? onFund : null,
                  icon: const Icon(Icons.south_west_rounded),
                  label: Text(
                    transferTypeLabelAr(
                      cashbox.isAgent ? 'agent_funding' : 'topup',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: enabled ? onCollect : null,
                  icon: const Icon(Icons.north_east_rounded),
                  label: Text(
                    transferTypeLabelAr(
                      cashbox.isAgent ? 'agent_collection' : 'collection',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TreasuryOperationDialog extends StatefulWidget {
  const _TreasuryOperationDialog({
    required this.title,
    required this.fromName,
    required this.toName,
  });

  final String title;
  final String fromName;
  final String toName;

  @override
  State<_TreasuryOperationDialog> createState() =>
      _TreasuryOperationDialogState();
}

class _TreasuryOperationDialogState extends State<_TreasuryOperationDialog> {
  final _key = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _commission = TextEditingController(text: '0');
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _commission.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_key.currentState!.validate()) return;
    Navigator.of(context).pop(
      _TreasuryInput(
        amount: _amount.text.trim(),
        commissionPercent: _commission.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _key,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'المسار'),
              child: Text('${widget.fromName} -> ${widget.toName}'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'المبلغ'),
              validator: AppValidators.amount,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _commission,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'عمولة الخزنة %'),
              validator: AppValidators.percent,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('تنفيذ')),
      ],
    );
  }
}

class _TreasuryInput {
  const _TreasuryInput({
    required this.amount,
    required this.commissionPercent,
    this.note,
  });

  final String amount;
  final String commissionPercent;
  final String? note;
}
