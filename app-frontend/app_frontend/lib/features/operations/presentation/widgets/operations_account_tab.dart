import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/quick_action_tile.dart';
import '../../../auth/logic/auth_controller.dart';
import '../../../shared/presentation/screens/user_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OperationsAccountTab extends ConsumerWidget {
  const OperationsAccountTab({
    super.key,
    required this.session,
    required this.isActive,
    required this.onHistory,
    required this.onReports,
  });

  final AuthSession session;
  final bool isActive;
  final VoidCallback onHistory;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        AppSectionCard(
          title: 'معلومات الحساب',
          subtitle: 'بيانات المستخدم الحالي',
          icon: Icons.person_rounded,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
                title: Text(session.fullName),
                subtitle: Text(
                  '${roleLabelAr(session.role)} - ${session.city}, ${session.country}',
                ),
                trailing: Chip(label: Text(isActive ? 'فعال' : 'غير فعال')),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: width,
                        child: QuickActionTile(
                          title: 'باركود المستخدم',
                          icon: Icons.qr_code_2_rounded,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserQrScreen.fromSession(session),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: QuickActionTile(
                          title: 'السجل',
                          icon: Icons.history_rounded,
                          color: Colors.blue,
                          onTap: onHistory,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: QuickActionTile(
                          title: 'التقارير',
                          icon: Icons.bar_chart_rounded,
                          color: Colors.green,
                          onTap: onReports,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: QuickActionTile(
                          title: 'تسجيل الخروج',
                          icon: Icons.logout_rounded,
                          color: Colors.red,
                          onTap: () => ref
                              .read(authControllerProvider.notifier)
                              .logout(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
