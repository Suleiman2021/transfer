import '../utils/currency_utils.dart';
import '../utils/input_utils.dart';
import '../validation/app_validators.dart';
import 'package:flutter/material.dart';

/// A combined widget: currency dropdown (SYP/USD/EUR/USDT) + amount text field.
/// Each currency is independent — there is no conversion between currencies.
class CurrencyAmountField extends StatelessWidget {
  const CurrencyAmountField({
    super.key,
    required this.amountController,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
    this.enabled = true,
    this.labelText = 'المبلغ',
  });

  final TextEditingController amountController;
  final String selectedCurrency;
  final ValueChanged<String> onCurrencyChanged;
  final bool enabled;
  final String labelText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currency dropdown
            SizedBox(
              width: 110,
              child: DropdownButtonFormField<String>(
                initialValue: selectedCurrency,
                decoration: const InputDecoration(labelText: 'العملة'),
                items: kSupportedCurrencies
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          currencySymbol(c),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (v) {
                        if (v != null) onCurrencyChanged(v);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            // Amount field
            Expanded(
              child: TextFormField(
                controller: amountController,
                enabled: enabled,
                onTap: tapToMoveCursor(amountController),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: labelText,
                  suffixText: currencySymbol(selectedCurrency),
                ),
                validator: AppValidators.amount,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
