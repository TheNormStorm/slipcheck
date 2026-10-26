import '../categories.dart';
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

/// Rows that show a photo pairing names with a neighbour's price, as a
/// curling or tilted photo does: a department heading with a price
/// ("ICE CREAM  4.99 T"), or a price and tax code with no name ("3.29 T").
/// (A totals block's amounts on rows of their own have no code.)
bool isMisPaired(String row) {
  final m = RegExp(r'^(.*?)\s*\$?\d{1,6}[.,]\d{2}\s*([A-Z]?)\s*$').firstMatch(row);
  if (m == null) return false;
  final name = m.group(1)!.trim();
  return name.isEmpty ? m.group(2)!.isNotEmpty : isDepartmentHeading(name);
}

/// How many of [rows] look paired with the wrong price (see [isMisPaired]).
int misPairedRows(Iterable<String> rows) => rows.where(isMisPaired).length;
