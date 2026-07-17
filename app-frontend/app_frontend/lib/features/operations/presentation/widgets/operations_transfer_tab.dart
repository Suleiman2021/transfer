import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/utils/input_utils.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/currency_amount_field.dart';
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
    this.initialCode,
  });

  final AuthSession session;
  final List<CashboxModel> cashboxes;
  final List<CashboxModel> myCashboxes;
  final bool enabled;
  final Future<void> Function(OperationsTransferRequest request) onSubmit;
  final String? initialCode;

  @override
  State<OperationsTransferTab> createState() => _OperationsTransferTabState();
}

class _OperationsTransferTabState extends State<OperationsTransferTab> {
  final _api = OperationsApi();
  final _formKey = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String? _ownCashboxId;
  String? _targetCashboxId;
  AppUser? _resolvedUser;
  String _currency = 'SYP';

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _resolveCode(widget.initialCode),
      );
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<CashboxModel> get _targets {
    final query = _search.text.trim().toLowerCase();
    final ownIds = widget.myCashboxes.map((box) => box.id).toSet();
    return widget.cashboxes.where((box) {
      if (!box.isActive || ownIds.contains(box.id)) return false;
      // The operations transfer tab is an agent top-up to an accredited cashbox.
      if (!box.isAccredited) return false;
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
    final code = (rawCode ?? _search.text).trim();
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
        // auto-select only when the user has exactly one cashbox
        _targetCashboxId = matches.length == 1 ? matches.first.id : null;
      });
      AppNotifier.success(context, 'تم اختيار ${user.fullName}.');
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    }
  }

  Future<void> _submit() async {
    if (!widget.enabled) return;
    if (!_formKey.currentState!.validate()) return;
    final ownId =
        _ownCashboxId ??
        (widget.myCashboxes.isEmpty ? null : widget.myCashboxes.first.id);
    if (ownId == null) return;
    final inputRaw = _amount.text.trim().replaceAll(',', '.');
    final inputAmount = double.tryParse(inputRaw) ?? 0;

    final target = _boxById(_targetCashboxId);
    if (target == null) return;
    final operationType = inferOperationsType(widget.session, target);
    final fromId = operationType == 'agent_funding' ? target.id : ownId;
    final toId = operationType == 'agent_funding' ? ownId : target.id;
    await widget.onSubmit(
      OperationsTransferRequest(
        fromCashboxId: fromId,
        toCashboxId: toId,
        amount: inputAmount.toStringAsFixed(2),
        operationType: operationType,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        sourceCurrency: _currency,
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
    if ((_targetCashboxId == null ||
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    enabled: widget.enabled,
                    onTap: tapToMoveCursor(_search),
                    decoration: const InputDecoration(
                      labelText: 'بحث عن اسم أو مستخدم',
                      prefixIcon: Icon(Icons.person_search_rounded),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _resolveCode(),
                  ),
                ),
                const SizedBox(width: 8),
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
                  labelText: 'المستخدم المحدد',
                ),
                child: Text(
                  '${_resolvedUser!.fullName} (@${_resolvedUser!.username}) - ${roleLabelAr(_resolvedUser!.role)}',
                ),
              ),
            ],
            const SizedBox(height: 10),
            // ── Target cashbox + country side by side ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _targetCashboxId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الجهة المستهدفة',
                    ),
                    items: targets
                        .map(
                          (box) => DropdownMenuItem(
                            value: box.id,
                            child: Text(
                              '${box.managerName ?? box.name} — ${box.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: widget.enabled
                        ? (value) => setState(() => _targetCashboxId = value)
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
                      _boxById(_targetCashboxId) != null
                          ? '${_boxById(_targetCashboxId)!.city}, ${_boxById(_targetCashboxId)!.country}'
                          : '—',
                    ),
                  ),
                ),
              ],
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
            const SizedBox(height: 10),
            CurrencyAmountField(
              amountController: _amount,
              selectedCurrency: _currency,
              onCurrencyChanged: (c) => setState(() => _currency = c),
              enabled: widget.enabled,
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
