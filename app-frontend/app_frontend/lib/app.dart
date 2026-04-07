import 'core/config/app_runtime_config.dart';
import 'core/entities/app_models.dart';
import 'core/security/device_security_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_loading_overlay.dart';
import 'core/ui/app_notifier.dart';
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
    final isAdminApp = AppRuntimeConfig.isAdminApp;

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
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final width = media.size.width;
        final textScale = width >= 1200
            ? 1.0
            : width >= 900
            ? 0.98
            : width >= 600
            ? 0.97
            : 0.95;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(textScale)),
            child: AppLoadingOverlay(child: child!),
          ),
        );
      },
      home: authState.when(
        data: (session) {
          if (session == null) {
            return LoginScreen(
              mode: isAdminApp ? LoginMode.admin : LoginMode.operations,
            );
          }

          if (isAdminApp) {
            if (session.role != UserRole.admin) {
              return const _RoleMismatchScreen(
                title: 'صلاحية غير متاحة',
                subtitle:
                    'هذا التطبيق مخصص للأدمن فقط. استخدم تطبيق المعتمدين والوكلاء.',
              );
            }

            return DeviceSecurityGate(
              enabled: true,
              child: AdminDashboardScreen(session: session),
            );
          }

          if (session.role == UserRole.admin) {
            return const _RoleMismatchScreen(
              title: 'صلاحية غير متاحة',
              subtitle:
                  'هذا التطبيق مخصص للمعتمدين والوكلاء. استخدم تطبيق الأدمن.',
            );
          }

          return DeviceSecurityGate(
            enabled: true,
            child: OperationsDashboardScreen(session: session),
          );
        },
        loading: () => const _SplashScreen(),
        error: (_, _) => LoginScreen(
          mode: isAdminApp ? LoginMode.admin : LoginMode.operations,
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _RoleMismatchScreen extends ConsumerWidget {
  const _RoleMismatchScreen({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, size: 34),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 12),
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
    );
  }
}
