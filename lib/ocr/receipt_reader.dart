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
          OcrLine(
            line.text,
            left: line.boundingBox.left,
            top: line.boundingBox.top,
            right: line.boundingBox.right,
            bottom: line.boundingBox.bottom,
          ),
    ];
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

  Future<void> close() => _recognizer.close();
}
