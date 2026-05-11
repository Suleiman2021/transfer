import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../shared/presentation/screens/qr_code_scan_screen.dart';
import '../../data/operations_api.dart';
import '../operations_form_models.dart';
import 'operations_helpers.dart';
import 'package:flutter/material.dart';

class OperationsTransferTab extends StatefulWidget {
  const OperationsTransferTab({
    super.key,
    required this.session,
    required this.cashboxes,
    required this.myCashboxes,
    required this.enabled,
    required this.onSubmit,
  });

  final AuthSession session;
  final List<CashboxModel> cashboxes;
  final List<CashboxModel> myCashboxes;
  final bool enabled;
  final Future<void> Function(OperationsTransferRequest request) onSubmit;

  @override
  State<OperationsTransferTab> createState() => _OperationsTransferTabState();
}

class _OperationsTransferTabState extends State<OperationsTransferTab> {
  final _api = OperationsApi();
  final _formKey = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _userCode = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _cashoutProfit = TextEditingController(text: '0');

  String? _ownCashboxId;
  String? _targetCashboxId;
  bool _cashout = false;
  AppUser? _resolvedUser;

  @override
  void dispose() {
    _search.dispose();
    _userCode.dispose();
    _amount.dispose();
    _note.dispose();
    _customerName.dispose();
    _customerPhone.dispose();
    _cashoutProfit.dispose();
    super.dispose();
  }

  List<CashboxModel> get _targets {
    final query = _search.text.trim().toLowerCase();
    final ownIds = widget.myCashboxes.map((box) => box.id).toSet();
    return widget.cashboxes.where((box) {
      if (!box.isActive || ownIds.contains(box.id)) return false;
      if (query.isEmpty) return true;
      final label = '${box.name} ${box.managerName ?? ''} ${box.city}'
          .toLowerCase();
      return label.contains(query);
    }).toList();
  }

  CashboxModel? _boxById(String? id) {
    for (final box in widget.cashboxes) {
      if (box.id == id) return box;
    }
    return null;
  }

  Future<void> _resolveCode([String? rawCode]) async {
    final code = (rawCode ?? _userCode.text).trim();
    if (code.isEmpty) return;
    try {
      final user = await _api.resolveUserCode(
        token: widget.session.token,
        code: code,
      );
      final matches = widget.cashboxes
          .where((box) => box.isActive && box.managerUserId == user.id)
          .toList();
      if (matches.isEmpty) {
        if (mounted) {
          AppNotifier.error(context, 'لا توجد صناديق فعالة لهذا المستخدم.');
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _resolvedUser = user;
        _search.text = user.fullName;
        _targetCashboxId = matches.first.id;
      });
      AppNotifier.success(context, 'تم اختيار ${user.fullName}.');
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
    if (!widget.enabled) return;
    if (!_formKey.currentState!.validate()) return;
    final ownId =
        _ownCashboxId ??
        (widget.myCashboxes.isEmpty ? null : widget.myCashboxes.first.id);
    if (ownId == null) return;
    if (_cashout) {
      await widget.onSubmit(
        OperationsTransferRequest(
          fromCashboxId: ownId,
          toCashboxId: ownId,
          amount: _amount.text.trim(),
          operationType: 'customer_cashout',
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          customerName: _customerName.text.trim(),
          customerPhone: _customerPhone.text.trim(),
          cashoutProfitPercent: _cashoutProfit.text.trim(),
        ),
      );
      _amount.clear();
      _note.clear();
      _customerName.clear();
      _customerPhone.clear();
      return;
    }

    final target = _boxById(_targetCashboxId);
    if (target == null) return;
    final operationType = inferOperationsType(widget.session, target);
    final fromId = operationType == 'agent_funding' ? target.id : ownId;
    final toId = operationType == 'agent_funding' ? ownId : target.id;
    await widget.onSubmit(
      OperationsTransferRequest(
        fromCashboxId: fromId,
        toCashboxId: toId,
        amount: _amount.text.trim(),
        operationType: operationType,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
    _amount.clear();
    _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targets;
    if (_ownCashboxId == null && widget.myCashboxes.isNotEmpty) {
      _ownCashboxId = widget.myCashboxes.first.id;
    }
    if (!_cashout &&
        (_targetCashboxId == null ||
            !targets.any((box) => box.id == _targetCashboxId)) &&
        targets.isNotEmpty) {
      _targetCashboxId = targets.first.id;
    }

    return AppSectionCard(
      title: 'تنفيذ عملية',
      subtitle: 'اختر مسارًا بسيطًا، وكل عملية ترسل للـ backend بنفس الحقول',
      icon: Icons.send_rounded,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            SegmentedButton<bool>(
              segments: [
                const ButtonSegment(
                  value: false,
                  icon: Icon(Icons.swap_horiz_rounded),
                  label: Text('حسب الاسم'),
                ),
                if (widget.session.role == UserRole.accredited)
                  const ButtonSegment(
                    value: true,
                    icon: Icon(Icons.payments_rounded),
                    label: Text('صرف عميل'),
                  ),
              ],
              selected: {_cashout},
              onSelectionChanged: widget.enabled
                  ? (value) => setState(() => _cashout = value.first)
                  : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _ownCashboxId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'صندوق التنفيذ'),
              items: widget.myCashboxes
                  .map(
                    (box) => DropdownMenuItem(
                      value: box.id,
                      child: Text(
                        '${box.name} - ${cashboxTypeLabelAr(box.type)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.enabled
                  ? (value) => setState(() => _ownCashboxId = value)
                  : null,
            ),
            if (!_cashout) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _search,
                enabled: widget.enabled,
                decoration: const InputDecoration(
                  labelText: 'بحث عن اسم أو صندوق',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userCode,
                      enabled: widget.enabled,
                      decoration: const InputDecoration(
                        labelText: 'كود أو QR المستخدم',
                        prefixIcon: Icon(Icons.qr_code_2_rounded),
                      ),
                      onSubmitted: (_) => _resolveCode(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: widget.enabled ? _scanCode : null,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: widget.enabled ? () => _resolveCode() : null,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
              if (_resolvedUser != null) ...[
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'المستخدم من QR',
                  ),
                  child: Text(
                    '${_resolvedUser!.fullName} (@${_resolvedUser!.username}) - ${roleLabelAr(_resolvedUser!.role)}',
                  ),
                ),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _targetCashboxId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الجهة المستهدفة'),
                items: targets
                    .map(
                      (box) => DropdownMenuItem(
                        value: box.id,
                        child: Text(
                          '${box.managerName ?? box.name} - ${box.name}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: widget.enabled
                    ? (value) => setState(() => _targetCashboxId = value)
                    : null,
              ),
              if (_boxById(_targetCashboxId) != null) ...[
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'العملية المحددة',
                  ),
                  child: Text(
                    transferTypeLabelAr(
                      inferOperationsType(
                        widget.session,
                        _boxById(_targetCashboxId)!,
                      ),
                    ),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerName,
                enabled: widget.enabled,
                decoration: const InputDecoration(labelText: 'اسم العميل'),
                validator: AppValidators.requiredText,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _customerPhone,
                enabled: widget.enabled,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم هاتف العميل'),
                validator: AppValidators.requiredText,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cashoutProfit,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'نسبة ربح الصرف %',
                ),
                validator: AppValidators.percent,
              ),
            ],
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              enabled: widget.enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'المبلغ'),
              validator: AppValidators.amount,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              enabled: widget.enabled,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.enabled ? _submit : null,
                icon: const Icon(Icons.send_rounded),
                label: const Text('متابعة التنفيذ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
