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
  const CheckLine({required this.cents, this.quantity = 1, this.unit = 'each', this.taxCode});
  final int cents;
  final double quantity;
  final String unit;

  /// The letter printed after the price ("F", "T", "H"), when read.
  final String? taxCode;
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

  final taxed = <String>{};
  for (final t in rated) {
    Set<String>? found;
    for (var mask = 1; mask < 1 << codes.length; mask++) {
      final chosen = {for (var i = 0; i < codes.length; i++) if (mask & (1 << i) != 0) codes[i]};
      final base = chosen.fold(0, (s, c) => s + byCode[c]!);
      final lines = chosen.fold(0, (s, c) => s + countByCode[c]!);
      // A cent either way, or half a cent a line when each line is rounded.
      final tolerance = lines > 2 ? (lines / 2).ceil() : 1;
      if ((base * t.ratePercent! / 100 - t.cents).abs() <= tolerance) {
        found = chosen;
        break;
      }
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
