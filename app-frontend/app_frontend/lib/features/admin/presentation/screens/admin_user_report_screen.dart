import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/security/device_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/input_utils.dart';
import '../../../../core/utils/report_pdf.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/cashbox_balance_sheet.dart';
import '../../../../core/widgets/code_dialogs.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/password_field.dart';
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
  String? _busyTransferId;
  static const bool _actionBusy = false;

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
      if (mounted) {
        setState(() {
          _report = report;
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

  Future<void> _editUser(AppUser user) async {
    final result = await showDialog<_UserEditInput>(
      context: context,
      builder: (_) => _UserEditDialog(user: user),
    );
    if (result == null) return;
    try {
      await _api.updateUser(
        token: widget.token,
        userId: user.id,
        username: result.username,
        fullName: result.fullName,
        city: result.city,
        country: result.country,
        phone: result.phone,
      );
      if (mounted) AppNotifier.success(context, 'تم تعديل معلومات المستخدم.');
      await _load();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _resetPassword(AppUser user) async {
    final ok = await DeviceAuth.verify(
      reason: 'تحقق من هويتك لإعادة تعيين كلمة مرور المستخدم',
    );
    if (!ok) {
      if (mounted) AppNotifier.error(context, 'تعذر التحقق من هوية الجهاز.');
      return;
    }
    if (!mounted) return;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordResetDialog(),
    );
    if (password == null || password.isEmpty) return;
    try {
      await _api.resetUserPassword(
        token: widget.token,
        userId: user.id,
        password: password,
      );
      if (mounted) AppNotifier.success(context, 'تم تعيين كلمة مرور جديدة.');
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _editCashbox(CashboxModel cashbox) async {
    final input = await showDialog<_CashboxEditInput>(
      context: context,
      builder: (_) => _CashboxEditDialog(cashbox: cashbox),
    );
    if (input == null) return;
    try {
      await _api.updateCashbox(
        token: widget.token,
        cashboxId: cashbox.id,
        name: input.name,
        city: input.city,
        country: input.country,
        isActive: input.isActive,
      );
      if (mounted) AppNotifier.success(context, 'تم تعديل الصندوق.');
      await _load();
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  // ── ملخص المستخدم: أرصدة قابلة للضغط + إدارة الصناديق مباشرة ───────────────
  Widget _summaryCard(UserTransferReportModel report) {
    final Map<String, double> currencyTotals = {};
    for (final box in report.cashboxes) {
      box.currencyBalances.forEach((k, v) {
        currencyTotals[k] = (currencyTotals[k] ?? 0) + v;
      });
    }
    void openBalances() => showCashboxBalanceSheet(
      context,
      cashboxes: report.cashboxes,
      ownerName: report.user.fullName,
    );
    return AppSectionCard(
      title: 'ملخص المستخدم',
      icon: Icons.analytics_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: MetricCard(
                      label: 'الرصيد',
                      value: currencyTotals.isEmpty ? '0' : '',
                      currencyAmounts: currencyTotals,
                      icon: Icons.wallet_rounded,
                      hint: 'اضغط للتفاصيل',
                      onTap: openBalances,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricCard(
                      label: 'الصناديق',
                      value: report.summary.cashboxesCount.toString(),
                      icon: Icons.inventory_rounded,
                      color: Colors.blue,
                      hint: report.cashboxes.isEmpty ? null : 'اضغط للتفاصيل',
                      onTap: report.cashboxes.isEmpty ? null : openBalances,
                    ),
                  ),
                ],
              );
            },
          ),
          if (report.cashboxes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 6),
                Text(
                  'إدارة الصناديق',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...report.cashboxes.map(
              (box) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _cashboxManageCard(box),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cashboxManageCard(CashboxModel box) {
    final balances = box.currencyBalances.entries
        .where((e) => e.value != 0)
        .toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassLine),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.brandTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppTheme.brandTeal,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${box.name} · ${cashboxTypeLabelAr(box.type)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  balances.isEmpty
                      ? 'لا يوجد رصيد'
                      : balances
                            .map((e) => formatCurrencyAmount(e.value, e.key))
                            .join('   ·   '),
                  style: TextStyle(
                    color: balances.isEmpty
                        ? AppTheme.textSoft
                        : AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تعديل الصندوق',
            onPressed: () => _editCashbox(box),
            icon: const Icon(Icons.edit_rounded, size: 19),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.glassTint,
              foregroundColor: AppTheme.brandInk,
            ),
          ),
        ],
      ),
    );
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
          if (widget.user.role != UserRole.admin &&
              widget.user.role != UserRole.superAdmin)
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
                          if (widget.user.role != UserRole.admin &&
                              widget.user.role != UserRole.superAdmin)
                            _summaryCard(report),
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
                                if (report.user.role != UserRole.superAdmin)
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
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _actionBusy
                                          ? null
                                          : () => _editUser(report.user),
                                      icon: const Icon(Icons.edit_rounded),
                                      label: const Text('تعديل المستخدم'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _actionBusy
                                          ? null
                                          : () => _resetPassword(report.user),
                                      icon: const Icon(Icons.password_rounded),
                                      label: const Text('تعيين كلمة مرور'),
                                    ),
                                  ],
                                ),
                              ],
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

class _UserEditInput {
  const _UserEditInput({
    required this.username,
    required this.fullName,
    required this.city,
    required this.country,
    required this.phone,
  });

  final String username;
  final String fullName;
  final String city;
  final String country;
  final String? phone;
}

class _UserEditDialog extends StatefulWidget {
  const _UserEditDialog({required this.user});

  final AppUser user;

  @override
  State<_UserEditDialog> createState() => _UserEditDialogState();
}

class _UserEditDialogState extends State<_UserEditDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _fullName;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.user.username);
    _fullName = TextEditingController(text: widget.user.fullName);
    _city = TextEditingController(text: widget.user.city);
    _country = TextEditingController(text: widget.user.country);
    _phone = TextEditingController(text: widget.user.phone ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _city.dispose();
    _country.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('تعديل المستخدم'),
      content: Form(
        key: _key,
        child: Column(
          children: [
            TextFormField(
              controller: _username,
              textDirection: TextDirection.ltr,
              onTap: tapToMoveCursor(_username),
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              validator: AppValidators.username,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullName,
              onTap: tapToMoveCursor(_fullName),
              decoration: const InputDecoration(labelText: 'الاسم الكامل'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              onTap: tapToMoveCursor(_phone),
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _city,
              onTap: tapToMoveCursor(_city),
              decoration: const InputDecoration(labelText: 'المدينة'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _country,
              onTap: tapToMoveCursor(_country),
              decoration: const InputDecoration(labelText: 'الدولة'),
              validator: AppValidators.requiredText,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            Navigator.of(context).pop(
              _UserEditInput(
                username: _username.text,
                fullName: _fullName.text,
                city: _city.text,
                country: _country.text,
                phone: _phone.text,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog();

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _key = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعيين كلمة مرور جديدة'),
      content: Form(
        key: _key,
        child: PasswordField(
          controller: _password,
          labelText: 'كلمة المرور الجديدة',
          validator: AppValidators.password,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            Navigator.of(context).pop(_password.text);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _CashboxEditInput {
  const _CashboxEditInput({
    required this.name,
    required this.city,
    required this.country,
    required this.isActive,
  });

  final String name;
  final String city;
  final String country;
  final bool isActive;
}

class _CashboxEditDialog extends StatefulWidget {
  const _CashboxEditDialog({required this.cashbox});

  final CashboxModel cashbox;

  @override
  State<_CashboxEditDialog> createState() => _CashboxEditDialogState();
}

class _CashboxEditDialogState extends State<_CashboxEditDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.cashbox.name);
    _city = TextEditingController(text: widget.cashbox.city);
    _country = TextEditingController(text: widget.cashbox.country);
    _isActive = widget.cashbox.isActive;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _country.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('تعديل الصندوق'),
      content: Form(
        key: _key,
        child: Column(
          children: [
            TextFormField(
              controller: _name,
              onTap: tapToMoveCursor(_name),
              decoration: const InputDecoration(labelText: 'اسم الصندوق'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _city,
              onTap: tapToMoveCursor(_city),
              decoration: const InputDecoration(labelText: 'المدينة'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _country,
              onTap: tapToMoveCursor(_country),
              decoration: const InputDecoration(labelText: 'الدولة'),
              validator: AppValidators.requiredText,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
              title: const Text('الصندوق فعال'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_key.currentState!.validate()) return;
            Navigator.of(context).pop(
              _CashboxEditInput(
                name: _name.text,
                city: _city.text,
                country: _country.text,
                isActive: _isActive,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
