import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

class DeviceAuth {
  DeviceAuth._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> verify({
    String reason = 'أكد هويتك ببصمة الإصبع أو قفل الهاتف',
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    final supported = await _auth.isDeviceSupported();
    final canBiometric = await _auth.canCheckBiometrics;
    if (!supported && !canBiometric) return false;
    return _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(stickyAuth: true),
    );
  }
}
