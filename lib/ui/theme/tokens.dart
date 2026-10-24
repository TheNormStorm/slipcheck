import 'package:flutter/material.dart';

/// Colours, radii and outline style from the design handoff
/// (docs/ui-redesign-plan.md): variant a is the light theme, b the dark one.
///
/// Small-text colours are adjusted from the handoff where it fell short of
/// 4.5:1 contrast: [upText], [downText], [accText], and [onAccSmall] for
/// text under 18px on the orange cards.
@immutable
class SlipTokens extends ThemeExtension<SlipTokens> {
  const SlipTokens({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.line,
    required this.ink,
    required this.ink2,
    required this.acc,
    required this.accInk,
    required this.accSoft,
    required this.accDeep,
    required this.accText,
    required this.onAccSmall,
    required this.up,
    required this.upSoft,
    required this.upText,
    required this.down,
    required this.downSoft,
    required this.downText,
    required this.success,
    required this.warning,
    required this.warningSoft,
    required this.rHero,
    required this.rCard,
    required this.rRow,
    required this.rField,
    required this.outline,
    required this.heroShadow,
    required this.popShadow,
  });

  final Color bg, surf, surf2, line, ink, ink2;
  final Color acc, accInk, accSoft, accDeep, accText, onAccSmall;
  final Color up, upSoft, upText, down, downSoft, downText;
  final Color success, warning, warningSoft;
  final double rHero, rCard, rRow, rField;

  /// Variant b's 2.5px cream outline; null in variant a.
  final BorderSide? outline;
  final List<BoxShadow> heroShadow, popShadow;

  bool get punchy => outline != null;

  static const light = SlipTokens(
    bg: Color(0xFFFBF7F2),
    surf: Color(0xFFFFFFFF),
    surf2: Color(0xFFF2EAE1),
    line: Color(0xFFE5DACE),
    ink: Color(0xFF231D18),
    ink2: Color(0xFF6E6258),
    acc: Color(0xFFEE6A2F),
    accInk: Color(0xFFFFFFFF),
    accSoft: Color(0xFFFFE6D7),
    accDeep: Color(0xFFC14A14),
    accText: Color(0xFFA93E0F),
    onAccSmall: Color(0xFF3B1404),
    up: Color(0xFFD6453D),
    upSoft: Color(0xFFFDE4E1),
    upText: Color(0xFFB3332A),
    down: Color(0xFF1F8A5B),
    downSoft: Color(0xFFDDF3E8),
    downText: Color(0xFF17774D),
    success: Color(0xFF1F8A5B),
    warning: Color(0xFF8F5500),
    warningSoft: Color(0xFFFFEFD1),
    rHero: 28,
    rCard: 22,
    rRow: 18,
    rField: 16,
    outline: null,
    heroShadow: [BoxShadow(color: Color(0x59EE6A2F), blurRadius: 30, offset: Offset(0, 10))],
    popShadow: [BoxShadow(color: Color(0x38231D18), blurRadius: 40, offset: Offset(0, 18))],
  );

  static const dark = SlipTokens(
    bg: Color(0xFF14110F),
    surf: Color(0xFF1F1A16),
    surf2: Color(0xFF2A231E),
    line: Color(0xFF3A312A),
    ink: Color(0xFFFFF6EC),
    ink2: Color(0xFFB5A89B),
    acc: Color(0xFFFF8A4C),
    accInk: Color(0xFF1A0E06),
    accSoft: Color(0xFF3A2418),
    accDeep: Color(0xFFFF8A4C),
    accText: Color(0xFFFF8A4C),
    onAccSmall: Color(0xFF1A0E06),
    up: Color(0xFFFF6B5E),
    upSoft: Color(0xFF3A1C19),
    upText: Color(0xFFFF6B5E),
    down: Color(0xFF5FD49A),
    downSoft: Color(0xFF16332A),
    downText: Color(0xFF5FD49A),
    success: Color(0xFF5FD49A),
    warning: Color(0xFFFFD37A),
    warningSoft: Color(0xFF3A2E14),
    rHero: 16,
    rCard: 14,
    rRow: 12,
    rField: 10,
    outline: BorderSide(color: Color(0xFFFFF6EC), width: 2.5),
    heroShadow: [BoxShadow(color: Color(0xFFFFF6EC), offset: Offset(5, 5))],
    popShadow: [BoxShadow(color: Color(0xFFFF8A4C), offset: Offset(6, 6))],
  );

  static SlipTokens of(BuildContext context) =>
      Theme.of(context).extension<SlipTokens>() ?? light;

  @override
  SlipTokens copyWith() => this;

  @override
  SlipTokens lerp(SlipTokens? other, double t) => t < 0.5 || other == null ? this : other;
}
