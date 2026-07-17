import '../../../../core/entities/app_models.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/cashbox_balance_sheet.dart';
import '../../../../core/widgets/finance_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/quick_action_tile.dart';
import '../../../../core/widgets/transfer_details_sheet.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'operations_metric_sheets.dart';
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

  /// يجمع currency_balances الفعلية من كل الصناديق.
  Map<String, double> _buildCurrencyTotals() {
    final totals = <String, double>{};
    for (final box in myCashboxes) {
      for (final e in box.currencyBalances.entries) {
        if (e.value != 0) totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    return totals;
  }

  /// يحسب الأرباح بعملتها الأصلية مباشرة (المبالغ مخزنة بعملة المصدر).
  /// يُحسب فقط من العمليات التي يكون فيها صندوق المستخدم هو المُرسِل،
  /// لتجنب احتساب أرباح الطرف الآخر (مثل ربح الوكيل في عمليات topup الواصلة).
  Map<String, double> _buildProfitByCurrency() {
    final myCashboxIds = myCashboxes.map((b) => b.id).toSet();
    final profits = <String, double>{};
    for (final t in transfers.where((t) => t.state == 'completed')) {
      if (!myCashboxIds.contains(t.fromCashboxId)) continue;
      final profit = t.agentProfitValue;
      if (profit <= 0) continue;
      final currency = t.sourceCurrency;
      profits[currency] = (profits[currency] ?? 0) + profit;
    }
    return profits;
  }

  @override
  Widget build(BuildContext context) {
    final currencyTotals = _buildCurrencyTotals();
    final profitByCurrency = _buildProfitByCurrency();

    // chips الأرباح: chip لكل عملة
    final profitChips = profitByCurrency.entries
        .where((e) => e.value > 0)
        .map<Widget>((e) => FinanceChip(
              label: 'ربح ${currencyLabel(e.key)}',
              value: formatCurrencyAmount(e.value, e.key),
            ))
        .toList();

    return Column(
      children: [
        FinanceCard(
          title: session.role == UserRole.agent
              ? 'رصيد صناديق الوكيل'
              : 'رصيد صناديق المعتمد',
          currencyAmounts: currencyTotals,
          subtitle:
              '${session.fullName} — ${session.city}، ${session.country}',
          chips: [
            FinanceChip(
              label: 'الصناديق',
              value: myCashboxes.length.toString(),
            ),
            FinanceChip(label: 'المعلقة', value: pending.length.toString()),
            ...profitChips,
          ],
          onTap: myCashboxes.isEmpty
              ? null
              : () => showCashboxBalanceSheet(
                    context,
                    cashboxes: myCashboxes,
                    ownerName: session.fullName,
                  ),
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
                    hint: myCashboxes.isEmpty ? null : 'اضغط للتفاصيل',
                    onTap: myCashboxes.isEmpty
                        ? null
                        : () => showMyCashboxesSheet(
                              context,
                              cashboxes: myCashboxes,
                              ownerName: session.fullName,
                            ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'الرصيد',
                    value: currencyTotals.isEmpty ? '0' : '',
                    icon: Icons.wallet_rounded,
                    color: Colors.blue,
                    hint: myCashboxes.isEmpty ? null : 'اضغط للتفاصيل',
                    currencyAmounts: currencyTotals,
                    onTap: myCashboxes.isEmpty
                        ? null
                        : () => showCashboxBalanceSheet(
                              context,
                              cashboxes: myCashboxes,
                              ownerName: session.fullName,
                            ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'الأرباح',
                    value: profitByCurrency.isEmpty ? '0' : '',
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                    hint: 'اضغط للتفاصيل',
                    currencyAmounts: profitByCurrency,
                    onTap: () => showProfitsDetailSheet(
                      context,
                      transfers: transfers,
                      myCashboxIds: myCashboxes.map((b) => b.id).toSet(),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'طلبات معلقة',
                    value: pending.length.toString(),
                    icon: Icons.pending_actions_rounded,
                    color: Colors.amber,
                    hint: pending.isEmpty ? 'لا طلبات معلقة' : 'اضغط للعرض',
                    onTap: () => showPendingBriefSheet(
                      context,
                      pending: pending,
                      onGoToPending: onPending,
                    ),
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
                      title: 'تنفيذ عملية',
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
                          child: TransferTile(
                            transfer: transfer,
                            onTap: () => showTransferDetailsSheet(
                              context,
                              transfer: transfer,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
