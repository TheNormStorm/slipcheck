import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';

/// Backups of the database, to keep receipts beyond this phone. Photos are
/// not included: the database holds every receipt, line, item, link and
/// category, which is what the history and analytics need.
class Backup {
  /// Writes a consistent copy of [db] to [target] (SQLite `VACUUM INTO`).
  static Future<File> writeTo(AppDatabase db, String target) async {
    final file = File(target);
    if (await file.exists()) await file.delete();
    await db.customStatement('VACUUM INTO ?', [target]);
    return file;
  }

  /// A dated backup file in the app's temporary folder, ready to share.
  static Future<File> create(AppDatabase db) async {
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final dir = await getTemporaryDirectory();
    return writeTo(db, p.join(dir.path, 'slipcheck-backup-$stamp.sqlite'));
  }

  /// Whether [file] is a Slipcheck backup: an SQLite file with its tables.
  static Future<bool> isBackup(File file) async {
    if (!await file.exists() || await file.length() < 100) return false;
    final header = await file.openRead(0, 16).expand((b) => b).toList();
    if (String.fromCharCodes(header) != 'SQLite format 3\u0000') return false;
    // Opened read-only and directly, so the picked file is never changed.
    try {
      final probe = sqlite3.open(file.path, mode: OpenMode.readOnly);
      try {
        probe.select('SELECT count(*) FROM receipts');
        probe.select('SELECT count(*) FROM line_items');
        return true;
      } finally {
        probe.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Replaces the app's database with [backup]. The app database must be
  /// closed first; it is upgraded to the current version when next opened.
  static Future<void> restore(File backup) async {
    final docs = await getApplicationDocumentsDirectory();
    final target = File(p.join(docs.path, 'slipcheck.sqlite'));
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('${target.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await backup.copy(target.path);
  }
}
