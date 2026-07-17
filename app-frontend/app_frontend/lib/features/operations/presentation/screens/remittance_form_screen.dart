import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/code_dialogs.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../shared/presentation/screens/qr_input_sheet.dart';
import '../../data/operations_api.dart';
import 'package:flutter/material.dart';

class RemittanceFormScreen extends StatefulWidget {
  const RemittanceFormScreen({
    super.key,
    required this.session,
    required this.myCashboxes,
    required this.accreditedCashboxes,
  });

  final AuthSession session;
  final List<CashboxModel> myCashboxes;
  final List<CashboxModel> accreditedCashboxes;

  @override
  State<RemittanceFormScreen> createState() => _RemittanceFormScreenState();
}

class _RemittanceFormScreenState extends State<RemittanceFormScreen> {
  final _api = OperationsApi();
  final _key = GlobalKey<FormState>();

  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();
  final _senderCountry = TextEditingController();
  final _senderCity = TextEditingController();

  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();
  final _receiverCountry = TextEditingController();
  final _receiverCity = TextEditingController();

  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _receiverSearch = TextEditingController();

  CashboxModel? _fromCashbox;
  CashboxModel? _toCashbox;
  String _currency = 'SYP';
  String _receiverQuery = '';
  bool _busy = false;
  bool _resolvingReceiver = false;

