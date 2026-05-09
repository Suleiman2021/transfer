import '../utils/dashboard_formatters.dart';
import 'package:flutter/material.dart';

class DateFilterBar extends StatelessWidget {
  const DateFilterBar({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onSearch,
    required this.onReset,
    this.onPrint,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final Future<void> Function() onSearch;
  final VoidCallback onReset;
  final Future<void> Function()? onPrint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickFrom,
                icon: const Icon(Icons.event_rounded),
                label: Text('من: ${dateText(fromDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickTo,
                icon: const Icon(Icons.event_note_rounded),
                label: Text('إلى: ${dateText(toDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
                label: const Text('بحث'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('تصفير'),
              ),
            ),
            if (onPrint != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
