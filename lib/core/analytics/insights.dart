import '../categories.dart';
import 'price_insights.dart';
import 'purchase.dart';

/// The time span the Insights screen looks at.
enum InsightRange {
  threeMonths('3 months'),
  thisMonth('This month'),
  all('All');

  const InsightRange(this.label);
  final String label;

  /// First day of the span, for [now]; null for all time.
  DateTime? start(DateTime now) => switch (this) {
        InsightRange.threeMonths => DateTime(now.year, now.month - 2),
        InsightRange.thisMonth => DateTime(now.year, now.month),
        InsightRange.all => null,
      };

  bool contains(DateTime date, DateTime now) {
    final from = start(now);
    return from == null || !date.isBefore(from);
  }
}

/// The price index for [range]: the months in it, plus the month before
/// when the range is a single month (a change needs two), re-based so the
/// first month shown is 100. Months are taken from the index over all
/// time, so a product's earlier price still counts.
List<IndexPoint> indexFor(List<IndexPoint> all, InsightRange range, DateTime now) {
  if (all.isEmpty) return const [];
  final from = range.start(now);
  var first = from == null ? 0 : all.indexWhere((p) => !p.month.isBefore(from));
  if (first < 0) return const [];
  if (first > 0 && all.length - first < 2) first--;
  final shown = all.sublist(first);
  final base = shown.first.value;
  return [for (final p in shown) IndexPoint(p.month, p.value / base * 100, p.comparedItems)];
}

/// What was spent on each category, largest first.
List<(Category, int)> spendByCategory(Iterable<Purchase> purchases, Map<int, Category> categories) {
  final spent = <Category, int>{};
  for (final p in purchases) {
    final c = categories[p.productId] ?? Category.other;
    spent[c] = (spent[c] ?? 0) + p.netCents;
  }
  return spent.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
}

/// One item's recent prices, for the Items list.
class ItemTrend {
  const ItemTrend({
    required this.productId,
    required this.recent,
    required this.latestUnitPrice,
    required this.unit,
    required this.trips,
    this.change,
  });

  final int productId;

  /// Unit prices of the last few trips, oldest first, in [unit].
  final List<double> recent;
  final double latestUnitPrice;
  final String unit;

  /// Trips it was bought on.
  final int trips;

  /// Latest price against the usual one at the same store; null when it
  /// was not bought there before.
  final double? change;

  bool get isNew => trips == 1;
  bool get wentUp => change != null && change! >= .01;
  bool get wentDown => change != null && change! <= -.01;
}

/// The trend of every product in [purchases] (lines of one product on one
/// receipt count as one trip), keyed by product id.
Map<int, ItemTrend> itemTrends(List<Purchase> purchases, {int recent = 6}) {
  final byProduct = <int, List<Purchase>>{};
  for (final p in mergeByProduct(purchases)) {
    byProduct.putIfAbsent(p.productId, () => []).add(p);
  }
  return {
    for (final e in byProduct.entries)
      e.key: () {
        final trips = e.value..sort((a, b) => a.date.compareTo(b.date));
        final latest = trips.last;
        final sameUnit = [for (final p in trips) if (p.unit == latest.unit) p.unitPrice];
        final before = [
          for (final p in trips.sublist(0, trips.length - 1))
            if (p.unit == latest.unit && p.storeId == latest.storeId) p.unitPrice,
        ];
        final usual = before.isEmpty ? null : median(before);
        return ItemTrend(
          productId: e.key,
          recent: sameUnit.length > recent ? sameUnit.sublist(sameUnit.length - recent) : sameUnit,
          latestUnitPrice: latest.unitPrice,
          unit: latest.unit,
          trips: trips.length,
          change: usual == null || usual <= 0 ? null : latest.unitPrice / usual - 1,
        );
      }(),
  };
}

/// "Market Basket beat Whole Foods on 4 of 4 shared items.": for the pair
/// of stores sharing the most items, how often the cheaper one was cheaper.
/// Null when no item was bought at two stores.
({String winner, String loser, int wins, int shared})? cheaperStore(List<StorePrices> compared) {
  final stores = {for (final c in compared) ...c.byStore.keys}.toList()..sort();
  ({String winner, String loser, int wins, int shared})? best;
  for (var i = 0; i < stores.length; i++) {
    for (var j = i + 1; j < stores.length; j++) {
      final a = stores[i], b = stores[j];
      var aWins = 0, bWins = 0, shared = 0;
      for (final c in compared) {
        final pa = c.byStore[a], pb = c.byStore[b];
        if (pa == null || pb == null) continue;
        shared++;
        if (pa < pb) aWins++;
        if (pb < pa) bWins++;
      }
      if (shared == 0 || aWins == bWins) continue;
      final pick = aWins > bWins
          ? (winner: a, loser: b, wins: aWins, shared: shared)
          : (winner: b, loser: a, wins: bWins, shared: shared);
      if (best == null || shared > best.shared || (shared == best.shared && pick.wins > best.wins)) {
        best = pick;
      }
    }
  }
  return best;
}
