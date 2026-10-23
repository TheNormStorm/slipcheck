import '../money.dart';
import 'date_parser.dart';

/// A purchased line as read from the receipt, before product matching.
class ParsedLine {
  ParsedLine({
    required this.rawText,
    required this.lineTotalCents,
    this.quantity = 1,
    this.unit = 'each',
    this.unitPriceCents,
    this.discountCents = 0,
  });

  String rawText;
  double quantity;

  /// 'each' or 'kg'.
  String unit;
  int? unitPriceCents;
  int lineTotalCents;

  /// Positive number of cents taken off this line by a following discount row.
  int discountCents;

  int get netCents => lineTotalCents - discountCents;
}

class ParsedReceipt {
  ParsedReceipt({
    this.storeName,
    this.date,
    List<ParsedLine>? items,
    this.subtotalCents,
    this.taxCents,
    this.totalCents,
    List<String>? warnings,
  })  : items = items ?? [],
        warnings = warnings ?? [];

  String? storeName;
  DateTime? date;
  final List<ParsedLine> items;
  int? subtotalCents;
  int? taxCents;
  int? totalCents;
  final List<String> warnings;

  int get itemsSumCents => items.fold(0, (sum, i) => sum + i.netCents);
}

/// Turns receipt text rows into a [ParsedReceipt].
///
/// Rows are expected one visual line each (see `groupIntoRows`). The parser is
/// rule based and deliberately forgiving: anything it cannot classify is
/// ignored, and the review screen is where the user fixes the rest.
class ReceiptParser {
  const ReceiptParser({this.dayFirst = true});

  /// How to read ambiguous dates such as 03/04/2026.
  final bool dayFirst;

  // Amount at the end of a row, optionally followed by a tax code ("H", "*", "E").
  static final _trailingAmount = RegExp(
      r'^(.*?)\s*(-?\$?\d{1,6}[.,]\d{2}-?)\s*(?:[A-Z*]{1,2})?\s*$');
  // "2 @ 1.99", "2 x $1.99", "3 for 5.00" is not handled (multi-buy) on purpose.
  static final _countQty = RegExp(
      r'(?:^|\s)(\d{1,3})\s*(?:@|x|X|×)\s*\$?(\d{1,5}[.,]\d{2})(?:\s*(?:ea|each))?',
      caseSensitive: false);
  // "0.512 kg @ $3.99/kg", "1.234kg @ 1.52 /kg"
  static final _weightQty = RegExp(
      r'(\d{1,3}[.,]\d{1,3})\s*kg\s*(?:@|x|×)\s*\$?(\d{1,5}[.,]\d{2})\s*/\s*kg',
      caseSensitive: false);
  static final _letters = RegExp(r'[A-Za-z]{2,}');

  static final _total = RegExp(
      r'^\s*(total|balance\s*due|amount\s*due|grand\s*total|to\s*pay)\b',
      caseSensitive: false);
  static final _subtotal =
      RegExp(r'^\s*sub[\s-]*total\b', caseSensitive: false);
  static final _tax = RegExp(r'\b(tax|gst|hst|pst|qst|vat)\b',
      caseSensitive: false);
  static final _discount = RegExp(
      r'\b(discount|savings?|coupon|promo|instant\s*saving|multi\s*buy|price\s*reduction)\b',
      caseSensitive: false);
  static final _nonItem = RegExp(
      r'\b(change|cash|visa|mastercard|amex|debit|credit|tend(?:er|ered)?|paid|'
      r'card|auth|approved|items?\s*sold|points|balance|rounding|deposit\s*refund|'
      r'loyalty|member)\b',
      caseSensitive: false);
  static final _phoneOrAddress = RegExp(
      r'(\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4})|(\b\d+\s+\w+\s+(st|street|rd|road|ave|avenue|blvd|dr|drive|way)\b)',
      caseSensitive: false);

