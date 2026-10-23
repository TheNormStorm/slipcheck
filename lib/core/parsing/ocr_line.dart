/// One line of text as returned by OCR, with its bounding box in image pixels.
class OcrLine {
  const OcrLine(this.text, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left, top, right, bottom;

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
}

/// Groups OCR fragments into visual rows.
///
/// OCR engines usually return a receipt's item name and its price as separate
/// lines, because of the gap between the columns. Fragments whose vertical
/// centre falls inside an existing row's band are joined, left to right, with
/// two spaces so the column gap survives into the parser.
List<String> groupIntoRows(List<OcrLine> lines) {
  final sorted = [...lines.where((l) => l.text.trim().isNotEmpty)]
    ..sort((a, b) => a.centerY.compareTo(b.centerY));
  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && _sameRow(row, line)) {
      row.add(line);
    } else {
      rows.add([line]);
    }
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left)))
          .map((l) => l.text.trim())
          .join('  '),
  ];
}

bool _sameRow(List<OcrLine> row, OcrLine line) {
  final top = row.map((l) => l.top).reduce((a, b) => a < b ? a : b);
  final bottom = row.map((l) => l.bottom).reduce((a, b) => a > b ? a : b);
  // Allow a little slack for slightly tilted photos.
  final slack = (bottom - top) * 0.15;
  return line.centerY >= top - slack && line.centerY <= bottom + slack;
}
