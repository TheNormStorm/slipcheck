import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/data/backup.dart';
import 'package:slipcheck/data/database.dart';
import 'package:slipcheck/data/receipt_repository.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('slipcheck_backup'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<ReceiptRepository> seeded(String path) async {
    final repo = ReceiptRepository(AppDatabase(NativeDatabase(File(path))));
    await repo.saveReceipt(ReceiptDraft(
      storeName: 'Market Basket',
      purchasedAt: DateTime(2026, 10, 22),
      lines: [
        DraftLine(name: 'MILK 2% 1GAL', lineTotalCents: 429, code: '012000171741'),
        DraftLine(name: 'BANANAS, ORGANIC', quantity: 2.17, unit: 'lb', lineTotalCents: 150),
        DraftLine(name: 'CHEDDAR', lineTotalCents: 799, discountCents: 100),
      ],
    ));
    return repo;
  }

  test('a backup holds every receipt and reopens as the app database', () async {
    final repo = await seeded('${dir.path}/app.sqlite');
    final backup = await Backup.writeTo(repo.db, '${dir.path}/backup.sqlite');
    await repo.db.close();
    expect(await Backup.isBackup(backup), isTrue);

    final restored = ReceiptRepository(AppDatabase(NativeDatabase(backup)));
    expect((await restored.receipts()).single.itemCount, 3);
    expect(await restored.products(), hasLength(3));
    await restored.db.close();
  });

  test('other files are not taken for backups', () async {
    final text = File('${dir.path}/notes.sqlite')..writeAsStringSync('hello' * 50);
    expect(await Backup.isBackup(text), isFalse);
  });

  test('CSV export: one row per line, quoted where needed', () async {
    final repo = await seeded('${dir.path}/app.sqlite');
    final lines = (await repo.csvExport()).trim().split('\n');
    await repo.db.close();
    expect(lines.first, startsWith('date,store,item,category,quantity'));
    expect(lines, hasLength(4));
    expect(lines[1], '2026-10-22,Market Basket,MILK 2% 1GAL,Dairy & eggs,1,each,4.29,4.29,0.00,4.29,012000171741,1');
    expect(lines[2], contains('"BANANAS, ORGANIC"'));
    expect(lines[2], contains(',2.17,lb,0.69,1.50,'));
    expect(lines[3], contains(',7.99,1.00,6.99,'));
  });
}
