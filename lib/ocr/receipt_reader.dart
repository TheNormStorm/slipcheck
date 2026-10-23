import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/parsing/ocr_line.dart';
import '../core/parsing/page_quality.dart';
import '../core/parsing/receipt_parser.dart';
import '../core/parsing/stitcher.dart';

/// One photo of (part of) a receipt after OCR.
class PageRead {
  PageRead(this.imagePath, this.rows, this.problem);

  /// Where the photo was copied inside the app's own storage.
  final String imagePath;
  final List<String> rows;

  /// Why this photo may read badly (see `pageProblem`), or null.
  final String? problem;
}

class ReadResult {
  ReadResult(this.pages, this.stitch, this.parsed);

  final List<PageRead> pages;
  final StitchResult stitch;
  final ParsedReceipt parsed;

  List<String> get imagePaths => [for (final page in pages) page.imagePath];
}

/// Reads receipt photos entirely on the device with ML Kit's bundled Latin
/// text model, joins the pages of a long receipt, then parses it.
class ReceiptReader {
  ReceiptReader({this.parser = const ReceiptParser()});

  final ReceiptParser parser;
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<PageRead> readPage(String pickedPath) async {
    final imagePath = await _keepCopy(pickedPath);
    final recognized =
        await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    final lines = [
      for (final block in recognized.blocks)
        for (final line in block.lines)
          OcrLine.fromCorners(
            line.text,
            [for (final pt in line.cornerPoints) (pt.x.toDouble(), pt.y.toDouble())],
            confidence: line.confidence,
          ),
    ];
    await _saveOcrDump(imagePath, lines);
    return PageRead(imagePath, groupIntoRows(lines), pageProblem(lines));
  }

  /// Stitches [pages] (top of the receipt first) and parses the result.
  ReadResult combine(List<PageRead> pages) {
    final stitch = stitchPages([for (final page in pages) page.rows]);
    return ReadResult(pages, stitch, parser.parse(stitch.rows));
  }

  Future<String> _keepCopy(String source) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    await dir.create(recursive: true);
    final target = p.join(dir.path,
        '${DateTime.now().microsecondsSinceEpoch}${p.extension(source)}');
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
