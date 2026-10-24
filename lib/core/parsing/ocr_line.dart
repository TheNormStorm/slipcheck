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
///
/// With [acrossWidth], the tilt may also change from left to right (a
/// receipt curling across its width, a camera tipped towards one end): the
/// nearby angles are fitted as a straight line against x, and a line's
/// position is corrected by following that changing tilt back to the
/// middle.
List<String> groupIntoRows(List<OcrLine> lines, {bool acrossWidth = false}) {
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
  List<OcrLine> near(OcrLine l) =>
      [for (final o in measured) if ((o.centerY - l.centerY).abs() <= window) o];
  double localAngle(OcrLine l) {
    final band = near(l);
    return band.isEmpty ? 0 : _weightedMedian([for (final o in band) (o.angle, o.right - o.left)]);
  }

  // How far the row through [l] rises or falls between the middle and l.
  double shift(OcrLine l) {
    if (!acrossWidth) return localAngle(l) * (l.centerX - refX);
    final (a, b) = _fitAngle(near(l), refX);
    // The tilt at x is a + b (x - refX); integrating its tangent from the
    // middle to the line, at the midpoint, is exact for a straight-line fit
    // to second order.
    final dx = l.centerX - refX;
    return math.tan(a + b * dx / 2) * dx;
  }

  final corrected = <OcrLine, double>{
    for (final l in usable) l: l.centerY - shift(l),
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

/// Groups OCR fragments into rows by following each line's own slope, for
/// photos where one tilt per height is not enough: a receipt curling across
/// its width, or a camera tipped towards one end (keystone), bends every row
/// differently from left to right.
///
/// Each fragment gets the slope the measured lines around its height give
/// at its place across the width (their angles fitted as a straight line
/// against x), since one short line's own angle is mostly noise.
/// Neighbouring fragments are linked left to right when their
/// slopes, extended to the gap between them, meet within half a text height;
/// the closest pairs link first and each fragment links once on each side.
/// Every chain of links is a row. Rows are ordered by where they cross the
/// middle of the receipt.
List<String> groupIntoRowsByLinking(List<OcrLine> lines) {
  final usable = lines.where((l) => l.text.trim().isNotEmpty).toList();
  if (usable.isEmpty) return [];

  final h = _median(usable.map((l) => l.lineHeight).toList());
  final minX = usable.map((l) => l.left).reduce(math.min);
  final maxX = usable.map((l) => l.right).reduce(math.max);
  final width = math.max(maxX - minX, h);
  final refX = _median(usable.map((l) => l.centerX).toList());
  final measured = usable.where((l) => l.angle != 0).toList();

  // The tilt fitted across the width at each fragment's height.
  double fitted(OcrLine l) {
    final (a, b) = _fitAngle([for (final o in measured) if ((o.centerY - l.centerY).abs() <= h * 6) o], refX);
    return a + b * (l.centerX - refX);
  }

  final slope = <OcrLine, double>{for (final l in usable) l: math.tan(fitted(l))};
  double yAt(OcrLine l, double x) => l.centerY + slope[l]! * (x - l.centerX);

  final pairs = <(double, OcrLine, OcrLine)>[];
  for (final a in usable) {
    for (final b in usable) {
      if (identical(a, b) || b.left < a.right - h * 0.5 || b.centerX <= a.centerX) continue;
      final xm = (a.right + b.left) / 2;
      final d = (yAt(a, xm) - yAt(b, xm)).abs();
      if (d > h * 0.5) continue;
      pairs.add((d / h + (b.left - a.right).abs() / width, a, b));
    }
  }
  pairs.sort((p, q) => p.$1.compareTo(q.$1));
  final right = <OcrLine, OcrLine>{}, left = <OcrLine, OcrLine>{};
  for (final (_, a, b) in pairs) {
    if (right.containsKey(a) || left.containsKey(b)) continue;
    right[a] = b;
    left[b] = a;
  }

  final rows = <(double, List<OcrLine>)>[];
  for (final start in usable.where((l) => !left.containsKey(l))) {
    final row = [start];
    for (var next = right[start]; next != null; next = right[next]) {
      row.add(next);
    }
    final key = row.map((l) => yAt(l, refX)).reduce((a, b) => a + b) / row.length;
    rows.add((key, row));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, row) in rows) row.map((l) => l.text.trim()).join('  ')];
}

/// The tilt of [lines] as a straight line against x: (angle at [x0], change
/// per pixel). Weighted by width, with one pass dropping lines more than two
/// typical deviations off the fit (short lines whose angle is noise). Too
/// few lines, or too little spread across the width, give a flat fit at the
/// weighted median.
(double, double) _fitAngle(List<OcrLine> lines, double x0) {
  if (lines.isEmpty) return (0, 0);
  final flat = _weightedMedian([for (final o in lines) (o.angle, o.right - o.left)]);
  if (lines.length < 4) return (flat, 0);
  (double, double)? fit(List<OcrLine> ls) {
    var sw = 0.0, sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (final o in ls) {
      final w = o.right - o.left, x = o.centerX - x0, y = o.angle;
      sw += w;
      sx += w * x;
      sy += w * y;
      sxx += w * x * x;
      sxy += w * x * y;
    }
    final mx = sx / sw, my = sy / sw;
    final varX = sxx / sw - mx * mx;
    // Under ~a text column of spread, the slope is not measurable.
    if (varX < 150 * 150) return null;
    final b = (sxy / sw - mx * my) / varX;
    return (my - b * mx, b);
  }

  final first = fit(lines);
  if (first == null) return (flat, 0);
  final residuals = [for (final o in lines) (o.angle - first.$1 - first.$2 * (o.centerX - x0)).abs()];
  final typical = _median(residuals);
  final kept = [
    for (final (i, o) in lines.indexed)
      if (residuals[i] <= math.max(typical * 2, 0.005)) o,
  ];
  return (kept.length >= 4 ? fit(kept) : null) ?? first;
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
