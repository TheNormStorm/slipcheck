import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/checks.dart';

CheckLine line(int cents, [String? code, double qty = 1, String unit = 'each']) =>
    CheckLine(cents: cents, quantity: qty, unit: unit, taxCode: code);

void main() {
  group('tax', () {
    test('the printed rate of the taxed codes gives the printed tax', () {
      // Market Basket: seven T lines, 25.14 at 6.25% = 1.57; F lines untaxed.
      final lines = [
        line(179, 'T'), line(250, 'T'), line(659, 'T'), line(449, 'T'), line(149, 'T'), line(329, 'T'), line(499, 'T'),
        line(1998, 'F'), line(846, 'F'), line(399),
      ];
      final t = checkTax(lines, [const TaxLine(157, ratePercent: 6.25)]);
      expect(t.agrees, isTrue);
      expect(t.taxedCodes, {'T'});
    });

    test('a misread taxed line breaks it', () {
      final t = checkTax([line(1679, 'T'), line(999, 'F')], [const TaxLine(157, ratePercent: 6.25)]);
      expect(t.agrees, isFalse);
    });

    test('nothing to check without a rate, without codes, or without tax', () {
      expect(checkTax([line(100, 'T')], [const TaxLine(6)]).agrees, isNull);
      expect(checkTax([line(100)], [const TaxLine(6, ratePercent: 6.25)]).agrees, isNull);
      expect(checkTax([line(100, 'F')], [const TaxLine(0, ratePercent: 0)]).agrees, isNull);
    });

    test('two rates on two sets of codes', () {
      final lines = [line(1000, 'A'), line(2000, 'B'), line(500, 'Z')];
      final t = checkTax(lines, [const TaxLine(50, ratePercent: 5), const TaxLine(160, ratePercent: 8)]);
      expect(t.agrees, isTrue);
      expect(t.taxedCodes, {'A', 'B'});
    });

    test('rounding each line is allowed for', () {
      // Six lines of 0.99 at 6.25%: 0.37 by the total, 0.36 line by line.
      final lines = [for (var i = 0; i < 6; i++) line(99, 'T')];
      expect(checkTax(lines, [const TaxLine(36, ratePercent: 6.25)]).agrees, isTrue);
    });
  });

  group('count', () {
    test('units of counted items, one per weighed line', () {
      final lines = [line(897, 'F', 3), line(150, 'F', 3), line(681, 'F', 4.57, 'lb'), line(10, 'F', 2)];
      expect(unitCount(lines), 9);
      expect(checkCount(lines, 9), isTrue);
      expect(checkCount(lines, 10), isFalse);
      expect(checkCount(lines, null), isNull);
    });
  });
}
