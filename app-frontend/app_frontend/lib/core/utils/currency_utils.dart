const List<String> kSupportedCurrencies = ['SYP', 'USD', 'EUR', 'USDT'];

String currencyLabel(String code) {
  switch (code.toUpperCase()) {
    case 'SYP':
      return 'ليرة سورية';
    case 'USD':
      return 'دولار أمريكي';
    case 'EUR':
      return 'يورو';
    case 'USDT':
      return 'تيثر USDT';
    default:
      return code;
  }
}

String currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'SYP':
      return 'SYP';
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'USDT':
      return '₮';
    default:
      return code;
  }
}

/// Formats an amount with its currency symbol.
/// e.g. formatCurrencyAmount(100, 'USD') → "100.00 $"
String formatCurrencyAmount(double amount, String currency) {
  final formatted = amount
      .toStringAsFixed(currency == 'SYP' ? 0 : 2)
      .replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
  return '$formatted ${currencySymbol(currency)}';
}

/// Returns the amount formatted in its source currency.
String transferAmountLabel(double amount, String sourceCurrency) {
  return formatCurrencyAmount(amount, sourceCurrency);
}
