import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/date_filter_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../core/widgets/transfer_tile.dart';
import 'package:flutter/material.dart';

class OperationsHistoryScreen extends StatelessWidget {
  const OperationsHistoryScreen({
    super.key,
    required this.transfers,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSearch,
    required this.onReset,
    required this.onPrint,
  });

  final List<TransferModel> transfers;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final Future<void> Function() onSearch;
  final VoidCallback onReset;
  final Future<void> Function() onPrint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التحويلات')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: Column(
                children: [
                  AppSectionCard(
                    title: 'فلترة السجل',
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
                  if (transfers.isEmpty)
                    const AppEmptyState(
                      title: 'لا توجد عمليات',
                      subtitle: 'غيّر الفترة الزمنية أو نفذ عملية جديدة.',
                    )
                  else
                    AppSectionCard(
                      title: 'النتائج',
                      icon: Icons.receipt_long_rounded,
                      child: Column(
                        children: transfers
                            .map(
                              (transfer) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TransferTile(transfer: transfer),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
