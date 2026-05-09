import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class OperationsPendingTab extends StatelessWidget {
  const OperationsPendingTab({
    super.key,
    required this.transfers,
    required this.onApprove,
    required this.onReject,
    this.busyTransferId,
  });

  final List<TransferModel> transfers;
  final Future<void> Function(TransferModel transfer) onApprove;
  final Future<void> Function(TransferModel transfer) onReject;
  final String? busyTransferId;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'الطلبات المعلقة',
      subtitle: 'اعتماد أو رفض العمليات بانتظار القرار',
      icon: Icons.pending_actions_rounded,
      child: transfers.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد طلبات',
              subtitle: 'كل شيء هادئ الآن.',
              icon: Icons.task_alt_rounded,
            )
          : Column(
              children: transfers
                  .map(
                    (transfer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransferTile(
                        transfer: transfer,
                        busy: busyTransferId == transfer.id,
                        onApprove: () => onApprove(transfer),
                        onReject: () => onReject(transfer),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
