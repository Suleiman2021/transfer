import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/cashbox_balance_sheet.dart';
import '../../../../core/widgets/quick_action_tile.dart';
import '../../../auth/logic/auth_controller.dart';
import '../../../shared/presentation/screens/user_qr_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OperationsAccountTab extends ConsumerWidget {
  const OperationsAccountTab({
    super.key,
    required this.session,
    required this.myCashboxes,
    required this.isActive,
    required this.onHistory,
    required this.onReports,
  });

  final AuthSession session;
  final List<CashboxModel> myCashboxes;
  final bool isActive;
  final VoidCallback onHistory;
  final VoidCallback onReports;

  Map<String, double> _currencyTotals() {
    final result = <String, double>{};
    for (final box in myCashboxes) {
      box.currencyBalances.forEach((k, v) {
        result[k] = (result[k] ?? 0) + v;
      });
    }
    return result;
  }

  String _totalsSubtitle() {
    final n = myCashboxes.length;
    return '$n ${n == 1 ? 'صندوق' : 'صناديق'}';
  }

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
        if (myCashboxes.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppSectionCard(
            title: 'صناديقي',
            subtitle: _totalsSubtitle(),
            icon: Icons.inventory_2_rounded,
            child: Column(
              children: [
                ...myCashboxes.map(
                  (box) => _CashboxTile(box: box),
                ),
                if (myCashboxes.length > 1) ...[
                  const Divider(height: 20),
                  _CurrencyTotalsRow(totals: _currencyTotals()),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showCashboxBalanceSheet(
                      context,
                      cashboxes: myCashboxes,
                      ownerName: session.fullName,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('عرض تفاصيل الأرصدة'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CurrencyTotalsRow extends StatelessWidget {
  const _CurrencyTotalsRow({required this.totals});

  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الإجمالي',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: totals.entries
                .map(
                  (e) => Text(
                    formatCurrencyAmount(e.value, e.key),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _CashboxTile extends StatelessWidget {
  const _CashboxTile({required this.box});

  final CashboxModel box;

  @override
  Widget build(BuildContext context) {
    final balances = box.currencyBalances.entries
        .where((e) => e.value != 0)
        .toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassLine),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.brandTeal.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppTheme.brandTeal,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  box.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cashboxTypeLabelAr(box.type)} · ${box.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.textSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (balances.isEmpty)
            const Text(
              'لا يوجد رصيد',
              style: TextStyle(color: AppTheme.textSoft, fontSize: 11.5),
            )
          else
            Flexible(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.end,
                children: balances
                    .map((e) => _BalanceChip(currency: e.key, amount: e.value))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.currency, required this.amount});
  final String currency;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.20)),
      ),
      child: Text(
        formatCurrencyAmount(amount, currency),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          color: AppTheme.brandInk,
        ),
      ),
    );
  }
}
