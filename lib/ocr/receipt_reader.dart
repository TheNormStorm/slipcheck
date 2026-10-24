import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;

import '../core/parsing/ocr_line.dart';
import '../core/parsing/page_quality.dart';
import '../core/parsing/receipt_parser.dart';
import '../core/parsing/redaction.dart';
import '../core/parsing/stitcher.dart';
import '../data/receipt_files.dart';

/// One photo of (part of) a receipt after OCR.
class PageRead {
  PageRead(this.imagePath, this.rows, this.problem, {int? lineCount, this.lines})
      : lineCount = lineCount ?? rows.length;

  /// Where the photo was copied inside the app's own storage.
  final String imagePath;
  final List<String> rows;

  /// Why this photo may read badly (see `pageProblem`), or null.
  final String? problem;

  /// Text lines ML Kit found, before they were grouped into rows.
  final int lineCount;

  /// Those lines with their positions, kept in memory (never saved) so the
  /// rows can be grouped again a different way.
  final List<OcrLine>? lines;

  /// This photo with its rows grouped by [group] instead.
  PageRead regrouped(List<String> Function(List<OcrLine>) group) =>
      PageRead(imagePath, group(lines!), problem, lineCount: lineCount, lines: lines);
}

class ReadResult {
  ReadResult(this.pages, this.stitch, this.parsed, {this.regrouping});

  final List<PageRead> pages;
  final StitchResult stitch;
  final ParsedReceipt parsed;

  /// How the rows were re-grouped to make the receipt add up, or null when
  /// the usual grouping did.
  final String? regrouping;

  List<String> get imagePaths => [for (final page in pages) page.imagePath];
}

/// Other ways to group a photo's lines into rows, for photos taken at an
/// angle, of a curling receipt, or with the phone tipped (see
/// `groupIntoRowsByLinking` and `groupIntoRows(acrossWidth:)`).
final regroupings = <String, List<String> Function(List<OcrLine>)>{
  'rows followed across the tilt': groupIntoRowsByLinking,
  'tilt fitted across the width': (lines) => groupIntoRows(lines, acrossWidth: true),
};

/// Puts [pages] in receipt order (see `bestPageOrder`), stitches them and
/// parses the result. The returned pages are in the order used.
///
/// The receipt checks itself: when its items do not add up to its own
/// subtotal (or total less tax), every photo's rows are grouped again each
/// of the other [regroupings] ways, and a reading that does add up exactly is
/// used instead. A reading that is only closer is not: dropping a line can
/// make it closer by chance.
ReadResult combinePages(List<PageRead> pages, ReceiptParser parser) {
  ReadResult read(List<PageRead> pages, {String? regrouping}) {
    final order = bestPageOrder([for (final page in pages) page.rows]);
    final ordered = [for (final i in order) pages[i]];
    final stitch = stitchPages([for (final page in ordered) page.rows]);
    return ReadResult(ordered, stitch, parser.parse(stitch.rows), regrouping: regrouping);
  }

  final usual = read(pages);
  if (addsUp(usual.parsed) || pages.any((p) => p.lines == null)) return usual;
  for (final MapEntry(key: name, value: group) in regroupings.entries) {
    final other = read([for (final page in pages) page.regrouped(group)], regrouping: name);
    if (addsUp(other.parsed)) return other;
  }
  return usual;
}

/// The items add up exactly to what the receipt says they come to.
bool addsUp(ParsedReceipt r) {
  final expected = r.subtotalCents ?? (r.totalCents == null ? null : r.totalCents! - (r.taxCents ?? 0));
  return r.items.isNotEmpty && expected == r.itemsSumCents;
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
    // The card section is left out of the saved OCR lines.
    await _saveOcrDump(imagePath, withoutPaymentLines(lines));
    return PageRead(imagePath, groupIntoRows(lines), pageProblem(lines), lineCount: lines.length, lines: lines);
  }

  /// See [combinePages].
  ReadResult combine(List<PageRead> pages) => combinePages(pages, parser);

  Future<String> _keepCopy(String source) async {
    final dir = await ReceiptFiles.photosDir();
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
    await File(ReceiptFiles.ocrPathFor(imagePath)).writeAsString(json);
    final external = await ReceiptFiles.externalOcrPathFor(imagePath);
    if (external != null) {
      await File(external).parent.create(recursive: true);
      await File(external).writeAsString(json);
    }
  }

  Future<void> close() => _recognizer.close();
}
