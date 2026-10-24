import 'purchase.dart';

/// What you usually pay per unit for each product at each store: the median
/// unit price of the purchases given. Like-for-like only (same store, same
/// unit), as everywhere else in the analytics.
class UsualPrices {
  UsualPrices(Iterable<Purchase> history) {
    for (final p in history) {
      _prices.putIfAbsent((p.productId, p.unit, p.storeId), () => []).add(p.unitPrice);
    }
  }

  final _prices = <(int, String, int?), List<double>>{};

  /// Median unit price in cents, or null when never bought there before.
  double? of(int productId, String unit, int? storeId) {
    final prices = _prices[(productId, unit, storeId)];
    return prices == null ? null : median(prices);
  }

  /// How [unitPrice] compares with the usual price, or null without one.
  VsUsual? compare(int productId, String unit, int? storeId, double unitPrice) {
    final usual = of(productId, unit, storeId);
    if (usual == null || usual <= 0) return null;
    return VsUsual(unitPrice, usual);
  }
}

/// One price against the usual one.
class VsUsual {
  const VsUsual(this.unitPrice, this.usualUnitPrice);

  /// Cents per unit, unrounded.
  final double unitPrice, usualUnitPrice;

  double get fraction => unitPrice / usualUnitPrice - 1;

  /// Under 1% (or under a cent) counts as the usual price.
  bool get isUsual => fraction.abs() < .01 || (unitPrice - usualUnitPrice).abs() < 1;
  bool get isUp => !isUsual && fraction > 0;
  bool get isDown => !isUsual && fraction < 0;

  /// Whole percent, at least 1 when the price moved.
  int get percent {
    final p = (fraction.abs() * 100).round();
    return isUsual ? 0 : (p < 1 ? 1 : p);
  }
}

/// How one receipt's prices compare with what you usually paid at that
/// store before it.
class ReceiptMoves {
  const ReceiptMoves(this.up, this.down, {this.extraCents = 0, this.known = 0});

  /// How many prices went up or down.
  final int up, down;

  /// What the receipt's known items cost beyond their usual prices (negative:
  /// less), and how many items had a usual price to compare with.
  final int extraCents, known;

  static const none = ReceiptMoves(0, 0);
}

/// The usual prices before receipt [receiptId]: from the other receipts in
/// [all] dated no later than it.
UsualPrices usualBefore(List<Purchase> all, int receiptId) {
  final date = all.where((p) => p.receiptId == receiptId).firstOrNull?.date;
  return UsualPrices(mergeByProduct(
      all.where((p) => p.receiptId != receiptId && (date == null || !p.date.isAfter(date)))));
}

/// Compares receipt [receiptId]'s purchases in [all] with [usualBefore].
ReceiptMoves receiptMoves(List<Purchase> all, int receiptId) {
  final mine = mergeByProduct(all.where((p) => p.receiptId == receiptId));
  if (mine.isEmpty) return ReceiptMoves.none;
  final usual = usualBefore(all, receiptId);
  var up = 0, down = 0, known = 0;
  var extra = 0.0;
  for (final p in mine) {
    final vs = usual.compare(p.productId, p.unit, p.storeId, p.unitPrice);
    if (vs == null) continue;
    known++;
    extra += p.netCents - vs.usualUnitPrice * p.quantity;
    if (vs.isUp) up++;
    if (vs.isDown) down++;
  }
  return ReceiptMoves(up, down, extraCents: extra.round(), known: known);
}
