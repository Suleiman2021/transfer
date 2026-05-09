import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/finance_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/quick_action_tile.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class OperationsHomeTab extends StatelessWidget {
  const OperationsHomeTab({
    super.key,
    required this.session,
    required this.myCashboxes,
    required this.transfers,
    required this.pending,
    required this.onTransfer,
    required this.onPending,
    required this.onHistory,
    required this.onReports,
  });

  final AuthSession session;
  final List<CashboxModel> myCashboxes;
  final List<TransferModel> transfers;
  final List<TransferModel> pending;
  final VoidCallback onTransfer;
  final VoidCallback onPending;
  final VoidCallback onHistory;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
    final total = myCashboxes.fold<double>(
      0,
      (sum, box) => sum + box.balanceValue,
    );
    final profit = transfers
        .where((transfer) => transfer.state == 'completed')
        .fold<double>(
          0,
          (sum, transfer) =>
              sum + transfer.agentProfitValue + transfer.cashoutProfitValue,
        );
    return Column(
      children: [
        FinanceCard(
          title: session.role == UserRole.agent
              ? 'رصيد صناديق الوكيل'
              : 'رصيد صناديق المعتمد',
          amount: '${moneyText(total)} SYP',
          subtitle: '${session.fullName} - ${session.city}, ${session.country}',
          chips: [
            FinanceChip(
              label: 'الصناديق',
              value: myCashboxes.length.toString(),
            ),
            FinanceChip(label: 'المعلقة', value: pending.length.toString()),
            FinanceChip(label: 'الربح', value: moneyText(profit)),
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
                    label: 'صناديقي',
                    value: myCashboxes.length.toString(),
                    icon: Icons.inventory_2_rounded,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'الرصيد',
                    value: moneyText(total),
                    icon: Icons.wallet_rounded,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'الأرباح',
                    value: moneyText(profit),
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'طلبات معلقة',
                    value: pending.length.toString(),
                    icon: Icons.pending_actions_rounded,
                    color: Colors.amber,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'اختصارات سريعة',
          subtitle: 'أزرار كبيرة مثل تطبيقات التوصيل لتقليل الازدحام',
          icon: Icons.bolt_rounded,
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
                      title: 'تنفيذ تحويل',
                      icon: Icons.send_rounded,
                      onTap: onTransfer,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: QuickActionTile(
                      title: 'الطلبات',
                      icon: Icons.fact_check_rounded,
                      badge: pending.length.toString(),
                      color: Colors.amber,
                      onTap: onPending,
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
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'النشاط الحديث',
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