  ParsedReceipt parse(List<String> rows) {
    final receipt = ParsedReceipt();
    final cleaned = [
      for (final r in rows)
        if (r.trim().isNotEmpty) r.replaceAll(RegExp(r'\s+'), ' ').trim(),
    ];

    receipt.date = findDate(cleaned, dayFirst: dayFirst);
    receipt.storeName = _findStore(cleaned);

    String? pendingName;
    _Qty? pendingQty;
    var seenTotal = false;

    for (final row in cleaned) {
      if (seenTotal) break; // payment section follows the total.

      // Read and remove "2 @ 1.99" first, so its unit price is not mistaken
      // for the row's line total.
      final qty = _readQty(row);
      final rest = qty == null ? row : _stripQty(row);
      final amountMatch = _trailingAmount.firstMatch(rest);
      final amount =
          amountMatch == null ? null : parseCents(amountMatch.group(2)!);
      final desc = amountMatch?.group(1)?.trim() ?? rest;

      if (amount != null && _subtotal.hasMatch(desc)) {
        receipt.subtotalCents = amount;
        pendingName = null;
        continue;
      }
      if (amount != null && _total.hasMatch(desc)) {
        receipt.totalCents = amount;
        seenTotal = true;
        continue;
      }
      if (amount != null && _tax.hasMatch(desc) && !_hasItemWords(desc)) {
        receipt.taxCents = (receipt.taxCents ?? 0) + amount;
        continue;
      }
      if (amount != null &&
          (amount < 0 || _discount.hasMatch(desc)) &&
          receipt.items.isNotEmpty) {
        receipt.items.last.discountCents += amount.abs();
        continue;
      }
      if (_nonItem.hasMatch(desc)) {
        pendingName = null;
        continue;
      }

      final rowHasName = _letters.hasMatch(desc);

      if (amount == null) {
        if (qty != null) {
          // Quantity on its own row. It describes the item above when that
          // item's total matches ("COKE 3.98" / "2 @ 1.99"), otherwise the
          // next priced row ("2 @ 1.99" / "COKE 3.98").
          final last = receipt.items.isEmpty ? null : receipt.items.last;
          if (pendingName == null &&
              last != null &&
              last.unitPriceCents == null &&
              (qty.amount * qty.unitPriceCents).round() == last.lineTotalCents) {
            _applyQty(last, qty);
          } else {
            pendingQty = qty;
          }
        } else if (rowHasName) {
          pendingName = desc;
        }
        continue;
      }

      final name = rowHasName ? desc : pendingName;
      if (name == null) {
        // A priced row with no name: a quantity line under the previous item,
        // e.g. "ORANGES" / "3 @ 0.79  2.37" is handled by pendingName; this is
        // the variant where the price repeats under an already priced item.
        if (qty != null &&
            receipt.items.isNotEmpty &&
            receipt.items.last.lineTotalCents == amount) {
          _applyQty(receipt.items.last, qty);
        }
        continue;
      }

      final line = ParsedLine(rawText: name, lineTotalCents: amount);
      final appliedQty = qty ?? pendingQty;
      if (appliedQty != null) _applyQty(line, appliedQty);
      receipt.items.add(line);
      pendingName = null;
      pendingQty = null;
    }

    _validate(receipt);
    return receipt;
  }

  bool _hasItemWords(String desc) =>
      // "TAXI CAB TOY" vs "HST 13%": tax rows are short.
      desc.split(' ').where((w) => _letters.hasMatch(w)).length > 3;

  _Qty? _readQty(String row) {
    final w = _weightQty.firstMatch(row);
    if (w != null) {
      return _Qty(_num(w.group(1)!), 'kg', parseCents(w.group(2)!)!);
    }
    final c = _countQty.firstMatch(row);
    if (c != null) {
      return _Qty(double.parse(c.group(1)!), 'each', parseCents(c.group(2)!)!);
    }
    return null;
  }

  String _stripQty(String desc) => desc
      .replaceAll(_weightQty, ' ')
      .replaceAll(_countQty, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _applyQty(ParsedLine line, _Qty qty) {
    line
      ..quantity = qty.amount
      ..unit = qty.unit
      ..unitPriceCents = qty.unitPriceCents;
  }

  String? _findStore(List<String> rows) {
    // First row near the top that reads like a name rather than an address,
    // phone number, date or amount.
    for (final row in rows.take(6)) {
      if (!_letters.hasMatch(row)) continue;
      if (_phoneOrAddress.hasMatch(row)) continue;
      if (_trailingAmount.hasMatch(row)) continue;
      if (findDate([row], dayFirst: dayFirst) != null) continue;
      final digits = row.replaceAll(RegExp(r'\D'), '').length;
      if (digits > row.length / 3) continue;
      return row;
    }
    return null;
  }

  void _validate(ParsedReceipt r) {
    if (r.items.isEmpty) r.warnings.add('No items found.');
    if (r.totalCents == null) r.warnings.add('No total found.');
    final expected = r.subtotalCents ??
        (r.totalCents == null ? null : r.totalCents! - (r.taxCents ?? 0));
    if (expected != null && r.items.isNotEmpty) {
      final diff = r.itemsSumCents - expected;
      if (diff != 0) {
        r.warnings.add('Items add up to ${formatCents(r.itemsSumCents)} '
            'but the receipt says ${formatCents(expected)} '
            '(${diff > 0 ? '+' : ''}${formatCents(diff)}).');
      }
    }
  }

  static double _num(String s) => double.parse(s.replaceAll(',', '.'));
}

class _Qty {
  _Qty(this.amount, this.unit, this.unitPriceCents);
  final double amount;
  final String unit;
  final int unitPriceCents;
}
