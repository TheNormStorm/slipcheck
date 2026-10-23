import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/analytics/price_insights.dart';
import 'package:slipcheck/core/analytics/purchase.dart';
import 'package:slipcheck/core/analytics/receipt_diff.dart';

Purchase buy(int receipt, int product, String name, double qty, int net,
        {String unit = 'each', DateTime? date, String store = 'A'}) =>
    Purchase(
      receiptId: receipt,
      date: date ?? DateTime(2026, 10, receipt),
      storeName: store,
      productId: product,
      productName: name,
      quantity: qty,
      unit: unit,
      netCents: net,
    );

void main() {
  group('compareReceipts', () {
    final before = [
      buy(1, 1, 'MILK', 1, 469),
      buy(1, 2, 'EGGS', 2, 598),
      buy(1, 3, 'BREAD', 1, 349),
      buy(1, 4, 'BANANAS', 1.2, 182, unit: 'lb'),
    ];
    final after = [
      buy(2, 1, 'MILK', 1, 515), // price up
      buy(2, 2, 'EGGS', 3, 897), // more of them, same price
      buy(2, 4, 'BANANAS', 2.0, 300, unit: 'lb'), // both
      buy(2, 5, 'STEAK', 1, 1998), // new
    ];

    test('the parts add up to the difference exactly', () {
      final d = compareReceipts(before, after, beforeTaxCents: 10, afterTaxCents: 25);
      expect(d.beforeTotalCents, 469 + 598 + 349 + 182 + 10);
      expect(d.afterTotalCents, 515 + 897 + 300 + 1998 + 25);
      expect(
        d.priceEffectCents + d.quantityEffectCents + d.addedCents + d.removedCents +
            d.taxChangeCents,
        d.differenceCents,
      );
    });

    test('splits price from quantity', () {
      final d = compareReceipts(before, after);
      ItemChange of(String n) => d.items.firstWhere((i) => i.name == n);
      expect((of('MILK').priceEffectCents, of('MILK').quantityEffectCents), (46, 0));
      expect((of('EGGS').priceEffectCents, of('EGGS').quantityEffectCents), (0, 299));
      expect(of('STEAK').kind, ChangeKind.added);
      expect(of('BREAD').kind, ChangeKind.removed);
      expect(d.addedCents, 1998);
      expect(d.removedCents, -349);
      // Bananas 151.67c/lb → 150c/lb over 1.2 and 2.0 lb.
      expect(of('BANANAS').priceEffectCents, -3);
      expect(of('BANANAS').quantityEffectCents, 121);
    });

    test('explains in sentences, biggest cause first', () {
      final lines = compareReceipts(before, after).explain();
      expect(lines.first, 'You spent \$21.12 more on the second receipt.');
      expect(lines[1], startsWith('+\$19.98 from 1 item only on the second receipt: STEAK'));
      expect(lines.any((l) => l.contains('MILK \$4.69 → \$5.15')), isTrue);
      expect(lines.any((l) => l.startsWith('−\$3.49 from 1 item only on the first')), isTrue);
    });

    test('several lines of one product are compared as one', () {
      final d = compareReceipts(
        [buy(1, 1, 'MILK', 1, 469), buy(1, 1, 'MILK', 1, 469)],
        [buy(2, 1, 'MILK', 2, 938)],
      );
      expect(d.items.single.kind, ChangeKind.unchanged);
      expect(d.differenceCents, 0);
    });

    test('the parts always add up, on random baskets', () {
      final rnd = Random(7);
      for (var trial = 0; trial < 200; trial++) {
        List<Purchase> basket(int receipt) => [
              for (var p = 0; p < 12; p++)
                if (rnd.nextBool())
                  buy(receipt, p, 'P$p', 1 + rnd.nextInt(4) + (p.isOdd ? rnd.nextDouble() : 0),
                      50 + rnd.nextInt(2000), unit: p.isOdd ? 'lb' : 'each'),
            ];
        final d = compareReceipts(basket(1), basket(2),
            beforeTaxCents: rnd.nextInt(100), afterTaxCents: rnd.nextInt(100));
        expect(
          d.priceEffectCents + d.quantityEffectCents + d.addedCents + d.removedCents +
              d.taxChangeCents,
          d.differenceCents,
        );
      }
    });
  });

  group('personalPriceIndex', () {
    test('chains the geometric mean of price moves month to month', () {
      final points = personalPriceIndex([
        buy(1, 1, 'MILK', 1, 400, date: DateTime(2026, 8, 3)),
        buy(1, 2, 'EGGS', 1, 300, date: DateTime(2026, 8, 3)),
        buy(2, 1, 'MILK', 1, 440, date: DateTime(2026, 9, 5)), // +10%
        buy(2, 2, 'EGGS', 1, 300, date: DateTime(2026, 9, 5)), // 0%
        buy(3, 3, 'STEAK', 1, 2000, date: DateTime(2026, 10, 2)), // nothing to compare
      ]);
      expect(points.map((p) => p.month), [
        DateTime(2026, 8), DateTime(2026, 9), DateTime(2026, 10)]);
      expect(points[0].value, 100);
      expect(points[1].value, closeTo(100 * sqrt(1.1), 1e-9));
      expect(points[1].comparedItems, 2);
      expect(points[2].value, points[1].value);
      expect(points[2].comparedItems, 0);
    });

    test('compares with the most recent earlier price, even months back', () {
      final points = personalPriceIndex([
        buy(1, 1, 'MILK', 1, 400, date: DateTime(2026, 6, 1)),
        buy(2, 2, 'EGGS', 1, 300, date: DateTime(2026, 7, 1)),
        buy(3, 1, 'MILK', 1, 500, date: DateTime(2026, 9, 1)),
      ]);
      expect(points.last.value, closeTo(125, 1e-9));
    });

    test('a weighed item is compared per pound', () {
      final points = personalPriceIndex([
        buy(1, 1, 'BANANAS', 2, 138, unit: 'lb', date: DateTime(2026, 8, 1)),
        buy(2, 1, 'BANANAS', 3, 207, unit: 'lb', date: DateTime(2026, 9, 1)),
      ]);
      expect(points.last.value, closeTo(100, 1e-9));
    });
  });

  group('priceChanges', () {
    test('latest price against the median of earlier ones', () {
      final changes = priceChanges([
        buy(1, 1, 'MILK', 1, 400),
        buy(2, 1, 'MILK', 1, 420),
        buy(3, 1, 'MILK', 1, 500),
        buy(1, 2, 'EGGS', 1, 300),
        buy(2, 2, 'EGGS', 1, 300),
        buy(3, 9, 'ONCE', 1, 999),
      ]);
      expect(changes.single.name, 'MILK');
      expect(changes.single.typicalUnitPrice, 410);
      expect(changes.single.changeFraction, closeTo(500 / 410 - 1, 1e-9));
    });
  });

  group('storeComparison', () {
    final purchases = [
      buy(1, 1, 'MILK', 1, 469, store: 'Market Basket'),
      buy(2, 1, 'MILK', 1, 529, store: 'Whole Foods'),
      buy(1, 2, 'EGGS', 1, 299, store: 'Market Basket'),
      buy(2, 2, 'EGGS', 1, 399, store: 'Whole Foods'),
      buy(3, 2, 'EGGS', 1, 309, store: 'Market Basket'),
      buy(1, 3, 'BREAD', 1, 349, store: 'Market Basket'),
    ];

    test('typical price per store for products bought at two or more', () {
      final c = storeComparison(purchases);
      expect(c.map((s) => s.name), ['EGGS', 'MILK']); // widest gap first
      expect(c.first.byStore, {'Market Basket': 304, 'Whole Foods': 399});
      expect(c.first.cheapest.key, 'Market Basket');
    });

    test('overall gap between two stores', () {
      final gap = storeGap(storeComparison(purchases), 'Whole Foods', 'Market Basket')!;
      expect(gap.items, 2);
      expect(gap.fraction, closeTo(sqrt(529 / 469 * 399 / 304) - 1, 1e-9));
    });
  });
}
