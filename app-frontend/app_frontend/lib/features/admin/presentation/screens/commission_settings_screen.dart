import '../../../../core/entities/app_models.dart';
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
    required String accreditedInternal,
    required String accreditedExternal,
    required String accreditedProfitInternal,
    required String accreditedProfitExternal,
    required String agentInternal,
    required String agentExternal,
    required String agentProfitInternal,
    required String agentProfitExternal,
    required String treasuryToAccredited,
    required String treasuryToAgent,
    required String collectionFromAccredited,
    required String collectionFromAgent,
  })
  onSave;

  @override
  State<CommissionSettingsScreen> createState() =>
      _CommissionSettingsScreenState();
}

class _CommissionSettingsScreenState extends State<CommissionSettingsScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _ai;
  late final TextEditingController _ae;
  late final TextEditingController _api;
  late final TextEditingController _ape;
  late final TextEditingController _gi;
  late final TextEditingController _ge;
  late final TextEditingController _gpi;
  late final TextEditingController _gpe;
  late final TextEditingController _ta;
  late final TextEditingController _tg;
  late final TextEditingController _ca;
  late final TextEditingController _cg;
  bool _busy = false;

  CommissionRuleModel? _rule(UserRole role) =>
      widget.rules.where((rule) => rule.role == role).firstOrNull;

  @override
  void initState() {
    super.initState();
    final accredited = _rule(UserRole.accredited);
    final agent = _rule(UserRole.agent);
    final admin = _rule(UserRole.admin);
    _ai = TextEditingController(text: accredited?.internalFeePercent ?? '0');
    _ae = TextEditingController(text: accredited?.externalFeePercent ?? '0');
    _api = TextEditingController(
      text: accredited?.agentTopupProfitInternalPercent ?? '0',
    );
    _ape = TextEditingController(
      text: accredited?.agentTopupProfitExternalPercent ?? '0',
    );
    _gi = TextEditingController(text: agent?.internalFeePercent ?? '0');
    _ge = TextEditingController(text: agent?.externalFeePercent ?? '0');
    _gpi = TextEditingController(
      text: agent?.agentTopupProfitInternalPercent ?? '0',
    );
    _gpe = TextEditingController(
      text: agent?.agentTopupProfitExternalPercent ?? '0',
    );
    _ta = TextEditingController(
      text: admin?.treasuryToAccreditedFeePercent ?? '0',
    );
    _tg = TextEditingController(text: admin?.treasuryToAgentFeePercent ?? '0');
    _ca = TextEditingController(
      text: admin?.treasuryCollectionFromAccreditedFeePercent ?? '0',
    );
    _cg = TextEditingController(
      text: admin?.treasuryCollectionFromAgentFeePercent ?? '0',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _ai,
      _ae,
      _api,
      _ape,
      _gi,
      _ge,
      _gpi,
      _gpe,
      _ta,
      _tg,
      _ca,
      _cg,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    await widget.onSave(
      accreditedInternal: _ai.text,
      accreditedExternal: _ae.text,
      accreditedProfitInternal: _api.text,
      accreditedProfitExternal: _ape.text,
      agentInternal: _gi.text,
      agentExternal: _ge.text,
      agentProfitInternal: _gpi.text,
      agentProfitExternal: _gpe.text,
      treasuryToAccredited: _ta.text,
      treasuryToAgent: _tg.text,
      collectionFromAccredited: _ca.text,
      collectionFromAgent: _cg.text,
    );
    if (mounted) setState(() => _busy = false);
  }

  Widget _field(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: AppValidators.percent,
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
                      title: 'عمولات المعتمد',
                      icon: Icons.storefront_rounded,
                      child: Column(
                        children: [
                          _pair(
                            _field(_ai, 'عمولة داخلية %'),
                            _field(_ae, 'عمولة خارجية %'),
                          ),
                          const SizedBox(height: 8),
                          _pair(
                            _field(_api, 'ربح داخلي %'),
                            _field(_ape, 'ربح خارجي %'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'عمولات الوكيل',
                      icon: Icons.hub_rounded,
                      child: Column(
                        children: [
                          _pair(
                            _field(_gi, 'عمولة داخلية %'),
                            _field(_ge, 'عمولة خارجية %'),
                          ),
                          const SizedBox(height: 8),
                          _pair(
                            _field(_gpi, 'ربح داخلي %'),
                            _field(_gpe, 'ربح خارجي %'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSectionCard(
                      title: 'مسارات الخزنة',
                      icon: Icons.account_balance_rounded,
                      child: Column(
                        children: [
                          _pair(
                            _field(_ta, 'الخزنة إلى معتمد %'),
                            _field(_tg, 'الخزنة إلى وكيل %'),
                          ),
                          const SizedBox(height: 8),
                          _pair(
                            _field(_ca, 'تحصيل من معتمد %'),
                            _field(_cg, 'تحصيل من وكيل %'),
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
