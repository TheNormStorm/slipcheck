import 'receipt_repository.dart';

/// Made-up receipts across three months and two stores, for trying the
/// analytics screens. Only reachable from debug builds.
Future<void> loadSampleReceipts(ReceiptRepository repo) async {
  DraftLine l(String name, int cents, {double q = 1, String unit = 'each'}) =>
      DraftLine(name: name, lineTotalCents: cents, quantity: q, unit: unit);

  final receipts = [
    ReceiptDraft(storeName: 'Market Basket', purchasedAt: DateTime(2026, 8, 9), taxCents: 31, lines: [
      l('MILK 2% 1GAL', 389), l('MB LG BROWN CAGE FREE 18PK', 897, q: 3),
      l('BANANAS', 140, q: 2.03, unit: 'lb'), l('CEDARS PITA', 279), l('GOYA WHITE BEANS', 119),
      l('FOCO JASMINE RICE', 849), l('CHEDDAR 8OZ', 349), l('COFFEE 12OZ', 899),
    ]),
    ReceiptDraft(storeName: 'Whole Foods', purchasedAt: DateTime(2026, 8, 23), taxCents: 0, lines: [
      l('MILK 2% 1GAL', 489), l('BANANAS', 186, q: 1.95, unit: 'lb'), l('CHEDDAR 8OZ', 499),
      l('COFFEE 12OZ', 1199), l('SOURDOUGH LOAF', 599),
    ]),
    ReceiptDraft(storeName: 'Market Basket', purchasedAt: DateTime(2026, 9, 13), taxCents: 44, lines: [
      l('MILK 2% 1GAL', 409), l('MB LG BROWN CAGE FREE 18PK', 598, q: 2),
      l('BANANAS', 152, q: 2.2, unit: 'lb'), l('CEDARS PITA', 299), l('GOYA WHITE BEANS', 125),
      l('COFFEE 12OZ', 949), l('PRIME SHAVED STEAK', 1998, q: 2),
    ]),
    ReceiptDraft(storeName: 'Whole Foods', purchasedAt: DateTime(2026, 9, 27), taxCents: 0, lines: [
      l('MILK 2% 1GAL', 499), l('BANANAS', 190, q: 1.9, unit: 'lb'), l('SOURDOUGH LOAF', 599),
      l('CHEDDAR 8OZ', 529), l('365 LG BROWN CAGE FREE EGGS 18PK', 449),
    ]),
    ReceiptDraft(storeName: 'Market Basket', purchasedAt: DateTime(2026, 10, 18), taxCents: 57, lines: [
      l('MILK 2% 1GAL', 429), l('MB LG BROWN CAGE FREE 18PK', 1047, q: 3),
      l('BANANAS', 150, q: 2.17, unit: 'lb'), l('CEDARS PITA', 299), l('GOYA WHITE BEANS', 125),
      l('FOCO JASMINE RICE', 899), l('CHEDDAR 8OZ', 379), l('COFFEE 12OZ', 999),
      l('CAT CHOW', 659),
    ]),
  ];
  for (final r in receipts) {
    await repo.saveReceipt(r);
  }
}
