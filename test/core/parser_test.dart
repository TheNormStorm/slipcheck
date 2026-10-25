import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/money.dart';
import 'package:slipcheck/core/parsing/date_parser.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/core/parsing/stitcher.dart';

List<String> fixture(String name) =>
    File('test/fixtures/$name.txt').readAsLinesSync();

void main() {
  group('a Jamaican receipt in dollars with thousands separators', () {
    void expectCm(ParsedReceipt r) {
      expect(r.storeName, 'C&M MEATS & GROCERIES');
      expect(r.date, DateTime(2026, 10, 24));
      expect((r.subtotalCents, r.taxCents, r.totalCents), (546000, 0, 546000));
      expect([for (final i in r.items) (i.quantity, i.unitPriceCents, i.lineTotalCents)], [
        (3.0, 95000, 285000),
        (3.0, 32000, 96000),
        (3.0, 55000, 165000),
      ]);
      expect(r.itemsSumCents, 546000);
      expect(r.warnings, isEmpty);
    }

    test('as read on the emulator (curling, "3e \$320.00/", "Sales Ta")', () {
      final json = jsonDecode(File('test/fixtures/cm_meats_mlkit.json').readAsStringSync()) as List;
      expectCm(const ReceiptParser().parse(groupIntoRows([for (final l in json) OcrLine.fromJson(l)])));
    });

    // A tilted photo puts SPARE RIBS' price on a row other than its name.
    const head = ['C&M MEATS & GROCERIES', 'Date: 10/24/2026', 'Description Amount', r'MUTTON IMP $2,850.00',
      r'3 @ $950.00/', 'Manual Weight', r'TURKEY NECK(33LBS) $960.00'];
    const tail = [r'Sub Total $5,460.00', r'5ales Ta% $0.00', r'Total $5,460.00'];
    final layouts = {
      'above the name': [r'3 @ $320.00/', 'Manual Weight', r'$1,650.00', 'SPARE RIBS', r'3 @ $550.00/'],
      'on the "Manual Weight" row above': [r'3 @ $320.00/', r'Manual Weight $1,650.00', 'SPARE RIBS', r'3 @ $550.00/'],
      'below the name': [r'3 @ $320.00/', 'Manual Weight', 'SPARE RIBS', r'$1,650.00', r'3 @ $550.00/'],
      "on the turkey's quantity line": [r'3 @ $320.00/ $1,650.00', 'Manual Weight', 'SPARE RIBS', r'3 @ $550.00/'],
      'on a misread quantity line, its own read without @': [r'3e $320.00/ $1,650.00', 'Manual Weight', 'SPARE RIBS', r'3 $550.00/'],
      'with the note above, name and price on one row': [r'3 @ $320.00/', r'Manual Weight SPARE RIBS $1,650.00', r'3 @ $550.00/'],
      'on the note row, name on its quantity row': [r'3 @ $320.00/', r'Manual Weight $1,650.00', r'SPARE RIBS 3 @ $550.00/'],
      'on a row of its own, name on its quantity row': [r'3 @ $320.00/', 'Manual Weight', r'$1,650.00', r'SPARE RIBS 3 @ $550.00/'],
    };
    for (final MapEntry(key: where, value: middle) in layouts.entries) {
      test('the price of the last item $where', () {
        final r = const ReceiptParser().parse([...head, ...middle, 'Manual Weight', ...tail]);
        expect(r.items.map((i) => i.rawText), ['MUTTON IMP', 'TURKEY NECK(33LBS)', 'SPARE RIBS']);
        expectCm(r);
      });
    }

    test('as read on an iPhone ("\$1,650.0D", "Manual eight", price under name)', () {
      final r = const ReceiptParser().parse(fixture('cm_meats_iphone'));
      expect(r.items.map((i) => i.rawText), ['MUTTON IMP', 'TURKEY NECK(33LBS)', 'SPARE RIBS']);
      expectCm(r);
    });

    test('a misread 0 in the cents', () {
      final r = const ReceiptParser().parse(['EGGS 4.O9', 'MILK 1.0D', 'BREAD 3.49 D', 'TOTAL 8.58']);
      expect(r.items.map((i) => i.lineTotalCents), [409, 100, 349]);
    });

    test('as read on a phone ("5ales Ta%")', () {
      final r = const ReceiptParser().parse(fixture('cm_meats_phone'));
      expectCm(r);
      expect(r.items.map((i) => i.rawText), ['MUTTON IMP', 'TURKEY NECK(33LBS)', 'SPARE RIBS']);
    });
  });

  group('a Jamaican supermarket: GCT at two rates, each lines, department headings', () {
    test('the whole receipt as read on a phone', () {
      final r = const ReceiptParser().parse(fixture('jm_supermarket_phone'));
      expect(r.items, hasLength(53));
      expect(r.subtotalCents, 1803888);
      expect(r.itemsSumCents, 1803888);
      expect(r.taxCents, 168198 + 37500);
      expect(r.totalCents, 2009586);
      expect(r.warnings, isEmpty);
      expect(r.corrections, isEmpty);
      // 15% of the T3 lines (and the two read as TR), 25% of the phone cards.
      expect(r.taxCheck.agrees, isTrue);
      expect(r.taxCheck.taxedCodes, {'T3', 'TR', 'T4'});
      expect(r.items.where((i) => i.rawText.contains('Spiced Bun')), hasLength(5));
      expect(r.items.map((i) => i.section).toSet(), {
        'BAKERY EXTERNAL GOODS', 'BEVERAGES', 'DAIRY', 'GROCERY-FOODS', 'GROCERY NON-FOODS', 'MEATS', 'PRODUCE',
        'HABERDASHERY', 'LIQUORS', 'PHONE CARDS',
      });
    });

    test('a price on the row above its name, under a heading', () {
      final r = const ReceiptParser().parse([
        'BAKERY EXTERNAL GOODS', r'$156.53 T3', 'National Spiced Bun 4 OZ', r'National Spiced Bun 4 OZ $156.53 T3',
        r'Hardo Bread $580.00', r'TOTAL $893.06',
      ]);
      expect(r.items.map((i) => (i.rawText, i.lineTotalCents, i.taxCode)), [
        ('National Spiced Bun 4 OZ', 15653, 'T3'),
        ('National Spiced Bun 4 OZ', 15653, 'T3'),
        ('Hardo Bread', 58000, null),
      ]);
      expect(r.items.first.section, 'BAKERY EXTERNAL GOODS');
    });

    test('a stray price without a tax code is not given to the next name', () {
      final r = const ReceiptParser().parse(
          [r'MILK $4.00 T', r'BREAD $3.00 T', r'$12.34', 'Cashier: Pat', r'EGGS $5.00 T', r'TOTAL $12.00']);
      expect(r.items.map((i) => i.rawText), ['MILK', 'BREAD', 'EGGS']);
    });

    test('an each line over a name whose price was lost', () {
      final r = const ReceiptParser().parse([
        'LIQUORS', r'1 @ $210,34 each (3@$202.54) (24@$194.75)', 'Legend Flavoured Beer Kola', 'PHONE CARDS',
        r'Digi 1000 $1000.00 T4', r'TOTAL $1210.34',
      ]);
      expect(r.items.map((i) => (i.rawText, i.lineTotalCents)), [
        ('Legend Flavoured Beer Kola', 21034),
        ('Digi 1000', 100000),
      ]);
      expect(r.items.first.taxCodeUnknown, isTrue);
      expect(r.items.first.section, 'LIQUORS');
    });

    test("each lines with the count misread don't make a quantity of 10", () {
      final r = const ReceiptParser().parse([
        r'10 $171.75 each (308164.70) (30@$157.66)', r'Arizona Fruit Punch $171.75 T3',
        r'I@ $226.08 each (3@$220.42) (30@$207.23)', r'Uncle Sams Vegetable Oil $226.08',
        r'19 $1.99 each (3@$1.89)', r'Chips $5.97 T3',
        r'TOTAL $403.80',
      ]);
      expect(r.items.map((i) => (i.quantity, i.unitPriceCents, i.lineTotalCents)), [
        (1.0, 17175, 17175),
        (1.0, 22608, 22608),
        (3.0, 199, 597),
      ]);
    });

    test('Items Subtotal is before discounts; the discount total is not a line discount', () {
      final r = const ReceiptParser().parse([
        r'Roma Cocoa $117.35 T3', r'Package price discount -$4.80', r'Digi 500 $500.00 T4',
        r'Items Subtotal $617.35', r'Package price di scount Tot -$4.80', r'Subtotal $612.55',
        r'GCT Standard 15% [$112.55 $16.88', r'GCT Standard 25% [$500.00 $125.00', r'TOTAL $754.43',
      ]);
      expect(r.items.map((i) => (i.rawText, i.netCents)), [('Roma Cocoa', 11255), ('Digi 500', 50000)]);
      expect(r.subtotalCents, 61255);
      expect(r.taxCents, 14188);
      expect(r.warnings, isEmpty);
      expect(r.taxCheck.agrees, isTrue);
    });

    test('only Items Subtotal read: the subtotal is it less the discounts', () {
      final r = const ReceiptParser().parse(
          [r'Roma Cocoa $117.35 T3', r'Package price discount -$4.80', r'Items Subtotal $117.35']);
      expect(r.subtotalCents, 11255);
      expect(r.warnings, ['No total found.']);
    });
  });

  group('second readings make a misread receipt add up', () {
    test('the 96-line Market Basket receipt as an iPhone read it', () {
      final r = const ReceiptParser().parse(fixture('market_basket3_iphone'));
      expect((r.subtotalCents, r.taxCents, r.totalCents), (36133, 157, 36290));
      expect(r.items, hasLength(64));
      expect(r.itemsSumCents, 36133);
      expect(r.warnings, isEmpty);
      int price(String name) => r.items.firstWhere((i) => i.rawText.startsWith(name)).lineTotalCents;
      expect(price('CAB BONELESS RIB'), 1678); // read 16.73, "1 @ 16.78"
      expect(price('CAB PRIME RIBEYE'), 1949); // read 13.49, "1 @ 19.49"
      expect(price('93% X-LEAN GR BF 1-2'), 846); // read 6.46, "1 @ 8.46"
      expect(price('SCALLIONS'), 149); // read "1.4 F"
      expect(r.corrections, hasLength(4));
      expect(r.corrections.first, contains('SCALLIONS'));
    });

    test('the tax and the printed item count check out too', () {
      // The card section, where "Number of Items 96" is printed, is not kept
      // in Text as read; the app reads it before cutting that section.
      final r = const ReceiptParser().parse([...fixture('market_basket3_iphone'), 'Number of Items 96']);
      expect(r.taxCheck.agrees, isTrue);
      expect(r.taxCheck.taxedCodes, {'T'});
      expect(r.taxCheck.ratePercent, 6.25);
      expect(r.printedItemCount, 96);
      expect(r.countCheck, isTrue);
      // "3@ 2/1-00": the deal's point read as a dash.
      expect(r.items.firstWhere((i) => i.rawText == 'PLANTAINS').quantity, 3);
    });

    test('the item count as OCR misreads it', () {
      for (final row in ['Numben of Items  96', 'Number of ltems 96', 'No. of Items: 96', '# ITEMS SOLD 96',
          'TOTAL NUMBER OF ITEMS SOLD = 96', 'Item count: 96']) {
        expect(const ReceiptParser().parse(['MILK 4.29', 'TOTAL 4.29', row]).printedItemCount, 96, reason: row);
      }
      // Not a count: a price, or an item that happens to say "items".
      expect(const ReceiptParser().parse(['ITEMS 4.99', 'TOTAL 4.99']).printedItemCount, isNull);
    });

    test('the tax check picks between two fixes that both add up', () {
      // BEEF (taxed) and LAMB (untaxed) could each be 14.49; only BEEF at
      // 14.49 makes 6.25% of the taxed lines 0.91.
      final r = const ReceiptParser().parse([
        'BEEF 13.49 T', '1 @ 14.49', 'LAMB 13.49 F', '1 @ 14.49', 'SALT 1.00 T',
        'SUBTOTAL 28.98', 'MA 6.25% Sales Tax 0.97', 'TOTAL 29.95',
      ]);
      expect(r.items.map((i) => i.lineTotalCents), [1449, 1349, 100]);
      expect(r.corrections, hasLength(1));
      expect(r.taxCheck.agrees, isTrue);
    });

    test('nothing changes when the receipt already adds up', () {
      final r = const ReceiptParser().parse(['BEEF 13.49 F', '1 @ 19.49', 'MILK 4.29 F', 'SUBTOTAL 17.78', 'TOTAL 17.78']);
      expect(r.items.map((i) => i.lineTotalCents), [1349, 429]);
      expect(r.corrections, isEmpty);
    });

    test('two fixes that would both work: neither is guessed', () {
      final r = const ReceiptParser().parse(
          ['BEEF 13.49 F', '1 @ 14.49', 'LAMB 13.49 F', '1 @ 14.49', 'SUBTOTAL 27.98', 'TOTAL 27.98']);
      expect(r.corrections, isEmpty);
      expect(r.itemsSumCents, 2698);
    });

    test('"1.5 L" is a size, not a price that lost a digit', () {
      final r = const ReceiptParser().parse(['WATER 1.5 L', 'MILK 4.29 F', 'TOTAL 4.29']);
      expect(r.items.map((i) => i.rawText), ['MILK']);
    });
  });

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
    test('reads thousands separators, both ways round', () {
      expect(parseCents(r'$2,850.00'), 285000);
      expect(parseCents('123,456.78'), 12345678);
      expect(parseCents('2.850,00'), 285000);
      expect(parseCents('1,99'), 199);
      expect(parseCents('2,850'), isNull);
      expect(parseTypedCents('2,850.00'), 285000);
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

  group('real receipt: long Market Basket in two scanner photos, faded print', () {
    late ParsedReceipt r;
    late List<int> order;
    setUpAll(() {
      List<String> rowsOf(String name) {
        final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List;
        return groupIntoRows([for (final l in json) OcrLine.fromJson(l)]);
      }

      // The gallery handed them over bottom first, and they do not overlap.
      final pages = [rowsOf('market_basket2_bottom'), rowsOf('market_basket2_top')];
      order = bestPageOrder(pages);
      r = const ReceiptParser().parse(stitchPages([for (final i in order) pages[i]]).rows);
    });

    ParsedLine item(String name) => r.items.firstWhere((i) => i.rawText == name);

    test('the photo with the TOTAL goes last when photos do not overlap', () {
      expect(order, [1, 0]);
      expect((r.subtotalCents, r.taxCents, r.totalCents), (36133, 157, 36290));
    });

    test('"1 @ 2.99" misread as "102.99" prices the item above it', () {
      expect(r.items.where((i) => i.lineTotalCents >= 10000), isEmpty);
      expect(item('GEN 8E ANS USA').lineTotalCents, 299);
    });

    test('weights read through "1b" for "lb" and a lost "@"', () {
      expect((item('YAMS RED').quantity, item('YAMS RED').unit), (4.73, 'lb'));
      expect(item('YAMS RED').lineTotalCents, 610); // its own price was unreadable
      expect(item('CARROTS BULK').lineTotalCents, 210);
      expect(item('Item 4065').unitPriceCents, 199); // PLU only: name not printed
    });

    test('stray marks after a price, and "16 78 F" for 16.78', () {
      expect(item('BELL & EVANS').lineTotalCents, 463);
      expect(item('CAB BONELESS RIB STEAKS').lineTotalCents, 1678);
      expect(item('CAB PRIME RIBEYE STEAK').lineTotalCents, 1949);
      expect(item('BOT TLE DEPOSIT 1PK').quantity, 2); // "2 @ 0.05" read as "290.05"
    });

    test('what is still missing is what the photos could not show', () {
      // 361.33 on the receipt. Missing: lines between the photos and faded
      // past reading (rosemary 1.99, shaved steak 19.98, ~9.88 above them),
      // misread prices (kiwi "a.42" for 8.42, scallions "1.4:" for 1.49) and
      // ground beef read as 6.46 for 8.46.
      expect(r.itemsSumCents, 31856);
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
