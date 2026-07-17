import '../entities/app_models.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/dashboard_formatters.dart';
import 'status_badge.dart';
import 'package:flutter/material.dart';

class TransferTile extends StatelessWidget {
  const TransferTile({
    super.key,
    required this.transfer,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.busy = false,
  });

  final TransferModel transfer;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.tileDecoration().copyWith(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.brandTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppTheme.brandTeal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transferTypeLabelAr(transfer.operationType),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          transferSummaryAr(transfer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge.transfer(transfer.state),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      formatCurrencyAmount(transfer.amountValue, transfer.sourceCurrency),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    shortDateTimeText(transfer.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSoft,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              if (onApprove != null || onReject != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (onReject != null) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onReject,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('رفض'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (onApprove != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : onApprove,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(busy ? 'جار...' : 'اعتماد'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
