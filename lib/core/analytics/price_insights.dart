import 'dart:math' as math;

import 'purchase.dart';

/// A month's value of the personal price index (first month = 100).
class IndexPoint {
  const IndexPoint(this.month, this.value, this.comparedItems);

  /// First day of the month.
  final DateTime month;
  final double value;

  /// How many products had an earlier price to compare with. 0 means the
  /// month carried the previous value forward.
  final int comparedItems;
}

/// Personal inflation: how the prices of the things *you* buy moved.
///
/// Each month, every product bought both that month and at some earlier
/// time gets a price relative (this month's median unit price over its most
/// recent earlier unit price). The month's step is the geometric mean of
/// those relatives (a Jevons index, which one big-ticket item cannot
/// dominate), and steps are chained. Only same-unit prices are compared.
List<IndexPoint> personalPriceIndex(List<Purchase> purchases) {
  final byMonth = <DateTime, List<Purchase>>{};
  for (final p in purchases) {
    byMonth.putIfAbsent(DateTime(p.date.year, p.date.month), () => []).add(p);
  }
  final months = byMonth.keys.toList()..sort();
  final lastPrice = <(int, String), double>{};
  final points = <IndexPoint>[];
  var value = 100.0;

  for (final month in months) {
    final prices = <(int, String), List<double>>{};
    for (final p in byMonth[month]!) {
      prices.putIfAbsent((p.productId, p.unit), () => []).add(p.unitPrice);
    }
    final logs = <double>[];
    for (final e in prices.entries) {
      final previous = lastPrice[e.key];
      final now = median(e.value);
      if (previous != null && previous > 0 && now > 0) logs.add(math.log(now / previous));
    }
    if (points.isNotEmpty && logs.isNotEmpty) {
      value *= math.exp(logs.reduce((a, b) => a + b) / logs.length);
    }
    points.add(IndexPoint(month, value, logs.length));
    for (final e in prices.entries) {
      // The month's last purchase is the reference for the next month.
      final lastOfMonth = byMonth[month]!
          .where((p) => (p.productId, p.unit) == e.key)
          .reduce((a, b) => b.date.isBefore(a.date) ? a : b);
      lastPrice[e.key] = lastOfMonth.unitPrice;
    }
  }
  return points;
}

/// A product whose latest price moved against what you usually paid.
class PriceChange {
  const PriceChange({
    required this.productId,
    required this.name,
    required this.unit,
    required this.latest,
    required this.typicalUnitPrice,
  });

  final int productId;
  final String name;
  final String unit;
  final Purchase latest;

  /// Median unit price of the earlier purchases.
  final double typicalUnitPrice;

  double get changeFraction => latest.unitPrice / typicalUnitPrice - 1;
}

/// Latest price of each product compared with its own earlier purchases,
/// biggest moves first. Products bought only once are skipped.
List<PriceChange> priceChanges(List<Purchase> purchases, {double minChange = 0.01}) {
  final byProduct = <(int, String), List<Purchase>>{};
  for (final p in purchases) {
    byProduct.putIfAbsent((p.productId, p.unit), () => []).add(p);
  }
  final out = <PriceChange>[];
  for (final history in byProduct.values) {
    if (history.length < 2) continue;
    history.sort((a, b) => a.date.compareTo(b.date));
    final latest = history.last;
    final typical = median([for (final p in history.sublist(0, history.length - 1)) p.unitPrice]);
    if (typical <= 0) continue;
    final change = PriceChange(
      productId: latest.productId,
      name: latest.productName,
      unit: latest.unit,
      latest: latest,
      typicalUnitPrice: typical,
    );
    if (change.changeFraction.abs() >= minChange) out.add(change);
  }
  out.sort((a, b) => b.changeFraction.abs().compareTo(a.changeFraction.abs()));
  return out;
}

/// What one product typically costs at each store you bought it at.
class StorePrices {
  const StorePrices({
    required this.productId,
    required this.name,
    required this.unit,
    required this.byStore,
  });

  final int productId;
  final String name;
  final String unit;

  /// Store name → median unit price there.
  final Map<String, double> byStore;

  MapEntry<String, double> get cheapest =>
      byStore.entries.reduce((a, b) => b.value < a.value ? b : a);
  MapEntry<String, double> get dearest =>
      byStore.entries.reduce((a, b) => b.value > a.value ? b : a);

  /// How much more the dearest store charges than the cheapest, as a fraction.
  double get spread => dearest.value / cheapest.value - 1;
}

/// Products bought at two or more stores, widest price gap first.
List<StorePrices> storeComparison(List<Purchase> purchases) {
  final prices = <(int, String), Map<String, List<double>>>{};
  final names = <(int, String), String>{};
  for (final p in purchases) {
    if (p.storeName == null) continue;
    final key = (p.productId, p.unit);
    names[key] = p.productName;
    prices.putIfAbsent(key, () => {}).putIfAbsent(p.storeName!, () => []).add(p.unitPrice);
  }
  final out = [
    for (final e in prices.entries)
      if (e.value.length >= 2)
        StorePrices(
          productId: e.key.$1,
          name: names[e.key]!,
          unit: e.key.$2,
          byStore: {for (final s in e.value.entries) s.key: median(s.value)},
        ),
  ]..sort((a, b) => b.spread.compareTo(a.spread));
  return out;
}

/// How much pricier [store] is than [other] on the products bought at
/// both, as a geometric mean of price ratios (0.05 = 5% pricier), or null
/// when they share no products.
({double fraction, int items})? storeGap(List<StorePrices> compared, String store, String other) {
  final logs = [
    for (final c in compared)
      if (c.byStore[store] != null && c.byStore[other] != null && c.byStore[other]! > 0)
        math.log(c.byStore[store]! / c.byStore[other]!),
  ];
  if (logs.isEmpty) return null;
  return (fraction: math.exp(logs.reduce((a, b) => a + b) / logs.length) - 1, items: logs.length);
}
