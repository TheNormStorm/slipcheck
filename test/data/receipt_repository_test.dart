import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/matching/product_matcher.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
  });
  tearDown(() => db.close());

  ReceiptDraft draft(String store, DateTime date, List<DraftLine> lines) =>
      ReceiptDraft(storeName: store, purchasedAt: date, lines: lines);

  test('same product across differently written receipts shares history', () async {
    await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), [
      DraftLine(name: 'MILK 2% 1L', lineTotalCents: 469),
    ]));
    await repo.saveReceipt(draft('Corner Shop', DateTime(2026, 10, 1), [
      DraftLine(name: 'Milk 2% 1 litre', lineTotalCents: 515),
    ]));

    final products = await repo.products();
    expect(products, hasLength(1));
    final history = await repo.priceHistory(products.single.id);
    expect(history.map((p) => (p.storeName, p.unitPriceCents)).toList(), [
      ('FreshMart', 469),
      ('Corner Shop', 515),
    ]);
  });

  test('stores are reused by normalised name', () async {
    await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), []));
    await repo.saveReceipt(draft('  freshmart ', DateTime(2026, 9, 2), []));
    expect(await db.select(db.stores).get(), hasLength(1));
  });

  test('corrected OCR text is learned as a store alias', () async {
    await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), [
      DraftLine(originalText: 'HG MLK 2PC 1L', name: 'Milk 2% 1L', lineTotalCents: 469),
    ]));
    final storeId = await repo.findStoreId('FreshMart');
    final matcher = await repo.loadMatcher();

    final m = matcher.match('HG MLK 2PC 1L', storeId: storeId);
    expect(m.kind, MatchKind.storeAlias);
    expect(m.product!.displayName, 'Milk 2% 1L');
  });

  test('price history uses net unit price for weighed and discounted lines', () async {
    await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), [
      DraftLine(name: 'Bananas', quantity: 1.25, unit: 'kg', lineTotalCents: 190),
      DraftLine(name: 'Cheddar 400g', lineTotalCents: 799, discountCents: 100),
    ]));
    final products = await repo.products();
    final bananas = products.firstWhere((p) => p.displayName == 'Bananas');
    final cheddar = products.firstWhere((p) => p.displayName == 'Cheddar 400g');
    expect(bananas.lastUnitPriceCents, 152);
    expect(cheddar.lastUnitPriceCents, 699);
  });

  test('receipts list newest first with item counts', () async {
    await repo.saveReceipt(draft('A', DateTime(2026, 9, 1), [
      DraftLine(name: 'x', lineTotalCents: 1),
    ])..totalCents = 1);
    await repo.saveReceipt(draft('B', DateTime(2026, 10, 1), [
      DraftLine(name: 'y', lineTotalCents: 1),
      DraftLine(name: 'z', lineTotalCents: 2),
    ]));
    final list = await repo.receipts();
    expect(list.map((r) => (r.storeName, r.itemCount)).toList(), [('B', 2), ('A', 1)]);
  });

  test('all photos of a receipt are kept in order', () async {
    final id = await repo.saveReceipt(ReceiptDraft(
      storeName: 'A',
      purchasedAt: DateTime(2026, 10, 22),
      lines: [],
      imagePaths: ['/top.jpg', '/middle.jpg', '/bottom.jpg'],
    ));
    final images = await (db.select(db.receiptImages)
          ..where((i) => i.receiptId.equals(id))
          ..orderBy([(i) => OrderingTerm.asc(i.position)]))
        .get();
    expect(images.map((i) => i.path), ['/top.jpg', '/middle.jpg', '/bottom.jpg']);
  });
}
