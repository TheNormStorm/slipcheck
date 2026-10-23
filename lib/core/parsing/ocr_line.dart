import 'dart:math' as math;

/// One line of text as returned by OCR.
///
/// [left]..[bottom] is the axis-aligned bounding box in image pixels. On a
/// tilted photo that box is taller than the text, so the line's own
/// [angle] (radians, clockwise positive) and [lineHeight] are kept as well.
class OcrLine {
  const OcrLine(
    this.text, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.angle = 0,
    this.height,
    this.confidence,
  });

  /// Builds a line from its four corners, clockwise from top-left.
  factory OcrLine.fromCorners(String text, List<(double, double)> c, {double? confidence}) {
    final xs = c.map((p) => p.$1), ys = c.map((p) => p.$2);
    final (x0, y0) = c[0];
    final (x1, y1) = c[1];
    final (x3, y3) = c[3];
    return OcrLine(
      text,
      left: xs.reduce(math.min),
      top: ys.reduce(math.min),
      right: xs.reduce(math.max),
      bottom: ys.reduce(math.max),
      angle: math.atan2(y1 - y0, x1 - x0),
      height: math.sqrt(math.pow(x3 - x0, 2) + math.pow(y3 - y0, 2)),
      confidence: confidence,
    );
  }

  factory OcrLine.fromJson(Map<String, dynamic> j) => OcrLine(
        j['text'] as String,
        left: (j['l'] as num).toDouble(),
        top: (j['t'] as num).toDouble(),
        right: (j['r'] as num).toDouble(),
        bottom: (j['b'] as num).toDouble(),
        angle: (j['a'] as num?)?.toDouble() ?? 0,
        height: (j['h'] as num?)?.toDouble(),
        confidence: (j['c'] as num?)?.toDouble(),
      );

  final String text;
  final double left, top, right, bottom, angle;

  /// Text height measured across the line; null means use the box height.
  final double? height;

  /// Recognition confidence 0..1 (ML Kit reports it on Android only).
  final double? confidence;

  double get lineHeight => height ?? bottom - top;
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  Map<String, dynamic> toJson() => {
        'text': text,
        'l': left.round(), 't': top.round(), 'r': right.round(), 'b': bottom.round(),
        'a': double.parse(angle.toStringAsFixed(4)),
        'h': double.parse(lineHeight.toStringAsFixed(1)),
        if (confidence != null) 'c': double.parse(confidence!.toStringAsFixed(3)),
      };
}

/// Groups OCR fragments into visual rows.
///
/// OCR engines return a receipt's item name and its price as separate lines
/// because of the gap between the columns. Putting them back together has to
/// undo the photo's tilt, and a receipt held in the hand curls, so the tilt
/// differs from top to bottom: near the top of a real receipt the prices sat
/// 26 px above their names, at the bottom level with them. Each line's
/// position is therefore corrected with the width-weighted median measured
/// angle of the lines around it, then fragments whose corrected centres are within half a text height of
/// a row's centre join that row, left to right, separated by two spaces so the
/// column gap survives.
///
/// A row is anchored on its average centre, never on the union of its boxes:
/// a growing band chains neighbouring rows together on long receipts.
List<String> groupIntoRows(List<OcrLine> lines) {
  final usable = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (usable.isEmpty) return [];

  final textHeight = _median(usable.map((l) => l.lineHeight).toList());
  final refX = _median(usable.map((l) => l.centerX).toList());
  final window = textHeight * 6;
  // ML Kit returns an unrotated box (angle exactly 0) for many lines whose
  // neighbours measure a clear tilt, so a 0 means "not measured". Short lines
  // measure angle poorly (a pixel of error is a large angle), so each angle
  // is weighted by the line's width.
  final measured = usable.where((l) => l.angle != 0).toList();
  double localAngle(OcrLine l) {
    final near = [
      for (final o in measured)
        if ((o.centerY - l.centerY).abs() <= window) (o.angle, o.right - o.left),
    ];
    return near.isEmpty ? 0 : _weightedMedian(near);
  }

  final corrected = <OcrLine, double>{
    for (final l in usable) l: l.centerY - localAngle(l) * (l.centerX - refX),
  };

  final tolerance = textHeight * 0.5;
  final sorted = [...usable]..sort((a, b) => corrected[a]!.compareTo(corrected[b]!));

  final rows = <List<OcrLine>>[];
  final centres = <double>[];
  for (final line in sorted) {
    final y = corrected[line]!;
    var best = -1;
    var bestDist = double.infinity;
    // Only the last few rows can be close, since lines arrive sorted.
    for (var i = rows.length - 1; i >= 0 && i >= rows.length - 3; i--) {
      final d = (y - centres[i]).abs();
      if (d <= tolerance && d < bestDist) {
        best = i;
        bestDist = d;
      }
    }
    if (best == -1) {
      rows.add([line]);
      centres.add(y);
    } else {
      rows[best].add(line);
      centres[best] =
          rows[best].map((l) => corrected[l]!).reduce((a, b) => a + b) / rows[best].length;
    }
  }
  return [
    for (final row in rows)
      (row..sort((a, b) => a.left.compareTo(b.left))).map((l) => l.text.trim()).join('  '),
  ];
}

double _median(List<double> values) {
  final s = [...values]..sort();
  return s[s.length ~/ 2];
}

double _weightedMedian(List<(double, double)> valueWeights) {
  final s = [...valueWeights]..sort((a, b) => a.$1.compareTo(b.$1));
  final half = s.fold(0.0, (sum, e) => sum + e.$2) / 2;
  var acc = 0.0;
  for (final (value, weight) in s) {
    acc += weight;
    if (acc >= half) return value;
  }
  return s.last.$1;
}
