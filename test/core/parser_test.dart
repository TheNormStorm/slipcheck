import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/money.dart';
import 'package:slipcheck/core/parsing/date_parser.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';

List<String> fixture(String name) =>
    File('test/fixtures/$name.txt').readAsLinesSync();

void main() {
  group('money', () {
    test('parses common amount formats', () {
      expect(parseCents('4.99'), 499);
      expect(parseCents('1,15'), 115);
      expect(parseCents(r'$12.30'), 1230);
      expect(parseCents('-1.00'), -100);
      expect(parseCents('1.00-'), -100);
      expect(parseCents('12'), isNull);
      expect(parseCents('1.5'), isNull);
    });
    test('formats cents', () {
      expect(formatCents(2435), '24.35');
      expect(formatCents(5), '0.05');
      expect(formatCents(-100), '-1.00');
    });
  });

  group('dates', () {
    test('ISO', () => expect(findDate(['2026-10-18 14:32']), DateTime(2026, 10, 18)));
    test('month name', () {
      expect(findDate(['Oct 21, 2026']), DateTime(2026, 10, 21));
      expect(findDate(['21 October 2026']), DateTime(2026, 10, 21));
    });
    test('ambiguous numeric follows dayFirst', () {
      expect(findDate(['03/04/26']), DateTime(2026, 4, 3));
      expect(findDate(['03/04/26'], dayFirst: false), DateTime(2026, 3, 4));
    });
    test('unambiguous numeric ignores dayFirst', () {
      expect(findDate(['21/10/2026'], dayFirst: false), DateTime(2026, 10, 21));
      expect(findDate(['10/21/2026']), DateTime(2026, 10, 21));
    });
    test('rejects impossible dates', () => expect(findDate(['31/02/2026']), isNull));
  });

  group('row grouping', () {
    test('joins name and price fragments on the same line', () {
      final rows = groupIntoRows(const [
        OcrLine('4.99', left: 300, top: 101, right: 340, bottom: 119),
        OcrLine('MILK 2% 1L', left: 10, top: 100, right: 120, bottom: 120),
        OcrLine('3.49', left: 300, top: 131, right: 340, bottom: 150),
        OcrLine('BREAD', left: 10, top: 130, right: 80, bottom: 150),
      ]);
      expect(rows, ['MILK 2% 1L  4.99', 'BREAD  3.49']);
    });
  });

  group('ReceiptParser', () {
    const parser = ReceiptParser();

    test('typical grocery receipt', () {
      final r = parser.parse(fixture('grocery_basic'));
      expect(r.storeName, 'FRESHMART');
      expect(r.date, DateTime(2026, 10, 18));
      expect(r.items.map((i) => i.rawText).toList(), [
        'MILK 2% 1L',
        'BREAD WW 675G',
        'BANANAS',
        'COKE 355ML',
        'ORANGES',
        'CHEDDAR CHS 400G',
      ]);
      final bananas = r.items[2];
      expect(bananas.quantity, 1.234);
      expect(bananas.unit, 'kg');
      expect(bananas.unitPriceCents, 152);
      expect(bananas.lineTotalCents, 188);
      final coke = r.items[3];
      expect(coke.quantity, 2);
      expect(coke.unitPriceCents, 199);
      expect(r.items[4].quantity, 3);
      expect(r.items[5].discountCents, 100);
      expect(r.subtotalCents, 2370);
      expect(r.taxCents, 65);
      expect(r.totalCents, 2435);
      expect(r.warnings, isEmpty);
    });

    test('decimal commas and day-first dates', () {
      final r = parser.parse(fixture('dayfirst_comma'));
      expect(r.storeName, 'Bäckerei Corner Shop');
      expect(r.date, DateTime(2026, 4, 3));
      expect(r.items.map((i) => (i.rawText, i.lineTotalCents)).toList(), [
        ('Milk 2% 1 litre', 115),
        ('Free range eggs 12', 320),
        ('Butter 250g', 210),
      ]);
      expect(r.totalCents, 645);
      expect(r.warnings, isEmpty);
    });

    test('quantity line after the item it belongs to', () {
      final r = parser.parse(fixture('qty_after_item'));
      expect(r.storeName, 'VALUE STORE #1042');
      expect(r.date, DateTime(2026, 10, 21));
      expect(r.items[0].rawText, 'YOGURT 750G');
      expect(r.items[0].quantity, 2);
      expect(r.items[0].unitPriceCents, 299);
      expect(r.items[1].rawText, 'APPLES GALA');
      expect(r.items[1].unit, 'kg');
      expect(r.totalCents, 971);
      expect(r.warnings, isEmpty);
    });

    test('quantity inline with the name', () {
      final r = parser.parse(['SODA 355ML 3 @ 1.25   3.75', 'TOTAL 3.75']);
      expect(r.items.single.rawText, 'SODA 355ML');
      expect(r.items.single.quantity, 3);
      expect(r.items.single.lineTotalCents, 375);
    });

    test('warns when items do not add up to the total', () {
      final r = parser.parse(fixture('mismatch'));
      expect(r.items, hasLength(2));
      expect(r.warnings.single, contains('4.48'));
      expect(r.warnings.single, contains('5.48'));
    });

    test('ignores the payment section after the total', () {
      final r = parser.parse(fixture('grocery_basic'));
      expect(r.items.any((i) => i.rawText.contains('VISA')), isFalse);
    });

    test('warns on empty input', () {
      final r = parser.parse([]);
      expect(r.items, isEmpty);
      expect(r.warnings, containsAll(['No items found.', 'No total found.']));
    });
  });
}
