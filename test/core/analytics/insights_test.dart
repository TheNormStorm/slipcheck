import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/analytics/insights.dart';
import 'package:slipcheck/core/analytics/price_insights.dart';
import 'package:slipcheck/core/analytics/purchase.dart';
import 'package:slipcheck/core/categories.dart';

Purchase buy(int receipt, int product, int net,
        {double qty = 1, String unit = 'each', DateTime? date, int store = 1, String storeName = 'A'}) =>
    Purchase(
      receiptId: receipt,
      date: date ?? DateTime(2026, 10, receipt),
      storeId: store,
      storeName: storeName,
      productId: product,
      productName: 'P$product',
      quantity: qty,
      unit: unit,
      netCents: net,
    );

void main() {
  final now = DateTime(2026, 10, 24);

  group('ranges', () {
    test('three months, this month, all', () {
      expect(InsightRange.threeMonths.start(now), DateTime(2026, 8));
      expect(InsightRange.thisMonth.start(now), DateTime(2026, 10));
      expect(InsightRange.all.start(now), isNull);
      expect(InsightRange.threeMonths.contains(DateTime(2026, 7, 31), now), isFalse);
      expect(InsightRange.threeMonths.contains(DateTime(2026, 8, 1), now), isTrue);
    });

    test('three months back across a new year', () {
      expect(InsightRange.threeMonths.start(DateTime(2027, 1, 5)), DateTime(2026, 11));
    });
  });

  group('indexFor', () {
    final all = [
      IndexPoint(DateTime(2026, 6), 100, 0),
      IndexPoint(DateTime(2026, 8), 102, 3),
      IndexPoint(DateTime(2026, 9), 105.06, 3),
      IndexPoint(DateTime(2026, 10), 107.1, 2),
    ];

    test('is re-based to the first month shown', () {
      final shown = indexFor(all, InsightRange.threeMonths, now);
      expect(shown.map((p) => p.month.month), [8, 9, 10]);
      expect(shown.first.value, 100);
      expect(shown.last.value, closeTo(107.1 / 102 * 100, 1e-9));
    });

    test('a single month is shown against the month before', () {
      final shown = indexFor(all, InsightRange.thisMonth, now);
      expect(shown.map((p) => p.month.month), [9, 10]);
      expect(shown.last.value, closeTo(107.1 / 105.06 * 100, 1e-9));
    });

    test('all time keeps the first month at 100', () {
      expect(indexFor(all, InsightRange.all, now).map((p) => p.value).first, 100);
    });

    test('nothing in range, nothing shown', () {
      expect(indexFor(all, InsightRange.thisMonth, DateTime(2027, 3)), isEmpty);
      expect(indexFor(const [], InsightRange.all, now), isEmpty);
    });
  });

  test('spend by category, largest first, unknown items as Other', () {
    final spend = spendByCategory(
      [buy(1, 1, 400), buy(1, 2, 999), buy(2, 1, 420), buy(2, 3, 50)],
      {1: Category.dairy, 2: Category.meat},
    );
    expect(spend, [(Category.meat, 999), (Category.dairy, 820), (Category.other, 50)]);
  });

  group('itemTrends', () {
    test('recent prices, latest against usual at the same store', () {
      final t = itemTrends([
        buy(1, 1, 400),
        buy(2, 1, 420),
        buy(3, 1, 460),
        buy(4, 1, 900, store: 2), // another store: not this store's usual
        buy(5, 1, 480),
      ])[1]!;
      expect(t.recent, [400, 420, 460, 900, 480]);
      expect(t.trips, 5);
      expect(t.change, closeTo(480 / 420 - 1, 1e-9));
      expect(t.wentUp, isTrue);
    });

    test('bought once is new; a first trip to a store has no change', () {
      final trends = itemTrends([buy(1, 1, 400), buy(1, 2, 300), buy(2, 2, 310, store: 2)]);
      expect(trends[1]!.isNew, isTrue);
      expect(trends[1]!.change, isNull);
      expect(trends[2]!.isNew, isFalse);
      expect(trends[2]!.change, isNull);
    });

    test('two lines on one receipt are one trip', () {
      final t = itemTrends([buy(1, 1, 790), buy(1, 1, 806), buy(2, 1, 763), buy(2, 1, 833)])[1]!;
      expect(t.trips, 2);
      expect(t.wentUp || t.wentDown, isFalse);
    });

    test('only the latest unit is drawn', () {
      final t = itemTrends([
        buy(1, 1, 300),
        buy(2, 1, 150, qty: 1.5, unit: 'lb'),
        buy(3, 1, 160, qty: 2, unit: 'lb'),
      ])[1]!;
      expect(t.unit, 'lb');
      expect(t.recent, [100, 80]);
    });
  });

  group('cheaperStore', () {
    StorePrices item(int id, double a, double b) =>
        StorePrices(productId: id, name: 'P$id', unit: 'each', byStore: {'Market Basket': a, 'Whole Foods': b});

    test('counts wins on shared items', () {
      final r = cheaperStore([item(1, 409, 494), item(2, 299, 349), item(3, 999, 950)])!;
      expect((r.winner, r.loser, r.wins, r.shared), ('Market Basket', 'Whole Foods', 2, 3));
    });

    test('a draw, or nothing shared, says nothing', () {
      expect(cheaperStore([item(1, 400, 500), item(2, 500, 400)]), isNull);
      expect(cheaperStore(const []), isNull);
    });
  });
}
