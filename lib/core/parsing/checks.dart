/// Checks a receipt can make of itself beyond "the items add up to the
/// subtotal": that the printed tax is the printed rate of the taxed lines,
/// and that the printed item count matches the quantities read. Each catches
/// mistakes the others miss (a quantity read as 1 instead of 3 leaves the
/// money right but the count wrong).
library;

/// A tax line as printed: "MA 6.25% Sales Tax 1.57" or "HST 13% 0.65".
class TaxLine {
  const TaxLine(this.cents, {this.ratePercent});
  final int cents;

  /// The rate printed on the line, when there is one.
  final double? ratePercent;
}

/// One item line, as the checks need it.
class CheckLine {
  const CheckLine(
      {required this.cents, this.quantity = 1, this.unit = 'each', this.taxCode, this.taxCodeUnknown = false});
  final int cents;
  final double quantity;
  final String unit;

  /// The letter printed after the price ("F", "T", "H"), when read.
  final String? taxCode;

  /// The line's code was lost with its price (it was rebuilt from its
  /// quantity line, or added by hand), so it may or may not be taxed.
  final bool taxCodeUnknown;
}

/// What a tax check found.
class TaxCheck {
  const TaxCheck(this.agrees, {this.taxedCodes = const {}, this.ratePercent});

  /// True when each printed rate times the lines of some tax codes gives the
  /// printed tax; false when no set of codes does; null when the receipt
  /// gives nothing to check (no rate printed, no tax codes, or no tax).
  final bool? agrees;

  /// The codes the tax was charged on ("T"), when it agrees.
  final Set<String> taxedCodes;
  final double? ratePercent;
}

/// Whether each printed tax line equals its printed rate of the lines with
/// some set of tax codes, to the cent (allowing for per-line rounding).
TaxCheck checkTax(List<CheckLine> lines, List<TaxLine> taxLines) {
  final rated = [for (final t in taxLines) if (t.ratePercent != null && t.cents != 0) t];
  if (rated.isEmpty) return const TaxCheck(null);
  final byCode = <String, int>{};
  final countByCode = <String, int>{};
  for (final l in lines) {
    final c = l.taxCode;
    if (c == null) continue;
    byCode[c] = (byCode[c] ?? 0) + l.cents;
    countByCode[c] = (countByCode[c] ?? 0) + 1;
  }
  if (byCode.isEmpty) return const TaxCheck(null);
  final codes = byCode.keys.toList()..sort();
  if (codes.length > 6) return const TaxCheck(null);
  // Lines whose code is unknown are tried both ways, when there are few.
  final unknown = [for (final l in lines) if (l.taxCode == null && l.taxCodeUnknown) l.cents];
  final extras = unknown.length > 4 ? const <int>[] : unknown;

  final taxed = <String>{};
  for (final t in rated) {
    bool fits(int base, int lines) {
      // A cent either way, or half a cent a line when each line is rounded.
      final tolerance = lines > 2 ? (lines / 2).ceil() : 1;
      return (base * t.ratePercent! / 100 - t.cents).abs() <= tolerance;
    }

    Set<String>? found;
    final sets = [
      for (var mask = 1; mask < 1 << codes.length; mask++)
        {for (var i = 0; i < codes.length; i++) if (mask & (1 << i) != 0) codes[i]},
    ];
    for (final chosen in sets) {
      if (fits(chosen.fold(0, (s, c) => s + byCode[c]!), chosen.fold(0, (s, c) => s + countByCode[c]!))) {
        found = chosen;
        break;
      }
    }
    // Then with some of the unknown lines taxed too, but only if exactly one
    // way fits: a few small lines can otherwise be made to fit any tax.
    if (found == null && extras.isNotEmpty) {
      final ways = <Set<String>>[];
      for (final chosen in sets) {
        for (var extraMask = 1; extraMask < 1 << extras.length && ways.length < 2; extraMask++) {
          var base = chosen.fold(0, (s, c) => s + byCode[c]!);
          var lines = chosen.fold(0, (s, c) => s + countByCode[c]!);
          for (var i = 0; i < extras.length; i++) {
            if (extraMask & (1 << i) == 0) continue;
            base += extras[i];
            lines++;
          }
          if (fits(base, lines)) ways.add(chosen);
        }
      }
      if (ways.length == 1) found = ways.single;
    }
    if (found == null) return TaxCheck(false, ratePercent: t.ratePercent);
    taxed.addAll(found);
  }
  return TaxCheck(true, taxedCodes: taxed, ratePercent: rated.length == 1 ? rated.single.ratePercent : null);
}

/// Items as a till counts them: each unit of a counted item, and one for
/// each weighed line.
int unitCount(List<CheckLine> lines) =>
    lines.fold(0.0, (s, l) => s + (l.unit == 'each' ? l.quantity : 1)).round();

/// Whether the quantities read match the item count printed on the receipt;
/// null when it prints none.
bool? checkCount(List<CheckLine> lines, int? printed) => printed == null ? null : unitCount(lines) == printed;
