import 'app.dart';
import 'core/config/app_runtime_config.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppRuntimeConfig.initialize(ClientAppType.operations);
  runApp(const ProviderScope(child: CashboxTransferApp()));
}
