import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:slipcheck/core/update.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';
import 'package:slipcheck/data/update_checker.dart';
import 'package:slipcheck/ocr/receipt_reader.dart';
import 'package:slipcheck/ui/app_actions.dart';
import 'package:slipcheck/ui/theme/app_theme.dart';

class _FakeUpdates extends UpdateChecker {
  const _FakeUpdates(this.release, {this.fail = false});
  final ReleaseInfo? release;
  final bool fail;

  @override
  Future<ReleaseInfo?> latest() async => fail ? throw Exception('offline') : release;
}

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    PackageInfo.setMockInitialValues(
        appName: 'Slipcheck', packageName: 'com.slipcheck.slipcheck', version: '0.10.0', buildNumber: '10', buildSignature: '');
  });
  tearDown(() => db.close());

  Future<void> check(WidgetTester tester, UpdateChecker updates) async {
    final actions = AppActions(ReceiptRepository(db), ReceiptReader(), updates: updates);
    await tester.pumpWidget(MaterialApp(
      theme: buildSlipTheme(Brightness.light),
      home: Builder(
        builder: (context) =>
            TextButton(onPressed: () => actions.checkForUpdates(context), child: const Text('check')),
      ),
    ));
    await tester.tap(find.text('check'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('up to date', (tester) async {
    await check(tester, const _FakeUpdates(ReleaseInfo(version: '0.10.0', pageUrl: 'https://x')));
    expect(find.text("You're up to date"), findsOneWidget);
  });

  testWidgets('no releases yet counts as up to date', (tester) async {
    await check(tester, const _FakeUpdates(null));
    expect(find.text("You're up to date"), findsOneWidget);
  });

  testWidgets('a newer version offers the download', (tester) async {
    await check(tester,
        const _FakeUpdates(ReleaseInfo(version: '0.11.0', pageUrl: 'https://x', apkUrl: 'https://x/a.apk', notes: 'Reads big amounts.')));
    expect(find.text('Slipcheck 0.11.0 is out'), findsOneWidget);
    expect(find.textContaining('Reads big amounts.'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('offline says so', (tester) async {
    await check(tester, const _FakeUpdates(null, fail: true));
    expect(find.text("Couldn't check"), findsOneWidget);
  });
}
