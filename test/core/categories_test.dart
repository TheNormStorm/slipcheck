import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/categories.dart';
import 'package:slipcheck/core/matching/cross_store.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/core/parsing/stitcher.dart';

void main() {
  group('department headings', () {
    test('recognised', () {
      for (final h in ['PRODUCE DEPT', 'FRESH POULTRY', 'TAX GROCERY', 'ICE CREAM', 'HABA',
          'STORE CUT BEEF', 'ORGANIC FRUIT', 'BOTTLE DEPOSIT', 'YOGURT']) {
        expect(isDepartmentHeading(h), isTrue, reason: h);
      }
    });
    test('second lines of wrapped names are not headings', () {
      for (final n in ['CHICKEN', 'DRUMSTICK ABF', 'FREE 18PK', 'BREAD', 'FREE COKE',
          'SANDWICH 8PK', 'STEAKS', 'Sale', 'Cashier:']) {
        expect(isDepartmentHeading(n), isFalse, reason: n);
      }
    });
  });

  group('categorize', () {
    test('keywords first, then the heading, then Other', () {
      expect(categorize('CEDARS PITA', section: 'CHEESE'), Category.bakery);
      expect(categorize('GOYA LITE COCNUTMILK', section: 'GROCERY'), Category.pantry);
      expect(categorize('PKG GREEN BEANS USA', section: 'PRODUCE DEPT'), Category.produce);
      expect(categorize('GOYA WHITE BEANS'), Category.pantry);
      expect(categorize('BEPRTYWNGABF', section: 'FRESH POULTRY'), Category.meat);
      expect(categorize('SO CM VANILLA SANDWICH 8PK', section: 'ICE CREAM'), Category.frozen);
      expect(categorize('MB SINGLE ROLL 130CT', section: 'TAX GROCERY'), Category.household);
      expect(categorize('MB FOIL HVY DTY 50SF'), Category.household);
      expect(categorize('CAT CHOW'), Category.pet);
      expect(categorize('LIBBYS', section: 'GROCERY'), Category.pantry);
      expect(categorize('LIBBYS'), Category.other);
      expect(categorize('BOTTLE DEPOSIT 12PK'), Category.deposits);
      expect(categorize('APPLE JUICE'), Category.drinks);
    });
  });

  group('parser keeps codes and headings (real receipt)', () {
    late ParsedReceipt r;
    setUpAll(() {
      List<String> rowsOf(String name) => groupIntoRows([
            for (final l in jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List)
              OcrLine.fromJson(l),
          ]);
      r = const ReceiptParser().parse(stitchPages([
        rowsOf('market_basket3_top'), rowsOf('market_basket3_middle'),
        rowsOf('market_basket3_bottom'),
      ]).rows);
    });
    ParsedLine item(String name) => r.items.firstWhere((i) => i.rawText == name);

    test('barcodes and PLUs', () {
      expect(item('CEDARS PITA').code, '044115110322');
      expect(item('ORGANIC BANANAS').code, '94011');
      expect(item('TRAY KIWI').code, '4030');
      expect(item('PKG GREEN BEANS USA').code, '2093870000000');
    });

    test('department headings', () {
      expect(item('CEDARS PITA').section, 'CHEESE');
      expect(item('PKG GREEN BEANS USA').section, 'PRODUCE DEPT');
      expect(item('CAT CHOW').section, 'TAX GROCERY');
      expect(item('TZERO PLAIN').section, 'YOGURT');
      expect(r.items.first.section, 'BOTTLE DEPOSIT');
    });

    test('headings never end up in item names', () {
      expect(r.items.where((i) => RegExp(r'GROCERY|DEPT|POULTRY').hasMatch(i.rawText)), isEmpty);
      expect(r.itemsSumCents, 36133);
    });
  });

  group('suggestSameProduct', () {
    const eggsMB = ProductInfo(id: 1, name: 'MB LG BROWN CAGE FREE 18PK', storeIds: {1},
        category: 'dairy');
    test('finds the same item at another store', () {
      final s = suggestSameProduct(eggsMB, const [
        ProductInfo(id: 2, name: '365 LARGE BROWN CAGE FREE EGGS 18PK', storeIds: {2},
            category: 'dairy'),
        ProductInfo(id: 3, name: 'BROWN RICE', storeIds: {2}, category: 'pantry'),
        ProductInfo(id: 4, name: 'LG BROWN EGGS 12PK', storeIds: {2}, category: 'dairy'),
      ]);
      expect(s.map((m) => m.product.id), [2]); // 12PK is a different size
    });
    test('never suggests a product from the same store', () {
      expect(
        suggestSameProduct(eggsMB, const [
          ProductInfo(id: 5, name: 'MB LG BROWN CAGE FREE 12PK EGGS', storeIds: {1, 2},
              category: 'dairy'),
        ]),
        isEmpty,
      );
    });
  });
}
