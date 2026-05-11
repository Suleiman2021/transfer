import '../../../../core/entities/app_models.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../../core/widgets/responsive_page.dart';
import 'package:flutter/material.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key, required this.onSubmit});

  final Future<void> Function({
    required String username,
    required String fullName,
    required UserRole role,
    required String city,
    required String country,
    String? phone,
    required String password,
  })
  onSubmit;

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _key = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _fullName = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'syria');
  final _phone = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.agent;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _city.dispose();
    _country.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    await widget.onSubmit(
      username: _username.text,
      fullName: _fullName.text,
      role: _role,
      city: _city.text,
      country: _country.text,
      phone: _phone.text,
      password: _password.text,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة مستخدم')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: AppSectionCard(
                title: 'بيانات المستخدم',
                icon: Icons.person_add_rounded,
                child: Form(
                  key: _key,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم',
                        ),
                        validator: AppValidators.username,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _fullName,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل',
                        ),
                        validator: AppValidators.requiredText,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: _role,
                        decoration: const InputDecoration(labelText: 'الدور'),
                        items:
                            [
                                  UserRole.agent,
                                  UserRole.accredited,
                                  UserRole.admin,
                                ]
                                .map(
                                  (role) => DropdownMenuItem(
                                    value: role,
                                    child: Text(roleLabelAr(role)),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) =>
                            setState(() => _role = value ?? _role),
                      ),
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
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      PasswordField(
                        controller: _password,
                        labelText: 'كلمة المرور الأولية',
                        validator: AppValidators.password,
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            _busy ? 'جار الحفظ...' : 'إنشاء المستخدم',
                          ),
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
