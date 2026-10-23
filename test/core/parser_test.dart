import 'dart:convert';
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
    test('parses typed prices', () {
      expect(parseTypedCents('4'), 400);
      expect(parseTypedCents('4.5'), 450);
      expect(parseTypedCents('4,05'), 405);
      expect(parseTypedCents('abc'), isNull);
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

  group('real receipt: Market Basket (ML Kit output, curled paper)', () {
    late ParsedReceipt r;
    setUpAll(() {
      final json = jsonDecode(
          File('test/fixtures/market_basket_mlkit.json').readAsStringSync()) as List;
      final rows = groupIntoRows([for (final l in json) OcrLine.fromJson(l)]);
      r = const ReceiptParser().parse(rows);
    });

    test('store and US date', () {
      expect(r.storeName, 'MARKET BASKET');
      expect(r.date, DateTime(2026, 10, 22));
    });

    test('every line item, names without UPC codes, wrapped names joined', () {
      expect(r.items.map((i) => (i.rawText, formatCents(i.lineTotalCents))).toList(), [
        ('BOTTLE DEPOSIT 1PK', '0.10'),
        ('BOTTLE DEPOSIT 12PK', '0.60'),
        ('CEDARS PITA', '2.99'),
        ('LEMON SQUEEZE', '1.50'),
        ('MB LG BROWN CAGE FREE 18PK', '8.97'),
        ('GII HAND CUT FRIES', '4.99'),
        ('BELL & EVANS HALF CHICKEN', '7.63'),
        ('BEPRTYWNGABF', '4.22'),
        ('BELL & EVANS DRUMSTICK ABF', '4.63'),
        ('BELL & EVANS HALF CHICKEN', '8.33'),
        ('BELL & EVANS DRUMSTICK ABF', '4.04'),
        ('BADIA CHIMICHURI SCE', '3.99'),
        ('OLIVARI OIL', '8.99'),
        ('BH SOLID WHITE N/S', '18.00'),
        ('POLAND SPRINGS 24PK', '9.00'),
        ('FOCO JASMINE RICE', '8.99'),
        ('LIBBYS', '5.29'),
        ('GOYA SWEET PLANTAIN', '2.99'),
        ('POPCORNERS WT-CHEDDR', '3.99'),
        ('OSPRAY CRAN 100%', '6.29'),
        ('GOYA DRY SM RED BEAN', '1.89'),
        ('PEPSI DIET', '2.39'),
        ('GOYA WHITE BEANS', '1.25'),
        ('GOYA LITE COCNUTMILK', '3.00'),
        ('PANERA HONEY WHEAT', '4.99'),
        ('WELCHS SPARKLING RED', '3.99'),
        ('EXCEL FAMILY CRACKER', '6.87'),
        ('FR DIET CAFFEINE', '8.49'),
        ('CREST', '4.99'),
        ('So CM VANILLA', '5.49'),
        ('sc VAN NSA', '4.49'),
        ('ORGANIC RASPBERRIES', '4.99'),
        ('ORGANIC BANANAS', '1.50'),
      ]);
    });

    test('quantities, including multi-buy deals', () {
      ParsedLine item(String name) => r.items.firstWhere((i) => i.rawText == name);
      expect((item('BOTTLE DEPOSIT 1PK').quantity, item('BOTTLE DEPOSIT 1PK').unitPriceCents), (2, 5));
      expect((item('MB LG BROWN CAGE FREE 18PK').quantity, item('MB LG BROWN CAGE FREE 18PK').unitPriceCents), (3, 299));
      expect((item('BH SOLID WHITE N/S').quantity, item('BH SOLID WHITE N/S').unitPriceCents), (6, 300));
      expect((item('POLAND SPRINGS 24PK').quantity, item('POLAND SPRINGS 24PK').unitPriceCents), (2, 450));
      expect((item('EXCEL FAMILY CRACKER').quantity, item('EXCEL FAMILY CRACKER').unitPriceCents), (3, 229));
    });

    test('photo ends before the total, so that is flagged', () {
      expect(r.totalCents, isNull);
      expect(r.warnings, contains('No total found.'));
    });
  });

  group('quantity formats', () {
    test('per-pound weight', () {
      final r = const ReceiptParser().parse(['BANANAS', '2.170 lb @ \$0.69/lb  1.50 F', 'TOTAL 1.50']);
      expect(r.items.single.unit, 'lb');
      expect(r.items.single.quantity, 2.17);
      expect(r.items.single.unitPriceCents, 69);
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

    test('real ML Kit output of grocery_basic, with a split amount', () {
      final r = parser.parse(fixture('mlkit_grocery_basic'));
      expect(r.items, hasLength(6));
      expect(r.items[4].rawText, 'ORANGES');
      expect(r.items[4].quantity, 3);
      expect(r.items[4].unitPriceCents, 79);
      expect(r.totalCents, 2435);
      expect(r.warnings, isEmpty);
    });

    test('decimal commas and day-first dates', () {
      final r = const ReceiptParser(dayFirst: true).parse(fixture('dayfirst_comma'));
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
