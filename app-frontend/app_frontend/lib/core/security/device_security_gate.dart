import '../../features/auth/logic/auth_controller.dart';
import '../widgets/app_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

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
  bool _passed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _verify());
  }

  Future<void> _verify() async {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    if (!widget.enabled) {
      setState(() {
        _checking = false;
        _passed = true;
      });
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final supported = await _auth.isDeviceSupported();
      final canBiometric = await _auth.canCheckBiometrics;
      if (!supported && !canBiometric) {
        setState(() {
          _checking = false;
          _error = 'فعّل قفل الشاشة أو البصمة من إعدادات الهاتف.';
        });
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'أكّد هويتك ببصمة الإصبع أو قفل الهاتف',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!mounted) return;
      setState(() {
        _checking = false;
        _passed = ok;
        _error = ok ? null : 'لم يتم التحقق من هوية الجهاز.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'تعذر تشغيل تحقق الجهاز.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_passed) return widget.child;
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              margin: const EdgeInsets.all(18),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _checking
                          ? Icons.fingerprint_rounded
                          : Icons.phonelink_lock_rounded,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _checking ? 'جاري التحقق من الجهاز' : 'تحقق الجهاز',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _checking
                          ? 'يرجى إكمال التحقق للمتابعة.'
                          : (_error ?? 'أعد المحاولة للمتابعة.'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    if (_checking)
                      const CircularProgressIndicator()
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _verify,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('إعادة المحاولة'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .logout(),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('خروج'),
                          ),
                        ],
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
