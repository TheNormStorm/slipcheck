import '../categories.dart';
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

  /// Barcode (UPC/EAN) or produce PLU printed before the name.
  String? code;

  /// Department heading the line was printed under ("PRODUCE DEPT").
  String? section;

  int get netCents => lineTotalCents - discountCents;

  /// Other line totals this line may have been: its quantity line's
  /// ("1 @ 16.78" under a 16.73), or every last digit when it was lost
  /// ("1.4" for 1.4?). Used only to make the receipt add up.
  final alternatives = <int>[];
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

  /// Lines changed to a second reading so the receipt adds up, in words.
  final corrections = <String>[];

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
  // "2/5.00" or "2 FOR $5.00": a deal price for a number of items.
  static final _dealQty = RegExp(
      r'(?:^|\s)(\d{1,2})\s*(?:/|for)\s*\$?(\d{1,4}[.,]\d{2})(?=\s|$)',
      caseSensitive: false);
  // Quantity before the name: "2 x MILK 4.69  9.38", "3 BANANA @ 0.25  0.75",
  // "2 x MILK  9.38".
  static final _qtyFirst = RegExp(
      r'^(\d{1,3})\s*(?:[x×]\s+)?([A-Za-z][^@]*?)\s*(?:@\s*)?(?:\$?(\d{1,5}[.,]\d{2})\s+)?'
      r'\$?(\d{1,6}[.,]\d{2})\s*[A-Z*]?$',
      caseSensitive: false);
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
  // "3 @ $950.00/" (a unit price ending in a slash, as some tills print).
  static final _looseCount =
      RegExp(r'^(\d{1,2})\s*(?:[@09©®eaQ]|\s)\s*\$?(\d{1,4}[.,]\d{2})\s*/?$');

  static final _letters = RegExp(r'[A-Za-z]{2,}');
  // "SCALLIONS 1.4 F": one digit of the cents, then a tax code.
  static final _partialAmount = RegExp(r'^(.*?)\s*\$?(\d{1,4}[.,]\d)\s*([A-Z])$');
  // A tax code printed after a price: "4.99 F", "6.59 T".
  static final _taxCodeAfterPrice = RegExp(r'\d[.,]\d{2}\s*([A-Z])$');
  // Notes printed under an item that are not part of its name: "Manual
  // Weight" (and OCR's "Manual #eight").
  static final _note = RegExp(r'^\s*manual\s+\S?eight\b', caseSensitive: false);
  // A product code at the start of a name, allowing for a misread character
  // or two ("20938700901K6").
  static final _codePrefix = RegExp(r'^\d{4,}\w{0,3}\s');

  static final _total = RegExp(
      r'^\s*(total|balance\s*due|amount\s*due|grand\s*total|to\s*pay)\b',
      caseSensitive: false);
  static final _subtotal =
      RegExp(r'^\s*sub[\s-]*total\b', caseSensitive: false);
  // Also "Sales Ta" and "5ales Ta%", a cut-off or misread SALES TAX.
  static final _tax = RegExp(r'\b(tax|gst|hst|pst|qst|vat)\b|^\s*[s5]ales\s+ta\S?(?=\s|$)',
      caseSensitive: false);
  static final _discount = RegExp(
      r'\b(discount|savings?|coupon|promo|instant\s*saving|multi\s*buy|price\s*reduction)\b',
      caseSensitive: false);
  // Payment and loyalty lines. Only at the start of a row, so items such as
  // "CARD - BIRTHDAY" or "CASHEWS" are kept.
  static final _nonItem = RegExp(
      r'^\s*(cash|visa|mastercard|amex|discover|debit|credit|tend(?:er|ered)?|paid|'
      r'auth|approved|items?\s*sold|points|balance|rounding|deposit\s*refund|loyalty|'
      r'member\s*(?:#|no|number|id)|card\s*(?:#|no|number|type|name|ending))\b',
      caseSensitive: false);
  // "TOTAL SAVINGS", "YOU SAVED": summaries of discounts already on the lines.
  static final _savingsSummary = RegExp(
      r'^\s*(total\s+(savings?|discounts?|saved)|you\s+saved|your\s+savings|'
      r'savings\s+total|today.?s\s+savings)',
      caseSensitive: false);
  // A TOTAL that is not the amount paid: "TOTAL TAX", "TOTAL ITEMS".
  static final _notTotal = RegExp(
      r'\b(savings?|saved|discounts?|items?|number|count|tendered|tax|points)\b',
      caseSensitive: false);
  static final _return = RegExp(r'^\s*(return|refund|rtn|void)\b\s*', caseSensitive: false);
  static final _phoneOrAddress = RegExp(
      r'(\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4})|(\b\d+\s+\w+\s+(st|street|rd|road|ave|avenue|blvd|dr|drive|way)\b)',
      caseSensitive: false);

  ParsedReceipt parse(List<String> rows) {
    final receipt = ParsedReceipt();
    final cleaned = [
      for (final r in rows)
        if (r.trim().isNotEmpty)
          r
              // A count printed in its own column before the name: "1  BOTTLE
              // DEPOSIT" (but not the 12 of "12  PK COKE").
              .replaceFirst(
                  RegExp(r'^\s*\d{1,3}\s{2,}(?=[A-Za-z])(?!(pk|ct|pack|oz|lbs?|g|kg|ml|l|ltr|count|cnt|ea)\b)',
                      caseSensitive: false),
                  '')
              .replaceAll(RegExp(r'\s+'), ' ')
              // OCR reads a cent's 0 as D, O or o: "1,650.0D", "4.O9".
              .replaceAllMapped(RegExp(r'(\d[.,])([\dDOo])([\dDOo])(?![\w.,])'),
                  (m) => m[1]! + [m[2]!, m[3]!].map((c) => RegExp(r'\d').hasMatch(c) ? c : '0').join())
              // Thousands separators: "$2,850.00" and "1.234,56" are read whole,
              // not as 850.00 and 234,56.
              .replaceAll(RegExp(r'(?<=\d),(?=\d{3}(?:,\d{3})*\.\d{2}\b)'), '')
              .replaceAll(RegExp(r'(?<=\d)\.(?=\d{3}(?:\.\d{3})*,\d{2}\b)'), '')
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
    // Tax codes seen on at least two priced rows, so "1.5 L" is never read
    // as a price that lost a digit.
    final codeCounts = <String, int>{};
    for (final row in cleaned) {
      final c = _taxCodeAfterPrice.firstMatch(row)?.group(1);
      if (c != null) codeCounts[c] = (codeCounts[c] ?? 0) + 1;
    }
    final taxCodes = {for (final e in codeCounts.entries) if (e.value >= 2) e.key};
    receipt.storeName = _findStore(cleaned);

    // Name-only rows since the last item: section headings, names whose
    // price was not read, or the second line of a wrapped name.
    final pendingNames = <String>[];
    _Qty? pendingQty;
    String? section;
    var seenTotal = false;

    // A price that landed on a row with no name of its own: on a tilted
    // photo, the next item's price can sit on the row above ("3 @ $320.00/
    // $1,650.00"). Kept until a name and quantity line that cost exactly
    // that come along.
    int? strayAmount;

    void add(ParsedLine line, String nameAsPrinted) {
      line
        ..code ??= _codeOf(nameAsPrinted)
        ..section = section;
      receipt.items.add(line);
      strayAmount = null;
    }

    /// Prices the pending name from the stray amount when its quantity line
    /// costs exactly that ("SPARE RIBS" / "3 @ $550.00/" and a stray 1,650.00).
    bool fromStray(_Qty qty) {
      final amount = strayAmount;
      if (amount == null || pendingNames.isEmpty || !qty.fits(amount)) return false;
      final name = pendingNames.last;
      final line = ParsedLine(rawText: _cleanUnpricedName(name), lineTotalCents: amount);
      _applyQty(line, qty);
      add(line, name);
      pendingNames.clear();
      pendingQty = null;
      return true;
    }

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

    var rowsAfterTotal = 0;
    for (var row in cleaned) {
      if (seenTotal) {
        // The payment section follows the total; only a tax line printed
        // right under it is still read.
        if (++rowsAfterTotal > 3 || receipt.taxCents != null) break;
        final m = _trailingAmount.firstMatch(row);
        if (m != null && _tax.hasMatch(m.group(1)!) && !_hasItemWords(m.group(1)!)) {
          receipt.taxCents = parseCents(m.group(2)!);
        }
        continue;
      }
      if (_savingsSummary.hasMatch(row)) continue;
      // A note under an item is dropped; whatever OCR put on the same row
      // (the next item's name or price) is read as usual.
      final noted = _note.firstMatch(row);
      if (noted != null) {
        row = row.substring(noted.end).trim();
        if (row.isEmpty) continue;
      }

      final first = _qtyFirst.firstMatch(row);
      if (first != null && !_codePrefix.hasMatch(row)) {
        final count = double.parse(first.group(1)!);
        final total = parseCents(first.group(4)!)!;
        final unit = first.group(3) == null ? null : parseCents(first.group(3)!);
        final name = first.group(2)!.trim();
        final looksLikeQty = row.contains(RegExp(r'^\d{1,3}\s*[x×]\s', caseSensitive: false)) ||
            (unit != null && (count * unit - total).abs() <= 1);
        if (looksLikeQty && count > 1 && _letters.hasMatch(name)) {
          add(
            ParsedLine(rawText: _cleanName(name), lineTotalCents: total)
              ..quantity = count
              ..unitPriceCents = unit ?? (total / count).round(),
            name,
          );
          pendingNames.clear();
          pendingQty = null;
          continue;
        }
      }

      // Read and remove "2 @ 1.99" first, so its unit price is not mistaken
      // for the row's line total.
      var qty = _readQty(row);
      final rest = qty == null ? row : _stripQty(row);
      final amountMatch = _trailingAmount.firstMatch(rest);
      var amount =
          amountMatch == null ? null : parseCents(amountMatch.group(2)!);
      var desc = amountMatch?.group(1)?.trim() ?? rest;
      // A price that lost its last digit ("SCALLIONS 1.4 F"), when what
      // follows is a tax code this receipt prints after prices.
      List<int>? lostDigit;
      if (amount == null) {
        final m = _partialAmount.firstMatch(rest);
        if (m != null && taxCodes.contains(m.group(3)) && _letters.hasMatch(m.group(1)!)) {
          final tenths = parseCents('${m.group(2)}0')!;
          amount = tenths;
          desc = m.group(1)!.trim();
          lostDigit = [for (var d = 1; d <= 9; d++) tenths + d];
        }
      }

      if (qty == null) {
        final loose = _readLooseQty(row);
        if (loose != null) {
          if (amount != null && loose.fits(amount) && loose.unit != 'each') {
            // A weight line that carries the item's price, under its name.
            qty = loose;
            desc = '';
          } else if (attachToLast(loose) || (amount == null && fromStray(loose))) {
            continue;
          } else if (_fromPending(pendingNames, loose) case final made?) {
            // "1 @ 2.99" read as "102.99" under a name whose price was lost.
            add(made.$1, made.$2);
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
      if (amount != null && _total.hasMatch(desc) && !_notTotal.hasMatch(desc)) {
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
      if (amount != null && amount < 0 && _return.hasMatch(desc) &&
          _letters.hasMatch(desc.replaceFirst(_return, ''))) {
        // A returned item: a line of its own with a negative quantity, so it
        // nets out against the purchase in every comparison.
        final name = desc.replaceFirst(_return, '');
        add(
          ParsedLine(rawText: _cleanName(name), lineTotalCents: amount)
            ..quantity = -1
            ..unitPriceCents = -amount,
          name,
        );
        pendingNames.clear();
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
          if (attachToLast(qty)) continue;
          // "SPARE RIBS 3 @ $550.00/": a name on the quantity's own row.
          final named = desc.replaceAll(RegExp(r'[\s/]+$'), '');
          if (_letters.hasMatch(named) && !isDepartmentHeading(named)) pendingNames.add(named);
          if (fromStray(qty)) continue;
          if (_fromPending(pendingNames, qty) case final made?) {
            add(made.$1, made.$2);
          } else {
            pendingQty = qty;
            // A quantity line that does not fit the item above may be the
            // right reading of its price ("16.73" over "1 @ 16.78").
            final last = lastUnquantified();
            if (last != null && qty.unit == 'each' && qty.expectedCents > 0) {
              last.alternatives.add(qty.expectedCents);
            }
          }
        } else if (rowHasName && isDepartmentHeading(desc)) {
          section = desc;
          pendingNames.clear();
        } else if (rowHasName) {
          pendingNames.add(desc);
        }
        continue;
      }

      String? name = rowHasName ? desc : pendingNames.lastOrNull;
      String? code;
      // A produce line printed as just its PLU code and price: "4065  4.14 F".
      if (name == null && RegExp(r'^\d{4,5}$').hasMatch(desc)) {
        name = 'Item $desc';
        code = desc;
      }
      if (name == null) {
        // A priced row with no name: a quantity line under the previous item,
        // e.g. "ORANGES" / "3 @ 0.79  2.37" is handled by pendingNames; this is
        // the variant where the price repeats under an already priced item.
        if (qty != null &&
            receipt.items.isNotEmpty &&
            receipt.items.last.lineTotalCents == amount) {
          _applyQty(receipt.items.last, qty);
        } else if (amount > 0) {
          // The row's quantity may still be the item above's ("3 @ $320.00/"
          // under TURKEY NECK 960.00), with the next item's price beside it.
          final own = qty ?? _readLooseQty(desc);
          if (own != null) attachToLast(own);
          strayAmount = amount;
        }
        continue;
      }

      final line = ParsedLine(
          rawText: rowHasName ? _cleanName(name) : _cleanUnpricedName(name),
          lineTotalCents: amount)
        ..code = code;
      if (lostDigit != null) line.alternatives.addAll(lostDigit);
      final appliedQty = qty ?? pendingQty;
      if (appliedQty != null && appliedQty.fits(amount)) _applyQty(line, appliedQty);
      add(line, name);
      pendingNames.clear();
      pendingQty = null;
    }

    _reconcile(receipt);
    _validate(receipt);
    return receipt;
  }

  /// When the items do not add up to the receipt's own subtotal, tries the
  /// lines' second readings ([ParsedLine.alternatives]) and takes the
  /// fewest changes that make it add up exactly, if only one set does.
  void _reconcile(ParsedReceipt r) {
    final expected = r.subtotalCents ?? (r.totalCents == null ? null : r.totalCents! - (r.taxCents ?? 0));
    if (expected == null) return;
    final diff = expected - r.itemsSumCents;
    final open = [for (final i in r.items) if (i.alternatives.isNotEmpty) i];
    if (diff == 0 || open.isEmpty || open.length > 12) return;

    List<(ParsedLine, int)>? best;
    var found = 0;
    var tried = 0;
    // Every way to change exactly [want] of the open lines.
    void search(int at, int left, int want, List<(ParsedLine, int)> chosen) {
      if (++tried > 200000 || found > 1) return;
      if (chosen.length == want || at == open.length) {
        if (chosen.length == want && left == 0) {
          found++;
          best ??= [...chosen];
        }
        return;
      }
      search(at + 1, left, want, chosen);
      final line = open[at];
      for (final alt in line.alternatives.toSet()) {
        if (alt == line.lineTotalCents) continue;
        chosen.add((line, alt));
        search(at + 1, left - (alt - line.lineTotalCents), want, chosen);
        chosen.removeLast();
      }
    }

    for (var want = 1; want <= open.length && found == 0; want++) {
      search(0, diff, want, []);
    }
    // None, or more than one equally small fix: leave it for the user.
    if (found != 1) return;
    for (final (line, alt) in best!) {
      final lostDigit = line.alternatives.length == 9 && line.alternatives.first == line.lineTotalCents + 1;
      r.corrections.add(lostDigit
          ? '${line.rawText}: the last digit was unreadable; ${formatCents(alt)} makes the receipt add up.'
          : '${line.rawText}: read as ${formatCents(line.lineTotalCents)}; its quantity line says '
              '${formatCents(alt)}, which makes the receipt add up.');
      line
        ..lineTotalCents = alt
        ..unitPriceCents = line.quantity == 1 ? null : (alt / line.quantity).round();
    }
  }

  /// Makes an item from name rows whose price was not read, pricing it from
  /// its quantity line. Only for names that start with a product code (so a
  /// stray heading is never turned into an item) or for weighed items.
  /// Returns the line and its first name row as printed.
  (ParsedLine, String)? _fromPending(List<String> pending, _Qty qty) {
    final codeAt = pending.lastIndexWhere((n) => _codePrefix.hasMatch(n));
    final from = codeAt >= 0 ? codeAt : (qty.unit != 'each' ? pending.length - 1 : -1);
    if (from < 0 || pending.isEmpty) return null;
    final line = ParsedLine(
      rawText: pending.sublist(from).map(_cleanUnpricedName).join(' '),
      lineTotalCents: qty.expectedCents,
    );
    _applyQty(line, qty);
    final printed = pending[from];
    pending.clear();
    return (line, printed);
  }

  /// A barcode or PLU at the start of a name as printed, if it is all digits
  /// (a misread code such as "20938700901K6" is not worth keeping).
  static String? _codeOf(String printed) =>
      RegExp(r'^(\d{4,14})\s').firstMatch(printed.trim())?.group(1);

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
    final d = _dealQty.firstMatch(row);
    if (d != null) {
      final count = int.parse(d.group(1)!);
      if (count > 1) {
        return _Qty(count.toDouble(), 'each', parseCents(d.group(2)!)! / count);
      }
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
      .replaceAll(_dealQty, ' ')
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
    for (final raw in rows.take(6)) {
      // Logo and greeting text around the store name.
      final row = raw.replaceFirst(RegExp(r'^\s*welcome\s+to\b\s*', caseSensitive: false), '');
      if (RegExp(r'^(welcome|thank you|thanks|receipt|sales? receipt|customer copy|store\s*#?\s*\d*)\W*$',
              caseSensitive: false)
          .hasMatch(row)) {
        continue;
      }
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
