import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/parsing/ocr_line.dart';
import '../core/parsing/receipt_parser.dart';

class ReadResult {
  ReadResult(this.imagePath, this.rows, this.parsed);

  /// Where the photo was copied inside the app's own storage.
  final String imagePath;
  final List<String> rows;
  final ParsedReceipt parsed;
}

/// Reads a receipt photo entirely on the device with ML Kit's bundled
/// Latin text model, then parses it.
class ReceiptReader {
  ReceiptReader({this.parser = const ReceiptParser()});

  final ReceiptParser parser;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<ReadResult> read(String pickedPath) async {
    final imagePath = await _keepCopy(pickedPath);
    final recognized =
        await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final lines = [
      for (final block in recognized.blocks)
        for (final line in block.lines)
          OcrLine.fromCorners(line.text, [
            for (final pt in line.cornerPoints) (pt.x.toDouble(), pt.y.toDouble()),
          ]),
    ];
    await _saveOcrDump(imagePath, lines);
    final rows = groupIntoRows(lines);
    return ReadResult(imagePath, rows, parser.parse(rows));
  }

  Future<String> _keepCopy(String source) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    await dir.create(recursive: true);
    final target = p.join(dir.path,
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(source)}');
    await File(source).copy(target);
    return target;
  }

  /// Writes the raw OCR lines next to the photo as JSON. They are what a
  /// parser test fixture is made from when a receipt reads badly; on Android
  /// a copy also goes to the app's external files folder, reachable over USB
  /// (Android/data/com.slipcheck.slipcheck/files/ocr).
  Future<void> _saveOcrDump(String imagePath, List<OcrLine> lines) async {
    final json = jsonEncode([for (final l in lines) l.toJson()]);
    await File('${p.withoutExtension(imagePath)}.ocr.json').writeAsString(json);
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      if (external == null) return;
      final dir = Directory(p.join(external.path, 'ocr'));
      await dir.create(recursive: true);
      await File(p.join(dir.path, '${p.basenameWithoutExtension(imagePath)}.json'))
          .writeAsString(json);
    }
  }

  Future<void> close() => _recognizer.close();
}
