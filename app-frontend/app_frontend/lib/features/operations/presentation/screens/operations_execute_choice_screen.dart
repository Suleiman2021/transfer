import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../shared/presentation/screens/qr_input_sheet.dart';
import '../../data/operations_api.dart';
import '../operations_form_models.dart';
import '../widgets/operations_transfer_tab.dart';
import 'remittance_form_screen.dart';
import 'package:flutter/material.dart';

class OperationsExecuteChoiceScreen extends StatefulWidget {
  const OperationsExecuteChoiceScreen({
    super.key,
    required this.session,
    required this.cashboxes,
    required this.myCashboxes,
    required this.enabled,
    required this.onSubmit,
  });

  final AuthSession session;
  final List<CashboxModel> cashboxes;
  final List<CashboxModel> myCashboxes;
  final bool enabled;
  final Future<void> Function(OperationsTransferRequest request) onSubmit;

  @override
  State<OperationsExecuteChoiceScreen> createState() =>
      _OperationsExecuteChoiceScreenState();
}

class _OperationsExecuteChoiceScreenState
    extends State<OperationsExecuteChoiceScreen> {
  final _api = OperationsApi();
  bool _scanning = false;

  void _openRemittanceForm() {
    final myCashboxes = widget.myCashboxes;
    final accredited = widget.cashboxes
        .where((b) => b.isAccredited && !myCashboxes.any((m) => m.id == b.id))
        .toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RemittanceFormScreen(
          session: widget.session,
          myCashboxes: myCashboxes,
          accreditedCashboxes: accredited,
        ),
      ),
    );
  }

  void _openByName({String? initialCode}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OperationsTransferScreen(
          session: widget.session,
          cashboxes: widget.cashboxes,
          myCashboxes: widget.myCashboxes,
          enabled: widget.enabled,
          onSubmit: widget.onSubmit,
          initialCode: initialCode,
        ),
      ),
    );
  }

  Future<void> _openByQr() async {
    final code = await showQrInputSheet(context);
    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _scanning = true);
    try {
      await _api.resolveUserCode(
        token: widget.session.token,
        code: code,
      );
      if (!mounted) return;
      _openByName(initialCode: code);
    } catch (error) {
      if (mounted) AppNotifier.error(context, apiErrorText(error));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنفيذ عملية')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'اختر طريقة تحديد الجهة المستهدفة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  // Agents top up accredited cashboxes; accredited users only
                  // create customer remittances.
                  if (widget.session.role == UserRole.agent) ...[
                    const SizedBox(height: 12),
                    _ChoiceCard(
                      icon: Icons.manage_search_rounded,
                      title: 'حسب الاسم أو البحث',
                      subtitle:
                          'ابحث عن المعتمد المستهدف لتعبئة رصيده',
                      color: AppTheme.brandTeal,
                      onTap: _scanning ? null : () => _openByName(),
                    ),
                    const SizedBox(height: 12),
                    _ChoiceCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'مسح رمز QR',
                      subtitle:
                          'وجّه الكاميرا نحو رمز QR للمعتمد وسيُحدَّد تلقائياً',
                      color: Colors.indigo,
                      loading: _scanning,
                      onTap: _scanning ? null : _openByQr,
                    ),
                  ],
                  if (widget.session.role == UserRole.accredited) ...[
                    const SizedBox(height: 12),
                    _ChoiceCard(
                      icon: Icons.send_rounded,
                      title: 'إنشاء حوالة عميل',
                      subtitle:
                          'أرسل حوالة نقدية لعميل عبر معتمد آخر',
                      color: Colors.teal,
                      onTap: _scanning ? null : _openRemittanceForm,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsTransferScreen extends StatelessWidget {
  const _OperationsTransferScreen({
    required this.session,
    required this.cashboxes,
    required this.myCashboxes,
    required this.enabled,
    required this.onSubmit,
    this.initialCode,
  });

  final AuthSession session;
  final List<CashboxModel> cashboxes;
  final List<CashboxModel> myCashboxes;
  final bool enabled;
  final Future<void> Function(OperationsTransferRequest request) onSubmit;
  final String? initialCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنفيذ عملية')),
      body: AppBackground(
        child: ListView(
          children: [
            ResponsivePage(
              child: OperationsTransferTab(
                session: session,
                cashboxes: cashboxes,
                myCashboxes: myCashboxes,
                enabled: enabled,
                onSubmit: onSubmit,
                initialCode: initialCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: color,
                        ),
                      )
                    : Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: onTap == null ? AppTheme.textMuted : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
