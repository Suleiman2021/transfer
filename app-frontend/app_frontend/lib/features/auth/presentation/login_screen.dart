import 'dart:async';
import 'dart:math' as math;

import '../../../core/entities/app_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/app_notifier.dart';
import '../../../core/validation/app_validators.dart';
import '../../../core/widgets/app_load_error_card.dart';
import '../../../core/widgets/app_shell_background.dart';
import '../../../core/widgets/responsive_frame.dart';
import '../../../core/widgets/reveal_on_mount.dart';
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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  ProviderSubscription<AsyncValue<AuthSession?>>? _authSubscription;
  bool _submitting = false;
  Timer? _noticeTimer;
  String? _noticeMessage;
  String? _loginLoadError;
  AppNoticeType _noticeType = AppNoticeType.info;

  bool get _isAdminMode => widget.mode == LoginMode.admin;

  String get _title => _isAdminMode ? 'دخول الأدمن' : 'دخول المستخدمين';
  String get _subtitle => _isAdminMode
      ? 'تسجيل آمن لمدير النظام.'
      : 'تسجيل آمن للمعتمدين والوكلاء.';
  String get _submitLabel => _isAdminMode ? 'دخول الأدمن' : 'دخول المستخدم';

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual(authControllerProvider, (prev, next) {
      final session = next.asData?.value;
      final previousSession = prev?.asData?.value;
      if (session != null && previousSession == null) {
        _showLoginNotice(
          AppNoticeType.success,
          'تم تسجيل الدخول بنجاح. يرجى إكمال التحقق ببصمة/نمط الجهاز.',
        );
      }

      next.whenOrNull(
        error: (error, _) => _showLoginNotice(
          AppNoticeType.error,
          _normalizeAuthErrorMessage(error.toString()),
        ),
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _noticeTimer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showLoginNotice(AppNoticeType type, String message) {
    if (!mounted) return;

    setState(() {
      _noticeType = type;
      _noticeMessage = message;
    });
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _noticeMessage = null);
    });

    AppNotifier.show(context, message, type: type);
  }

  String _normalizeAuthErrorMessage(String message) {
    final text = message.toLowerCase();
    if (text.contains('invalid credentials')) {
      return 'اسم المستخدم أو كلمة المرور غير صحيحة.';
    }
    if (text.contains('user is inactive')) {
      return 'هذا الحساب غير مفعل. تواصل مع الإدارة.';
    }
    if (text.contains('admin must use')) {
      return 'هذا الحساب إداري. استخدم تسجيل دخول الأدمن.';
    }
    if (text.contains('only admin can use')) {
      return 'هذا الحساب ليس أدمن. استخدم تطبيق العمليات.';
    }
    return message;
  }

  bool _isConnectivityOrServerError(String raw) {
    final text = raw.toLowerCase();
    return text.contains('تعذر الوصول') ||
        text.contains('failed host lookup') ||
        text.contains('socket') ||
        text.contains('connection') ||
        text.contains('timeout') ||
        text.contains('مهلة') ||
        text.contains('xmlhttprequest error');
  }

  String _friendlyLoginLoadError(String raw) {
    final normalized = raw.replaceFirst('ApiException:', '').trim();
    if (_isConnectivityOrServerError(raw)) {
      return 'تعذر الاتصال بالشبكة أو الخادم. تحقق من الإنترنت ورابط API ثم أعد المحاولة.';
    }
    if (normalized.isEmpty) {
      return 'حدث خطأ غير متوقع أثناء محاولة تسجيل الدخول.';
    }
    return normalized;
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (!_formKey.currentState!.validate()) {
      _showLoginNotice(
        AppNoticeType.warning,
        'تحقق من الحقول المطلوبة ثم أعد المحاولة.',
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitting = true;
      _loginLoadError = null;
    });
    final auth = ref.read(authControllerProvider.notifier);
    try {
      if (_isAdminMode) {
        await auth.adminLogin(
          username: _usernameController.text.trim(),
          password: _passwordController.text,
        );
        return;
      }

      await auth.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      final showLoadCard = _isConnectivityOrServerError(raw);
      setState(() {
        _loginLoadError = showLoadCard ? _friendlyLoginLoadError(raw) : null;
      });
      _showLoginNotice(AppNoticeType.error, _normalizeAuthErrorMessage(raw));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildInlineNotice() {
    final message = _noticeMessage;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    final (icon, borderColor, bgColor) = switch (_noticeType) {
      AppNoticeType.success => (
        Icons.check_circle_rounded,
        AppTheme.noticeSuccess,
        AppTheme.noticeSuccess.withValues(alpha: 0.09),
      ),
      AppNoticeType.error => (
        Icons.error_rounded,
        AppTheme.noticeError,
        AppTheme.noticeError.withValues(alpha: 0.09),
      ),
      AppNoticeType.warning => (
        Icons.warning_amber_rounded,
        AppTheme.noticeWarning,
        AppTheme.noticeWarning.withValues(alpha: 0.09),
      ),
      AppNoticeType.info => (
        Icons.info_rounded,
        AppTheme.brandTeal,
        AppTheme.brandTeal.withValues(alpha: 0.09),
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: borderColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AppShellBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    14,
                    14,
                    14,
                    math.max(14, keyboardInset + 14),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 28,
                    ),
                    child: Center(
                      child: ResponsiveFrame(
                        maxWidth: 420,
                        child: RevealOnMount(
                          delay: const Duration(milliseconds: 70),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Form(
                                key: _formKey,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandSky.withValues(
                                          alpha: 0.52,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/branding/app_logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _subtitle,
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        height: 1.35,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _usernameController,
                                      decoration: const InputDecoration(
                                        labelText: 'اسم المستخدم',
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                        ),
                                      ),
                                      validator: AppValidators.username,
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      decoration: const InputDecoration(
                                        labelText: 'كلمة المرور',
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                      ),
                                      validator: AppValidators.password,
                                    ),
                                    const SizedBox(height: 12),
                                    if (_loginLoadError != null) ...[
                                      AppLoadErrorCard(
                                        title: 'تعذر تسجيل الدخول',
                                        subtitle:
                                            'حدثت مشكلة اتصال أثناء التحقق من البيانات.',
                                        message: _loginLoadError!,
                                        onRetry: _submit,
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    _buildInlineNotice(),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _submitting
                                            ? null
                                            : () => _submit(),
                                        icon: _submitting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.login_rounded,
                                                size: 18,
                                              ),
                                        label: Text(
                                          _submitting
                                              ? 'جاري التحقق...'
                                              : _submitLabel,
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
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
