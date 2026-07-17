import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/input_utils.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/currency_amount_field.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../data/admin_api.dart';
import 'package:flutter/material.dart';

class AdminExecuteRequest {
  const AdminExecuteRequest({
    required this.fromCashboxId,
    required this.toCashboxId,
    required this.operationType,
    required this.amount,
    required this.commissionPercent,
    this.note,
    this.sourceCurrency = 'SYP',
  });

  final String fromCashboxId;
  final String toCashboxId;
  final String operationType;
  final String amount;
  final String commissionPercent;
  final String? note;
  final String sourceCurrency;
}

class AdminExecuteScreen extends StatefulWidget {
  const AdminExecuteScreen({
    super.key,
    required this.users,
    required this.cashboxes,
    required this.commissions,
    required this.token,
    required this.onSubmit,
    this.initialUserId,
  });

  final List<AppUser> users;
  final List<CashboxModel> cashboxes;
  final List<CommissionRuleModel> commissions;
  final String token;
  final Future<void> Function(AdminExecuteRequest request) onSubmit;
  final String? initialUserId;

  @override
  State<AdminExecuteScreen> createState() => _AdminExecuteScreenState();
}

class _AdminExecuteScreenState extends State<AdminExecuteScreen> {
  final _api = AdminApi();
  final _key = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _amount = TextEditingController();
  final _commission = TextEditingController(text: '0');
  final _note = TextEditingController();
  String? _userId;
  String? _cashboxId;
  String _currency = 'SYP';
  bool _busy = false;
  bool _commissionTouched = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null) {
      _userId = widget.initialUserId;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    _commission.dispose();
    _note.dispose();
    super.dispose();
  }

  CashboxModel? get _treasury => widget.cashboxes
      .where((box) => box.isTreasury && box.isActive)
      .firstOrNull;

  List<AppUser> get _userOptions {
    final query = _search.text.trim().toLowerCase();
    return widget.users.where((user) {
      if (!user.isActive || user.role == UserRole.admin) return false;
      if (query.isEmpty) return true;
      return '${user.fullName} ${user.username}'.toLowerCase().contains(query);
    }).toList();
  }

  AppUser? get _selectedUser =>
      widget.users.where((user) => user.id == _userId).firstOrNull;

  List<CashboxModel> _cashboxesForUser(AppUser user) {
    return widget.cashboxes.where((box) {
      return box.isActive &&
          box.managerUserId == user.id &&
          ((user.role == UserRole.agent && box.isAgent) ||
              (user.role == UserRole.accredited && box.isAccredited));
    }).toList();
  }

  List<CashboxModel> get _userCashboxes {
    final user = _selectedUser;
    if (user == null) return [];
    return _cashboxesForUser(user);
  }

  CashboxModel? get _selectedCashboxModel {
    final boxes = _userCashboxes;
    if (boxes.isEmpty) return null;
    if (boxes.length == 1) return boxes.first;
    return boxes.where((box) => box.id == _cashboxId).firstOrNull;
  }

  void _resetCashboxForUser(AppUser user) {
    final boxes = _cashboxesForUser(user);
    _cashboxId = boxes.length == 1 ? boxes.first.id : null;
  }

  String _defaultCommissionFor(AppUser user) {
    final rule = widget.commissions
        .where((item) => item.role == user.role)
        .firstOrNull;
    if (rule == null) return '0';
    if (user.role == UserRole.agent) {
      return rule.treasuryToAgentFeePercent;
    }
    return rule.treasuryToAccreditedFeePercent;
  }

  void _applyDefaultCommission({bool force = false}) {
    final user = _selectedUser;
    if (user == null) return;
    if (!force && _commissionTouched) return;
    _commission.text = _defaultCommissionFor(user);
  }

  Future<void> _resolveBySearch() async {
    final code = _search.text.trim();
    if (code.isEmpty) return;
    try {
      final user = await _api.resolveUserCode(token: widget.token, code: code);
      setState(() {
        _userId = user.id;
        _search.text = user.fullName;
        _commissionTouched = false;
        _resetCashboxForUser(user);
        _applyDefaultCommission(force: true);
      });
      if (mounted) AppNotifier.success(context, 'تم اختيار ${user.fullName}.');
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  String _boxBalanceText(CashboxModel box) {
    final balances = box.currencyBalances;
    if (balances.isEmpty) return '${moneyText(box.balanceValue)} SYP';
    return balances.entries
        .map((e) => formatCurrencyAmount(e.value, e.key))
        .join(' • ');
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final treasury = _treasury;
    final cashbox = _selectedCashboxModel;
    final user = _selectedUser;
    if (treasury == null || cashbox == null || user == null) return;
    final operationType =
        user.role == UserRole.agent ? 'agent_funding' : 'topup';

    final inputRaw = _amount.text.trim().replaceAll(',', '.');
    final inputAmount = double.tryParse(inputRaw) ?? 0;

    final request = AdminExecuteRequest(
      fromCashboxId: treasury.id,
      toCashboxId: cashbox.id,
      operationType: operationType,
      amount: inputAmount.toStringAsFixed(2),
      commissionPercent: _commission.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      sourceCurrency: _currency,
    );
    final percent =
        double.tryParse(request.commissionPercent.replaceAll(',', '.')) ?? 0;
    final commission = inputAmount * percent / 100;
    final net = inputAmount - commission;
    final deducted = inputAmount + commission;

    String fmtAmt(double val) => formatCurrencyAmount(val, _currency);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transferTypeLabelAr(operationType)),
            Text('${cashbox.name} — ${cashbox.city}, ${cashbox.country}'),
            if (_currency != 'SYP') Text('العملة: ${currencySymbol(_currency)}'),
            Text('المبلغ: ${fmtAmt(inputAmount)}'),
            Text('عمولة: ${request.commissionPercent}%'),
            Text('قيمة العمولة: ${fmtAmt(commission)}'),
            Text('الصافي الواصل: ${fmtAmt(net)}'),
            Text('المخصوم من المرسل: ${fmtAmt(deducted)}'),
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
    if (confirmed != true) return;
    setState(() => _busy = true);
    await widget.onSubmit(request);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final options = _userOptions;
    if ((_userId == null || !options.any((user) => user.id == _userId)) &&
        options.isNotEmpty) {
      _userId = options.first.id;
      final firstUser = options.first;
      _resetCashboxForUser(firstUser);
      _applyDefaultCommission(force: true);
    }
    final user = _selectedUser;
    final boxes = _userCashboxes;
    final selectedBox = _selectedCashboxModel;

    return Scaffold(
      appBar: AppBar(title: const Text('تنفيذ حسب الاسم')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: AppSectionCard(
                title: 'عملية خزنة',
                subtitle: 'تمويل أو تحصيل من مستخدم محدد',
                icon: Icons.person_search_rounded,
                child: Form(
                  key: _key,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      // ── Search field + button ──
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _search,
                              onTap: tapToMoveCursor(_search),
                              decoration: const InputDecoration(
                                labelText: 'بحث باسم المستخدم أو الكود',
                                prefixIcon: Icon(Icons.person_search_rounded),
                              ),
                              onChanged: (_) => setState(() {
                                _userId = null;
                                _cashboxId = null;
                              }),
                              onSubmitted: (_) => _resolveBySearch(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _resolveBySearch,
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── User dropdown ──
                      DropdownButtonFormField<String>(
                        initialValue: _userId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المستخدم',
                        ),
                        items: options
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  '${u.fullName} (@${u.username}) - ${roleLabelAr(u.role)}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          final picked = widget.users
                              .where((u) => u.id == value)
                              .firstOrNull;
                          setState(() {
                            _userId = value;
                            _commissionTouched = false;
                            if (picked != null) _resetCashboxForUser(picked);
                            _applyDefaultCommission(force: true);
                          });
                        },
                      ),
                      // ── Cashbox + Country side by side ──
                      if (user != null && boxes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: boxes.length == 1
                                  ? InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'الصندوق',
                                      ),
                                      child: Text(
                                        '${boxes.first.name}\n${_boxBalanceText(boxes.first)}',
                                      ),
                                    )
                                  : DropdownButtonFormField<String>(
                                      initialValue: _cashboxId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'الصندوق',
                                      ),
                                      items: boxes
                                          .map(
                                            (box) => DropdownMenuItem(
                                              value: box.id,
                                              child: Text(
                                                '${box.name} — ${_boxBalanceText(box)}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _cashboxId = v),
                                      validator: (_) => _cashboxId == null
                                          ? 'اختر الصندوق'
                                          : null,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'الدولة / المدينة',
                                ),
                                child: Text(
                                  selectedBox != null
                                      ? '${selectedBox.city}, ${selectedBox.country}'
                                      : '—',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),

                      // ── Amount + Currency ──
                      CurrencyAmountField(
                        amountController: _amount,
                        selectedCurrency: _currency,
                        onCurrencyChanged: (c) =>
                            setState(() => _currency = c),
                      ),
                      const SizedBox(height: 10),

                      // ── Commission ──
                      TextFormField(
                        controller: _commission,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onTap: tapToMoveCursor(_commission),
                        onChanged: (_) => _commissionTouched = true,
                        decoration: const InputDecoration(
                          labelText: 'عمولة الخزنة %',
                        ),
                        validator: AppValidators.percent,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _note,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'ملاحظة'),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: const Icon(Icons.send_rounded),
                          label: Text(_busy ? 'جار التنفيذ...' : 'تنفيذ'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
