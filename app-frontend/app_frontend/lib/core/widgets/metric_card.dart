import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import 'package:flutter/material.dart';

const _kCurrencyColors = <String, Color>{
  'SYP': AppTheme.brandTeal,
  'USD': Color(0xFF2E7D32),
  'EUR': Color(0xFF1565C0),
  'USDT': Color(0xFF00695C),
};

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.brandTeal,
    this.hint,
    this.currencyAmounts = const {},
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  /// خريطة العملات → المبالغ الفعلية. عند وجودها تحلّ محلّ value.
  final Map<String, double> currencyAmounts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final currencyEntries = currencyAmounts.entries
        .where((e) => e.value != 0)
        .toList();
    final showCurrencies = currencyEntries.isNotEmpty;

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          // ── قيمة رئيسية: scroll أفقي ثابت الارتفاع أو نص واحد ───
          if (showCurrencies)
            SizedBox(
              height: 26,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < currencyEntries.length; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      _MiniCurrencyChip(
                        currency: currencyEntries[i].key,
                        amount: currencyEntries[i].value,
                        color: _kCurrencyColors[currencyEntries[i].key] ?? color,
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                height: 1.1,
              ),
            ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSoft, fontSize: 10.5),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: color.withValues(alpha: 0.55),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

class _MiniCurrencyChip extends StatelessWidget {
  const _MiniCurrencyChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        formatCurrencyAmount(amount, currency),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
