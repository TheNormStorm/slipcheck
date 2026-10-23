import 'ocr_line.dart';

/// Where a receipt's card section starts: "CARD INFORMATION", account,
/// approval and reference numbers, terminal codes (AID, TVR, ...), or a
/// masked card number ("************1234").
final _cardLine = RegExp(
  r'^\s*(card\s+(information|info|type|#|no|number|name)|account|acct|approval|appr\b|'
  r'auth(orization)?\s*(#|code|no)|reference|ref\s*#|aid\b|tvr\b|iad\b|arc\b|mid\b|tid\b|'
  r'entry\s*(method|mode)?\s*:|application\s*(label|id))'
  r'|[*xX]{4,}\s*\d{4}\b',
  caseSensitive: false,
);

bool isCardLine(String text) => _cardLine.hasMatch(text);

/// The rows above the card section. Totals, tax and the item list are
/// kept; card numbers, approval codes and terminal data are not stored.
List<String> withoutPaymentSection(List<String> rows) {
  final cut = rows.indexWhere(isCardLine);
  return cut < 0 ? rows : rows.sublist(0, cut);
}

/// The OCR lines above the first card-section line of a photo.
List<OcrLine> withoutPaymentLines(List<OcrLine> lines) {
  final card = lines.where((l) => isCardLine(l.text));
  if (card.isEmpty) return lines;
  final top = card.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  return [for (final l in lines) if (l.centerY < top) l];
}
