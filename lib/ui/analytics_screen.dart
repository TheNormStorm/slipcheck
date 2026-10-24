import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/insights.dart';
import '../core/analytics/price_insights.dart';
import '../core/analytics/purchase.dart';
import '../core/categories.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'charts.dart';
import 'components/brand.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'reload_on_change.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// Insights over a time span: how the prices of what you buy moved, the
/// biggest moves, spending by category and by month, where the same item is
/// cheaper, and one tip from Slip.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.repo, this.now});
  final ReceiptRepository repo;

  /// Today, for the ranges; tests pass a fixed day.
  final DateTime? now;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _Data {
  _Data(this.receipts, this.purchases, this.categories);
  final List<ReceiptSummary> receipts;
  final List<Purchase> purchases;

  /// Product id → category.
  final Map<int, Category> categories;
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with ReloadOnChange {
  @override
  ReceiptRepository get repo => widget.repo;

  late Future<_Data> _data = _load();
  InsightRange _range = InsightRange.threeMonths;

  @override
  void reload() {
    _data = _load();
  }

  Future<_Data> _load() async => _Data(
        await repo.receipts(),
        await repo.purchases(),
        {for (final p in await repo.products()) p.id: p.category},
      );

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final now = widget.now ?? DateTime.now();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            final data = snap.data;
            final header = [
              Text('Insights', style: slipText(28, 900, color: t.ink, letterSpacing: -.5)),
              const SizedBox(height: 10),
              _RangeChips(value: _range, onChanged: (r) => setState(() => _range = r)),
              const SizedBox(height: 12),
            ];
            if (data == null) {
              return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
                ...header,
                for (final h in <double>[180, 200, 120])
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Skeleton(height: h, radius: t.rCard)),
              ]);
            }
            if (data.receipts.isEmpty) {
              return ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 24), children: [
                ...header,
                const SizedBox(height: 40),
                const Center(child: SlipMascot(width: 56, mood: SlipMood.sleepy)),
                const SizedBox(height: 12),
                Center(
                  child: Text('Save a few receipts to see insights.', style: slipText(14, 700, color: t.ink2)),
                ),
              ]);
            }
            final inRange = data.purchases.where((p) => _range.contains(p.date, now)).toList();
            final receiptsInRange = data.receipts.where((r) => _range.contains(r.purchasedAt, now)).toList();
            final index = indexFor(personalPriceIndex(data.purchases), _range, now);
            final moves = priceChanges(data.purchases).where((c) => _range.contains(c.latest.date, now)).toList();
            final stores = storeComparison(data.purchases);
            final slots = storeSlots(data.receipts.map((r) => (r.storeId, r.storeName)));
            final tip = _tip(stores, moves);
            var i = 0;
            Widget rise(Widget child) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Rise(key: ValueKey((_range, i)), index: i++, child: child),
                );
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                ...header,
                rise(_IndexCard(points: index, range: _range)),
                rise(_MovesCard(moves: moves)),
                rise(_CategoryCard(
                  spend: spendByCategory(inRange, data.categories),
                  label: _range == InsightRange.thisMonth ? DateFormat.MMMM().format(now) : _range.label,
                )),
                if (receiptsInRange.isNotEmpty)
                  rise(_Card(
                    title: 'Spending by month',
                    child: MonthlySpendingChart(receipts: receiptsInRange, slots: slots),
                  )),
                if (stores.isNotEmpty) rise(_StoresCard(stores: stores, slots: slots)),
                if (tip != null) rise(_TipCard(text: tip)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One plain sentence worth acting on.
  static String? _tip(List<StorePrices> stores, List<PriceChange> moves) {
    if (cheaperStore(stores) case final c?) {
      return '${c.winner} beat ${c.loser} on ${c.wins} of ${plural(c.shared, 'shared item')}.';
    }
    final riser = moves.where((m) => m.changeFraction >= .1).firstOrNull;
    if (riser != null) {
      return '${sentenceCase(riser.name)} went up ${(riser.changeFraction * 100).round()}%'
          '${riser.latest.storeName == null ? '' : ' at ${riser.latest.storeName}'}. '
          'Worth checking another store.';
    }
    return null;
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.value, required this.onChanged});
  final InsightRange value;
  final ValueChanged<InsightRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Wrap(spacing: 6, children: [
      for (final r in InsightRange.values)
        Semantics(
          selected: r == value,
          button: true,
          child: GestureDetector(
            onTap: () => onChanged(r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: r == value ? t.ink : t.surf2,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(r.label, style: slipText(13, 900, color: r == value ? t.bg : t.ink2)),
            ),
          ),
        ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, this.trailing, required this.child});
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return SlipCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(title, style: slipText(15, 900, color: t.ink))),
          ?trailing,
        ]),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }
}

