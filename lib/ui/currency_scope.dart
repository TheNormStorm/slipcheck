import 'package:flutter/widgets.dart';

import '../core/currency.dart';
import '../data/receipt_repository.dart';

/// The currency most of your receipts are in. Amounts in it are shown
/// plain ("362.90"); amounts in any other get their symbol ("J$5,460.00").
class CurrencyScope extends InheritedNotifier<ValueNotifier<String>> {
  const CurrencyScope({super.key, required ValueNotifier<String> main, required super.child}) : super(notifier: main);

  static String mainOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.notifier?.value ?? 'USD';
}

/// An amount for showing, with its symbol unless it is in your main
/// currency.
String money(BuildContext context, int cents, String currency) =>
    formatMoney(cents, currency, main: CurrencyScope.mainOf(context));

/// "362.90 · J$5,460.00": what [receipts] cost, one total per currency, the
/// main currency first.
String totalsByCurrency(Iterable<ReceiptSummary> receipts, BuildContext context) {
  final main = CurrencyScope.mainOf(context);
  final totals = <String, int>{};
  for (final r in receipts) {
    totals[r.currency] = (totals[r.currency] ?? 0) + r.spentCents;
  }
  final codes = totals.keys.toList()..sort((a, b) => a == main ? -1 : b == main ? 1 : a.compareTo(b));
  return [for (final c in codes) formatMoney(totals[c]!, c, main: main)].join(' · ');
}

/// The symbol to put before an amount in [currency], or '' for your main
/// currency.
String symbolFor(BuildContext context, String currency) =>
    currency == CurrencyScope.mainOf(context) ? '' : currencySymbol(currency);
