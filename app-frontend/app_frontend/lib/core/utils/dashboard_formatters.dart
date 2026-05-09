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
