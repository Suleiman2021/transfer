import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/date_filter_bar.dart';
import '../../../../core/widgets/transfer_details_sheet.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({
    super.key,
    required this.transfers,
    required this.dailyRows,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSearch,
    required this.onReset,
    required this.onPrint,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  final List<TransferModel> transfers;
  final List<DailyTransferReportRowModel> dailyRows;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final Future<void> Function() onSearch;
  final VoidCallback onReset;
  final Future<void> Function() onPrint;
  final ValueChanged<TransferModel> onApprove;
  final ValueChanged<TransferModel> onReject;
  final ValueChanged<TransferModel> onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSectionCard(
          title: 'فلترة وطباعة',
          icon: Icons.tune_rounded,
          child: DateFilterBar(
            fromDate: fromDate,
            toDate: toDate,
            onPickFrom: onPickFrom,
            onPickTo: onPickTo,
            onSearch: onSearch,
            onReset: onReset,
            onPrint: onPrint,
          ),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'التقرير اليومي',
          icon: Icons.calendar_month_rounded,
          child: dailyRows.isEmpty
              ? const Text('لا توجد بيانات يومية.')
              : Column(
                  children: dailyRows
                      .map(
                        (row) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(row.date),
                          subtitle: Text(
                            'العمليات: ${row.transfersCount} - المكتملة: ${row.completedCount}',
                          ),
                          trailing: Text(moneyText(row.totalAmount)),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        AppSectionCard(
          title: 'سجل التحويلات',
          icon: Icons.receipt_long_rounded,
          child: transfers.isEmpty
              ? const AppEmptyState(
                  title: 'لا توجد عمليات',
                  subtitle: 'لا توجد سجلات ضمن الفترة الحالية.',
                )
              : Column(
                  children: transfers
                      .map(
                        (transfer) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TransferTile(
                            transfer: transfer,
                            onTap: () => showTransferDetailsSheet(
                              context,
                              transfer: transfer,
                              onApprove: transfer.state == 'pending_review'
                                  ? () => onApprove(transfer)
                                  : null,
                              onReject: transfer.state == 'pending_review'
                                  ? () => onReject(transfer)
                                  : null,
                              onCancel: transfer.state == 'completed'
                                  ? () => onCancel(transfer)
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}
