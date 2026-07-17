import '../entities/app_models.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import 'package:flutter/material.dart';

const _kCurrencyColors = <String, Color>{
  'SYP': AppTheme.brandTeal,
  'USD': Color(0xFF2E7D32),
  'EUR': Color(0xFF1565C0),
  'USDT': Color(0xFF00695C),
};

Future<void> showCashboxBalanceSheet(
  BuildContext context, {
  required List<CashboxModel> cashboxes,
  required String ownerName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CashboxBalanceSheet(
      cashboxes: cashboxes,
      ownerName: ownerName,
    ),
  );
}

class _CashboxBalanceSheet extends StatelessWidget {
  const _CashboxBalanceSheet({
    required this.cashboxes,
    required this.ownerName,
  });

  final List<CashboxModel> cashboxes;
  final String ownerName;

  /// يجمع currency_balances من كل الصناديق.
  Map<String, double> _totalsByCurrency() {
    final totals = <String, double>{};
    for (final box in cashboxes) {
      for (final e in box.currencyBalances.entries) {
        if (e.value != 0) totals[e.key] = (totals[e.key] ?? 0) + e.value;
      }
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totalsByCurrency();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رصيد الصناديق',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          ownerName,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // ── إجمالي العملات ──
              if (totals.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CurrencyTotalsBar(totals: totals),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // ── قائمة الصناديق ──
              if (cashboxes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'لا توجد صناديق.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                )
              else
                ...cashboxes.map((box) => _CashboxRow(box: box)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── شريط إجمالي العملات بألوانها ─────────────────────────────────────────────

class _CurrencyTotalsBar extends StatelessWidget {
  const _CurrencyTotalsBar({required this.totals});
  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'الإجمالي الكلي',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: entries
                .map((e) => _CurrencyAmountTile(
                      currency: e.key,
                      amount: e.value,
                      color: _kCurrencyColors[e.key] ?? AppTheme.brandTeal,
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── صف صندوق واحد ─────────────────────────────────────────────────────────────

class _CashboxRow extends StatelessWidget {
  const _CashboxRow({required this.box});

  final CashboxModel box;

  @override
  Widget build(BuildContext context) {
    final isAgent = box.type == 'agent';
    final color = isAgent ? Colors.orange : AppTheme.brandTeal;
    final cb = box.currencyBalances;
    final entries = cb.isNotEmpty
        ? cb.entries.where((e) => e.value != 0).toList()
        : [MapEntry('SYP', box.balanceValue)];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // اسم الصندوق + النوع
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isAgent ? Icons.store_rounded : Icons.verified_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      box.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${cashboxTypeLabelAr(box.type)} — ${box.city}، ${box.country}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (!box.isActive)
                      const Text(
                        'غير فعال',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // الأرصدة بكل عملة
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: entries
                .map(
                  (e) => _CurrencyChip(
                    currency: e.key,
                    amount: e.value,
                    color: _kCurrencyColors[e.key] ?? color,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Widgets مساعدة ────────────────────────────────────────────────────────────

class _CurrencyAmountTile extends StatelessWidget {
  const _CurrencyAmountTile({
    required this.currency,
    required this.amount,
    required this.color,
  });
  final String currency;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          currencyLabel(currency),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
        Text(
          formatCurrencyAmount(amount, currency),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.currency,
    required this.amount,
    required this.color,
  });
  final String currency;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        formatCurrencyAmount(amount, currency),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}
