import '../entities/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Approval code entry dialog — uses StatefulWidget so the TextEditingController
// has a proper lifecycle tied to the widget tree instead of .whenComplete().
// ---------------------------------------------------------------------------

Future<void> showTransferApprovalCodeDialog(
  BuildContext context,
  TransferModel transfer,
) async {
  final code = transfer.approvalCode?.trim();
  if (code == null || code.isEmpty) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('رمز اعتماد الحوالة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('أرسل هذا الرمز للطرف المستلم ليتم إدخاله عند الاعتماد.'),
          const SizedBox(height: 14),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (context.mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('نسخ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    ),
  );
}

Future<String?> promptTransferApprovalCode(
  BuildContext context,
  TransferModel transfer,
) {
  return showDialog<String>(
    context: context,
    builder: (context) => const _ApprovalCodeDialog(),
  );
}

class _ApprovalCodeDialog extends StatefulWidget {
  const _ApprovalCodeDialog();

  @override
  State<_ApprovalCodeDialog> createState() => _ApprovalCodeDialogState();
}

class _ApprovalCodeDialogState extends State<_ApprovalCodeDialog> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _hasText = _controller.text.trim().isNotEmpty),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isNotEmpty) Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('إدخال رمز الاعتماد'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: 'رمز الاعتماد',
          helperText: 'اكتب الرمز الذي وصل للطرف المستلم.',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _hasText ? _submit : null,
          child: const Text('اعتماد'),
        ),
      ],
    );
  }
}
