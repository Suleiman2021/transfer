import '../../../../core/entities/app_models.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/responsive_page.dart';
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
    required this.onSubmit,
  });

  final List<AppUser> users;
  final List<CashboxModel> cashboxes;
  final Future<void> Function(AdminExecuteRequest request) onSubmit;

  @override
  State<AdminExecuteScreen> createState() => _AdminExecuteScreenState();
}

class _AdminExecuteScreenState extends State<AdminExecuteScreen> {
  final _key = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _amount = TextEditingController();
  final _commission = TextEditingController(text: '0');
  final _note = TextEditingController();
  String? _userId;
  bool _collection = false;
  bool _busy = false;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد العملية'),
        content: Text(
          '${transferTypeLabelAr(operationType)}\n'
          '${request.amount} SYP\n'
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
                        onChanged: (value) => setState(() => _userId = value),
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
                        onSelectionChanged: (value) =>
                            setState(() => _collection = value.first),
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
