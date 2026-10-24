import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/money.dart';

/// Curves and timings from the design handoff's motion table. Everything
/// here shows its end state at once when the phone asks for reduced motion
/// (`MediaQuery.disableAnimations`).
class Motion {
  static const rise = Cubic(.2, .8, .2, 1);
  static const overshoot = Cubic(.2, .9, .3, 1.2);
  static const sheet = Cubic(.2, .9, .3, 1);
  static const stamp = Cubic(.3, 1.4, .5, 1);
  static const easeOutCubic = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

/// Runs a one-shot animation after [delay], unless motion is reduced.
mixin _OneShot<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController controller;
  Duration get duration;
  Duration get delay;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller.isAnimating || controller.isCompleted) return;
    if (Motion.reduced(context)) {
      controller.value = 1;
    } else {
      Future.delayed(delay, () {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

/// Entrance: fades in while rising 14px; [index] staggers a list.
class Rise extends StatefulWidget {
  const Rise({super.key, required this.child, this.index = 0, this.stagger = 70, this.ms = 380, this.delayMs = 0});
  final Widget child;
  final int index, stagger, ms, delayMs;

  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => Duration(milliseconds: widget.ms);
  @override
  Duration get delay => Duration(milliseconds: widget.delayMs + widget.index * widget.stagger);

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: controller, curve: Motion.rise);
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Opacity(
        opacity: a.value.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 14 * (1 - a.value)), child: child),
      ),
      child: widget.child,
    );
  }
}

/// Pop: scale .4 → 1.12 → 1.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delayMs = 0, this.ms = 360});
  final Widget child;
  final int delayMs, ms;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => Duration(milliseconds: widget.ms);
  @override
  Duration get delay => Duration(milliseconds: widget.delayMs);

  static final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: .4, end: 1.12), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 40),
  ]);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => Opacity(
          opacity: (controller.value * 3).clamp(0, 1),
          child: Transform.scale(scale: _scale.transform(controller.value), child: child),
        ),
        child: widget.child,
      );
}

/// Grows a bar from zero along [axis] (charts: 600–700ms, staggered).
class GrowIn extends StatefulWidget {
  const GrowIn({super.key, required this.child, this.axis = Axis.vertical, this.delayMs = 0, this.ms = 650, this.alignment});
  final Widget child;
  final Axis axis;
  final int delayMs, ms;
  final Alignment? alignment;

  @override
  State<GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<GrowIn> with SingleTickerProviderStateMixin, _OneShot {
  @override
  Duration get duration => Duration(milliseconds: widget.ms);
  @override
  Duration get delay => Duration(milliseconds: widget.delayMs);

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: controller, curve: Motion.easeOutCubic);
    final vertical = widget.axis == Axis.vertical;
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) => Transform(
        alignment: widget.alignment ?? (vertical ? Alignment.bottomCenter : Alignment.centerLeft),
        transform: Matrix4.diagonal3Values(vertical ? 1 : a.value, vertical ? a.value : 1, 1),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A money figure that rolls up to [cents] (ease-out cubic, tabular figures).
/// Rolls from its previous value when [cents] changes.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.cents, required this.style, this.prefix = '', this.ms = 1100, this.signed = false});
  final int cents;
  final TextStyle style;
  final String prefix;
  final int ms;

  /// Show a leading + for positive values.
  final bool signed;

  String _format(int c) => '${signed && c > 0 ? '+' : c < 0 ? '−' : ''}$prefix${formatCents(c.abs())}';

  @override
  Widget build(BuildContext context) {
    final s = style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    if (Motion.reduced(context)) return Text(_format(cents), style: s);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: cents.toDouble()),
      duration: Duration(milliseconds: ms),
      curve: Motion.easeOutCubic,
      builder: (context, v, _) => Text(_format(v.round()), style: s),
    );
  }
}

/// Same, for a plain number such as a percentage: "+5.4%".
class CountUpNumber extends StatelessWidget {
  const CountUpNumber({super.key, required this.value, required this.style, this.decimals = 1, this.suffix = '', this.signed = false, this.ms = 1100});
  final double value;
  final TextStyle style;
  final int decimals, ms;
  final String suffix;
  final bool signed;

  String _format(double v) => '${signed && v > 0 ? '+' : v < 0 ? '−' : ''}${v.abs().toStringAsFixed(decimals)}$suffix';

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text(_format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: Duration(milliseconds: ms),
      curve: Motion.easeOutCubic,
      builder: (context, v, _) => Text(_format(v), style: style),
    );
  }
}

/// Skeleton placeholder with a 1.3s shimmer.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = 12});
  final double? width;
  final double height, radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

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
    final base = Theme.of(context).colorScheme.surfaceContainerHigh;
    final shine = Color.lerp(base, Theme.of(context).colorScheme.surface, .7)!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * _c.value - 1, 0),
              end: Alignment(3 * _c.value - 1, 0),
              colors: [base, shine, base],
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular progress ring with something in its middle.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 76, this.stroke = 7, this.child});
  final double value;
  final double size, stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 400),
        curve: Motion.easeOutCubic,
        builder: (context, v, child) => CustomPaint(
          painter: _RingPainter(v, stroke, scheme.primary, scheme.surfaceContainerHigh),
          child: Center(child: child),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.stroke, this.color, this.track);
  final double value, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * value, false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Repeating motion: a ring that grows and fades around [child] (2.2s).
class PulseRing extends StatefulWidget {
  const PulseRing({super.key, required this.child, required this.color, this.radius = 999});
  final Widget child;
  final Color color;
  final double radius;

  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: .45 * (1 - _c.value)),
                spreadRadius: 14 * _c.value,
              ),
            ],
          ),
          child: child,
        ),
        child: widget.child,
      );
}

/// Gentle up-and-down bob (the mascot), [period] long, ±[amplitude] px.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.amplitude = 5, this.period = 2600, this.angle = 0});
  final Widget child;
  final double amplitude;
  final int period;

  /// Extra tilt in radians, swung with the bob.
  final double angle;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.period));

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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final s = math.sin(_c.value * 2 * math.pi);
          return Transform.translate(
            offset: Offset(0, widget.amplitude * s),
            child: Transform.rotate(angle: widget.angle * s, child: child),
          );
        },
        child: widget.child,
      );
}