/// "Your price index +5.4% since August", with a column per month.
class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.points, required this.range});
  final List<IndexPoint> points;
  final InsightRange range;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final onAcc = t.punchy ? t.accInk : Colors.white;
    if (points.length < 2) {
      return HeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your price index', style: slipText(13, 800, color: t.onAccSmall)),
          const SizedBox(height: 6),
          Text('Needs two months with some of the same items.', style: slipText(16, 900, color: onAcc)),
        ]),
      );
    }
    final shown = points.length > 6 ? points.sublist(points.length - 6) : points;
    final change = points.last.value / 100 - 1;
    final lo = shown.map((p) => p.value).reduce(math.min), hi = shown.map((p) => p.value).reduce(math.max);
    final since = DateFormat.MMMM().format(points.first.month);
    return Semantics(
      label: 'Your price index: ${change >= 0 ? 'up' : 'down'} ${(change.abs() * 100).toStringAsFixed(1)} percent '
          'since $since. ${[for (final p in shown) '${DateFormat.MMMM().format(p.month)} ${p.value.toStringAsFixed(1)}'].join(', ')}.',
      excludeSemantics: true,
      child: HeroCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your price index', style: slipText(13, 800, color: t.onAccSmall)),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            CountUpNumber(
              value: change * 100,
              signed: true,
              suffix: '%',
              style: slipText(34, 900, color: onAcc, tabular: true, height: 1.15),
            ),
            const SizedBox(width: 8),
            Text('since $since', style: slipText(13, 800, color: t.onAccSmall)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            height: 92,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (i, p) in shown.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(p.value.toStringAsFixed(1), style: slipText(11, 900, color: onAcc, tabular: true)),
                    const SizedBox(height: 3),
                    GrowIn(
                      delayMs: 120 * i,
                      child: Container(
                        height: 18 + 40 * (hi == lo ? .5 : (p.value - lo) / (hi - lo)),
                        decoration: BoxDecoration(
                          color: t.punchy ? t.accInk.withValues(alpha: .85) : Colors.white.withValues(alpha: .92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat.MMM().format(p.month), style: slipText(11, 800, color: t.onAccSmall)),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The biggest price moves, each with a bar that grows in.
class _MovesCard extends StatelessWidget {
  const _MovesCard({required this.moves});
  final List<PriceChange> moves;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    if (moves.isEmpty) {
      return _Card(
        title: 'Biggest price moves',
        child: Text('Buy the same item twice at a store to see its price move.',
            style: slipText(13, 700, color: t.ink2)),
      );
    }
    final shown = moves.take(5).toList();
    final maxAbs = shown.map((m) => m.changeFraction.abs()).reduce(math.max);
    return _Card(
      title: 'Biggest price moves',
      child: Column(children: [
        for (final (i, m) in shown.indexed)
          () {
            final up = m.changeFraction > 0;
            final per = m.unit == 'each' ? '' : '/${m.unit}';
            final pct = '${up ? '+' : '−'}${math.max(1, (m.changeFraction.abs() * 100).round())}%';
            return Semantics(
              label: '${m.name}: ${up ? 'up' : 'down'} $pct, from ${formatCents(m.typicalUnitPrice.round())} '
                  'to ${formatCents(m.latest.unitPrice.round())}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    flex: 5,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sentenceCase(m.name),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: slipText(13.5, 900, color: t.ink)),
                      Text(
                        '${m.latest.storeName ?? ''}${m.latest.storeName == null ? '' : ' · '}'
                        '${formatCents(m.typicalUnitPrice.round())} → ${formatCents(m.latest.unitPrice.round())}$per',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: slipText(11.5, 700, color: t.ink2, tabular: true),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(999)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: math.max(.08, m.changeFraction.abs() / maxAbs),
                        child: GrowIn(
                          axis: Axis.horizontal,
                          delayMs: 100 * i,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                                color: up ? t.up : t.down, borderRadius: BorderRadius.circular(999)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(pct,
                        textAlign: TextAlign.right,
                        style: slipText(13, 900, color: up ? t.upText : t.downText, tabular: true)),
                  ),
                ]),
              ),
            );
          }(),
      ]),
    );
  }
}

/// One stacked bar of spending by category, with a legend carrying the
/// amounts. The six largest get their own colour; the rest are "Everything
/// else".
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.spend, required this.label});
  final List<(Category, int)> spend;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final palette = ChartPalette.of(context);
    final total = spend.fold(0, (s, e) => s + e.$2);
    if (total <= 0) {
      return _Card(
        title: 'By category',
        child: Text('Nothing saved in this range.', style: slipText(13, 700, color: t.ink2)),
      );
    }
    final top = spend.take(6).toList();
    final rest = spend.skip(6).fold(0, (s, e) => s + e.$2);
    final parts = [
      for (final (i, (c, cents)) in top.indexed) (c.label, cents, palette.series(i)),
      if (rest > 0) ('Everything else', rest, palette.muted),
    ];
    return _Card(
      title: 'By category',
      trailing: Text('$label ${formatCents(total)}', style: slipText(12.5, 900, color: t.ink2, tabular: true)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ExcludeSemantics(
          child: GrowIn(
            axis: Axis.horizontal,
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 14,
                child: Row(children: [
                  for (final (i, (_, cents, color)) in parts.indexed)
                    Expanded(
                      flex: math.max(1, (cents * 1000 / total).round()),
                      child: Container(
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                        color: color,
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6, children: [
          for (final (name, cents, color) in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 9, height: 9, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 5),
              Text(name, style: slipText(12, 800, color: t.ink)),
              const SizedBox(width: 4),
              Text(formatCents(cents), style: slipText(12, 700, color: t.ink2, tabular: true)),
            ]),
        ]),
      ]),
    );
  }
}

