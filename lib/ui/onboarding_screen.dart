import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'components/brand.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// First launch: Slip says hello. Calls [onDone] on "Let's go".
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final bg = t.punchy ? t.bg : t.acc;
    final ink = t.punchy ? t.ink : Colors.white;
    final perks = [
      (Symbols.photo_camera_rounded, 'Long receipts? Snap a few photos'),
      (Symbols.trending_up_rounded, 'See what went up, and where'),
      (Symbols.lock_rounded, 'No account. No cloud.'),
    ];
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Center(
                child: Bob(
                  amplitude: 6,
                  period: 2400,
                  angle: .05,
                  child: SlipMascot(
                    width: 120,
                    fill: t.punchy ? t.acc : const Color(0xFFFFB48C),
                    ink: t.punchy ? t.accInk : Colors.white,
                  ),
                ),
              ),
            ),
            Rise(
              child: Text("Hi, I'm Slip. I read receipts.",
                  style: slipText(34, 900, color: ink, height: 1.1)),
            ),
            const SizedBox(height: 10),
            Rise(
              index: 1,
              child: Text("Snap one, I'll track every price. Nothing leaves your phone.",
                  style: slipText(15, 700, color: ink)),
            ),
            const SizedBox(height: 18),
            for (final (i, (icon, text)) in perks.indexed)
              Rise(
                index: i + 2,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    SlipIcon(icon, size: 22, color: t.punchy ? t.acc : ink),
                    const SizedBox(width: 12),
                    Expanded(child: Text(text, style: slipText(14, 800, color: ink))),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: t.punchy ? t.acc : Colors.white,
                  foregroundColor: t.punchy ? t.accInk : t.accDeep,
                  textStyle: slipText(18, 900),
                ),
                onPressed: onDone,
                child: const Text("Let's go"),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Shown before the scanner opens the first time: Google's scanner is a
/// system screen, so the tips come first. Pops true to open it.
class ScanTipsScreen extends StatelessWidget {
  const ScanTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFFFF6EC);
    const ink2 = Color(0xFFB5A89B);
    const tile = Color(0xFF2A231E);
    final tips = [
      (Symbols.light_mode_rounded, 'Flat and bright', 'Lay the receipt on a dark table, in good light.'),
      (Symbols.crop_free_rounded, 'The scanner finds the edges', 'It crops, flattens and cleans each photo for you.'),
      (Symbols.vertical_split_rounded, 'Long one? Top first',
          'Take up to 8 photos down the receipt, each overlapping the last by 2–3 lines.'),
      (Symbols.lock_rounded, 'Read on this phone', 'Card details are cut before anything is kept.'),
    ];
    // Always dark, so the status bar icons are light in either theme.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: const Color(0xFF14110F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAction(
              icon: Symbols.close_rounded,
              tooltip: 'Close',
              color: tile,
              iconColor: ink,
              onTap: () => Navigator.pop(context, false),
            ),
            const Spacer(),
            const Center(child: Bob(child: SlipMascot(width: 72, fill: Color(0xFFFF8A4C), ink: Color(0xFF1A0E06)))),
            const SizedBox(height: 22),
            Text('Before you snap', style: slipText(28, 900, color: ink)),
            const SizedBox(height: 14),
            for (final (i, (icon, title, body)) in tips.indexed)
              Rise(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(12)),
                      child: SlipIcon(icon, size: 22, color: const Color(0xFF5FD49A)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: slipText(15, 900, color: ink)),
                        Text(body, style: slipText(13, 700, color: ink2)),
                      ]),
                    ),
                  ]),
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A4C),
                  foregroundColor: const Color(0xFF1A0E06),
                  textStyle: slipText(18, 900),
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const SlipIcon(Symbols.document_scanner_rounded, size: 24),
                label: const Text('Open the scanner'),
              ),
            ),
          ]),
        ),
      ),
    ),
    );
  }
}
