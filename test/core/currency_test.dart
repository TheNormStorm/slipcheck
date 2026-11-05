import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/currency.dart';

List<String> fixture(String name) => File('test/fixtures/$name.txt').readAsLinesSync();

void main() {
  group('detect', () {
    test('your receipts', () {
      expect(detectCurrency(fixture('cm_meats_iphone')), 'JMD'); // TRN, Clarendon
      expect(detectCurrency(fixture('cm_meats_phone')), 'JMD');
      expect(detectCurrency(fixture('market_basket3_iphone')), 'USD'); // "MA 6.25% Sales Tax"
      expect(detectCurrency(['MARKET BASKET', 'Somerville, MA 02143', 'TOTAL 362.90']), 'USD');
    });

    test('codes, symbols and tax names', () {
      expect(detectCurrency(['TOTAL J\$1,200.00']), 'JMD');
      expect(detectCurrency(['Amount: USD \$362.90']), 'USD');
      expect(detectCurrency(['SUBTOTAL 10.00', 'GCT 15% 1.50']), 'JMD');
      expect(detectCurrency(['TOTAL £4.20', 'VAT 0.70']), 'GBP');
      expect(detectCurrency(['Summe 4,20 €', 'MwSt 19%']), 'EUR');
      expect(detectCurrency(['Toronto ON M5V 2T6', 'HST 13% 0.65']), 'CAD');
      expect(detectCurrency(fixture('grocery_basic')), 'CAD'); // HST 13%
    });

    test('too little to go on, or clues both ways', () {
      expect(detectCurrency(['CORNER SHOP', 'MILK 1.99', 'TOTAL 1.99']), isNull);
      expect(detectCurrency(['MANCHESTER AVENUE', 'TOTAL 5.00']), isNull); // a street, not the parish
      expect(detectCurrency(['Sales Tax 0.50', 'TOTAL 5.00']), isNull);
      expect(detectCurrency(['USD 5.00', 'J\$ 800.00']), isNull);
    });
  });

  test('showing amounts', () {
    expect(groupedAmount(546000), '5,460.00');
    expect(groupedAmount(123456789), '1,234,567.89');
    expect(groupedAmount(5), '0.05');
    expect(formatMoney(546000, 'JMD', main: 'USD'), r'J$5,460.00');
    expect(formatMoney(36290, 'USD', main: 'USD'), '362.90');
    expect(formatMoney(-150, 'GBP', main: 'USD'), '-£1.50');
    expect(formatMoney(100, 'CHF', main: 'USD'), 'CHF 1.00');
  });
}