/// Items bought at more than one store, and what each store charges.
class _StoresCard extends StatelessWidget {
  const _StoresCard({required this.stores, required this.slots});
  final List<StorePrices> stores;
  final Map<String, int> slots;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final palette = ChartPalette.of(context);
    final names = {for (final s in stores) ...s.byStore.keys}.toList()
      ..sort((a, b) => (slots[a] ?? 99).compareTo(slots[b] ?? 99));
    final summaries = <String>[];
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final gap = storeGap(stores, names[i], names[j]);
        if (gap == null) continue;
        // gap.fraction: how much pricier names[i] is than names[j].
        final (pricier, cheaper) = gap.fraction >= 0 ? (names[i], names[j]) : (names[j], names[i]);
        final f = gap.fraction >= 0 ? 1 - 1 / (1 + gap.fraction) : -gap.fraction;
        summaries.add('$cheaper is ${(f * 100).toStringAsFixed(0)}% cheaper than $pricier '
            'on the ${plural(gap.items, 'item')} you bought at both.');
      }
    }
    return _Card(
      title: 'Same item, different stores',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final s in summaries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(s, style: slipText(13.5, 800, color: t.ink)),
          ),
        for (final item in stores.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sentenceCase(item.name), style: slipText(13.5, 900, color: t.ink)),
              const SizedBox(height: 3),
              Wrap(spacing: 12, runSpacing: 4, children: [
                for (final e in (item.byStore.entries.toList()..sort((a, b) => a.value.compareTo(b.value))))
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(color: palette.series(slots[e.key] ?? 8), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('${e.key} ${formatCents(e.value.round())}${item.unit == 'each' ? '' : '/${item.unit}'}',
                        style: slipText(12, 700, color: t.ink2, tabular: true)),
                    if (e.key == item.cheapest.key)
                      Text(' · cheapest', style: slipText(12, 900, color: t.downText)),
                  ]),
              ]),
            ]),
          ),
      ]),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return SlipCard(
      color: t.downSoft,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: Row(children: [
        const SlipMascot(width: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SlipIcon(Symbols.lightbulb_rounded, size: 14, color: t.downText, fill: 1),
              const SizedBox(width: 4),
              Text('Tip from Slip', style: slipText(11.5, 900, color: t.downText)),
            ]),
            Text(text, style: slipText(13.5, 800, color: t.ink)),
          ]),
        ),
      ]),
    );
  }
}
