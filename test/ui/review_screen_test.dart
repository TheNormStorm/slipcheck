import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ui/review_screen.dart';

void main() {
  testWidgets('corrected line is saved', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ReceiptRepository(db);
    final draft = ReceiptDraft(
      storeName: 'FreshMart',
      purchasedAt: DateTime(2026, 10, 18),
      lines: [DraftLine(name: 'MLK 2% 1L', lineTotalCents: 499)],
      totalCents: 499,
    );

    await tester.pumpWidget(MaterialApp(
      home: ReviewScreen(repo: repo, draft: draft),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('Items add up to 4.99'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'MLK 2% 1L'), 'Milk 2% 1L');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();

    final products = await tester.runAsync(repo.products);
    expect(products!.single.displayName, 'Milk 2% 1L');
  });
}
