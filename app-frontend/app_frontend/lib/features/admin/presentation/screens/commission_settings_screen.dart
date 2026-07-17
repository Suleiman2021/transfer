import '../../../../core/entities/app_models.dart';
import '../../../../core/utils/input_utils.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/responsive_page.dart';
import 'package:flutter/material.dart';

class CommissionSettingsScreen extends StatefulWidget {
  const CommissionSettingsScreen({
    super.key,
    required this.rules,
    required this.onSave,
  });

  final List<CommissionRuleModel> rules;
  final Future<void> Function({
    required String agentInternal,
    required String agentExternal,
    required String treasuryToAgentInternal,
    required String treasuryToAgentExternal,
    required String treasuryToAccreditedInternal,
    required String treasuryToAccreditedExternal,
    required String remittanceTreasury,
    required String remittanceSender,
    required String remittanceReceiver,
  })
  onSave;

  @override
  State<CommissionSettingsScreen> createState() =>
      _CommissionSettingsScreenState();
}

class _CommissionSettingsScreenState extends State<CommissionSettingsScreen> {
  final _key = GlobalKey<FormState>();

  // Agent → Accredited topup (agent keeps commission, no treasury)
  late final TextEditingController _gi;
  late final TextEditingController _ge;

  // Treasury → Agent (internal/external)
  late final TextEditingController _tai;
  late final TextEditingController _tae;

  // Treasury → Accredited (internal/external)
  late final TextEditingController _taci;
  late final TextEditingController _tace;

  // Remittance 3-way split
  late final TextEditingController _rt;
  late final TextEditingController _rs;
  late final TextEditingController _rr;

  bool _busy = false;

  CommissionRuleModel? _rule(UserRole role) =>
      widget.rules.where((r) => r.role == role).firstOrNull;

  @override
  void initState() {
    super.initState();
    final agent = _rule(UserRole.agent);
    final admin = _rule(UserRole.admin);

    _gi = TextEditingController(text: agent?.internalFeePercent ?? '0');
    _ge = TextEditingController(text: agent?.externalFeePercent ?? '0');

    _tai = TextEditingController(
      text: admin?.treasuryToAgentInternalFeePercent ?? '0',
    );
    _tae = TextEditingController(
      text: admin?.treasuryToAgentExternalFeePercent ?? '0',
    );

    _taci = TextEditingController(
      text: admin?.treasuryToAccreditedInternalFeePercent ?? '0',
    );
    _tace = TextEditingController(
      text: admin?.treasuryToAccreditedExternalFeePercent ?? '0',
    );

    _rt = TextEditingController(
      text: admin?.remittanceTreasuryPercent ?? '0',
    );
    _rs = TextEditingController(
      text: admin?.remittanceSenderPercent ?? '0',
    );
    _rr = TextEditingController(
      text: admin?.remittanceReceiverPercent ?? '0',
    );
  }

  @override
  void dispose() {
    for (final c in [
      _gi, _ge,
      _tai, _tae, _taci, _tace,
      _rt, _rs, _rr,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    await widget.onSave(
      agentInternal: _gi.text,
      agentExternal: _ge.text,
      treasuryToAgentInternal: _tai.text,
      treasuryToAgentExternal: _tae.text,
      treasuryToAccreditedInternal: _taci.text,
      treasuryToAccreditedExternal: _tace.text,
      remittanceTreasury: _rt.text,
      remittanceSender: _rs.text,
      remittanceReceiver: _rr.text,
    );
    if (mounted) setState(() => _busy = false);
  }

  Widget _field(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: AppValidators.percent,
      onTap: tapToMoveCursor(c),
    );
  }

  Widget _pair(Widget a, Widget b) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ضبط العمولات')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: Form(
                key: _key,
                child: Column(
                  children: [
                    AppSectionCard(
                      title: 'تحويل الخزنة إلى الوكيل',
                      subtitle: 'عمولة خزنة على التمويل المباشر للوكيل',
                      icon: Icons.hub_rounded,
                      child: _pair(
                        _field(_tai, 'داخلي %'),
                        _field(_tae, 'خارجي %'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'تحويل الخزنة إلى المعتمد',
                      subtitle: 'عمولة خزنة على التمويل المباشر للمعتمد',
                      icon: Icons.storefront_rounded,
                      child: _pair(
                        _field(_taci, 'داخلي %'),
                        _field(_tace, 'خارجي %'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'تعبئة الوكيل للمعتمد',
                      subtitle: 'عمولة الوكيل (تبقى عنده — لا عمولة للخزنة)',
                      icon: Icons.swap_horiz_rounded,
                      child: _pair(
                        _field(_gi, 'داخلي %'),
                        _field(_ge, 'خارجي %'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'عمولات الحوالات',
                      subtitle: 'تقسيم عمولة حوالات العملاء بين المعتمدين',
                      icon: Icons.send_rounded,
                      child: Column(
                        children: [
                          _field(_rt, 'حصة الخزنة %'),
                          const SizedBox(height: 8),
                          _pair(
                            _field(_rs, 'حصة المرسل %'),
                            _field(_rr, 'حصة المستقبل %'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_rounded),
                        label: Text(_busy ? 'جار الحفظ...' : 'حفظ العمولات'),
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
