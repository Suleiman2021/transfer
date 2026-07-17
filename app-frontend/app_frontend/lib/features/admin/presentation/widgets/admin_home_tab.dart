import '../../../../core/entities/app_models.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/finance_card.dart';
import '../../../../core/widgets/metric_card.dart';
import '../../../../core/widgets/quick_action_tile.dart';
import '../../../../core/widgets/transfer_details_sheet.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'admin_metric_sheets.dart';
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
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
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
  final Future<void> Function(TransferModel) onApprove;
  final Future<void> Function(TransferModel) onReject;
  final Future<void> Function(TransferModel) onCancel;

  /// يجمع currency_balances من كل الصناديق (ما عدا الخزنة).
  Map<String, double> _networkCurrencyTotals() {
    final totals = <String, double>{};
    for (final box in cashboxes.where((b) => !b.isTreasury)) {
      for (final e in box.currencyBalances.entries) {
        if (e.value != 0) totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    return totals;
  }

  /// يحسب العمولات بعملتها الأصلية من التحويلات.
  Map<String, double> _commissionByCurrency() {
    final result = <String, double>{};
    for (final t in transfers.where((t) => t.state == 'completed')) {
      final comm = t.commissionValue;
      if (comm <= 0) continue;
      final currency = t.sourceCurrency;
      result[currency] = (result[currency] ?? 0) + comm;
    }
    return result;
  }

  /// يبني chips أرصدة الخزنة للكرت الكبير.
  List<Widget> _treasuryChips(CashboxModel? treasury) {
    if (treasury == null) return [];
    return treasury.currencyBalances.entries
        .where((e) => e.value != 0)
        .map<Widget>((e) => FinanceChip(
              label: 'خزنة ${currencyLabel(e.key)}',
              value: formatCurrencyAmount(e.value, e.key),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final networkCurrencyTotals = _networkCurrencyTotals();
    final commByCurrency = _commissionByCurrency();
    final treasury = cashboxes.where((b) => b.isTreasury).firstOrNull;
    final completed = transfers.where((t) => t.state == 'completed').length;

    return Column(
      children: [
        FinanceCard(
          title: 'مركز الشبكة المالي',
          currencyAmounts: networkCurrencyTotals,
          subtitle: 'شبكة التحويل الداخلية',
          icon: Icons.account_balance_rounded,
          chips: [
            FinanceChip(label: 'المستخدمون', value: users.length.toString()),
            FinanceChip(label: 'الصناديق', value: cashboxes.length.toString()),
            FinanceChip(label: 'معلقة', value: pending.length.toString()),
            ..._treasuryChips(treasury),
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
                    hint: '${users.where((u) => u.isActive).length} فعّال',
                    onTap: () => showUsersDetailSheet(context, users),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'الصناديق',
                    value: cashboxes.length.toString(),
                    icon: Icons.inventory_rounded,
                    color: Colors.blue,
                    hint: '${cashboxes.where((b) => b.isActive).length} فعّال',
                    onTap: () => showCashboxesDetailSheet(
                      context,
                      cashboxes,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'رصيد الشبكة',
                    value: networkCurrencyTotals.isEmpty ? '0' : '',
                    icon: Icons.wallet_rounded,
                    color: Colors.green,
                    hint: 'اضغط للتفاصيل',
                    currencyAmounts: networkCurrencyTotals,
                    onTap: () => showNetworkBalanceSheet(
                      context,
                      cashboxes,
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: MetricCard(
                    label: 'إيراد العمولة',
                    value: commByCurrency.isEmpty ? '0' : '',
                    icon: Icons.paid_rounded,
                    color: Colors.amber,
                    hint: 'من $completed عملية',
                    currencyAmounts: commByCurrency,
                    onTap: () => showCommissionDetailSheet(
                      context,
                      transfers,
                    ),
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
                      title: 'تنفيذ عملية',
                      icon: Icons.send_rounded,
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
                          child: TransferTile(
                            transfer: transfer,
                            onTap: () => showTransferDetailsSheet(
                              context,
                              transfer: transfer,
                              onApprove: transfer.state == 'pending_review'
                                  ? () => onApprove(transfer)
                                  : null,
                              onReject: transfer.state == 'pending_review'
                                  ? () => onReject(transfer)
                                  : null,
                              onCancel: transfer.state == 'completed'
                                  ? () => onCancel(transfer)
                                  : null,
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
