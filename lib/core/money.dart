/// Money helpers. All amounts are integer cents.
library;

final _amount = RegExp(r'^(-)?\$?(\d{1,6})[.,](\d{2})(-)?$');

/// Parses "1.99", "1,99", "$1.99", "-1.99" or "1.99-" into cents.
/// Returns null if [text] is not a two-decimal amount.
int? parseCents(String text) {
  final m = _amount.firstMatch(text.trim().replaceAll(' ', ''));
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
