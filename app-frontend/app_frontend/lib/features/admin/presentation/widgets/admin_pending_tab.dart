import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/transfer_details_sheet.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class AdminPendingTab extends StatelessWidget {
  const AdminPendingTab({
    super.key,
    required this.transfers,
    required this.onApprove,
    required this.onReject,
    this.busyTransferId,
  });

  final List<TransferModel> transfers;
  final ValueChanged<TransferModel> onApprove;
  final ValueChanged<TransferModel> onReject;
  final String? busyTransferId;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'طلبات بانتظار القرار',
      icon: Icons.pending_actions_rounded,
      child: transfers.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد طلبات',
              subtitle: 'لا توجد عمليات تحتاج قرار الأدمن الآن.',
            )
          : Column(
              children: transfers
                  .map(
                    (transfer) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransferTile(
                        transfer: transfer,
                        busy: busyTransferId == transfer.id,
                        onTap: () => showTransferDetailsSheet(
                          context,
                          transfer: transfer,
                          busy: busyTransferId == transfer.id,
                          onApprove: () => onApprove(transfer),
                          onReject: () => onReject(transfer),
                        ),
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
