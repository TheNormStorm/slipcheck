import 'package:flutter/material.dart';

/// Chart colours: the dataviz reference palette, validated for colour-vision
/// deficiency in both modes (scripts/validate_palette.js, adjacent pairs).
/// Three light-mode slots sit under 3:1 against the surface, so every chart
/// that uses them also shows a legend and the values as text.
class ChartPalette {
  ChartPalette.of(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark;

  final bool dark;

  static const _light = [
    Color(0xff2a78d6), Color(0xffeb6834), Color(0xff1baf7a), Color(0xffeda100),
    Color(0xffe87ba4), Color(0xff008300), Color(0xff6250d6), Color(0xffe34948),
  ];
  static const _dark = [
    Color(0xff3987e5), Color(0xffd95926), Color(0xff199e70), Color(0xffc98500),
    Color(0xffd55181), Color(0xff008300), Color(0xff9085e9), Color(0xffe66767),
  ];

  /// Categorical slot [i] in fixed order; past the eighth, a neutral "other".
  Color series(int i) => i < 8 ? (dark ? _dark : _light)[i] : muted;

  Color get surface => dark ? const Color(0xff1a1a19) : const Color(0xfffcfcfb);
  Color get ink => dark ? const Color(0xfff0efec) : const Color(0xff0b0b0b);
  Color get secondaryInk => dark ? const Color(0xffc3c2b7) : const Color(0xff52514e);
  Color get muted => const Color(0xff898781);
  Color get grid => dark ? const Color(0xff2c2c2a) : const Color(0xffe1e0d9);
  Color get baseline => dark ? const Color(0xff383835) : const Color(0xffc3c2b7);

  /// Diverging poles: spent more (red) / spent less (blue).
  Color get more => dark ? const Color(0xffe66767) : const Color(0xffe34948);
  Color get less => dark ? const Color(0xff3987e5) : const Color(0xff2a78d6);

  /// Text for a price that went down / up (status ink, always with an arrow).
  Color get goodText => dark ? const Color(0xff0ca30c) : const Color(0xff006300);
  Color get badText => const Color(0xffd03b3b);
}

/// Gives each store a fixed colour slot by when it was first seen (its id),
/// so a store keeps its colour on every chart and filter.
Map<String, int> storeSlots(Iterable<(int?, String?)> stores) {
  final byId = <int, String>{};
  for (final (id, name) in stores) {
    if (id != null && name != null) byId[id] = name;
  }
  final ids = byId.keys.toList()..sort();
  return {for (final (i, id) in ids.indexed) byId[id]!: i};
}

/// A coloured swatch with its name in text ink, for legends.
class LegendChip extends StatelessWidget {
  const LegendChip({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
      ]);
}
