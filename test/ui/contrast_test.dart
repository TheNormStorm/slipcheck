import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/ui/theme/contrast.dart';
import 'package:slipcheck/ui/theme/tokens.dart';

/// Every text colour against every background it is used on, in both
/// themes. Small text needs 4.5:1; large bold text (18px+, or 14px+ bold,
/// such as the Save button and the big amounts on orange) needs 3:1.
void main() {
  for (final (name, t) in [('light', SlipTokens.light), ('dark', SlipTokens.dark)]) {
    final small = <String, (Color, Color)>{
      'ink on bg': (t.ink, t.bg),
      'ink on surf': (t.ink, t.surf),
      'ink on surf2': (t.ink, t.surf2),
      'ink2 on bg': (t.ink2, t.bg),
      'ink2 on surf': (t.ink2, t.surf),
      'ink2 on surf2': (t.ink2, t.surf2),
      'accText on bg': (t.accText, t.bg),
      'accText on surf': (t.accText, t.surf),
      'accText on surf2': (t.accText, t.surf2),
      'accText on accSoft': (t.accText, t.accSoft),
      'upText on upSoft': (t.upText, t.upSoft),
      'upText on surf': (t.upText, t.surf),
      'downText on downSoft': (t.downText, t.downSoft),
      'downText on surf': (t.downText, t.surf),
      'warning on warningSoft': (t.warning, t.warningSoft),
      'warning on bg': (t.warning, t.bg),
      'onAccSmall on acc': (t.onAccSmall, t.acc),
      'ink on downSoft (tip)': (t.ink, t.downSoft),
      'selected chip: bg on ink': (t.bg, t.ink),
      'ink2 on surf2 chips': (t.ink2, t.surf2),
    };
    final large = <String, (Color, Color)>{
      'big amounts on orange': (t.punchy ? t.accInk : Colors.white, t.acc),
      'Save when it matches': (t.punchy ? t.accInk : Colors.white, t.success),
      'Save otherwise': (t.accInk, t.acc),
    };
    group('$name theme', () {
      small.forEach((what, pair) {
        test('$what ≥ 4.5', () => expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5)));
      });
      large.forEach((what, pair) {
        test('$what ≥ 3', () => expect(contrastRatio(pair.$1, pair.$2), greaterThanOrEqualTo(3)));
      });
    });
  }

  test('text on any store colour is readable', () {
    const stores = [
      Color(0xff2a78d6), Color(0xff1baf7a), Color(0xffeda100), Color(0xffe87ba4),
      Color(0xff008300), Color(0xff6250d6), Color(0xffe34948), Color(0xff898781),
      Color(0xff3987e5), Color(0xff199e70), Color(0xffc98500), Color(0xffd55181), Color(0xff9085e9), Color(0xffe66767),
    ];
    for (final c in stores) {
      // Store names are large bold text on the header; initials are bold too.
      expect(contrastRatio(readableOn(c), c), greaterThanOrEqualTo(3), reason: c.toString());
    }
  });

  test('contrast ratio', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 1e-9));
    expect(contrastRatio(Colors.white, Colors.white), 1);
  });
}
