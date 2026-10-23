import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ui/analytics_screen.dart';
import 'package:slipcheck/ui/compare_screen.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;
  late int first, second;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    first = await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 9, 12),
      lines: [
        DraftLine(name: 'MILK 2% 1L', lineTotalCents: 469),
        DraftLine(name: 'EGGS 18PK', quantity: 2, lineTotalCents: 598),
        DraftLine(name: 'BREAD', lineTotalCents: 349),
      ],
      taxCents: 0,
    ));
    second = await repo.saveReceipt(ReceiptDraft(
      storeName: 'Whole Foods',
      purchasedAt: DateTime(2026, 10, 20),
      lines: [
        DraftLine(name: 'MILK 2% 1L', lineTotalCents: 529),
        DraftLine(name: 'EGGS 18PK', quantity: 3, lineTotalCents: 897),
        DraftLine(name: 'STEAK', lineTotalCents: 1998),
      ],
      taxCents: 25,
    ));
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
  }

  testWidgets('compare explains the difference', (tester) async {
    await pump(tester, CompareScreen(repo: repo, beforeId: first, afterId: second));
    expect(find.text('You spent \$20.33 more on the second receipt.'), findsOneWidget);
    expect(find.textContaining('+\$19.98 from 1 item only on the second receipt'), findsOneWidget);
    expect(find.text('Price changes'), findsOneWidget);
    expect(find.text('+\$0.60'), findsWidgets); // milk price effect
  });

  testWidgets('analytics shows spending, index and store comparison', (tester) async {
    await pump(tester, AnalyticsScreen(repo: repo));
    expect(find.text('Spending by month'), findsOneWidget);
    expect(find.text('Your price index'), findsOneWidget);
    // Whole Foods milk 5.29 vs 4.69, eggs 2.99 vs 2.99: geometric mean 1.062,
    // so Market Basket is 1 - 1/1.062 = 5.8% cheaper (not 6.2%).
    expect(find.textContaining('Market Basket is 6% cheaper than Whole Foods on the 2 items'),
        findsOneWidget);
    expect(find.text('MILK 2% 1L'), findsWidgets);
  });
}
