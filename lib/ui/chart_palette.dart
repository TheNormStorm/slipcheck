import 'package:flutter/material.dart';

import '../core/categories.dart';
import 'theme/tokens.dart';

/// Chart colours: the dataviz reference palette, validated for colour-vision
/// deficiency in both modes (scripts/validate_palette.js, adjacent pairs).
/// Three light-mode slots sit under 3:1 against the surface, so every chart
/// that uses them also shows a legend and the values as text.
///
/// Orange is left out of the store colours: it is the app's accent, so an
/// orange store would read as "selected" (docs/ui-redesign-plan.md, point 7).
/// The seven remaining slots were re-validated in this order, both modes.
class ChartPalette {
  ChartPalette.of(BuildContext context)
      : dark = Theme.of(context).brightness == Brightness.dark,
        _t = SlipTokens.of(context);

  final bool dark;
  final SlipTokens _t;

  static const _light = [
    Color(0xff2a78d6), Color(0xff1baf7a), Color(0xffeda100), Color(0xffe87ba4),
    Color(0xff008300), Color(0xff6250d6), Color(0xffe34948),
  ];
  static const _dark = [
    Color(0xff3987e5), Color(0xff199e70), Color(0xffc98500), Color(0xffd55181),
    Color(0xff008300), Color(0xff9085e9), Color(0xffe66767),
  ];

  /// Categorical slot [i] in fixed order; past the seventh, a neutral "other".
  Color series(int i) => i < _light.length ? (dark ? _dark : _light)[i] : muted;

  Color get surface => _t.surf;
  Color get ink => _t.ink;
  Color get secondaryInk => _t.ink2;
  Color get muted => const Color(0xff898781);
  Color get grid => _t.line;
  Color get baseline => _t.line;

  /// Diverging poles: spent more (red) / spent less (blue).
  Color get more => dark ? const Color(0xffe66767) : const Color(0xffe34948);
  Color get less => dark ? const Color(0xff3987e5) : const Color(0xff2a78d6);

  /// Text for a price that went down / up (status ink, always with an arrow).
  Color get goodText => _t.downText;
  Color get badText => _t.upText;
}

/// A category's colour for its icon tile: a fixed slot so an item looks the
/// same everywhere. (Charts that put categories side by side colour them by
/// rank instead, so neighbours always differ.)
Color categoryColor(Category c, ChartPalette palette) => switch (c) {
      Category.produce || Category.snacks => palette.series(1),
      Category.meat || Category.pet => palette.series(6),
      Category.dairy || Category.drinks => palette.series(0),
      Category.bakery || Category.pantry => palette.series(2),
      Category.frozen || Category.household => palette.series(5),
      Category.personalCare => palette.series(3),
      Category.deposits || Category.other => palette.muted,
    };

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
