import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import 'package:flutter/material.dart';

const _kCurrencyColors = <String, Color>{
  'SYP': AppTheme.brandTeal,
  'USD': Color(0xFF2E7D32),
  'EUR': Color(0xFF1565C0),
  'USDT': Color(0xFF00695C),
};

// ─── صناديقي مع تفاصيل العملات ────────────────────────────────────────────────

void showMyCashboxesSheet(
  BuildContext context, {
  required List<CashboxModel> cashboxes,
  required String ownerName,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MyCashboxesSheet(
      cashboxes: cashboxes,
      ownerName: ownerName,
    ),
  );
}

class _MyCashboxesSheet extends StatelessWidget {
  const _MyCashboxesSheet({required this.cashboxes, required this.ownerName});
  final List<CashboxModel> cashboxes;
  final String ownerName;

  Map<String, double> _totals() {
    final t = <String, double>{};
    for (final b in cashboxes) {
      for (final e in b.currencyBalances.entries) {
        if (e.value != 0) t[e.key] = (t[e.key] ?? 0) + e.value;
      }
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final totals = _totals();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── رأس الصفحة ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'صناديقي',
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
                  _Badge('${cashboxes.length} صندوق', AppTheme.brandTeal),
                ],
              ),
              // ── إجمالي العملات ──
              if (totals.isNotEmpty) ...[
                const SizedBox(height: 10),
                _CurrencyTotalsCard(totals: totals, label: 'الإجمالي الكلي'),
              ],
              const SizedBox(height: 14),
              // ── تفاصيل كل صندوق ──
              ...cashboxes.map(
                (box) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CashboxCurrencyCard(box: box),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── تفاصيل الأرباح ────────────────────────────────────────────────────────────

void showProfitsDetailSheet(
  BuildContext context, {
  required List<TransferModel> transfers,
  required Set<String> myCashboxIds,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProfitsSheet(transfers: transfers, myCashboxIds: myCashboxIds),
  );
}

class _ProfitsSheet extends StatelessWidget {
  const _ProfitsSheet({required this.transfers, required this.myCashboxIds});
  final List<TransferModel> transfers;
  final Set<String> myCashboxIds;

  static void _addToCurrencyMap(
    Map<String, double> map,
    double amount,
    String sourceCurrency,
  ) {
    if (amount <= 0) return;
    map[sourceCurrency] = (map[sourceCurrency] ?? 0) + amount;
  }

  @override
  Widget build(BuildContext context) {
    // فقط العمليات التي كان فيها صندوقنا هو المُرسِل لتجنب احتساب أرباح الطرف الآخر.
    final completed = transfers
        .where((t) => t.state == 'completed' && myCashboxIds.contains(t.fromCashboxId))
        .toList();

    final agentProfitByCurrency = <String, double>{};
    final byTypeByCurrency = <String, Map<String, double>>{};

    for (final t in completed) {
      _addToCurrencyMap(agentProfitByCurrency, t.agentProfitValue, t.sourceCurrency);
      final profit = t.agentProfitValue;
      if (profit > 0) {
        final typeMap = byTypeByCurrency.putIfAbsent(t.operationType, () => {});
        _addToCurrencyMap(typeMap, profit, t.sourceCurrency);
      }
    }

    // الإجمالي الكلي = مجموع كل العملات
    final totalByCurrency = <String, double>{};
    for (final map in [agentProfitByCurrency]) {
      for (final e in map.entries) {
        totalByCurrency[e.key] = (totalByCurrency[e.key] ?? 0) + e.value;
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'تفاصيل الأرباح',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  _Badge('${completed.length} عملية', Colors.green),
                ],
              ),
              const SizedBox(height: 12),

              // ── الإجمالي الكلي ──
              if (totalByCurrency.isNotEmpty)
                _CurrencyTotalsCard(
                  totals: totalByCurrency,
                  label: 'إجمالي الأرباح',
                  color: Colors.green,
                ),

              const SizedBox(height: 12),

              // ── ربح العمليات ──
              if (agentProfitByCurrency.isNotEmpty) ...[
                _ProfitSectionCard(
                  label: 'ربح العمليات',
                  icon: Icons.swap_horiz_rounded,
                  amounts: agentProfitByCurrency,
                  color: AppTheme.brandTeal,
                ),
                const SizedBox(height: 8),
              ],

              // ── توزيع حسب نوع العملية ──
              if (byTypeByCurrency.isNotEmpty) ...[
                const Divider(height: 20),
                const Text(
                  'توزيع حسب نوع العملية',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                ...byTypeByCurrency.entries
                    .toList()
                    .sorted((a, b) {
                      final sumA = a.value.values.fold(0.0, (s, v) => s + v);
                      final sumB = b.value.values.fold(0.0, (s, v) => s + v);
                      return sumB.compareTo(sumA);
                    })
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TypeBreakdownRow(
                          label: transferTypeLabelAr(e.key),
                          amounts: e.value,
                        ),
                      ),
                    ),
              ],

              if (totalByCurrency.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'لا توجد أرباح في العمليات المحددة.',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── الطلبات المعلقة ──────────────────────────────────────────────────────────

void showPendingBriefSheet(
  BuildContext context, {
  required List<TransferModel> pending,
  required VoidCallback onGoToPending,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PendingBriefSheet(
      pending: pending,
      onGoToPending: onGoToPending,
    ),
  );
}

class _PendingBriefSheet extends StatelessWidget {
  const _PendingBriefSheet({
    required this.pending,
    required this.onGoToPending,
  });
  final List<TransferModel> pending;
  final VoidCallback onGoToPending;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'الطلبات المعلقة',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _Badge('${pending.length} طلب', Colors.amber),
              ],
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'لا توجد طلبات معلقة حالياً.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              )
            else ...[
              ...pending.take(4).map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              transferTypeLabelAr(t.operationType),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            transferAmountLabel(
                              t.amountValue,
                              t.sourceCurrency,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (pending.length > 4)
                Text(
                  '+ ${pending.length - 4} طلبات أخرى...',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onGoToPending();
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('الذهاب إلى الطلبات'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets مساعدة مشتركة ────────────────────────────────────────────────────

/// كارد يعرض إجمالي عملات متعددة بتصميم مميز.
class _CurrencyTotalsCard extends StatelessWidget {
  const _CurrencyTotalsCard({
    required this.totals,
    required this.label,
    this.color = AppTheme.brandTeal,
  });
  final Map<String, double> totals;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.where((e) => e.value > 0).toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: entries
                .map((e) => Expanded(
                      child: _CurrencyColumn(
                        currency: e.key,
                        amount: e.value,
                        color: _kCurrencyColors[e.key] ?? color,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// عمود عملة: اسم العملة فوق المبلغ.
class _CurrencyColumn extends StatelessWidget {
  const _CurrencyColumn({
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
      children: [
        Text(
          currencyLabel(currency),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrencyAmount(amount, currency),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

/// بطاقة قسم ربح مع أيقونة وعملات.
class _ProfitSectionCard extends StatelessWidget {
  const _ProfitSectionCard({
    required this.label,
    required this.icon,
    required this.amounts,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Map<String, double> amounts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final entries = amounts.entries.where((e) => e.value > 0).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: entries
                .map((e) => Expanded(
                      child: _CurrencyColumn(
                        currency: e.key,
                        amount: e.value,
                        color: _kCurrencyColors[e.key] ?? color,
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// صف توزيع حسب نوع عملية مع عملات.
class _TypeBreakdownRow extends StatelessWidget {
  const _TypeBreakdownRow({
    required this.label,
    required this.amounts,
  });
  final String label;
  final Map<String, double> amounts;

  @override
  Widget build(BuildContext context) {
    final entries = amounts.entries.where((e) => e.value > 0).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.brandTeal.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.brandTeal.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            children: entries
                .map((e) => _CurrencyBadge(
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

/// بطاقة صندوق واحد مع عملاته.
class _CashboxCurrencyCard extends StatelessWidget {
  const _CashboxCurrencyCard({required this.box});
  final CashboxModel box;

  @override
  Widget build(BuildContext context) {
    final isAgent = box.isAgent;
    final color = isAgent ? Colors.orange : AppTheme.brandTeal;
    final cb = box.currencyBalances;
    final entries = cb.isNotEmpty
        ? cb.entries.where((e) => e.value != 0).toList()
        : [MapEntry('SYP', box.balanceValue)];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── رأس: أيقونة + اسم + نوع ──
          Row(
            children: [
              Icon(
                isAgent ? Icons.store_rounded : Icons.verified_rounded,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  box.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  cashboxTypeLabelAr(box.type),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${box.city}، ${box.country}',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          // ── الأرصدة بكل عملة ──
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: entries
                .map(
                  (e) => _CurrencyBadge(
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

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({
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
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
    );
  }
}

extension _Sorted<T> on List<T> {
  List<T> sorted(int Function(T, T) compare) => [...this]..sort(compare);
}
