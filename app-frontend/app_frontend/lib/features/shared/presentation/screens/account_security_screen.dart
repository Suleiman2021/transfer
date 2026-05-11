import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/security/device_auth.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/password_field.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../auth/data/auth_api.dart';
import 'package:flutter/material.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _api = AuthApi();
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  bool _verified = false;
  bool _busy = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await DeviceAuth.verify(
      reason: 'تحقق من هويتك لعرض معلومات تسجيل الدخول',
    );
    if (!mounted) return;
    setState(() => _verified = ok);
    if (!ok) AppNotifier.error(context, 'تعذر التحقق من هوية الجهاز.');
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await _api.changePassword(
        token: widget.session.token,
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      _currentPassword.clear();
      _newPassword.clear();
      if (mounted) AppNotifier.success(context, 'تم تعديل كلمة المرور.');
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: AppBar(title: const Text('الأمان ومعلومات الدخول')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              maxWidth: 560,
              child: Column(
                children: [
                  AppSectionCard(
                    title: 'معلومات تسجيل الدخول',
                    subtitle:
                        'كلمة المرور لا يتم حفظها كنص قابل للكشف، ويمكن تغييرها فقط.',
                    icon: Icons.verified_user_rounded,
                    child: Column(
                      children: [
                        if (!_verified)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _verify,
                              icon: const Icon(Icons.fingerprint_rounded),
                              label: const Text('تحقق لعرض المعلومات'),
                            ),
                          )
                        else ...[
                          _InfoTile('اسم المستخدم', session.username),
                          _InfoTile('الاسم الكامل', session.fullName),
                          _InfoTile('الدور', roleLabelAr(session.role)),
                          _InfoTile('الهاتف', session.phone ?? '-'),
                          _InfoTile(
                            'المدينة والدولة',
                            '${session.city}, ${session.country}',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'لا يمكن كشف كلمة المرور الحالية لأنها محفوظة بشكل مشفر أحادي الاتجاه.',
                            style: TextStyle(color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppSectionCard(
                    title: 'تعديل كلمة المرور',
                    icon: Icons.password_rounded,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          PasswordField(
                            controller: _currentPassword,
                            labelText: 'كلمة المرور الحالية',
                            validator: AppValidators.password,
                          ),
                          const SizedBox(height: 10),
                          PasswordField(
                            controller: _newPassword,
                            labelText: 'كلمة المرور الجديدة',
                            validator: AppValidators.password,
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : _changePassword,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: Text(
                                _busy ? 'جار الحفظ...' : 'حفظ كلمة المرور',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: SelectableText(value),
    );
  }
}
