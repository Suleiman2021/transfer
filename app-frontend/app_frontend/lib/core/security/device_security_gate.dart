import '../../features/auth/logic/auth_controller.dart';
import '../widgets/app_shell_background.dart';
import '../widgets/responsive_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum DeviceCheckStatus { success, failed, unavailable }

class DeviceSecurityGate extends ConsumerStatefulWidget {
  const DeviceSecurityGate({
    super.key,
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

  @override
  ConsumerState<DeviceSecurityGate> createState() => _DeviceSecurityGateState();
}

class _DeviceSecurityGateState extends ConsumerState<DeviceSecurityGate> {
  final LocalAuthentication _auth = LocalAuthentication();

  bool _checking = true;
  DeviceCheckStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    });
    _verifyDeviceAuth();
  }

  Future<void> _verifyDeviceAuth() async {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (!widget.enabled) {
      if (!mounted) return;
      setState(() {
        _status = DeviceCheckStatus.success;
        _checking = false;
      });
      return;
    }

    try {
      final canUseBiometrics = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();

      if (!canUseBiometrics && !isSupported) {
        if (!mounted) return;
        setState(() {
          _status = DeviceCheckStatus.unavailable;
          _checking = false;
        });
        return;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'أكّد هويتك ببصمة الإصبع أو قفل الهاتف',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;
      setState(() {
        _status = didAuthenticate
            ? DeviceCheckStatus.success
            : DeviceCheckStatus.failed;
        _checking = false;
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _status = DeviceCheckStatus.unavailable;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return _buildShell(
        context,
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.3),
                ),
                SizedBox(height: 12),
                Text(
                  'جاري التحقق من هوية الجهاز...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_status == DeviceCheckStatus.success) {
      return widget.child;
    }

    final unavailable = _status == DeviceCheckStatus.unavailable;
    final title = unavailable ? 'قفل الجهاز غير متاح' : 'تعذر التحقق من الهوية';
    final subtitle = unavailable
        ? 'يرجى تفعيل بصمة الإصبع أو قفل الشاشة في إعدادات الهاتف.'
        : 'لم يتم التحقق من هوية الجهاز. أعد المحاولة للمتابعة.';

    return _buildShell(
      context,
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phonelink_lock_rounded, size: 34),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _checking = true);
                      _verifyDeviceAuth();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShell(BuildContext context, Widget child) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AppShellBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 28,
                  ),
                  child: Center(
                    child: ResponsiveFrame(maxWidth: 440, child: child),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
