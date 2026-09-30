import '../constants/app_constants.dart';

String formatCurrency(num amount, Currency currency) =>
    '${formatNumber(amount)} ${currency.label}';

/// Parses Latin, Persian, and Arabic-Indic digits as an integer.
int? parseLocalizedInt(String value) {
  final normalized = value
      .trim()
      .replaceAll(RegExp(r'[\s,٬،_]'), '')
      .replaceAllMapped(RegExp('[۰-۹٠-٩]'), (match) {
        final digit = match.group(0)!;
        final persianIndex = '۰۱۲۳۴۵۶۷۸۹'.indexOf(digit);
        if (persianIndex >= 0) return persianIndex.toString();
        return ('٠١٢٣٤٥٦٧٨٩'.indexOf(digit)).toString();
      });
  return int.tryParse(normalized);
}

/// Parses Latin, Persian, and Arabic-Indic decimal digits.
double? parseLocalizedDecimal(String value) {
  final normalized = value
      .trim()
      .replaceAllMapped(RegExp('[۰-۹٠-٩]'), (match) {
        final digit = match.group(0)!;
        final persianIndex = '۰۱۲۳۴۵۶۷۸۹'.indexOf(digit);
        if (persianIndex >= 0) return persianIndex.toString();
        return ('٠١٢٣٤٥٦٧٨٩'.indexOf(digit)).toString();
      })
      .replaceAll('٫', '.')
      .replaceAll(',', '')
      .replaceAll('٬', '');
  return double.tryParse(normalized);
}

String formatNumber(num amount) {
  final negative = amount < 0;
  final value = amount.abs().toString();
  final parts = value.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (_) => '٬',
  );
  final formatted = parts.length == 1 || double.parse(parts.last) == 0
      ? grouped
      : '$grouped٫${parts.last}';
  final localized = formatted.split('').map((character) {
    const latin = '0123456789';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final index = latin.indexOf(character);
    return index == -1 ? character : persian[index];
  }).join();
  return negative ? '−$localized' : localized;
}
