import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/categories.dart';
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

  test('purchases carry store, date and net price per known product', () async {
    await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), [
      DraftLine(name: 'MILK 2% 1L', lineTotalCents: 469),
      DraftLine(name: 'Cheddar 400g', lineTotalCents: 799, discountCents: 100),
    ]));
    final purchases = await repo.purchases();
    expect(purchases.map((p) => (p.storeName, p.productName, p.netCents)).toList(), [
      ('FreshMart', 'MILK 2% 1L', 469),
      ('FreshMart', 'Cheddar 400g', 699),
    ]);
  });

  test('receipt detail and summary totals', () async {
    final id = await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), [
      DraftLine(name: 'Bananas', quantity: 1.25, unit: 'kg', lineTotalCents: 190),
      DraftLine(name: 'Cheddar 400g', lineTotalCents: 799, discountCents: 100),
    ])..taxCents = 12);
    final detail = await repo.receipt(id);
    expect(detail.lines.map((l) => l.name), ['Bananas', 'Cheddar 400g']);
    expect(detail.summary.itemsCents, 889);
    expect(detail.summary.spentCents, 901); // no printed total: items + tax
    expect(detail.purchases, hasLength(2));
  });

  test('deleting a receipt removes its lines but keeps products', () async {
    final id = await repo.saveReceipt(draft('FreshMart', DateTime(2026, 9, 1), [
      DraftLine(name: 'MILK 2% 1L', lineTotalCents: 469),
    ]));
    await repo.deleteReceipt(id);
    expect(await repo.receipts(), isEmpty);
    expect(await db.select(db.lineItems).get(), isEmpty);
    expect(await db.select(db.products).get(), hasLength(1));
  });

  group('barcodes, categories, merging', () {
    test('a UPC barcode matches the same product at another store', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'CEDARS PITA', code: '044115110322', lineTotalCents: 299),
      ]));
      final otherStore = await repo.saveReceipt(draft('Whole Foods', DateTime(2026, 9, 2), []));
      final wf = (await repo.receipts(id: otherStore)).single.storeId;
      final m = (await repo.loadMatcher())
          .match('CEDARS WHITE PITA BREAD', storeId: wf, code: '044115110322');
      expect(m.kind, MatchKind.barcode);
      expect(m.product!.displayName, 'CEDARS PITA');
    });

    test('an in-store code (2xxxxxxxxxxxx) only matches at that store', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'PKG GREEN BEANS', code: '2093870000000', lineTotalCents: 299),
      ]));
      final mb = await repo.findStoreId('Market Basket');
      final matcher = await repo.loadMatcher();
      expect(matcher.match('X', storeId: mb, code: '2093870000000').kind, MatchKind.barcode);
      expect(matcher.match('X', storeId: mb! + 1, code: '2093870000000').kind,
          isNot(MatchKind.barcode));
    });

    test('new products get a category from keywords or the heading', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'BEPRTYWNGABF', section: 'FRESH POULTRY', lineTotalCents: 422),
        DraftLine(name: 'CAT CHOW', lineTotalCents: 659),
      ]));
      final products = {for (final p in await repo.products()) p.displayName: p.category};
      expect(products, {'BEPRTYWNGABF': Category.meat, 'CAT CHOW': Category.pet});
    });

    test('linking two products merges their history and keeps matching', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'MB LG BROWN CAGE FREE 18PK', lineTotalCents: 299),
      ]));
      await repo.saveReceipt(draft('Whole Foods', DateTime(2026, 9, 2), [
        DraftLine(name: '365 LARGE BROWN EGGS 18PK', lineTotalCents: 449),
      ]));
      final ps = await repo.products();
      final keep = ps.firstWhere((p) => p.displayName.startsWith('MB'));
      final other = ps.firstWhere((p) => p.displayName.startsWith('365'));
      await repo.mergeProducts(keepId: keep.id, mergeId: other.id);

      final merged = (await repo.products()).single;
      expect(merged.purchaseCount, 2);
      expect(merged.storeIds, hasLength(2));
      final m = (await repo.loadMatcher()).match('365 LARGE BROWN EGGS 18PK');
      expect(m.product!.id, keep.id);
    });

    test('a store name OCR read slightly differently is the same store', () async {
      await repo.saveReceipt(draft('MARKET BASKET', DateTime(2026, 9, 1), []));
      await repo.saveReceipt(draft('MARKFT BASKET', DateTime(2026, 9, 8), []));
      expect(await db.select(db.stores).get(), hasLength(1));
    });

    test('merging stores moves their receipts', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), []));
      await repo.saveReceipt(draft('MB Somerville', DateTime(2026, 9, 8), []));
      final stores = await repo.stores();
      await repo.mergeStores(keepId: stores[0].id, mergeId: stores[1].id);
      final after = await repo.stores();
      expect(after.single.receiptCount, 2);
    });
  });

  group('clearAll', () {
    Future<void> seed() async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'MILK 2% 1L', code: '012000171741', lineTotalCents: 469),
      ]));
    }

    test('removes receipts, items, links and stores, but keeps settings', () async {
      await seed();
      await repo.markSeen('onboardingSeen');
      await repo.clearAll(deleteFiles: false);
      expect(await repo.receipts(), isEmpty);
      expect(await db.select(db.lineItems).get(), isEmpty);
      expect(await repo.products(), isEmpty);
      expect((await repo.loadMatcher()).match('X', code: '012000171741').kind, MatchKind.none);
      expect(await repo.hasSeen('onboardingSeen'), isTrue);
      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.productAliases).get(), isEmpty);
      expect(await db.select(db.stores).get(), isEmpty);
    });
  });

  test('a receipt shared as text has its lines and totals, and nothing else', () async {
    final id = await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 10, 23),
      lines: [
        DraftLine(name: 'MILK 2% 1GAL', lineTotalCents: 429),
        DraftLine(name: 'BANANAS', quantity: 2.11, unit: 'lb', lineTotalCents: 146),
        DraftLine(name: 'CHEDDAR', lineTotalCents: 399, discountCents: 20),
      ],
      subtotalCents: 954,
      taxCents: 0,
      totalCents: 954,
      // What was read, card section included as an old receipt might have.
      ocrText: 'MILK 2% 1GAL 4.29\nVISA ************4417',
      imagePaths: ['/photos/1.jpg'],
    ));
    final text = (await repo.receipt(id)).asText();
    expect(text.split('\n').take(4), ['Market Basket', 'Fri, Oct 23, 2026', '', startsWith('MILK 2% 1GAL')]);
    expect(text, contains('  2.11 lb'));
    expect(text, contains('  saved 0.20'));
    expect(text, contains(RegExp(r'Total +9\.54')));
    expect(text, isNot(contains('4417')));
    expect(text, isNot(contains('.jpg')));
  });

  test('finds receipts by item, printed or renamed, ignoring case', () async {
    final a = await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
      DraftLine(name: 'MB LG BROWN CAGE FREE 18PK', lineTotalCents: 897),
    ]));
    final b = await repo.saveReceipt(draft('Whole Foods', DateTime(2026, 9, 2), [
      DraftLine(name: '100% JUICE', lineTotalCents: 499),
    ]));
    final eggs = (await repo.products()).firstWhere((p) => p.displayName.startsWith('MB LG'));
    await repo.renameProduct(eggs.id, 'Brown eggs 18pk');
    expect(await repo.receiptsWithItem('cage free'), {a});
    expect(await repo.receiptsWithItem('EGGS'), {a});
    expect(await repo.receiptsWithItem('100%'), {b});
    expect(await repo.receiptsWithItem('0%'), {b});
    expect(await repo.receiptsWithItem('%'), {b});
    expect(await repo.receiptsWithItem('steak'), isEmpty);
    expect(await repo.receiptsWithItem('  '), isEmpty);
  });

  group('duplicates and editing', () {
    ReceiptDraft mb({int? total, List<DraftLine>? lines}) => ReceiptDraft(
          storeName: 'Market Basket',
          purchasedAt: DateTime(2026, 10, 22, 18, 14),
          lines: lines ?? [DraftLine(name: 'MILK', lineTotalCents: 469)],
          totalCents: total,
        );

    test('same store, day and total is a duplicate', () async {
      await repo.saveReceipt(mb(total: 36290));
      expect(await repo.findDuplicate(mb(total: 36290)), isNotNull);
      expect(await repo.findDuplicate(mb(total: 1000)), isNull);
      final otherDay = mb(total: 36290)..purchasedAt = DateTime(2026, 10, 23);
      expect(await repo.findDuplicate(otherDay), isNull);
    });

    test('without totals, the items total decides', () async {
      await repo.saveReceipt(mb());
      expect(await repo.findDuplicate(mb()), isNotNull);
    });

    test('editing replaces the lines and details, not the receipt', () async {
      final id = await repo.saveReceipt(mb(total: 469));
      expect(await repo.findDuplicate(mb(total: 469), exceptId: id), isNull);
      await repo.updateReceipt(id, mb(total: 818, lines: [
        DraftLine(name: 'MILK', lineTotalCents: 469),
        DraftLine(name: 'BREAD', lineTotalCents: 349),
      ]));
      final detail = await repo.receipt(id);
      expect(detail.lines.map((l) => l.name), ['MILK', 'BREAD']);
      expect(detail.summary.totalCents, 818);
      expect(await repo.receipts(), hasLength(1));
    });
  });

  group('rename and undo link', () {
    test('a renamed item keeps matching under both names', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'BEPRTYWNGABF', lineTotalCents: 422),
      ]));
      final id = (await repo.products()).single.id;
      await repo.renameProduct(id, 'Party wings');
      expect((await repo.products()).single.displayName, 'Party wings');
      final matcher = await repo.loadMatcher();
      expect(matcher.match('BEPRTYWNGABF').product!.id, id);
      expect(matcher.match('Party wings').product!.id, id);
    });

    test('undoing a link restores both items exactly', () async {
      await repo.saveReceipt(draft('Market Basket', DateTime(2026, 9, 1), [
        DraftLine(name: 'MB LG BROWN CAGE FREE 18PK', lineTotalCents: 299),
      ]));
      await repo.saveReceipt(draft('Whole Foods', DateTime(2026, 9, 2), [
        DraftLine(originalText: '365 LG BRN EGGS 18PK', name: '365 LARGE BROWN EGGS 18PK',
            lineTotalCents: 449),
      ]));
      final before = {for (final p in await repo.products()) p.displayName: p.purchaseCount};
      final aliasesBefore = (await db.select(db.productAliases).get()).length;
      final ps = await repo.products();
      final undo = await repo.mergeProducts(
          keepId: ps.firstWhere((p) => p.displayName.startsWith('MB')).id,
          mergeId: ps.firstWhere((p) => p.displayName.startsWith('365')).id);
      expect(await repo.products(), hasLength(1));
      await repo.undoMerge(undo);
      expect({for (final p in await repo.products()) p.displayName: p.purchaseCount}, before);
      expect((await db.select(db.productAliases).get()).length, aliasesBefore);
    });
  });

  test('store names: OCR slips match, different branches do not', () {
    expect(sameStoreName('market basket', 'markft basket'), isTrue);
    expect(sameStoreName('market basket', 'market baskets'), isTrue);
    expect(sameStoreName('restored store a', 'restored store b'), isFalse);
    expect(sameStoreName('cvs 12', 'cvs 15'), isFalse);
    expect(sameStoreName('market basket', 'market basket chelsea'), isFalse);
    expect(sameStoreName('whole foods', 'whole goods'), isTrue); // one slip in a long word
  });
}
