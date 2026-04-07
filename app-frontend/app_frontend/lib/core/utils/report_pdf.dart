import '../entities/app_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printReportPdf({
  required String title,
  required List<TransferModel> transfers,
  required List<DailyTransferReportRowModel> dailyRows,
  DateTime? fromDate,
  DateTime? toDate,
}) async {
  final regular = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document();

  String fmtDate(DateTime? value) {
    if (value == null) return '-';
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.all(20),
      ),
      build: (_) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EEF7F4'),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(font: bold, fontSize: 17),
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'الفترة: ${fmtDate(fromDate)} إلى ${fmtDate(toDate)}',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              _sectionTitle('التقارير اليومية', bold),
              pw.SizedBox(height: 6),
              if (dailyRows.isEmpty)
                pw.Text('لا توجد بيانات يومية.', textAlign: pw.TextAlign.right)
              else
                _buildRtlTable(
                  headers: const [
                    'التاريخ',
                    'العمليات',
                    'المكتملة',
                    'المعلقة',
                    'الإجمالي',
                    'عمولة الشركة',
                    'ربح الوكيل',
                  ],
                  rows: dailyRows
                      .map(
                        (r) => [
                          r.date,
                          '${r.transfersCount}',
                          '${r.completedCount}',
                          '${r.pendingCount}',
                          r.totalAmount.toStringAsFixed(2),
                          r.totalCommission.toStringAsFixed(2),
                          r.totalAgentProfit.toStringAsFixed(2),
                        ],
                      )
                      .toList(),
                  bold: bold,
                  headerColor: const PdfColor.fromInt(0xFFE6EFEA),
                ),
              pw.SizedBox(height: 14),
              _sectionTitle('سجل التحويلات', bold),
              pw.SizedBox(height: 6),
              if (transfers.isEmpty)
                pw.Text('لا توجد سجلات.', textAlign: pw.TextAlign.right)
              else
                _buildRtlTable(
                  headers: const [
                    'التاريخ',
                    'النوع',
                    'من',
                    'إلى',
                    'المبلغ',
                    'العمولة',
                    'ربح الوكيل',
                    'الحالة',
                  ],
                  rows: transfers
                      .map(
                        (t) => [
                          _safeDateText(t.createdAt),
                          transferTypeLabelAr(t.operationType),
                          t.fromLabel,
                          t.toLabel,
                          t.amountValue.toStringAsFixed(2),
                          t.commissionValue.toStringAsFixed(2),
                          t.agentProfitValue.toStringAsFixed(2),
                          transferStateLabelAr(t.state),
                        ],
                      )
                      .toList(),
                  bold: bold,
                  headerColor: const PdfColor.fromInt(0xFFEAF0FA),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

Future<void> printUserReportPdf({
  required UserTransferReportModel report,
}) async {
  final regular = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document();

  String fmtDate(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '-' : text;
  }

  String safeDate(String raw) {
    if (raw.length >= 10) return raw.substring(0, 10);
    return raw;
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        margin: const pw.EdgeInsets.all(20),
      ),
      build: (_) => [
        pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EEF7F4'),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'تقرير المستخدم',
                      style: pw.TextStyle(font: bold, fontSize: 17),
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      '${report.user.fullName} (@${report.user.username})',
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.Text(
                      '${roleLabelAr(report.user.role)} - ${report.user.city} / ${report.user.country}',
                      textAlign: pw.TextAlign.right,
                    ),
                    pw.Text(
                      'الفترة: ${fmtDate(report.summary.fromDate)} إلى ${fmtDate(report.summary.toDate)}',
                      style: const pw.TextStyle(fontSize: 10),
                      textAlign: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              _sectionTitle('ملخص المستخدم', bold),
              pw.SizedBox(height: 6),
              _buildRtlTable(
                headers: const [
                  'عدد الصناديق',
                  'الرصيد الإجمالي',
                  'العمليات',
                  'المكتملة',
                  'المعلقة',
                  'المرفوضة',
                  'إجمالي المبالغ',
                  'عمولة الشبكة',
                  'ربح الوكيل',
                ],
                rows: [
                  [
                    '${report.summary.cashboxesCount}',
                    report.summary.totalBalance.toStringAsFixed(2),
                    '${report.summary.transfersCount}',
                    '${report.summary.completedCount}',
                    '${report.summary.pendingCount}',
                    '${report.summary.rejectedCount}',
                    report.summary.totalAmount.toStringAsFixed(2),
                    report.summary.totalCommission.toStringAsFixed(2),
                    report.summary.totalAgentProfit.toStringAsFixed(2),
                  ],
                ],
                bold: bold,
                headerColor: const PdfColor.fromInt(0xFFE6EFEA),
              ),
              pw.SizedBox(height: 14),
              _sectionTitle('أرصدة الصناديق', bold),
              pw.SizedBox(height: 6),
              if (report.cashboxes.isEmpty)
                pw.Text(
                  'لا توجد صناديق مرتبطة بهذا المستخدم.',
                  textAlign: pw.TextAlign.right,
                )
              else
                _buildRtlTable(
                  headers: const [
                    'الاسم',
                    'النوع',
                    'المدينة',
                    'الدولة',
                    'الرصيد',
                    'الحالة',
                  ],
                  rows: report.cashboxes
                      .map(
                        (c) => [
                          c.name,
                          cashboxTypeLabelAr(c.type),
                          c.city,
                          c.country,
                          c.balanceValue.toStringAsFixed(2),
                          c.isActive ? 'فعال' : 'غير فعال',
                        ],
                      )
                      .toList(),
                  bold: bold,
                  headerColor: const PdfColor.fromInt(0xFFEAF0FA),
                ),
              pw.SizedBox(height: 14),
              _sectionTitle('التقارير اليومية', bold),
              pw.SizedBox(height: 6),
              if (report.dailyRows.isEmpty)
                pw.Text('لا توجد بيانات يومية.', textAlign: pw.TextAlign.right)
              else
                _buildRtlTable(
                  headers: const [
                    'التاريخ',
                    'العمليات',
                    'المكتملة',
                    'المعلقة',
                    'الإجمالي',
                    'العمولة',
                    'ربح الوكيل',
                  ],
                  rows: report.dailyRows
                      .map(
                        (row) => [
                          row.date,
                          '${row.transfersCount}',
                          '${row.completedCount}',
                          '${row.pendingCount}',
                          row.totalAmount.toStringAsFixed(2),
                          row.totalCommission.toStringAsFixed(2),
                          row.totalAgentProfit.toStringAsFixed(2),
                        ],
                      )
                      .toList(),
                  bold: bold,
                  headerColor: const PdfColor.fromInt(0xFFE6EFEA),
                ),
              pw.SizedBox(height: 14),
              _sectionTitle('سجل المستخدم', bold),
              pw.SizedBox(height: 6),
              if (report.transfers.isEmpty)
                pw.Text('لا توجد سجلات تحويل.', textAlign: pw.TextAlign.right)
              else
                _buildRtlTable(
                  headers: const [
                    'التاريخ',
                    'النوع',
                    'من',
                    'إلى',
                    'المبلغ',
                    'العمولة',
                    'ربح الوكيل',
                    'الحالة',
                  ],
                  rows: report.transfers
                      .map(
                        (t) => [
                          safeDate(t.createdAt),
                          transferTypeLabelAr(t.operationType),
                          t.fromLabel,
                          t.toLabel,
                          t.amountValue.toStringAsFixed(2),
                          t.commissionValue.toStringAsFixed(2),
                          t.agentProfitValue.toStringAsFixed(2),
                          transferStateLabelAr(t.state),
                        ],
                      )
                      .toList(),
                  bold: bold,
                  headerColor: const PdfColor.fromInt(0xFFEAF0FA),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (_) async => doc.save());
}

pw.Widget _sectionTitle(String text, pw.Font bold) {
  return pw.Text(
    text,
    style: pw.TextStyle(font: bold, fontSize: 13),
    textAlign: pw.TextAlign.right,
  );
}

pw.Widget _buildRtlTable({
  required List<String> headers,
  required List<List<String>> rows,
  required pw.Font bold,
  required PdfColor headerColor,
}) {
  final tableRows = <pw.TableRow>[
    pw.TableRow(
      decoration: pw.BoxDecoration(color: headerColor),
      children: headers
          .map((cell) => _tableCell(cell, bold: bold, isHeader: true))
          .toList(),
    ),
    ...rows.map(
      (row) =>
          pw.TableRow(children: row.map((cell) => _tableCell(cell)).toList()),
    ),
  ];

  return pw.Table(
    border: pw.TableBorder.all(
      color: const PdfColor.fromInt(0xFFD9DEE6),
      width: 0.6,
    ),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: tableRows,
  );
}

pw.Widget _tableCell(String value, {pw.Font? bold, bool isHeader = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      value,
      textAlign: pw.TextAlign.right,
      style: pw.TextStyle(
        font: isHeader ? bold : null,
        fontSize: isHeader ? 9 : 8.5,
      ),
    ),
  );
}

String _safeDateText(String raw) {
  if (raw.length >= 10) {
    return raw.substring(0, 10);
  }
  return raw;
}
