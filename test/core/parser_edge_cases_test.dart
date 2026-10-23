import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';

ParsedReceipt parse(List<String> rows) => const ReceiptParser().parse(rows);
List<(String, int)> items(ParsedReceipt r) => [for (final i in r.items) (i.rawText, i.lineTotalCents)];

void main() {
  test('a savings summary before the total is neither the total nor a discount', () {
    final r = parse(['STOP & SHOP', 'MILK 2% 1GAL  3.99 F', 'EGGS 12CT  4.29 F',
        'TOTAL SAVINGS  1.00', 'BREAD  2.49', 'TOTAL  10.77', 'VISA  10.77']);
    expect(items(r), [('MILK 2% 1GAL', 399), ('EGGS 12CT', 429), ('BREAD', 249)]);
    expect(r.items.every((i) => i.discountCents == 0), isTrue);
    expect(r.totalCents, 1077);
    expect(r.warnings, isEmpty);
  });

  test('TOTAL TAX is tax, not the total', () {
    final r = parse(['SHOP', 'MILK  3.99', 'TOTAL TAX  0.25', 'TOTAL  4.24']);
    expect((r.taxCents, r.totalCents), (25, 424));
  });

  test('deal prices: "2/5.00" and "2 FOR \$5.00"', () {
    final r = parse(['SHOP', '10/20/2026', 'YOGURT  2/5.00  5.00', 'GREEK YOGURT  5.00',
        '2 FOR \$5.00', 'TOTAL  10.00']);
    expect(r.date, DateTime(2026, 10, 20)); // "2/5.00" is not a date
    expect(items(r), [('YOGURT', 500), ('GREEK YOGURT', 500)]);
    expect([for (final i in r.items) (i.quantity, i.unitPriceCents)], [(2, 250), (2, 250)]);
  });

  test('a price-like "2/5.00" is never taken as a date', () {
    expect(parse(['SHOP', 'YOGURT  2/5.00  5.00', 'TOTAL  5.00']).date, isNull);
  });

  test('a return is a negative item, a coupon a discount', () {
    final r = parse(['SHOP', 'MILK  4.69', 'MFR COUPON  1.00-', 'RETURN BREAD  -3.49',
        'EGGS  2.99', 'TOTAL  3.19']);
    expect(items(r), [('MILK', 469), ('BREAD', -349), ('EGGS', 299)]);
    expect(r.items.first.discountCents, 100);
    expect(r.items[1].quantity, -1);
    expect(r.warnings, isEmpty);
  });

  test('items whose names contain payment words are kept', () {
    final r = parse(['SHOP', 'CARD - BIRTHDAY  4.99', 'CASHEWS  6.99', 'CHANGE PURSE  9.99',
        'TOTAL  21.97', 'CASH  25.00', 'CHANGE  3.03']);
    expect(items(r), [('CARD - BIRTHDAY', 499), ('CASHEWS', 699), ('CHANGE PURSE', 999)]);
  });

  test('payment and loyalty lines before the total are skipped', () {
    final r = parse(['SHOP', 'MEMBER # 123456', 'MILK  3.99', 'ITEMS SOLD 1', 'TOTAL  3.99']);
    expect(items(r), [('MILK', 399)]);
  });

  test('quantity before the name', () {
    final r = parse(['SHOP', '2 x MILK 4.69  9.38', '3 BANANA @ 0.25  0.75', '2 x BREAD  5.98',
        'TOTAL  16.11']);
    expect(items(r), [('MILK', 938), ('BANANA', 75), ('BREAD', 598)]);
    expect([for (final i in r.items) (i.quantity, i.unitPriceCents)],
        [(2, 469), (3, 25), (2, 299)]);
  });

  test('names starting with numbers keep them', () {
    final r = parse(['SHOP', '7UP 2L  2.49', '2% MILK 1GAL  3.49', '12  PK COKE  6.99',
        '100% OJ  4.99', 'TOTAL  17.96']);
    expect(items(r).map((i) => i.$1), ['7UP 2L', '2% MILK 1GAL', '12 PK COKE', '100% OJ']);
  });

  test('greeting text is not the store name', () {
    expect(parse(['WELCOME TO', "SHAW'S", 'BREAD  2.99', 'TOTAL  2.99']).storeName, "SHAW'S");
    expect(parse(["WELCOME TO SHAW'S", 'BREAD  2.99', 'TOTAL  2.99']).storeName, "SHAW'S");
  });

  test('tax printed just under the total', () {
    final r = parse(['SHOP', 'SOAP  1.00', 'SUBTOTAL  1.00', 'TOTAL  1.06', 'SALES TAX  0.06',
        'VISA  1.06']);
    expect((r.subtotalCents, r.taxCents, r.totalCents), (100, 6, 106));
    expect(items(r), [('SOAP', 100)]);
  });
}
