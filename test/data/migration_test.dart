import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';

void main() {
  test('upgrading to v4 removes card details from saved OCR text', () async {
    final dir = Directory.systemTemp.createTempSync('slipcheck_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    // A database as version 3 left it: OCR text with the card section.
    var db = AppDatabase(NativeDatabase(file));
    await db.into(db.receipts).insert(ReceiptsCompanion.insert(
          purchasedAt: DateTime(2026, 10, 22),
          source: 'photo',
          ocrText: const Value('MILK  4.29\nTOTAL  4.29\nCARD INFORMATION:\nAccount:  1111\n'
              'Approval #:  999999'),
        ));
    await db.customStatement('PRAGMA user_version = 3');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final text = (await db.select(db.receipts).getSingle()).ocrText!;
    await db.close();
    expect(text, 'MILK  4.29\nTOTAL  4.29');
  });

  test('upgrading to v5 adds the settings table', () async {
    final dir = Directory.systemTemp.createTempSync('slipcheck_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await db.select(db.receipts).get();
    await db.customStatement('DROP TABLE settings');
    await db.customStatement('PRAGMA user_version = 4');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final repo = ReceiptRepository(db);
    expect(await repo.hasSeen('onboarding'), isFalse);
    await repo.markSeen('onboarding');
    await repo.markSeen('onboarding');
    expect(await repo.hasSeen('onboarding'), isTrue);
    await db.close();
  });

  test('upgrading to v6 works out the currency of receipts saved as US dollars', () async {
    final dir = Directory.systemTemp.createTempSync('slipcheck_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/app.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    Future<int> receipt(String text) => db.into(db.receipts).insert(ReceiptsCompanion.insert(
          purchasedAt: DateTime(2026, 10, 24),
          source: 'photo',
          ocrText: Value(text),
        ));
    final cm = await receipt('C&M MEATS & GROCERIES\nMAYPEN, CLARENDON\nTRN# D01 354-337-0003\nTotal \$5,460.00');
    final mb = await receipt('MARKET BASKET\nMA 6.25% Sales Tax 1.57\nTOTAL 362.90');
    final unsure = await receipt('CORNER SHOP\nTOTAL 1.99');
    await db.customStatement('PRAGMA user_version = 5');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    Future<String> currencyOf(int id) async =>
        (await (db.select(db.receipts)..where((r) => r.id.equals(id))).getSingle()).currency;
    expect(await currencyOf(cm), 'JMD');
    expect(await currencyOf(mb), 'USD');
    expect(await currencyOf(unsure), 'USD'); // left as it was
    await db.close();
  });
}
