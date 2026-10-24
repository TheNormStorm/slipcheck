import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/analytics/purchase.dart';
import 'package:slipcheck/core/analytics/vs_usual.dart';

Purchase buy(int receipt, int product, double qty, int net,
        {String unit = 'each', int day = 0, int store = 1}) =>
    Purchase(
      receiptId: receipt,
      date: DateTime(2026, 10, day == 0 ? receipt : day),
      storeId: store,
      productId: product,
      productName: 'P$product',
      quantity: qty,
      unit: unit,
      netCents: net,
    );

void main() {
  group('UsualPrices', () {
    final usual = UsualPrices([
      buy(1, 1, 1, 400),
      buy(2, 1, 1, 420),
      buy(3, 1, 1, 409),
      buy(1, 2, 2, 600), // 3.00 each
      buy(1, 3, 1.5, 300, unit: 'lb'),
      buy(4, 1, 1, 999, store: 2),
    ]);

    test('is the median unit price at that store and unit', () {
      expect(usual.of(1, 'each', 1), 409);
      expect(usual.of(2, 'each', 1), 300);
      expect(usual.of(3, 'lb', 1), 200);
      expect(usual.of(1, 'each', 2), 999);
    });

    test('is unknown elsewhere', () {
      expect(usual.of(1, 'each', 3), isNull);
      expect(usual.of(3, 'kg', 1), isNull);
      expect(usual.compare(9, 'each', 1, 100), isNull);
    });

    test('compares a price with it', () {
      final up = usual.compare(1, 'each', 1, 429)!;
      expect(up.isUp, isTrue);
      expect(up.percent, 5);
      final down = usual.compare(2, 'each', 1, 270)!;
      expect(down.isDown, isTrue);
      expect(down.percent, 10);
      final same = usual.compare(1, 'each', 1, 409.5)!;
      expect(same.isUsual, isTrue);
      expect(same.percent, 0);
    });

    test('a tiny move on a cheap item is still the usual price', () {
      final cheap = UsualPrices([buy(1, 1, 1, 50)]).compare(1, 'each', 1, 50.6)!;
      expect(cheap.isUsual, isTrue);
    });
  });

  group('receiptMoves', () {
    test('counts prices up and down against earlier receipts at the store', () {
      final all = [
        buy(1, 1, 1, 400),
        buy(1, 2, 1, 300),
        buy(1, 3, 1, 250),
        buy(2, 1, 1, 440), // up
        buy(2, 2, 1, 270), // down
        buy(2, 3, 1, 250), // same
        buy(2, 4, 1, 999), // new
      ];
      final moves = receiptMoves(all, 2);
      expect((moves.up, moves.down), (1, 1));
    });

    test('ignores later receipts and other stores', () {
      final all = [
        buy(1, 1, 1, 400),
        buy(3, 1, 1, 800),
        buy(4, 1, 1, 900, store: 2, day: 1),
      ];
      final moves = receiptMoves(all, 1);
      expect((moves.up, moves.down), (0, 0));
    });

    test('merges lines of one product on the receipt first', () {
      final all = [
        buy(1, 1, 2, 800),
        buy(2, 1, 1, 400),
        buy(2, 1, 1, 400),
      ];
      final moves = receiptMoves(all, 2);
      expect((moves.up, moves.down), (0, 0));
    });

    test('of an unknown receipt is none', () {
      expect(receiptMoves([buy(1, 1, 1, 1)], 7), same(ReceiptMoves.none));
    });
  });
}