  List<CashboxModel> get _filteredAccredited {
    final q = _receiverQuery.trim().toLowerCase();
    if (q.isEmpty) return widget.accreditedCashboxes;
    return widget.accreditedCashboxes.where((b) {
      final hay = '${b.name} ${b.managerName ?? ''} ${b.city} ${b.country}'
          .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _scanReceiverQr() async {
    final code = await showQrInputSheet(context);
    if (code == null || code.isEmpty || !mounted) return;
    setState(() => _resolvingReceiver = true);
    try {
      final user = await _api.resolveUserCode(
        token: widget.session.token,
        code: code,
      );
      final match = widget.accreditedCashboxes
          .where((b) => b.managerUserId == user.id)
          .firstOrNull;
      if (!mounted) return;
      if (match == null) {
        AppNotifier.error(context, 'لا يوجد صندوق معتمد لهذا المستخدم.');
        return;
      }
      setState(() {
        _toCashbox = match;
        _receiverSearch.text = '${user.fullName} — ${match.name}';
        _receiverQuery = '';
      });
      AppNotifier.success(context, 'تم اختيار ${user.fullName}.');
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _resolvingReceiver = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.myCashboxes.isNotEmpty) _fromCashbox = widget.myCashboxes.first;
    if (widget.accreditedCashboxes.isNotEmpty) {
      _toCashbox = widget.accreditedCashboxes.first;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _senderName, _senderPhone, _senderCountry, _senderCity,
      _receiverName, _receiverPhone, _receiverCountry, _receiverCity,
      _amount, _note, _receiverSearch,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (_fromCashbox == null || _toCashbox == null) {
      AppNotifier.error(context, 'يرجى تحديد صندوق المرسل والمستلم.');
      return;
    }
    if (_fromCashbox!.id == _toCashbox!.id) {
      AppNotifier.error(context, 'لا يمكن أن يكون صندوق المرسل والمستلم نفسه.');
      return;
    }
    setState(() => _busy = true);
    try {
      final transfer = await _api.createRemittance(
        token: widget.session.token,
        fromCashboxId: _fromCashbox!.id,
        toCashboxId: _toCashbox!.id,
        amount: _amount.text.trim(),
        senderName: _senderName.text.trim(),
        senderPhone: _senderPhone.text.trim(),
        senderCountry: _senderCountry.text.trim(),
        senderCity: _senderCity.text.trim(),
        receiverName: _receiverName.text.trim(),
        receiverPhone: _receiverPhone.text.trim(),
        receiverCountry: _receiverCountry.text.trim(),
        receiverCity: _receiverCity.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        sourceCurrency: _currency,
      );
      if (!mounted) return;
      await showTransferApprovalCodeDialog(context, transfer);
      if (!mounted) return;
      AppNotifier.success(context, 'تم إرسال الحوالة بانتظار التسليم.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: validator ?? AppValidators.requiredText,
    );
  }

  Widget _pair(Widget a, Widget b) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 8),
      Expanded(child: b),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حوالة عميل')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: Form(
                key: _key,
                child: Column(
                  children: [
                    AppSectionCard(
                      title: 'بيانات الصناديق',
                      icon: Icons.account_balance_wallet_rounded,
                      child: Column(
                        children: [
                          DropdownButtonFormField<CashboxModel>(
                            value: _fromCashbox,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'صندوق المرسل (صندوقي)',
                            ),
                            items: widget.myCashboxes
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      '${b.name} — ${formatCurrencyAmount(b.currencyBalances[_currency] ?? 0, _currency)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _fromCashbox = v),
                            validator: (v) =>
                                v == null ? 'يرجى اختيار صندوق المرسل' : null,
                          ),
                          if (_fromCashbox != null) ...[
                            const SizedBox(height: 8),
                            _SenderBalances(box: _fromCashbox!),
                          ],
                          const SizedBox(height: 12),
                          // المستلم: بحث بالاسم + باركود/QR ثم اختيار من القائمة
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _receiverSearch,
                                  decoration: const InputDecoration(
                                    labelText: 'المعتمد المستلم (بحث بالاسم)',
                                    prefixIcon: Icon(Icons.person_search_rounded),
                                  ),
                                  onChanged: (v) =>
                                      setState(() => _receiverQuery = v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _resolvingReceiver
                                  ? const SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: Padding(
                                        padding: EdgeInsets.all(12),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : IconButton.filled(
                                      tooltip: 'مسح باركود / QR',
                                      onPressed: _scanReceiverQr,
                                      icon: const Icon(
                                        Icons.qr_code_scanner_rounded,
                                      ),
                                    ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<CashboxModel>(
                            value: _filteredAccredited.contains(_toCashbox)
                                ? _toCashbox
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'اختر صندوق المستلم',
                            ),
                            items: _filteredAccredited
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      '${b.managerName ?? b.name} — ${b.name}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _toCashbox = v),
                            validator: (v) =>
                                v == null ? 'يرجى اختيار صندوق المستلم' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'المبلغ',
                      icon: Icons.payments_rounded,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _currency,
                            decoration: const InputDecoration(
                              labelText: 'العملة',
                            ),
                            items: kSupportedCurrencies
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text('${currencyLabel(c)} ($c)'),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _currency = v);
                            },
                          ),
                          const SizedBox(height: 8),
                          _field(
                            _amount,
                            'المبلغ ($_currency)',
                            validator: AppValidators.amount,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'بيانات المرسل',
                      icon: Icons.person_rounded,
                      child: Column(
                        children: [
                          _pair(
                            _field(_senderName, 'اسم المرسل'),
                            _field(
                              _senderPhone,
                              'هاتف المرسل',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _pair(
                            _field(_senderCountry, 'دولة المرسل'),
                            _field(_senderCity, 'مدينة المرسل'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'بيانات المستقبل',
                      icon: Icons.person_pin_rounded,
                      child: Column(
                        children: [
                          _pair(
                            _field(_receiverName, 'اسم المستقبل'),
                            _field(
                              _receiverPhone,
                              'هاتف المستقبل',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _pair(
                            _field(_receiverCountry, 'دولة المستقبل'),
                            _field(_receiverCity, 'مدينة المستقبل'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'ملاحظة',
                      icon: Icons.notes_rounded,
                      child: TextFormField(
                        controller: _note,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          hintText: 'ملاحظة اختيارية...',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _submit,
                        icon: const Icon(Icons.send_rounded),
                        label: Text(_busy ? 'جار الإرسال...' : 'إرسال الحوالة'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// يعرض جميع أرصدة صندوق المرسل بكل العملات (وليس SYP فقط).
class _SenderBalances extends StatelessWidget {
  const _SenderBalances({required this.box});

  final CashboxModel box;

  @override
  Widget build(BuildContext context) {
    final balances = box.currencyBalances.entries
        .where((e) => e.value != 0)
        .toList();
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الرصيد المتاح في الصندوق',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: primary,
            ),
          ),
          const SizedBox(height: 6),
          if (balances.isEmpty)
            const Text('لا يوجد رصيد', style: TextStyle(fontSize: 12))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: balances
                  .map(
                    (e) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        formatCurrencyAmount(e.value, e.key),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
