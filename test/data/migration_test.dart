import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/database.dart';

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
}
