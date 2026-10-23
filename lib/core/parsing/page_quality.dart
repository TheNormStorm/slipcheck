import 'ocr_line.dart';

/// Why a photo is unlikely to read well, or null when it looks fine.
///
/// Thresholds are first guesses: ML Kit wants characters roughly 16 px or
/// taller, and its line confidence drops on blur and faded thermal print.
String? pageProblem(List<OcrLine> lines) {
  if (lines.length < 3) return 'No receipt text found';
  final heights = [for (final l in lines) l.lineHeight]..sort();
  if (heights[heights.length ~/ 2] < 18) return 'Text is very small — move closer';
  final conf = [for (final l in lines) if (l.confidence != null) l.confidence!]..sort();
  if (conf.length >= 3 && conf[conf.length ~/ 2] < 0.5) return 'Blurry or faded';
  return null;
}
