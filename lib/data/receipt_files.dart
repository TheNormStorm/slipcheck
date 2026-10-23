import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/parsing/ocr_line.dart';
import '../core/parsing/redaction.dart';

/// Where receipt photos and their OCR dumps live, and how they are removed.
///
/// Each photo is copied into the app's private `receipts/` folder with its
/// OCR lines beside it (`<photo>.ocr.json`). On Android a second copy of the
/// OCR lines goes to the app's external folder (`files/ocr/`), reachable over
/// USB for turning bad reads into test fixtures.
class ReceiptFiles {
  static Future<Directory> photosDir() async =>
      Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));

  static Future<Directory?> externalOcrDir() async {
    if (!Platform.isAndroid) return null;
    final external = await getExternalStorageDirectory();
    return external == null ? null : Directory(p.join(external.path, 'ocr'));
  }

  static String ocrPathFor(String photoPath) => '${p.withoutExtension(photoPath)}.ocr.json';

  static Future<String?> externalOcrPathFor(String photoPath) async {
    final dir = await externalOcrDir();
    return dir == null ? null : p.join(dir.path, '${p.basenameWithoutExtension(photoPath)}.json');
  }

  /// Deletes a photo and both copies of its OCR lines.
  static Future<void> deleteFor(String photoPath) async {
    for (final path in [photoPath, ocrPathFor(photoPath), await externalOcrPathFor(photoPath)]) {
      if (path == null) continue;
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  /// Rewrites OCR dumps saved before card sections were left out, once.
  static Future<void> redactExistingDumps() async {
    final photos = await photosDir();
    final marker = File(p.join(photos.path, '.card-sections-removed'));
    if (!await photos.exists() || await marker.exists()) return;
    for (final dir in [photos, await externalOcrDir()]) {
      if (dir == null || !await dir.exists()) continue;
      await for (final f in dir.list()) {
        if (f is! File || !f.path.endsWith('.json')) continue;
        final lines = [
          for (final l in jsonDecode(await f.readAsString()) as List)
            OcrLine.fromJson(l as Map<String, dynamic>),
        ];
        final kept = withoutPaymentLines(lines);
        if (kept.length != lines.length) {
          await f.writeAsString(jsonEncode([for (final l in kept) l.toJson()]));
        }
      }
    }
    await marker.writeAsString('');
  }

  /// Deletes every photo and OCR dump, including those of scans that were
  /// never saved.
  static Future<void> deleteAll() async {
    for (final dir in [await photosDir(), await externalOcrDir()]) {
      if (dir != null && await dir.exists()) await dir.delete(recursive: true);
    }
  }
}
