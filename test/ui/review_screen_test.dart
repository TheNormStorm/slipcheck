import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ui/line_item_row.dart';
import 'package:slipcheck/ui/review_screen.dart';
import 'package:slipcheck/ui/saved_screen.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
  });
  tearDown(() => db.close());

  Future<void> show(WidgetTester tester, ReceiptDraft draft) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ReviewScreen(repo: repo, draft: draft)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  testWidgets('items are listed with amounts and quantity details', (tester) async {
    await show(tester, ReceiptDraft(
      storeName: 'FreshMart',
      purchasedAt: DateTime(2026, 10, 18),
      lines: [
        DraftLine(name: 'COKE 355ML', quantity: 2, unitPriceCents: 199, lineTotalCents: 398),
        DraftLine(name: 'BANANAS', quantity: 1.234, unit: 'kg', unitPriceCents: 152,
            lineTotalCents: 188),
        DraftLine(name: 'CHEDDAR 400G', lineTotalCents: 799, discountCents: 100),
      ],
      subtotalCents: 1285,
    ));
    expect(find.text('3 items'), findsOneWidget);
    expect(find.text('2 × 1.99'), findsOneWidget);
    expect(find.text('1.234 kg @ 1.52/kg'), findsOneWidget);
    expect(find.text('Discount −1.00'), findsOneWidget);
    expect(find.text('6.99'), findsOneWidget);
    expect(find.text('Matches subtotal 12.85'), findsOneWidget);
  });

  testWidgets('a total that does not add up is called out', (tester) async {
    await show(tester, ReceiptDraft(
      storeName: 'QuickStop',
      purchasedAt: DateTime(2026, 10, 21),
      lines: [DraftLine(name: 'CHIPS', lineTotalCents: 249)],
      totalCents: 548,
    ));
    expect(find.textContaining('off by 2.99'), findsOneWidget);
  });

  testWidgets('a line is corrected in its sheet and saved', (tester) async {
    await show(tester, ReceiptDraft(
      storeName: 'FreshMart',
      purchasedAt: DateTime(2026, 10, 18),
      lines: [DraftLine(name: 'MLK 2% 1L', lineTotalCents: 499)],
      totalCents: 499,
    ));

    await tester.tap(find.text('MLK 2% 1L'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'MLK 2% 1L'), 'Milk 2% 1L');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Milk 2% 1L'), findsOneWidget);

    await tester.tap(find.textContaining('Save ·'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    final products = await tester.runAsync(repo.products);
    expect(products!.single.displayName, 'Milk 2% 1L');
  });

  testWidgets('a line can be deleted from its sheet', (tester) async {
    await show(tester, ReceiptDraft(
      storeName: 'FreshMart',
      purchasedAt: DateTime(2026, 10, 18),
      lines: [
        DraftLine(name: 'BREAD', lineTotalCents: 349),
        DraftLine(name: 'CASHIER: 12', lineTotalCents: 1200),
      ],
    ));
    await tester.tap(find.text('CASHIER: 12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('CASHIER: 12'), findsNothing);
    expect(find.text('1 item'), findsOneWidget);
  });

  test('quantity detail text', () {
    expect(quantityDetail(DraftLine(name: 'x', lineTotalCents: 499)), isNull);
    expect(quantityDetail(DraftLine(name: 'x', quantity: 3, lineTotalCents: 897)), '3 × 2.99');
    expect(
        quantityDetail(DraftLine(name: 'x', quantity: 2.17, unit: 'lb', lineTotalCents: 150)),
        '2.17 lb @ 0.69/lb');
  });

  testWidgets('saving without a store asks for one', (tester) async {
    await show(tester, ReceiptDraft(
      storeName: '',
      purchasedAt: DateTime(2026, 10, 18),
      lines: [DraftLine(name: 'MILK', lineTotalCents: 469)],
    ));
    await tester.tap(find.textContaining('Save ·'));
    await tester.pumpAndSettle();
    expect(find.text('Which store?'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Market Basket');
    await tester.tap(find.text('OK'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect((await tester.runAsync(repo.receipts))!.single.storeName, 'Market Basket');
  });

  testWidgets('going back asks before discarding', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReviewScreen(
              repo: repo,
              draft: ReceiptDraft(storeName: 'X', purchasedAt: DateTime(2026, 10, 18), lines: []),
            ),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard this receipt?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Type it in'), findsOneWidget);
  });

  testWidgets('saving shows the celebration, then reports what was tracked', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    // An earlier visit, so the milk's price can go up.
    await tester.runAsync(() => repo.saveReceipt(ReceiptDraft(
          storeName: 'FreshMart',
          purchasedAt: DateTime(2026, 10, 1),
          lines: [DraftLine(name: 'MILK 2% 1L', lineTotalCents: 449)],
          totalCents: 449,
        )));
    SavedNote? reported;
    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(
        repo: repo,
        onSaved: (n) => reported = n,
        draft: ReceiptDraft(
          storeName: 'FreshMart',
          purchasedAt: DateTime(2026, 10, 18),
          lines: [
            DraftLine(name: 'MILK 2% 1L', lineTotalCents: 499),
            DraftLine(name: 'BREAD', lineTotalCents: 349),
          ],
          totalCents: 848,
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('↑ 11% vs usual 4.49'), findsOneWidget);

    await tester.tap(find.text('Save · 8.48'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('SAVED'), findsOneWidget);
    expect(find.text('Tracked! 2 items'), findsOneWidget);
    expect(find.text('↑ 1 went up'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(reported?.itemCount, 2);
    expect(reported?.moves.up, 1);
  });

  testWidgets('a total that does not match asks before saving', (tester) async {
    await show(tester, ReceiptDraft(
      storeName: 'QuickStop',
      purchasedAt: DateTime(2026, 10, 21),
      lines: [DraftLine(name: 'CHIPS', lineTotalCents: 249)],
      totalCents: 548,
    ));
    await tester.tap(find.textContaining('Save ·'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Off by 2.99, save anyway?'), findsOneWidget);
    await tester.tap(find.text('Check it'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(repo.receipts), isEmpty);
  });
}
