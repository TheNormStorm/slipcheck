import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';

/// The "Scan line" mark: a receipt with a scan bar across it, on an orange
/// tile. Drawn on the handoff's 100×100 grid. With [sweep] the bar moves
/// ±15 units as a loading indicator (2.4s), unless motion is reduced.
class LogoMark extends StatefulWidget {
  const LogoMark({super.key, this.size = 32, this.sweep = false, this.dark});
  final double size;
  final bool sweep;

  /// Paper and bar colours for dark backgrounds; defaults to the theme.
  final bool? dark;

  @override
  State<LogoMark> createState() => _LogoMarkState();
}

class _LogoMarkState extends State<LogoMark> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.sweep && !Motion.reduced(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark ?? Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: LogoPainter(
            dark: dark,
            barOffset: widget.sweep ? (Curves.easeInOut.transform(_c.value) * 30 - 15) : 0,
          ),
        ),
      ),
    );
  }
}

class LogoPainter extends CustomPainter {
  LogoPainter({this.dark = false, this.barOffset = 0, this.tile = true});
  final bool dark;
  final double barOffset;

  /// False draws only the receipt and bar (the adaptive-icon foreground).
  final bool tile;

  static const orange = Color(0xFFEE6A2F);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    if (tile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 100), const Radius.circular(24)),
        Paint()..color = dark ? const Color(0xFF14110F) : orange,
      );
    }
    final paper = dark ? const Color(0xFFFFF6EC) : Colors.white;
    final lines = dark ? const Color(0xFF5A4E44) : const Color(0xFFF8B996);
    final bar = dark ? const Color(0xFFFF8A4C) : const Color(0xFF231D18);

    // Receipt with a zigzag tear along the bottom.
    final path = Path()
      ..moveTo(32, 16)
      ..lineTo(68, 16)
      ..quadraticBezierTo(72, 16, 72, 20)
      ..lineTo(72, 82);
    for (var i = 0; i < 8; i++) {
      final x = 72 - 5.5 * (i + 1);
      path.lineTo(x, i.isEven ? 77 : 82);
    }
    path
      ..lineTo(28, 20)
      ..quadraticBezierTo(28, 16, 32, 16)
      ..close();
    canvas.drawPath(path, Paint()..color = paper);

    final linePaint = Paint()..color = lines;
    for (final r in const [
      Rect.fromLTWH(36, 27, 28, 4.5),
      Rect.fromLTWH(36, 37, 18, 4.5),
      Rect.fromLTWH(36, 47, 28, 4.5),
      Rect.fromLTWH(36, 57, 14, 4.5),
      Rect.fromLTWH(56, 57, 8, 4.5),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(2.25)), linePaint);
    }

    // Scan bar with a soft glow band above it.
    canvas.translate(0, barOffset);
    canvas.drawRect(const Rect.fromLTWH(22, 38, 56, 10),
        Paint()..color = bar.withValues(alpha: .22));
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(18, 46, 64, 6), const Radius.circular(3)),
        Paint()..color = bar);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.dark != dark || old.barOffset != barOffset || old.tile != tile;
}

enum SlipMood { happy, reading, sleepy }

/// Slip, the mascot: a little receipt with a face. Blinks every ~4s and,
/// while [mood] is reading, looks left and right with an open mouth.
class SlipMascot extends StatefulWidget {
  const SlipMascot({super.key, this.width = 40, this.mood = SlipMood.happy, this.fill, this.ink});
  final double width;
  final SlipMood mood;
  final Color? fill, ink;

  @override
  State<SlipMascot> createState() => _SlipMascotState();
}

class _SlipMascotState extends State<SlipMascot> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final fill = widget.fill ?? (t.punchy ? t.acc : const Color(0xFFFFF4EC));
    final ink = widget.ink ?? (t.punchy ? t.accInk : t.ink);
    return Semantics(
      label: 'Slip, the Slipcheck mascot',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            size: Size(widget.width, widget.width * 1.2),
            painter: _SlipPainter(widget.mood, _c.value, fill, ink, t.line),
          ),
        ),
      ),
    );
  }
}

class _SlipPainter extends CustomPainter {
  _SlipPainter(this.mood, this.t, this.fill, this.ink, this.dashColor);
  final SlipMood mood;
  final double t;
  final Color fill, ink, dashColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, u = w / 40;
    final stroke = math.max(2.5, 2.5 * u * .8);
    final body = RRect.fromRectAndCorners(
      Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, h - stroke),
      topLeft: Radius.circular(12 * u),
      topRight: Radius.circular(12 * u),
      bottomLeft: Radius.circular(6 * u),
      bottomRight: Radius.circular(6 * u),
    );
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    if (mood == SlipMood.sleepy) {
      canvas.drawRRect(body, Paint()..color = fill.withValues(alpha: .5));
      _dashed(canvas, Path()..addRRect(body), line..color = ink.withValues(alpha: .55));
    } else {
      canvas.drawRRect(body, Paint()..color = fill);
      canvas.drawRRect(body, line);
    }

    final eyeY = h * .40;
    final look = mood == SlipMood.reading ? math.sin(t * 2 * math.pi * 3) * 3 * u : 0.0;
    // A blink near the end of each 4s loop squashes the eyes.
    final blink = (t > .93 && t < .98) ? .1 : 1.0;
    final eyePaint = Paint()..color = ink;
    for (final x in [w / 2 - 6.5 * u, w / 2 + 6.5 * u]) {
      if (mood == SlipMood.sleepy) {
        canvas.drawLine(Offset(x - 3 * u, eyeY), Offset(x + 3 * u, eyeY), line..color = ink.withValues(alpha: .7));
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x + look, eyeY), width: 6 * u, height: 7 * u * blink),
            Radius.circular(3 * u),
          ),
          eyePaint,
        );
      }
    }

    final mouthY = h * .62;
    if (mood == SlipMood.happy) {
      canvas.drawArc(Rect.fromCenter(center: Offset(w / 2, mouthY - 3 * u), width: 12 * u, height: 8 * u),
          0.2, math.pi - .4, false, line..color = ink);
    } else {
      canvas.drawOval(Rect.fromCenter(center: Offset(w / 2, mouthY), width: 6 * u, height: 7 * u),
          line..color = ink.withValues(alpha: mood == SlipMood.sleepy ? .7 : 1));
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 8) {
        canvas.drawPath(m.extractPath(d, math.min(d + 4, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SlipPainter old) => old.t != t || old.mood != mood || old.fill != fill;
}
