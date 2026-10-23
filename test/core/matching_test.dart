import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/matching/product_matcher.dart';
import 'package:slipcheck/core/matching/product_normalizer.dart';

String key(String raw) => normalizeProduct(raw).key;

void main() {
  group('normalizeProduct', () {
    test('MILK 2% 1L and Milk 2% 1 litre match', () {
      expect(key('MILK 2% 1L'), 'milk 2% 1000ml');
      expect(key('Milk 2% 1 litre'), 'milk 2% 1000ml');
      expect(key('milk 2 % 1000 ml'), 'milk 2% 1000ml');
    });
    test('converts units', () {
      expect(key('Rice 1.5kg'), 'rice 1500g');
      expect(key('Rice 1,5 kg'), 'rice 1500g');
      expect(key('Juice 1.89 L'), 'juice 1890ml');
      expect(key('Cheese 12.5g'), 'cheese 12.5g');
    });
    test('pack sizes', () {
      final n = normalizeProduct('COKE 6x355ML');
      expect(n.packCount, 6);
      expect(n.sizeValue, 355);
      expect(n.key, 'coke 6x355ml');
    });
    test('expands abbreviations and drops SKU codes', () {
      expect(key('BREAD WW 675G'), 'bread whole wheat 675g');
      expect(key('0004011 BANANAS'), 'banana');
      expect(key('CHEDDAR CHS 400G'), 'cheddar cheese 400g');
    });
    test('no size', () {
      final n = normalizeProduct('Free range eggs 12');
      expect(n.sizeValue, isNull);
      expect(n.key, 'free range egg 12');
    });
  });

  group('ProductMatcher', () {
    final products = [
      ProductCandidate(id: 1, key: key('Milk 2% 1 litre'), displayName: 'Milk 2% 1 L'),
      ProductCandidate(id: 2, key: key('Milk 2% 4L'), displayName: 'Milk 2% 4 L'),
      ProductCandidate(id: 3, key: key('Cheddar cheese 400g'), displayName: 'Cheddar 400 g'),
    ];

    test('exact match through normalisation', () {
      final m = ProductMatcher(products, const []).match('MILK 2% 1L');
      expect(m.kind, MatchKind.exact);
      expect(m.product!.id, 1);
      expect(m.isConfident, isTrue);
    });

    test('store-specific alias wins over everything', () {
      final m = ProductMatcher(products, [
        ProductAlias(key: key('HG 2PC 1L'), productId: 1, storeId: 7),
      ]).match('HG 2PC 1L', storeId: 7);
      expect(m.kind, MatchKind.storeAlias);
      expect(m.product!.id, 1);
    });

    test('store alias does not apply at another store', () {
      final m = ProductMatcher(products, [
        ProductAlias(key: key('HG 2PC 1L'), productId: 1, storeId: 7),
      ]).match('HG 2PC 1L', storeId: 8);
      expect(m.kind, isNot(MatchKind.storeAlias));
    });

    test('global alias', () {
      final m = ProductMatcher(products, [
        ProductAlias(key: key('MLK2 1L'), productId: 1),
      ]).match('MLK2 1L');
      expect(m.kind, MatchKind.alias);
    });

    test('fuzzy match is a suggestion, not confident', () {
      final m = ProductMatcher(products, const []).match('CHEDDAR CHEES 400G');
      expect(m.kind, MatchKind.fuzzy);
      expect(m.product!.id, 3);
      expect(m.isConfident, isFalse);
    });

    test('never matches a different size', () {
      final m = ProductMatcher(products, const []).match('MILK 2% 2L');
      expect(m.kind, MatchKind.none);
    });

    test('unrelated text does not match', () {
      final m = ProductMatcher(products, const []).match('DISH SOAP 500ML');
      expect(m.kind, MatchKind.none);
    });
  });

  group('similarity', () {
    test('bounds', () {
      expect(similarity('milk', 'milk'), 1);
      expect(similarity('abc', 'xyz'), 0);
      expect(similarity('cheddar cheese', 'cheddar chees'), greaterThan(0.9));
    });
  });
}
