import '../../../../core/entities/app_models.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/responsive_page.dart';
import 'package:flutter/material.dart';

class AddCashboxScreen extends StatefulWidget {
  const AddCashboxScreen({
    super.key,
    required this.users,
    required this.onSubmit,
  });

  final List<AppUser> users;
  final Future<void> Function({
    required String name,
    required String city,
    required String country,
    required String type,
    String? managerUserId,
    required String openingBalance,
  })
  onSubmit;

  @override
  State<AddCashboxScreen> createState() => _AddCashboxScreenState();
}

class _AddCashboxScreenState extends State<AddCashboxScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'syria');
  final _opening = TextEditingController(text: '0');
  String _type = 'accredited';
  String? _managerId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _country.dispose();
    _opening.dispose();
    super.dispose();
  }

  List<AppUser> get _managers => widget.users
      .where(
        (user) =>
            user.isActive &&
            ((_type == 'agent' && user.role == UserRole.agent) ||
                (_type == 'accredited' && user.role == UserRole.accredited)),
      )
      .toList();

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    await widget.onSubmit(
      name: _name.text,
      city: _city.text,
      country: _country.text,
      type: _type,
      managerUserId: _type == 'treasury' ? null : _managerId,
      openingBalance: _opening.text,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final managers = _managers;
    if (_type != 'treasury' &&
        (_managerId == null ||
            !managers.any((user) => user.id == _managerId)) &&
        managers.isNotEmpty) {
      _managerId = managers.first.id;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة صندوق')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: AppSectionCard(
                title: 'بيانات الصندوق',
                icon: Icons.add_business_rounded,
                child: Form(
                  key: _key,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'اسم الصندوق',
                        ),
                        validator: AppValidators.requiredText,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: const InputDecoration(
                          labelText: 'نوع الصندوق',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'accredited',
                            child: Text('صندوق معتمد'),
                          ),
                          DropdownMenuItem(
                            value: 'agent',
                            child: Text('صندوق وكيل'),
                          ),
                          DropdownMenuItem(
                            value: 'treasury',
                            child: Text('الخزنة'),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _type = value ?? _type;
                          _managerId = null;
                        }),
                      ),
                      if (_type != 'treasury') ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _managerId,
                          decoration: const InputDecoration(
                            labelText: 'المسؤول',
                          ),
                          items: managers
                              .map(
                                (user) => DropdownMenuItem(
                                  value: user.id,
                                  child: Text(
                                    '${user.fullName} (@${user.username})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _managerId = value),
                          validator: (_) =>
                              _managerId == null ? 'اختر مسؤولًا' : null,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _city,
                              decoration: const InputDecoration(
                                labelText: 'المدينة',
                              ),
                              validator: AppValidators.requiredText,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _country,
                              decoration: const InputDecoration(
                                labelText: 'الدولة',
                              ),
                              validator: AppValidators.requiredText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _opening,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'الرصيد الافتتاحي',
                        ),
                        validator: AppValidators.nonNegativeAmount,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(_busy ? 'جار الحفظ...' : 'إنشاء الصندوق'),
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
