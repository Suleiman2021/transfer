import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import 'package:flutter/material.dart';

class FinanceCard extends StatelessWidget {
  const FinanceCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.amount,
    this.currencyAmounts = const {},
    this.icon = Icons.account_balance_wallet_rounded,
    this.chips = const [],
    this.onTap,
  });

  final String title;
  /// نص ثابت يُعرض إذا كان currencyAmounts فارغاً.
  final String? amount;
  /// خريطة العملات → المبالغ الفعلية. عند وجودها تحلّ محلّ amount.
  final Map<String, double> currencyAmounts;
  final String subtitle;
  final IconData icon;
  final List<Widget> chips;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandTeal.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -22,
            top: -26,
            child: Icon(
              Icons.hub_rounded,
              size: 116,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 23),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white54,
                      size: 15,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // ── عرض الأرصدة ─────────────────────────────────────────
              if (currencyAmounts.isNotEmpty)
                _MultiCurrencyDisplay(amounts: currencyAmounts)
              else if (amount != null)
                Text(
                  amount!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                    height: 1.05,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: chips),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: card,
      ),
    );
  }
}

// ── عرض متعدد العملات داخل الكرت الكبير ─────────────────────────────────────

class _MultiCurrencyDisplay extends StatelessWidget {
  const _MultiCurrencyDisplay({required this.amounts});
  final Map<String, double> amounts;

  @override
  Widget build(BuildContext context) {
    final entries = amounts.entries.where((e) => e.value != 0).toList();
    if (entries.isEmpty) {
      return const Text(
        '0',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 28,
        ),
      );
    }
    // Horizontal scroll so the card height stays fixed regardless of currency count.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _CurrencyTile(currency: entries[i].key, amount: entries[i].value),
          ],
        ],
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({required this.currency, required this.amount});
  final String currency;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currencyLabel(currency),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatCurrencyAmount(amount, currency),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip بسيط للمعلومات الإضافية ─────────────────────────────────────────────

class FinanceChip extends StatelessWidget {
  const FinanceChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
