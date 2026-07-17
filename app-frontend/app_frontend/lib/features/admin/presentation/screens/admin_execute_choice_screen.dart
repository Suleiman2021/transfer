import '../../../../core/entities/app_models.dart';
import '../../../../core/network/api_error_messages.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_notifier.dart';
import '../../../../core/widgets/app_background.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../shared/presentation/screens/qr_input_sheet.dart';
import '../../data/admin_api.dart';
import 'admin_execute_screen.dart';
import 'package:flutter/material.dart';

class AdminExecuteChoiceScreen extends StatefulWidget {
  const AdminExecuteChoiceScreen({
    super.key,
    required this.users,
    required this.cashboxes,
    required this.commissions,
    required this.token,
    required this.onSubmit,
  });

  final List<AppUser> users;
  final List<CashboxModel> cashboxes;
  final List<CommissionRuleModel> commissions;
  final String token;
  final Future<void> Function(AdminExecuteRequest request) onSubmit;

  @override
  State<AdminExecuteChoiceScreen> createState() =>
      _AdminExecuteChoiceScreenState();
}

class _AdminExecuteChoiceScreenState extends State<AdminExecuteChoiceScreen> {
  final _api = AdminApi();
  bool _scanning = false;

  Future<void> _openByName({String? initialUserId}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminExecuteScreen(
          users: widget.users,
          cashboxes: widget.cashboxes,
          commissions: widget.commissions,
          token: widget.token,
          onSubmit: widget.onSubmit,
          initialUserId: initialUserId,
        ),
      ),
    );
  }

  Future<void> _openByQr() async {
    final code = await showQrInputSheet(context);
    if (code == null || code.isEmpty || !mounted) return;

    setState(() => _scanning = true);
    try {
      final user = await _api.resolveUserCode(token: widget.token, code: code);
      if (!mounted) return;
      await _openByName(initialUserId: user.id);
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
                      'اختر طريقة تحديد المستخدم',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ChoiceCard(
                    icon: Icons.person_search_rounded,
                    title: 'حسب الاسم أو البحث',
                    subtitle:
                        'ابحث عن المستخدم من القائمة واختر التمويل أو التحصيل',
                    color: AppTheme.brandTeal,
                    onTap: _scanning ? null : () => _openByName(),
                  ),
                  const SizedBox(height: 12),
                  _ChoiceCard(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'مسح رمز QR',
                    subtitle:
                        'وجّه الكاميرا نحو رمز QR للمستخدم وسيُحدَّد تلقائياً',
                    color: Colors.indigo,
                    loading: _scanning,
                    onTap: _scanning ? null : _openByQr,
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
