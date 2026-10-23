import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ui/line_item_row.dart';
import 'package:slipcheck/ui/review_screen.dart';

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
    expect(find.text('Matches the receipt subtotal'), findsOneWidget);
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

    await tester.tap(find.text('Save receipt'));
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
}
