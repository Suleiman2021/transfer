import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/transfer_details_sheet.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class OperationsPendingTab extends StatefulWidget {
  const OperationsPendingTab({
    super.key,
    required this.transfers,
    required this.onApprove,
    this.onReject,
    this.busyTransferId,
  });

  final List<TransferModel> transfers;
  final Future<void> Function(TransferModel transfer) onApprove;
  final Future<void> Function(TransferModel transfer)? onReject;
  final String? busyTransferId;

  @override
  State<OperationsPendingTab> createState() => _OperationsPendingTabState();
}

class _OperationsPendingTabState extends State<OperationsPendingTab> {
  String _remittanceSearch = '';

  List<TransferModel> get _regular =>
      widget.transfers.where((t) => t.operationType != 'remittance').toList();

  List<TransferModel> get _remittances {
    final all =
        widget.transfers.where((t) => t.operationType == 'remittance').toList();
    if (_remittanceSearch.isEmpty) return all;
    final q = _remittanceSearch.toLowerCase();
    return all.where((t) {
      return (t.receiverName ?? '').toLowerCase().contains(q) ||
          (t.receiverPhone ?? '').contains(q) ||
          t.id.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _RegularSection(
          transfers: _regular,
          onApprove: widget.onApprove,
          onReject: widget.onReject,
          busyTransferId: widget.busyTransferId,
        ),
        const SizedBox(height: 12),
        _RemittancesSection(
          transfers: _remittances,
          search: _remittanceSearch,
          onSearchChanged: (v) => setState(() => _remittanceSearch = v),
          onApprove: widget.onApprove,
          busyTransferId: widget.busyTransferId,
        ),
      ],
    );
  }
}

class _RegularSection extends StatelessWidget {
  const _RegularSection({
    required this.transfers,
    required this.onApprove,
    required this.onReject,
    required this.busyTransferId,
  });

  final List<TransferModel> transfers;
  final Future<void> Function(TransferModel) onApprove;
  final Future<void> Function(TransferModel)? onReject;
  final String? busyTransferId;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'طلبات الاعتماد',
      subtitle: 'عمليات التمويل بانتظار القرار',
      icon: Icons.pending_actions_rounded,
      child: transfers.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد طلبات',
              subtitle: 'لا توجد عمليات معلقة الآن.',
              icon: Icons.task_alt_rounded,
            )
          : Column(
              children: transfers
                  .map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransferTile(
                        transfer: t,
                        busy: busyTransferId == t.id,
                        onTap: () => showTransferDetailsSheet(
                          context,
                          transfer: t,
                          busy: busyTransferId == t.id,
                          onApprove: () => onApprove(t),
                          onReject: onReject != null ? () => onReject!(t) : null,
                        ),
                        onApprove: () => onApprove(t),
                        onReject: onReject != null ? () => onReject!(t) : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _RemittancesSection extends StatelessWidget {
  const _RemittancesSection({
    required this.transfers,
    required this.search,
    required this.onSearchChanged,
    required this.onApprove,
    required this.busyTransferId,
  });

  final List<TransferModel> transfers;
  final String search;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(TransferModel) onApprove;
  final String? busyTransferId;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'طلبات الحوالات',
      subtitle: 'حوالات عملاء بانتظار التسليم',
      icon: Icons.send_rounded,
      child: Column(
        children: [
          TextField(
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'ابحث باسم المستقبل أو رقم هاتفه أو رقم الحوالة',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          if (transfers.isEmpty)
            const AppEmptyState(
              title: 'لا توجد حوالات',
              subtitle: 'لا توجد حوالات معلقة الآن.',
              icon: Icons.task_alt_rounded,
            )
          else
            ...transfers.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TransferTile(
                  transfer: t,
                  busy: busyTransferId == t.id,
                  onTap: () => showTransferDetailsSheet(
                    context,
                    transfer: t,
                    busy: busyTransferId == t.id,
                    onApprove: () => onApprove(t),
                    onReject: null,
                  ),
                  onApprove: () => onApprove(t),
                  onReject: null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
