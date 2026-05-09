import '../entities/app_models.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'package:flutter/material.dart';

Future<void> showTransferDetailsSheet(
  BuildContext context, {
  required TransferModel transfer,
  VoidCallback? onApprove,
  VoidCallback? onReject,
  VoidCallback? onCancel,
  bool busy = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تفاصيل التحويل',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    StatusBadge.transfer(transfer.state),
                  ],
                ),
                const SizedBox(height: 12),
                _InfoLine(
                  'نوع العملية',
                  transferTypeLabelAr(transfer.operationType),
                ),
                _InfoLine('من', transfer.fromLabel),
                _InfoLine('إلى', transfer.toLabel),
                _InfoLine('المبلغ', moneyText(transfer.amountValue)),
                _InfoLine('عمولة الخزنة', moneyText(transfer.commissionValue)),
                _InfoLine('ربح المنفذ', moneyText(transfer.agentProfitValue)),
                if (transfer.cashoutProfitValue > 0)
                  _InfoLine(
                    'ربح صرف العميل',
                    moneyText(transfer.cashoutProfitValue),
                  ),
                if ((transfer.customerName ?? '').isNotEmpty ||
                    (transfer.customerPhone ?? '').isNotEmpty)
                  _InfoLine(
                    'بيانات العميل',
                    '${transfer.customerName ?? '-'} - ${transfer.customerPhone ?? '-'}',
                  ),
                if ((transfer.note ?? '').isNotEmpty)
                  _InfoLine('ملاحظة', transfer.note!),
                _InfoLine('الوقت', transfer.createdAt),
                const SizedBox(height: 12),
                if (onApprove != null || onReject != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy ? null : onReject,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('رفض'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: busy ? null : onApprove,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('اعتماد'),
                        ),
                      ),
                    ],
                  ),
                if (onCancel != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onCancel,
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('إلغاء العملية'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.glassLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
