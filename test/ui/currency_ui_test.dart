import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/checks.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ui/analytics_screen.dart';
import 'package:slipcheck/ui/compare_screen.dart';
import 'package:slipcheck/ui/receipts_screen.dart';
import 'package:slipcheck/ui/review_screen.dart';
import 'package:slipcheck/ui/theme/app_theme.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;
  late int usd, jmd;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    usd = await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 10, 22),
      lines: [DraftLine(name: 'MILK', lineTotalCents: 429)],
      taxCents: 0,
    ));
    await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 10, 23),
      lines: [DraftLine(name: 'MILK', lineTotalCents: 449)],
      taxCents: 0,
    ));
    jmd = await repo.saveReceipt(ReceiptDraft(
      storeName: 'C&M Meats',
      purchasedAt: DateTime(2026, 10, 24),
      lines: [DraftLine(name: 'MUTTON IMP', quantity: 3, lineTotalCents: 285000)],
      taxCents: 0,
      currency: 'JMD',
    ));
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 3000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildSlipTheme(Brightness.light), home: screen));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('receipts in two currencies are never added together', (tester) async {
    await pump(tester, ReceiptsScreen(repo: repo));
    // October: 8.78 in dollars and 2,850.00 in Jamaican dollars, side by side.
    expect(find.text(r'8.78 · J$2,850.00'), findsOneWidget);
    expect(find.text(r'J$2,850.00'), findsOneWidget); // the C&M card
    expect(find.text('4.49'), findsOneWidget); // main currency: no symbol
  });

  testWidgets('Insights shows one currency at a time', (tester) async {
    await pump(tester, AnalyticsScreen(repo: repo, now: DateTime(2026, 10, 24)));
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('JMD'), findsOneWidget);
    expect(find.textContaining('8.78'), findsWidgets);
    expect(find.textContaining('2,858.78'), findsNothing); // never 8.78 + 2,850.00
    expect(find.text('C&M Meats'), findsNothing); // a JMD store, not in the dollar chart's legend
    await tester.tap(find.text('JMD'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('2,850.00'), findsWidgets);
    expect(find.textContaining('8.78'), findsNothing);
    expect(find.text(r'October 2026: J$2,850.00'), findsOneWidget); // under the chart
  });

  testWidgets('receipts in different currencies are not compared', (tester) async {
    await pump(tester, CompareScreen(repo: repo, beforeId: usd, afterId: jmd));
    expect(find.textContaining('different currencies (USD and JMD)'), findsOneWidget);
  });

  testWidgets("Check it: the store's currency, a chip to change it, and the receipt's checks", (tester) async {
    final draft = ReceiptDraft(
      storeName: 'C&M Meats',
      purchasedAt: DateTime(2026, 10, 25),
      lines: [
        DraftLine(name: 'SPARE RIBS', quantity: 3, lineTotalCents: 165000, taxCode: 'T'),
        DraftLine(name: 'RICE', lineTotalCents: 50000, taxCode: 'F'),
      ],
      subtotalCents: 215000,
      taxCents: 24750,
      taxLines: const [TaxLine(24750, ratePercent: 15)],
      printedItemCount: 4,
    );
    await pump(tester, ReviewScreen(repo: repo, draft: draft));
    expect(find.text('JMD'), findsOneWidget); // C&M's last receipt was in JMD
    expect(find.text('Tax checks out: 15% of the T lines'), findsOneWidget);
    expect(find.text('4 items, as printed'), findsOneWidget);

    await tester.tap(find.text('JMD'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TTD'));
    await tester.pumpAndSettle();
    expect(find.text('TTD'), findsOneWidget);
    expect(draft.currency, 'TTD');
  });
}
