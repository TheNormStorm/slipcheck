import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG contrast ratio between two opaque colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

/// Text colour for [background]: white, or the app's dark ink when white
/// would be hard to read (a yellow or mint store colour).
Color readableOn(Color background, {Color light = const Color(0xFFFFFFFF), Color dark = const Color(0xFF231D18)}) =>
    contrastRatio(light, background) >= contrastRatio(dark, background) ? light : dark;
