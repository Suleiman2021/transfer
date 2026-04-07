import '../../../../core/entities/app_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dashboard_parts.dart';
import 'package:flutter/material.dart';

class OperationsTransferTile extends StatelessWidget {
  const OperationsTransferTile({
    super.key,
    required this.transfer,
    this.onApprove,
    this.onReject,
    this.busy = false,
  });

  final TransferModel transfer;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final showActions = onApprove != null || onReject != null;
    final stateColor = switch (transfer.state) {
      'completed' => const Color(0xFF0F766E),
      'approved' => const Color(0xFF0F766E),
      'pending_review' => const Color(0xFFE76F51),
      'rejected' => const Color(0xFFB91C1C),
      _ => AppTheme.brandInk,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.brandInk.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 4,
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  transferTypeLabelAr(transfer.operationType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DashboardStatePill(text: transferStateLabelAr(transfer.state)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            transferSummaryAr(transfer),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '\u0627\u0644\u0645\u0628\u0644\u063a: ${moneyText(transfer.amountValue)} - \u0639\u0645\u0648\u0644\u0629 \u0627\u0644\u062e\u0632\u0646\u0629: ${moneyText(transfer.commissionValue)} - \u0631\u0628\u062d \u0627\u0644\u0645\u0646\u0641\u0630: ${moneyText(transfer.agentProfitValue)}',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (transfer.cashoutProfitValue > 0) ...[
            const SizedBox(height: 4),
            Text(
              '\u0631\u0628\u062d \u0635\u0631\u0641 \u0627\u0644\u0639\u0645\u064a\u0644: ${moneyText(transfer.cashoutProfitValue)}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          if ((transfer.customerName ?? '').isNotEmpty ||
              (transfer.customerPhone ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0639\u0645\u064a\u0644: ${transfer.customerName ?? '-'} - ${transfer.customerPhone ?? '-'}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          if ((transfer.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '\u0645\u0644\u0627\u062d\u0638\u0629: ${transfer.note}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: busy ? null : onApprove,
                  child: const Text('\u0627\u0639\u062a\u0645\u0627\u062f'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : onReject,
                  child: const Text('\u0631\u0641\u0636'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
