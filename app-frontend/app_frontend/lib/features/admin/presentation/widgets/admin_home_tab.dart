import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/finance_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/quick_action_tile.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({
    super.key,
    required this.users,
    required this.cashboxes,
    required this.transfers,
    required this.pending,
    required this.commissionRevenue,
    required this.onAddUser,
    required this.onAddCashbox,
    required this.onExecute,
    required this.onCommissions,
  });

  final List<AppUser> users;
  final List<CashboxModel> cashboxes;
  final List<TransferModel> transfers;
  final List<TransferModel> pending;
  final double commissionRevenue;
  final VoidCallback onAddUser;
  final VoidCallback onAddCashbox;
  final VoidCallback onExecute;
  final VoidCallback onCommissions;

  @override
  Widget build(BuildContext context) {
    final networkBalance = cashboxes
        .where((box) => !box.isTreasury)
        .fold<double>(0, (sum, box) => sum + box.balanceValue);
    final treasury = cashboxes.where((box) => box.isTreasury).firstOrNull;
    return Column(
      children: [
        FinanceCard(
          title: 'مركز الشبكة المالي',
          amount: '${moneyText(networkBalance)} SYP',
          subtitle: 'الخزنة: ${moneyText(treasury?.balanceValue ?? 0)}',
          icon: Icons.account_balance_rounded,
          chips: [
            FinanceChip(label: 'المستخدمون', value: users.length.toString()),
            FinanceChip(label: 'الصناديق', value: cashboxes.length.toString()),
            FinanceChip(label: 'معلقة', value: pending.length.toString()),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'المستخدمون',
                    value: users.length.toString(),
                    icon: Icons.people_alt_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'الصناديق',
                    value: cashboxes.length.toString(),
                    icon: Icons.inventory_rounded,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'رصيد الشبكة',
                    value: moneyText(networkBalance),
                    icon: Icons.wallet_rounded,
                    color: Colors.green,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'إيراد العمولة',
                    value: moneyText(commissionRevenue),
                    icon: Icons.paid_rounded,
                    color: Colors.amber,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'إجراءات الإدارة',
          icon: Icons.dashboard_customize_rounded,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: width,
                    child: QuickActionTile(
                      title: 'إضافة مستخدم',
                      icon: Icons.person_add_rounded,
                      onTap: onAddUser,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: QuickActionTile(
                      title: 'إضافة صندوق',
                      icon: Icons.add_business_rounded,
                      color: Colors.blue,
                      onTap: onAddCashbox,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: QuickActionTile(
                      title: 'تنفيذ حسب الاسم',
                      icon: Icons.person_search_rounded,
                      color: Colors.green,
                      onTap: onExecute,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: QuickActionTile(
                      title: 'ضبط العمولات',
                      icon: Icons.percent_rounded,
                      color: Colors.amber,
                      onTap: onCommissions,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'آخر عمليات الشبكة',
          icon: Icons.receipt_long_rounded,
          child: transfers.isEmpty
              ? const Text('لا توجد عمليات حديثة.')
              : Column(
                  children: transfers
                      .take(5)
                      .map(
                        (transfer) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TransferTile(transfer: transfer),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
