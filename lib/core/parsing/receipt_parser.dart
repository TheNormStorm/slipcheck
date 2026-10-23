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

  /// 'each', 'kg' or 'lb'.
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
  const ReceiptParser({this.dayFirst = false});

  /// How to read ambiguous dates such as 03/04/2026.
  final bool dayFirst;

  // Amount at the end of a row, optionally followed by a tax code ("H", "*",
  // "E") and a stray mark or two from the paper ("4.63 F  8").
  static final _trailingAmount = RegExp(
      r'^(.*?)\s*(-?\$?\d{1,6}[.,]\d{2}-?)\s*(?:[A-Z*]{1,2})?(?:\s+\S{1,2})?\s*$');
  // "6 @ 2/6.00": six bought at a 2-for-6.00 price.
  static final _multiBuyQty = RegExp(
      r'(?:^|\s)(\d{1,3})\s*@\s*(\d{1,2})\s*/\s*\$?(\d{1,5}[.,]\d{2})');
  // "2 @ 1.99", "2 x $1.99"
  static final _countQty = RegExp(
      r'(?:^|\s)(\d{1,3})\s*(?:@|x|X|×)\s*\$?(\d{1,5}[.,]\d{2})(?:\s*(?:ea|each))?',
      caseSensitive: false);
  // "0.512 kg @ $3.99/kg", "1.234kg @ 1.52 /kg"
  static final _weightQty = RegExp(
      r'(\d{1,3}[.,]\d{1,3})\s*kg\s*(?:@|x|×)\s*\$?(\d{1,5}[.,]\d{2})\s*/\s*kg',
      caseSensitive: false);
  // "2.170 lb @ $0.69/lb"
  static final _poundQty = RegExp(
      r'(\d{1,3}[.,]\d{1,3})\s*lbs?\s*(?:@|x|×)\s*\$?(\d{1,5}[.,]\d{2})\s*/\s*lb',
      caseSensitive: false);

  // The same lines as faded thermal print reads: "@" lost or read as 0, 9 or
  // ©, "lb" read as "1b", "]b" or "lt". Too loose to trust alone, so they are
  // only used when the price they imply matches a price on the receipt.
  static final _looseWeight = RegExp(
      r'^(\d{1,3}[.,]\d{3})\s*(kg|lbs?|[1il|\]!J]{1,2}[bt])\s*\S?\s*\$?(\d{1,4}[.,]\d{2})',
      caseSensitive: false);
  static final _looseCount =
      RegExp(r'^(\d{1,2})\s*(?:[@09©®eaQ]|\s)\s*\$?(\d{1,4}[.,]\d{2})$');

  static final _letters = RegExp(r'[A-Za-z]{2,}');
  // A product code at the start of a name, allowing for a misread character
  // or two ("20938700901K6").
  static final _codePrefix = RegExp(r'^\d{4,}\w{0,3}\s');

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
        if (r.trim().isNotEmpty)
          r
              // A count printed in its own column before the name: "1  BOTTLE DEPOSIT".
              .replaceFirst(RegExp(r'^\s*\d{1,3}\s{2,}(?=[A-Za-z])'), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              // OCR sometimes splits an amount: "0. 79", "1 .99".
              .replaceAllMapped(RegExp(r'(\d) ?([.,]) ?(\d{2})\b'),
                  (m) => '${m[1]}${m[2]}${m[3]}')
              // ...or reads a 0 as O inside it: "$O.99".
              .replaceAllMapped(RegExp(r'(?<=[\s$])O(?=[.,]\d{2})'), (m) => '0')
              // ...or loses its point before a tax code: "16 78 F".
              .replaceAllMapped(RegExp(r'(\d{1,3}) (\d{2}) ([A-Z])$'),
                  (m) => '${m[1]}.${m[2]} ${m[3]}')
              .trim(),
    ];

    receipt.date = findDate(cleaned, dayFirst: dayFirst);
    receipt.storeName = _findStore(cleaned);

    // Name-only rows since the last item: section headings, names whose
    // price was not read, or the second line of a wrapped name.
    final pendingNames = <String>[];
    _Qty? pendingQty;
    var seenTotal = false;

    ParsedLine? lastUnquantified() {
      if (receipt.items.isEmpty) return null;
      final last = receipt.items.last;
      return last.unitPriceCents == null ? last : null;
    }

    /// Applies [qty] to the item above if their prices agree; any name rows
    /// in between were that item's name wrapping onto more lines.
    bool attachToLast(_Qty qty) {
      final last = lastUnquantified();
      if (last == null || !qty.fits(last.lineTotalCents)) return false;
      _applyQty(last, qty);
      if (pendingNames.isNotEmpty) {
        last.rawText = [last.rawText, ...pendingNames.map(_cleanUnpricedName)].join(' ');
        pendingNames.clear();
      }
      return true;
    }

    for (final row in cleaned) {
      if (seenTotal) break; // payment section follows the total.

      // Read and remove "2 @ 1.99" first, so its unit price is not mistaken
      // for the row's line total.
      var qty = _readQty(row);
      final rest = qty == null ? row : _stripQty(row);
      final amountMatch = _trailingAmount.firstMatch(rest);
      final amount =
          amountMatch == null ? null : parseCents(amountMatch.group(2)!);
      var desc = amountMatch?.group(1)?.trim() ?? rest;

      if (qty == null) {
        final loose = _readLooseQty(row);
        if (loose != null) {
          if (amount != null && loose.fits(amount) && loose.unit != 'each') {
            // A weight line that carries the item's price, under its name.
            qty = loose;
            desc = '';
          } else if (attachToLast(loose)) {
            continue;
          } else if (_createFromPending(receipt, pendingNames, loose)) {
            // "1 @ 2.99" read as "102.99" under a name whose price was lost.
            pendingQty = null;
            continue;
          } else if (amount == null && loose.unit != 'each') {
            pendingQty = loose;
            continue;
          }
        }
      }

      if (amount != null && _subtotal.hasMatch(desc)) {
        receipt.subtotalCents = amount;
        pendingNames.clear();
        continue;
      }
      if (amount != null && _total.hasMatch(desc)) {
        receipt.totalCents = amount;
        seenTotal = true;
        continue;
      }
      if (amount != null &&
          _tax.hasMatch(desc) &&
          (desc.contains('%') || !_hasItemWords(desc))) {
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
        pendingNames.clear();
        continue;
      }

      final rowHasName = _letters.hasMatch(desc);

      if (amount == null) {
        if (qty != null) {
          // Quantity on its own row. It describes the item above when that
          // item's total matches ("COKE 3.98" / "2 @ 1.99"), otherwise the
          // next priced row ("2 @ 1.99" / "COKE 3.98").
          if (!attachToLast(qty) && !_createFromPending(receipt, pendingNames, qty)) {
            pendingQty = qty;
          }
        } else if (rowHasName) {
          pendingNames.add(desc);
        }
        continue;
      }

      String? name = rowHasName ? desc : pendingNames.map(_cleanUnpricedName).lastOrNull;
      // A produce line printed as just its PLU code and price: "4065  4.14 F".
      if (name == null && RegExp(r'^\d{4,5}$').hasMatch(desc)) name = 'Item $desc';
      if (name == null) {
        // A priced row with no name: a quantity line under the previous item,
        // e.g. "ORANGES" / "3 @ 0.79  2.37" is handled by pendingNames; this is
        // the variant where the price repeats under an already priced item.
        if (qty != null &&
            receipt.items.isNotEmpty &&
            receipt.items.last.lineTotalCents == amount) {
          _applyQty(receipt.items.last, qty);
        }
        continue;
      }

      final line = ParsedLine(rawText: _cleanName(name), lineTotalCents: amount);
      final appliedQty = qty ?? pendingQty;
      if (appliedQty != null && appliedQty.fits(amount)) _applyQty(line, appliedQty);
      receipt.items.add(line);
      pendingNames.clear();
      pendingQty = null;
    }

    _validate(receipt);
    return receipt;
  }

  /// Makes an item from name rows whose price was not read, pricing it from
  /// its quantity line. Only for names that start with a product code (so a
  /// section heading is never turned into an item) or for weighed items.
  bool _createFromPending(ParsedReceipt receipt, List<String> pending, _Qty qty) {
    final codeAt = pending.lastIndexWhere((n) => _codePrefix.hasMatch(n));
    final from = codeAt >= 0 ? codeAt : (qty.unit != 'each' ? pending.length - 1 : -1);
    if (from < 0 || pending.isEmpty) return false;
    final line = ParsedLine(
      rawText: pending.sublist(from).map(_cleanUnpricedName).join(' '),
      lineTotalCents: qty.expectedCents,
    );
    _applyQty(line, qty);
    receipt.items.add(line);
    pending.clear();
    return true;
  }

  _Qty? _readLooseQty(String row) {
    final w = _looseWeight.firstMatch(row);
    if (w != null) {
      final unit = w.group(2)!.toLowerCase() == 'kg' ? 'kg' : 'lb';
      return _Qty(_num(w.group(1)!), unit, parseCents(w.group(3)!)!.toDouble());
    }
    final c = _looseCount.firstMatch(row);
    if (c != null) {
      return _Qty(double.parse(c.group(1)!), 'each', parseCents(c.group(2)!)!.toDouble());
    }
    return null;
  }

  bool _hasItemWords(String desc) =>
      // "TAXI CAB TOY" vs "HST 13%": tax rows are short.
      desc.split(' ').where((w) => _letters.hasMatch(w)).length > 3;

  _Qty? _readQty(String row) {
    final w = _weightQty.firstMatch(row);
    if (w != null) {
      return _Qty(_num(w.group(1)!), 'kg', parseCents(w.group(2)!)!.toDouble());
    }
    final lb = _poundQty.firstMatch(row);
    if (lb != null) {
      return _Qty(_num(lb.group(1)!), 'lb', parseCents(lb.group(2)!)!.toDouble());
    }
    final mb = _multiBuyQty.firstMatch(row);
    if (mb != null) {
      final dealPrice = parseCents(mb.group(3)!)!;
      return _Qty(double.parse(mb.group(1)!), 'each', dealPrice / int.parse(mb.group(2)!));
    }
    final c = _countQty.firstMatch(row);
    if (c != null) {
      return _Qty(double.parse(c.group(1)!), 'each', parseCents(c.group(2)!)!.toDouble());
    }
    return null;
  }

  String _stripQty(String desc) => desc
      .replaceAll(_weightQty, ' ')
      .replaceAll(_poundQty, ' ')
      .replaceAll(_multiBuyQty, ' ')
      .replaceAll(_countQty, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Drops leading UPC/PLU codes and an unreadable price left at the end
  /// (").49 F"), and undoes OCR reading O as 0 inside words.
  static String _cleanName(String name) => name
      .replaceFirst(RegExp(r'^(\d{4,}\w{0,3}\s+)+'), '')
      .replaceFirst(RegExp(r'\s+\S{0,2}[.,:]\d{1,2}\S?(\s+[A-Z])?$'), '')
      .replaceFirst(RegExp(r'[.,]+$'), '')
      .replaceAllMapped(RegExp(r'\b0(?=[A-Za-z]{2})|(?<=[A-Za-z])0(?=[A-Za-z])'),
          (m) => 'O')
      .trim();

  /// For a name row whose price could not be read: also drops what is left
  /// of that price ("6.)", "1.4:", "2.1C"), but not a size such as "1.5L".
  static String _cleanUnpricedName(String name) {
    final cleaned = _cleanName(name);
    final m = RegExp(r'\s+(\S{0,3}[.,:]\S{0,3})(\s+[A-Z])?$').firstMatch(cleaned);
    if (m == null) return cleaned;
    final token = m.group(1)!;
    final isSize = RegExp(r'^\d+[.,]\d+(ml|l|g|kg|lbs?|oz)$', caseSensitive: false).hasMatch(token);
    if (isSize || !token.contains(RegExp(r'\d'))) return cleaned;
    return cleaned.substring(0, m.start);
  }

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
  _Qty(this.amount, this.unit, this.unitPriceExact);
  final double amount;
  final String unit;

  /// Unit price in cents, unrounded: a 2-for-0.99 deal is 49.5.
  final double unitPriceExact;

  int get unitPriceCents => unitPriceExact.round();
  int get expectedCents => (amount * unitPriceExact).round();

  /// Whether this quantity explains a printed line total (stores round
  /// deals and weights either way, so a cent either side is accepted).
  bool fits(int lineTotalCents) => (expectedCents - lineTotalCents).abs() <= 1;
}
