import '../../../core/network/api_error_messages.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/validation/app_validators.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/password_field.dart';
import '../logic/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoginMode { admin, operations }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.mode});

  final LoginMode mode;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _admin => widget.mode == LoginMode.admin;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = ref.read(authControllerProvider.notifier);
      if (_admin) {
        await auth.adminLogin(
          username: _username.text.trim(),
          password: _password.text,
        );
      } else {
        await auth.login(
          username: _username.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) AppNotifier.success(context, 'تم تسجيل الدخول بنجاح.');
    } catch (error) {
      final message = isConnectivityOrServerError(error)
          ? 'تعذر الاتصال بالخادم. تحقق من رابط API أو الشبكة.'
          : apiErrorText(error);
      setState(() => _error = message);
      if (mounted) AppNotifier.error(context, message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _admin ? 'دخول الأدمن' : 'دخول الوكلاء والمعتمدين';
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.viewInsetsOf(context).bottom + 18,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BrandHeader(mode: widget.mode),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: [
                              Text(
                                title,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'أدخل بياناتك للمتابعة إلى لوحة الصناديق.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _username,
                                textDirection: TextDirection.ltr,
                                onTap: () {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    final sel = _username.selection;
                                    if (sel.isValid && !sel.isCollapsed) {
                                      _username.selection =
                                          TextSelection.collapsed(
                                            offset: sel.extentOffset,
                                          );
                                    }
                                  });
                                },
                                decoration: const InputDecoration(
                                  labelText: 'اسم المستخدم',
                                  prefixIcon: Icon(Icons.person_rounded),
                                ),
                                validator: AppValidators.username,
                              ),
                              const SizedBox(height: 10),
                              PasswordField(
                                controller: _password,
                                labelText: 'كلمة المرور',
                                validator: AppValidators.password,
                                onSubmitted: (_) => _submit(),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppTheme.noticeError,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _busy ? null : _submit,
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.login_rounded),
                                  label: Text(_busy ? 'جاري التحقق...' : title),
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
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.mode});

  final LoginMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandTeal.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          // شعار شبكة مالية رقمية: عقدة مركزية بأطراف متصلة (تحويلات/شبكة).
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.hub_rounded, color: Colors.white, size: 38),
                PositionedDirectional(
                  bottom: 12,
                  child: Icon(
                    Icons.currency_exchange_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'سيدا نتوورك',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              mode == LoginMode.admin
                  ? 'بوابة الإدارة'
                  : 'بوابة الوكلاء والمعتمدين',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
