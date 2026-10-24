import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/categories.dart';
import '../motion/motion.dart';
import '../theme/app_theme.dart';
import '../theme/contrast.dart';
import '../theme/tokens.dart';

/// A surface card: radius, fill and (dark theme) outline from the tokens.
class SlipCard extends StatelessWidget {
  const SlipCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.radius, this.onTap, this.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? radius;
  final VoidCallback? onTap;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final r = BorderRadius.circular(radius ?? t.rCard);
    return Material(
      color: color ?? t.surf,
      shape: RoundedRectangleBorder(borderRadius: r, side: border ?? t.outline ?? BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// The orange hero card, with the theme's glow (light) or sticker shadow (dark).
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.acc,
        borderRadius: BorderRadius.circular(t.rHero),
        border: t.outline == null ? null : Border.fromBorderSide(t.outline!),
        boxShadow: t.heroShadow,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Price-direction colours for chips and text.
enum Trend { up, down, same }

/// A small rounded chip: "+5%", "usual", "↑ 3 prices".
class TrendChip extends StatelessWidget {
  const TrendChip({super.key, required this.label, this.trend = Trend.same, this.icon});
  final String label;
  final Trend trend;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final (bg, fg) = switch (trend) {
      Trend.up => (t.upSoft, t.upText),
      Trend.down => (t.downSoft, t.downText),
      Trend.same => (t.surf2, t.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 3)],
        Text(label, style: slipText(11.5, 800, color: fg, tabular: true)),
      ]),
    );
  }
}

/// A labelled figure: "Spent 59.43".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.color, this.ink, this.footer});
  final String label;
  final Widget value;
  final Color? color, ink;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return SlipCard(
      color: color,
      radius: t.rRow + 2,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: slipText(12, 800, color: ink ?? t.ink2)),
        const SizedBox(height: 4),
        DefaultTextStyle.merge(style: slipText(24, 900, color: ink ?? t.ink, tabular: true), child: value),
        ?footer,
      ]),
    );
  }
}

/// Store avatar: the store's colour with its initial.
class StoreAvatar extends StatelessWidget {
  const StoreAvatar({super.key, required this.name, required this.color, this.size = 38});
  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
            style: slipText(size * .42, 900, color: readableOn(color))),
      );
}

/// Material Symbols Rounded at the handoff's weight.
class SlipIcon extends StatelessWidget {
  const SlipIcon(this.icon, {super.key, this.size = 22, this.color, this.fill = 0});
  final IconData icon;
  final double size;
  final Color? color;
  final double fill;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color, weight: 500, fill: fill, opticalSize: size.clamp(20, 48));
}

IconData categoryIcon(Category c) => switch (c) {
      Category.produce => Symbols.nutrition_rounded,
      Category.meat => Symbols.kebab_dining_rounded,
      Category.dairy => Symbols.egg_rounded,
      Category.bakery => Symbols.bakery_dining_rounded,
      Category.frozen => Symbols.ac_unit_rounded,
      Category.pantry => Symbols.kitchen_rounded,
      Category.snacks => Symbols.cookie_rounded,
      Category.drinks => Symbols.local_drink_rounded,
      Category.household => Symbols.cleaning_services_rounded,
      Category.personalCare => Symbols.soap_rounded,
      Category.pet => Symbols.pets_rounded,
      Category.deposits => Symbols.recycling_rounded,
      Category.other => Symbols.category_rounded,
    };

/// A 36px tile with the category's icon on a 13% tint of [color].
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, required this.color, this.size = 36});
  final Category category;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(size * .33),
        ),
        child: SlipIcon(categoryIcon(category), size: size * .55, color: color),
      );
}

/// Mini bar sparkline of recent prices; the last bar is coloured by trend.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.width = 34, this.height = 18, this.trend = Trend.same});
  final List<double> values;
  final double width, height;
  final Trend trend;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final color = switch (trend) { Trend.up => t.up, Trend.down => t.down, Trend.same => t.ink2 };
    final shown = values.length > 5 ? values.sublist(values.length - 5) : values;
    if (shown.isEmpty) return SizedBox(width: width, height: height);
    final hi = shown.reduce(math.max), lo = shown.reduce(math.min);
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (i, v) in shown.indexed) ...[
            if (i > 0) const SizedBox(width: 2),
            GrowIn(
              delayMs: 80 * i,
              ms: 500,
              child: Container(
                width: 4,
                height: hi == lo ? height * .6 : height * (.35 + .65 * (v - lo) / (hi - lo)),
                decoration: BoxDecoration(
                  color: i == shown.length - 1 ? color : color.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Section heading with an optional trailing action.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: slipText(16, 900, color: SlipTokens.of(context).ink))),
          ?trailing,
        ]),
      );
}

/// A circular icon button on `surf2` (header actions: more, edit, share).
class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, required this.onTap, required this.tooltip, this.size = 44, this.color, this.iconColor});
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final double size;
  final Color? color, iconColor;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color ?? t.surf2,
        shape: CircleBorder(side: t.outline ?? BorderSide.none),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: SlipIcon(icon, size: size * .48, color: iconColor ?? t.ink),
          ),
        ),
      ),
    );
  }
}
