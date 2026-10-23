import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  /// Deletes every photo and OCR dump, including those of scans that were
  /// never saved.
  static Future<void> deleteAll() async {
    for (final dir in [await photosDir(), await externalOcrDir()]) {
      if (dir != null && await dir.exists()) await dir.delete(recursive: true);
    }
  }
}
