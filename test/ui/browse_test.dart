import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ui/price_history_screen.dart';
import 'package:slipcheck/ui/products_screen.dart';
import 'package:slipcheck/ui/receipt_detail_screen.dart';
import 'package:slipcheck/ui/receipts_screen.dart';
import 'package:slipcheck/ui/store_screen.dart';
import 'package:slipcheck/ui/theme/app_theme.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;
  late int oct;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 9, 12),
      lines: [DraftLine(name: 'MILK 2% 1GAL', lineTotalCents: 409), DraftLine(name: 'BREAD', lineTotalCents: 349)],
      taxCents: 0,
    ));
    oct = await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 10, 23),
      lines: [DraftLine(name: 'MILK 2% 1GAL', lineTotalCents: 429), DraftLine(name: 'BREAD', lineTotalCents: 349)],
      taxCents: 0,
    ));
    await repo.saveReceipt(ReceiptDraft(
      storeName: 'Whole Foods',
      purchasedAt: DateTime(2026, 10, 20),
      lines: [DraftLine(name: 'PRIME SHAVED STEAK', lineTotalCents: 1798)],
      taxCents: 0,
    ));
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildSlipTheme(Brightness.light), home: screen));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('receipts are listed by month and found by item', (tester) async {
    await pump(tester, ReceiptsScreen(repo: repo));
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Whole Foods'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'steak');
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Whole Foods'), findsOneWidget);
    expect(find.text('Market Basket'), findsNothing);

    await tester.tap(find.text('By store'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Whole Foods'), findsOneWidget);
    expect(find.text('Market Basket'), findsNothing);
  });

  testWidgets('a receipt shows what it cost against usual', (tester) async {
    await pump(tester, ReceiptDetailScreen(repo: repo, receiptId: oct));
    expect(find.text('Spent'), findsOneWidget);
    // Milk 4.29 against 4.09 in September: 20 cents over, about 5% up.
    expect(find.text('+0.20'), findsOneWidget);
    expect(find.text('+5%'), findsOneWidget);
    expect(find.text('usual'), findsOneWidget); // bread
    expect(find.text('with Sep 12'), findsOneWidget);
  });

  testWidgets('two lines of one item are compared together, as the tile counts them', (tester) async {
    ReceiptDraft chickens(DateTime d, int a, int b) => ReceiptDraft(
          storeName: 'Butcher',
          purchasedAt: d,
          lines: [DraftLine(name: 'HALF CHICKEN', lineTotalCents: a), DraftLine(name: 'HALF CHICKEN', lineTotalCents: b)],
          taxCents: 0,
        );
    await tester.runAsync(() => repo.saveReceipt(chickens(DateTime(2026, 9, 1), 790, 806)));
    final id = (await tester.runAsync(() => repo.saveReceipt(chickens(DateTime(2026, 10, 1), 763, 833))))!;
    await pump(tester, ReceiptDetailScreen(repo: repo, receiptId: id));
    expect(find.text('Same'), findsOneWidget);
    expect(find.text('usual'), findsNWidgets(2));
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('ticking two trips at a store offers to compare them', (tester) async {
    final storeId = (await tester.runAsync(repo.stores))!.firstWhere((s) => s.name == 'Market Basket').id;
    await pump(tester, StoreScreen(repo: repo, storeId: storeId));
    expect(find.text('2 trips · last Oct 23'), findsOneWidget);
    expect(find.text('Compare these two'), findsNothing);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Compare these two'), findsOneWidget);
    expect(find.textContaining('↑ 5%'), findsOneWidget);
  });

  testWidgets('items: search, and filter to what went up', (tester) async {
    await pump(tester, ProductsScreen(repo: repo));
    expect(find.text('Milk 2% 1gal'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('+5%'), findsOneWidget); // milk 4.09 → 4.29
    expect(find.text('same'), findsOneWidget); // bread

    await tester.tap(find.text('Went up'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Milk 2% 1gal'), findsOneWidget);
    expect(find.text('Bread'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.enterText(find.byType(TextField), 'stea');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Prime shaved steak'), findsOneWidget);
    expect(find.text('Milk 2% 1gal'), findsNothing);
  });

  testWidgets('price history: names read, usual price per store, and a link suggestion', (tester) async {
    await tester.runAsync(() => repo.saveReceipt(ReceiptDraft(
          storeName: 'Whole Foods',
          purchasedAt: DateTime(2026, 10, 21),
          lines: [DraftLine(name: 'MILK 2% 1 GAL', lineTotalCents: 494)],
          taxCents: 0,
        )));
    final milk = (await tester.runAsync(repo.products))!.firstWhere((p) => p.displayName == 'MILK 2% 1GAL');
    await pump(tester, PriceHistoryScreen(repo: repo, product: milk));
    expect(find.text('Milk 2% 1gal'), findsOneWidget);
    expect(find.text('↑ 5% since Sep'), findsOneWidget);
    expect(find.text('usual'), findsOneWidget); // one store so far
    expect(find.textContaining('Same as Milk 2% 1 gal at Whole Foods?'), findsOneWidget);
  });
}
