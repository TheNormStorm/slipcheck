/// Money helpers. All amounts are integer cents.
library;

final _amount = RegExp(r'^(-)?\$?(\d{1,6})[.,](\d{2})(-)?$');

/// Thousands separators: "2,850.00" or "2.850,00".
final _grouped = RegExp(r'(?<=\d)[,.](?=\d{3}(?:[,.]\d{3})*[.,]\d{2}-?$)');

/// Parses "1.99", "1,99", "$1.99", "-1.99", "1.99-" or "$2,850.00" into
/// cents.
/// Returns null if [text] is not a two-decimal amount.
int? parseCents(String text) {
  final m = _amount.firstMatch(text.trim().replaceAll(' ', '').replaceAll(_grouped, ''));
  if (m == null) return null;
  final cents = int.parse(m.group(2)!) * 100 + int.parse(m.group(3)!);
  final negative = m.group(1) != null || m.group(4) != null;
  return negative ? -cents : cents;
}

/// Formats cents as "12.34" (or "-0.50").
String formatCents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

final _typed = RegExp(r'^(-)?\$?(\d{1,6})(?:[.,](\d{1,2}))?$');

/// Parses what a person types in a price field: "4", "4.5", "4,50", "$4.50",
/// "2,850.00".
int? parseTypedCents(String text) {
  final m = _typed.firstMatch(text.trim().replaceAll(_grouped, ''));
  if (m == null) return null;
  final cents = int.parse(m.group(2)!) * 100 +
      int.parse((m.group(3) ?? '0').padRight(2, '0'));
  return m.group(1) != null ? -cents : cents;
}
