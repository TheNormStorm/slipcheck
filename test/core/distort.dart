import 'dart:math' as math;

import 'package:slipcheck/core/parsing/ocr_line.dart';

/// Moves a point of the photo, as a camera at another angle would.
typedef Warp = (double, double) Function(double x, double y);

/// The whole photo turned by [degrees] (clockwise) about ([cx], [cy]).
Warp rotation(double degrees, {double cx = 1500, double cy = 2000}) {
  final a = degrees * math.pi / 180;
  final c = math.cos(a), s = math.sin(a);
  return (x, y) => (cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c);
}

/// A camera tipped towards the top or bottom of the receipt: rows near one
/// end come out narrower and closer together, so the left and right edges
/// lean in (keystone). [k] is the change in scale per pixel down the photo.
Warp keystone(double k, {double cx = 1500, double y0 = 0}) => (x, y) {
      final scale = 1 + k * (y - y0);
      return (cx + (x - cx) * scale, y0 + (y - y0) * (1 + k * (y - y0) / 2));
    };

/// A receipt curling: each row bends into an arc, its ends [sag] pixels
/// lower (or higher, negative) than its middle at the photo's half width.
Warp curl(double sag, {double cx = 1500, double halfWidth = 1200}) =>
    (x, y) => (x, y + sag * math.pow((x - cx) / halfWidth, 2));

Warp then(Warp a, Warp b) => (x, y) {
      final (x1, y1) = a(x, y);
      return b(x1, y1);
    };

/// [lines] as OCR would report them after [warp]: each line's own corners
/// are moved and its box and angle measured again. Like ML Kit, every
/// [zeroEvery]th line reports an upright box with angle 0.
List<OcrLine> distort(List<OcrLine> lines, Warp warp, {int zeroEvery = 3}) {
  final out = <OcrLine>[];
  for (final (i, l) in lines.indexed) {
    final h = l.lineHeight, w = l.right - l.left;
    final cx = l.centerX, cy = l.centerY;
    final c = math.cos(l.angle), s = math.sin(l.angle);
    (double, double) corner(double dx, double dy) => warp(cx + dx * c - dy * s, cy + dx * s + dy * c);
    final corners = [
      corner(-w / 2, -h / 2),
      corner(w / 2, -h / 2),
      corner(w / 2, h / 2),
      corner(-w / 2, h / 2),
    ];
    final moved = OcrLine.fromCorners(l.text, corners, confidence: l.confidence);
    out.add(zeroEvery > 0 && i % zeroEvery == 0
        ? OcrLine(moved.text,
            left: moved.left, top: moved.top, right: moved.right, bottom: moved.bottom, angle: 0)
        : moved);
  }
  return out;
}
