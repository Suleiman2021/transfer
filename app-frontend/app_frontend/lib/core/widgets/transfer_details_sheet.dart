import '../entities/app_models.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';
import '../utils/dashboard_formatters.dart';
import 'status_badge.dart';
import 'package:flutter/material.dart';

Future<bool> _confirmCancel(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('إلغاء العملية'),
      content: const Text(
        'سيتم التراجع عن العملية بالكامل وإعادة جميع الأرصدة إلى حالتها السابقة. '
        'هل تريد المتابعة؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('رجوع'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.noticeError,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('نعم، إلغاء'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

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
                if (transfer.sourceCurrency != 'SYP')
                  _InfoLine('العملة', currencySymbol(transfer.sourceCurrency)),
                _InfoLine(
                  'المبلغ',
                  formatCurrencyAmount(transfer.amountValue, transfer.sourceCurrency),
                ),
                _InfoLine(
                  'عمولة الخزنة',
                  formatCurrencyAmount(transfer.commissionValue, transfer.sourceCurrency),
                ),
                _InfoLine(
                  'ربح المنفذ',
                  formatCurrencyAmount(transfer.agentProfitValue, transfer.sourceCurrency),
                ),
                if (transfer.operationType == 'remittance') ...[
                  if ((transfer.senderName ?? '').isNotEmpty)
                    _InfoLine(
                      'المرسل',
                      '${transfer.senderName} — ${transfer.senderPhone ?? ''}\n${transfer.senderCity ?? ''} / ${transfer.senderCountry ?? ''}',
                    ),
                  if ((transfer.receiverName ?? '').isNotEmpty)
                    _InfoLine(
                      'المستقبل',
                      '${transfer.receiverName} — ${transfer.receiverPhone ?? ''}\n${transfer.receiverCity ?? ''} / ${transfer.receiverCountry ?? ''}',
                    ),
                  if (double.tryParse(transfer.senderCommissionAmount) != null &&
                      double.parse(transfer.senderCommissionAmount) > 0)
                    _InfoLine(
                      'حصة المرسل المُحتجزة',
                      formatCurrencyAmount(double.parse(transfer.senderCommissionAmount), transfer.sourceCurrency),
                    ),
                  if (double.tryParse(transfer.receiverCommissionAmount) != null &&
                      double.parse(transfer.receiverCommissionAmount) > 0)
                    _InfoLine(
                      'حصة المستقبل',
                      formatCurrencyAmount(double.parse(transfer.receiverCommissionAmount), transfer.sourceCurrency),
                    ),
                ],
                if ((transfer.note ?? '').isNotEmpty)
                  _InfoLine('ملاحظة', transfer.note!),
                _InfoLine('الوقت', shortDateTimeText(transfer.createdAt)),
                const SizedBox(height: 12),
                if (onApprove != null || onReject != null)
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
                      onPressed: busy
                          ? null
                          : () async {
                              if (await _confirmCancel(context)) onCancel();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.noticeError,
                        side: BorderSide(
                          color: AppTheme.noticeError.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('إلغاء العملية (إرجاع الأرصدة)'),
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
