import 'core/config/app_runtime_config.dart';
import 'core/entities/app_models.dart';
import 'core/security/device_security_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_loading_overlay.dart';
import 'core/ui/app_notifier.dart';
import 'core/widgets/app_background.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/auth/logic/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/operations/presentation/operations_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CashboxTransferApp extends ConsumerWidget {
  const CashboxTransferApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final adminApp = AppRuntimeConfig.isAdminApp;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppRuntimeConfig.appTitle,
      scaffoldMessengerKey: AppNotifier.messengerKey,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: AppLoadingOverlay(child: child!),
      ),
      home: authState.when(
        loading: () => const _SplashScreen(),
        error: (_, _) => LoginScreen(
          mode: adminApp ? LoginMode.admin : LoginMode.operations,
        ),
        data: (session) {
          if (session == null) {
            return LoginScreen(
              mode: adminApp ? LoginMode.admin : LoginMode.operations,
            );
          }
          final isAdminRole = session.role == UserRole.admin ||
              session.role == UserRole.superAdmin;
          if (adminApp && !isAdminRole) {
            return const _RoleMismatchScreen(
              title: 'صلاحية غير متاحة',
              subtitle: 'هذا التطبيق مخصص للأدمن فقط.',
            );
          }
          if (!adminApp && isAdminRole) {
            return const _RoleMismatchScreen(
              title: 'صلاحية غير متاحة',
              subtitle: 'هذا التطبيق مخصص للوكلاء والمعتمدين.',
            );
          }
          return DeviceSecurityGate(
            enabled: true,
            child: adminApp
                ? AdminDashboardScreen(session: session)
                : OperationsDashboardScreen(session: session),
          );
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppBackground(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _RoleMismatchScreen extends ConsumerWidget {
  const _RoleMismatchScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              margin: const EdgeInsets.all(18),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('تسجيل الخروج'),
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
