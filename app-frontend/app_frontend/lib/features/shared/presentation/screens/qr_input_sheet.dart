import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/input_utils.dart';
import 'qr_code_scan_screen.dart';
import 'package:flutter/material.dart';

/// Shows a bottom sheet letting the user choose how to provide a QR/user code:
/// - Paste / type the code manually
/// - Open the camera or pick an image (delegates to [QrCodeScanScreen])
///
/// Returns the resolved code string, or null if cancelled.
Future<String?> showQrInputSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _QrInputSheet(),
  );
}

class _QrInputSheet extends StatefulWidget {
  const _QrInputSheet();

  @override
  State<_QrInputSheet> createState() => _QrInputSheetState();
}

class _QrInputSheetState extends State<_QrInputSheet> {
  final _controller = TextEditingController();
  bool _showPaste = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  Future<void> _openScanner() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrCodeScanScreen()),
    );
    if (code != null && code.isNotEmpty && mounted) {
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'طريقة إدخال رمز QR',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ── Camera / file scanner ──
            _MethodTile(
              icon: Icons.qr_code_scanner_rounded,
              title: 'مسح بالكاميرا أو الملفات',
              subtitle: 'وجّه الكاميرا نحو الرمز أو اختر صورة من الاستوديو',
              color: Colors.indigo,
              onTap: _openScanner,
            ),
            const SizedBox(height: 10),

            // ── Paste / type ──
            _MethodTile(
              icon: Icons.content_paste_rounded,
              title: 'لصق الكود أو إدخاله يدوياً',
              subtitle: 'الصق كود المستخدم أو اكتبه مباشرةً',
              color: AppTheme.brandTeal,
              onTap: () => setState(() => _showPaste = !_showPaste),
            ),

            if (_showPaste) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      onTap: tapToMoveCursor(_controller),
                      decoration: const InputDecoration(
                        labelText: 'الكود أو معرف المستخدم',
                        prefixIcon: Icon(Icons.key_rounded),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _submit,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: color.withValues(alpha: 0.22), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
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
