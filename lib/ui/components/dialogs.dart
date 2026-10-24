import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/motion.dart';
import '../theme/tokens.dart';
import 'kit.dart';

/// A yes/no question with an icon on top (14a/14b). Returns true for
/// [confirm]. With [danger] the icon and the confirm button are red, the
/// icon wobbles, and the safe answer is the filled button, so a quick tap
/// on the bigger button never deletes anything.
Future<bool> confirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  required String confirm,
  String cancel = 'Keep',
  bool danger = false,
  Color? iconColor,
}) async {
  final t = SlipTokens.of(context);
  final color = iconColor ?? (danger ? t.upText : t.accText);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: danger ? _Wobble(child: SlipIcon(icon, size: 36, color: color)) : SlipIcon(icon, size: 36, color: color),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(body, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: danger
          ? [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.upText),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context, true);
                },
                child: Text(confirm),
              ),
              FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
            ]
          : [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirm)),
            ],
    ),
  );
  return ok == true;
}

/// A short wobble when it appears, to say "careful".
class _Wobble extends StatefulWidget {
  const _Wobble({required this.child});
  final Widget child;

  @override
  State<_Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<_Wobble> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && _c.value == 0 && !_c.isAnimating) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.rotate(
          angle: .2 * (1 - _c.value) * math.sin(_c.value * 6 * math.pi),
          child: child,
        ),
        child: widget.child,
      );
}
