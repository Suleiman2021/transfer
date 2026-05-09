import '../../../../core/entities/app_models.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/date_filter_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import 'package:flutter/material.dart';

class OperationsReportsScreen extends StatelessWidget {
  const OperationsReportsScreen({
    super.key,
    required this.rows,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSearch,
    required this.onReset,
    required this.onPrint,
  });

  final List<DailyTransferReportRowModel> rows;
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
      appBar: AppBar(title: const Text('التقارير')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: Column(
                children: [
                  AppSectionCard(
                    title: 'فلترة وطباعة',
                    icon: Icons.bar_chart_rounded,
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
                    child: rows.isEmpty
                        ? const AppEmptyState(
                            title: 'لا توجد بيانات',
                            subtitle: 'لا توجد أرقام ضمن الفترة الحالية.',
                          )
                        : Column(
                            children: rows
                                .map(
                                  (row) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(row.date),
                                    subtitle: Text(
                                      'العمليات: ${row.transfersCount} - المكتملة: ${row.completedCount} - المعلقة: ${row.pendingCount}',
                                    ),
                                    trailing: Text(moneyText(row.totalAmount)),
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
