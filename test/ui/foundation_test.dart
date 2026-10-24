import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/ocr/receipt_reader.dart';
import 'package:slipcheck/ui/app_actions.dart';
import 'package:slipcheck/ui/components/brand.dart';
import 'package:slipcheck/ui/motion/motion.dart';
import 'package:slipcheck/ui/shell.dart';
import 'package:slipcheck/ui/theme/app_theme.dart';
import 'package:slipcheck/ui/theme/tokens.dart';

void main() {
  late AppDatabase db;
  late ReceiptRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = ReceiptRepository(db);
    await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime.now(),
      lines: [DraftLine(name: 'MILK 2% 1GAL', lineTotalCents: 429)],
      totalCents: 429,
    ));
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('shell: tabs and scan button (${brightness.name})', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildSlipTheme(brightness),
        home: AppShell(actions: AppActions(repo, ReceiptReader())),
      ));
      await settle(tester);
      expect(find.text('Slipcheck'), findsOneWidget);
      expect(find.text('Market Basket'), findsWidgets);
      expect(find.bySemanticsLabel('Scan a receipt'), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(AppShell))).extension<SlipTokens>()!.punchy,
          brightness == Brightness.dark);

      await tester.tap(find.bySemanticsLabel('Receipts'));
      await settle(tester);
      expect(find.text('By store'), findsOneWidget);
      await tester.tap(find.text('By store'));
      await settle(tester);
      expect(find.textContaining('1 trip'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Insights'));
      await settle(tester);
      expect(find.text('Insights'), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Items'));
      await settle(tester);
      expect(find.text('Milk 2% 1gal'), findsOneWidget);
    });
  }

  testWidgets('with reduced motion, counters and entrances show their end state at once', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildSlipTheme(Brightness.light),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(
          body: Column(children: [
            CountUp(cents: 10986, style: slipText(20, 900)),
            const Rise(index: 5, child: Text('risen')),
            const SlipMascot(),
            const LogoMark(sweep: true),
          ]),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('109.86'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.text('risen'), matching: find.byType(Opacity)).first);
    expect(opacity.opacity, 1);
  });

  testWidgets('open screens refresh when data changes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildSlipTheme(Brightness.light),
      home: AppShell(actions: AppActions(repo, ReceiptReader())),
    ));
    await settle(tester);
    expect(find.text('Whole Foods'), findsNothing);
    await tester.runAsync(() => repo.saveReceipt(ReceiptDraft(
          storeName: 'Whole Foods',
          purchasedAt: DateTime.now(),
          lines: [DraftLine(name: 'MILK', lineTotalCents: 499)],
        )));
    await settle(tester);
    expect(find.text('Whole Foods'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
