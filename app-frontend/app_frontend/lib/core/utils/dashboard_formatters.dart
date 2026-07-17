double parseInputNumber(String? value) {
  final raw = (value ?? '').trim().replaceAll(',', '.');
  return double.tryParse(raw) ?? 0;
}

double roundMoneyInput(double value) => double.parse(value.toStringAsFixed(2));

String formatFixed2(double value) => value.toStringAsFixed(2);

String dateText(DateTime? value) {
  if (value == null) return 'غير محدد';
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Formats a raw ISO timestamp string into a compact, readable "MM-DD · HH:MM"
/// (local time) for list rows. Falls back to the raw text if it can't parse.
String shortDateTimeText(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} · ${two(local.hour)}:${two(local.minute)}';
}
