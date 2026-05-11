import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../shared/presentation/screens/qr_code_scan_screen.dart';
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
  });

  final String fromCashboxId;
  final String toCashboxId;
  final String operationType;
  final String amount;
  final String commissionPercent;
  final String? note;
}

class AdminExecuteScreen extends StatefulWidget {
  const AdminExecuteScreen({
    super.key,
    required this.users,
    required this.cashboxes,
    required this.commissions,
    required this.token,
    required this.onSubmit,
  });

  final List<AppUser> users;
  final List<CashboxModel> cashboxes;
  final List<CommissionRuleModel> commissions;
  final String token;
  final Future<void> Function(AdminExecuteRequest request) onSubmit;

  @override
  State<AdminExecuteScreen> createState() => _AdminExecuteScreenState();
}

class _AdminExecuteScreenState extends State<AdminExecuteScreen> {
  final _api = AdminApi();
  final _key = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _userCode = TextEditingController();
  final _amount = TextEditingController();
  final _commission = TextEditingController(text: '0');
  final _note = TextEditingController();
  String? _userId;
  bool _collection = false;
  bool _busy = false;
  bool _commissionTouched = false;

  @override
  void dispose() {
    _search.dispose();
    _userCode.dispose();
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

  CashboxModel? get _selectedCashbox {
    final user = _selectedUser;
    if (user == null) return null;
    return widget.cashboxes.where((box) {
      return box.isActive &&
          box.managerUserId == user.id &&
          ((user.role == UserRole.agent && box.isAgent) ||
              (user.role == UserRole.accredited && box.isAccredited));
    }).firstOrNull;
  }

  String _defaultCommissionFor(AppUser user) {
    final rule = widget.commissions
        .where((item) => item.role == user.role)
        .firstOrNull;
    if (rule == null) return '0';
    if (user.role == UserRole.agent) {
      return _collection
          ? rule.treasuryCollectionFromAgentFeePercent
          : rule.treasuryToAgentFeePercent;
    }
    return _collection
        ? rule.treasuryCollectionFromAccreditedFeePercent
        : rule.treasuryToAccreditedFeePercent;
  }

  void _applyDefaultCommission({bool force = false}) {
    final user = _selectedUser;
    if (user == null) return;
    if (!force && _commissionTouched) return;
    _commission.text = _defaultCommissionFor(user);
  }

  Future<void> _resolveCode([String? rawCode]) async {
    final code = (rawCode ?? _userCode.text).trim();
    if (code.isEmpty) return;
    try {
      final user = await _api.resolveUserCode(token: widget.token, code: code);
      setState(() {
        _userId = user.id;
        _search.text = user.fullName;
        _commissionTouched = false;
        _applyDefaultCommission(force: true);
      });
      if (mounted) AppNotifier.success(context, 'تم اختيار ${user.fullName}.');
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _scanCode() async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrCodeScanScreen()));
    if (code == null || code.isEmpty) return;
    _userCode.text = code;
    await _resolveCode(code);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final treasury = _treasury;
    final cashbox = _selectedCashbox;
    final user = _selectedUser;
    if (treasury == null || cashbox == null || user == null) return;
    final operationType = user.role == UserRole.agent
        ? (_collection ? 'agent_collection' : 'agent_funding')
        : (_collection ? 'collection' : 'topup');
    final request = AdminExecuteRequest(
      fromCashboxId: _collection ? cashbox.id : treasury.id,
      toCashboxId: _collection ? treasury.id : cashbox.id,
      operationType: operationType,
      amount: _amount.text.trim(),
      commissionPercent: _commission.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    final amount = double.tryParse(request.amount.replaceAll(',', '.')) ?? 0;
    final percent =
        double.tryParse(request.commissionPercent.replaceAll(',', '.')) ?? 0;
    final commission = amount * percent / 100;
    final net = _collection ? amount : amount - commission;
    final deducted = _collection ? amount + commission : amount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية'),
        content: Text(
          '${transferTypeLabelAr(operationType)}\n'
          '${request.amount} SYP\n'
          'قيمة العمولة: ${moneyText(commission)}\n'
          'الصافي الواصل: ${moneyText(net)}\n'
          'المخصوم من المرسل: ${moneyText(deducted)}\n'
          'عمولة: ${request.commissionPercent}%',
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
      _applyDefaultCommission(force: true);
    }
    final user = _selectedUser;
    final cashbox = _selectedCashbox;
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
                      TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          labelText: 'بحث باسم المستخدم',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (_) => setState(() => _userId = null),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _userCode,
                              decoration: const InputDecoration(
                                labelText: 'كود أو QR المستخدم',
                                prefixIcon: Icon(Icons.qr_code_2_rounded),
                              ),
                              onSubmitted: (_) => _resolveCode(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _scanCode,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filled(
                            onPressed: () => _resolveCode(),
                            icon: const Icon(Icons.search_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _userId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'المستخدم',
                        ),
                        items: options
                            .map(
                              (user) => DropdownMenuItem(
                                value: user.id,
                                child: Text(
                                  '${user.fullName} (@${user.username}) - ${roleLabelAr(user.role)}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          _userId = value;
                          _commissionTouched = false;
                          _applyDefaultCommission(force: true);
                        }),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            icon: Icon(Icons.south_west_rounded),
                            label: Text('تمويل'),
                          ),
                          ButtonSegment(
                            value: true,
                            icon: Icon(Icons.north_east_rounded),
                            label: Text('تحصيل'),
                          ),
                        ],
                        selected: {_collection},
                        onSelectionChanged: (value) => setState(() {
                          _collection = value.first;
                          _commissionTouched = false;
                          _applyDefaultCommission(force: true);
                        }),
                      ),
                      if (user != null && cashbox != null) ...[
                        const SizedBox(height: 10),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'الصندوق',
                          ),
                          child: Text(
                            '${cashbox.name} - ${moneyText(cashbox.balanceValue)} SYP',
                          ),
                        ),
                      ],
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
                        decoration: const InputDecoration(
                          labelText: 'عمولة الخزنة %',
                        ),
                        onChanged: (_) => _commissionTouched = true,
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
