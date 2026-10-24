import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/analytics/price_insights.dart';
import '../core/analytics/purchase.dart';
import '../core/categories.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'charts.dart';
import 'reload_on_change.dart';

/// Spending by month and store, how the prices of what you buy have moved,
/// which items changed price most, and where the same item is cheaper.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.repo});
  final ReceiptRepository repo;

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

  @override
  void reload() {
    _data = _load();
  }

  Future<_Data> _load() async => _Data(
        await widget.repo.receipts(),
        await widget.repo.purchases(),
        {for (final p in await widget.repo.products()) p.id: p.category},
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          if (data.receipts.isEmpty) {
            return const Center(child: Text('Save a few receipts to see analytics.'));
          }
          final slots = storeSlots(data.receipts.map((r) => (r.storeId, r.storeName)));
          final index = personalPriceIndex(data.purchases);
          final changes = priceChanges(data.purchases);
          final stores = storeComparison(data.purchases);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Headline(receipts: data.receipts, index: index),
              _Section(
                title: 'Spending by month',
                child: MonthlySpendingChart(receipts: data.receipts, slots: slots),
              ),
              _Section(
                title: 'Spending by category',
                subtitle: 'All saved receipts, after discounts.',
                child: _CategorySpending(data: data),
              ),
              _Section(
                title: 'Your price index',
                subtitle: 'How the prices of the things you buy have moved. '
                    'First month = 100.',
                child: _PriceIndexChart(points: index),
              ),
              _Section(
                title: 'Biggest price changes',
                subtitle: 'Latest price against what you usually paid.',
                child: changes.isEmpty
                    ? const _Empty('Buy the same item twice to see its price move.')
                    : Column(children: [for (final c in changes.take(10)) _ChangeRow(c)]),
              ),
              _Section(
                title: 'Store comparison',
                subtitle: 'Items you have bought at more than one store.',
                child: _StoreComparison(stores: stores, slots: slots),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (subtitle != null)
          Text(subtitle!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
}

/// Two headline numbers: this month's spending and your price index change.
class _Headline extends StatelessWidget {
  const _Headline({required this.receipts, required this.index});
  final List<ReceiptSummary> receipts;
  final List<IndexPoint> index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final latest = receipts.map((r) => r.purchasedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    final month = DateTime(latest.year, latest.month);
    final spent = receipts
        .where((r) => r.purchasedAt.year == month.year && r.purchasedAt.month == month.month)
        .fold(0, (s, r) => s + r.spentCents);

    Widget tile(String label, String value, {Widget? note}) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(value, style: theme.textTheme.headlineSmall),
                ?note,
              ]),
            ),
          ),
        );

    final change = index.length >= 2 ? index.last.value / 100 - 1 : null;
    return Row(children: [
      tile('Spent in ${DateFormat.yMMMM().format(month)}', '\$${formatCents(spent)}'),
      const SizedBox(width: 8),
      tile(
        'Your prices since ${index.isEmpty ? '-' : DateFormat.yMMM().format(index.first.month)}',
        change == null ? '—' : _percent(change),
        note: change == null
            ? Text('Needs two months', style: theme.textTheme.bodySmall)
            : Row(children: [
                Icon(change > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14, color: change > 0 ? palette.badText : palette.goodText),
                Flexible(
                  child: Text(change > 0 ? ' Paying more' : ' Paying less',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: change > 0 ? palette.badText : palette.goodText)),
                ),
              ]),
      ),
    ]);
  }
}

/// Horizontal bars, one per category, largest first. One hue: the bars
/// encode magnitude, and each carries its amount and share as text.
class _CategorySpending extends StatelessWidget {
  const _CategorySpending({required this.data});
  final _Data data;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final theme = Theme.of(context);
    final spent = <Category, int>{};
    for (final p in data.purchases) {
      final c = data.categories[p.productId] ?? Category.other;
      spent[c] = (spent[c] ?? 0) + p.netCents;
    }
    if (spent.isEmpty) return const _Empty('No items saved yet.');
    final rows = spent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = rows.fold(0, (s, e) => s + e.value);
    final max = rows.first.value;
    return Column(children: [
      for (final e in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 110, child: Text(e.key.label, style: theme.textTheme.bodySmall)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: math.max(2, c.maxWidth * e.value / max),
                    height: 14,
                    decoration: BoxDecoration(
                      color: palette.series(0),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 96,
              child: Text(
                '\$${formatCents(e.value)} · ${(e.value * 100 / total).round()}%',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _PriceIndexChart extends StatelessWidget {
  const _PriceIndexChart({required this.points});
  final List<IndexPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return const _Empty('Needs receipts from at least two months with some of the '
          'same items.');
    }
    final palette = ChartPalette.of(context);
    final values = points.map((p) => p.value);
    final lo = math.min(values.reduce(math.min), 100.0);
    final hi = math.max(values.reduce(math.max), 100.0);
    final pad = math.max((hi - lo) * 0.2, 2.0);

    return SizedBox(
      height: 180,
      child: LineChart(LineChartData(
        minY: (lo - pad).floorToDouble(),
        maxY: (hi + pad).ceilToDouble(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: palette.grid, strokeWidth: 1),
        ),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 100, color: palette.baseline, strokeWidth: 1, dashArray: [4, 4]),
        ]),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(v.round().toString(),
                    style: TextStyle(color: palette.muted, fontSize: 11)),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, meta) => v != v.roundToDouble()
                  ? const SizedBox.shrink()
                  : SideTitleWidget(
                      meta: meta,
                      child: Text(DateFormat.MMM().format(points[v.toInt()].month),
                          style: TextStyle(color: palette.muted, fontSize: 11)),
                    ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => palette.ink,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat.yMMM().format(points[s.x.toInt()].month)}\n'
                  '${points[s.x.toInt()].value.toStringAsFixed(1)} '
                  '(${points[s.x.toInt()].comparedItems} items compared)',
                  TextStyle(color: palette.surface, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final (i, p) in points.indexed) FlSpot(i.toDouble(), p.value)],
            color: palette.series(0),
            barWidth: 2,
            dotData: FlDotData(
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: palette.series(0),
                strokeWidth: 2,
                strokeColor: palette.surface,
              ),
            ),
          ),
        ],
      )),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow(this.change);
  final PriceChange change;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final theme = Theme.of(context);
    final up = change.changeFraction > 0;
    final per = change.unit == 'each' ? '' : '/${change.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(change.name),
            Text(
              'usually \$${formatCents(change.typicalUnitPrice.round())}$per · '
              'now \$${formatCents(change.latest.unitPrice.round())}$per'
              '${change.latest.storeName == null ? '' : ' at ${change.latest.storeName}'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ]),
        ),
        Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16, color: up ? palette.badText : palette.goodText),
        Text(_percent(change.changeFraction),
            style: TextStyle(
                color: up ? palette.badText : palette.goodText, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StoreComparison extends StatelessWidget {
  const _StoreComparison({required this.stores, required this.slots});
  final List<StorePrices> stores;
  final Map<String, int> slots;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return const _Empty('Buy the same item at two stores to compare them.');
    }
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);
    final names = {for (final s in stores) ...s.byStore.keys}.toList()
      ..sort((a, b) => (slots[a] ?? 99).compareTo(slots[b] ?? 99));
    final summaries = <String>[];
    for (var i = 0; i < names.length; i++) {
      for (var j = i + 1; j < names.length; j++) {
        final gap = storeGap(stores, names[i], names[j]);
        if (gap == null) continue;
        // gap.fraction: how much pricier names[i] is than names[j].
        final (pricier, cheaper) =
            gap.fraction >= 0 ? (names[i], names[j]) : (names[j], names[i]);
        final f = gap.fraction >= 0 ? 1 - 1 / (1 + gap.fraction) : -gap.fraction;
        summaries.add('$cheaper is ${(f * 100).toStringAsFixed(0)}% cheaper than $pricier '
            'on the ${gap.items} item${gap.items == 1 ? '' : 's'} you bought at both.');
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final s in summaries) Text(s, style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      for (final item in stores.take(10))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name),
            Wrap(spacing: 12, children: [
              for (final e in (item.byStore.entries.toList()
                ..sort((a, b) => a.value.compareTo(b.value))))
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  LegendChip(
                    color: palette.series(slots[e.key] ?? 8),
                    label: '${e.key} \$${formatCents(e.value.round())}'
                        '${item.unit == 'each' ? '' : '/${item.unit}'}',
                  ),
                  if (e.key == item.cheapest.key)
                    Text(' cheapest',
                        style: theme.textTheme.bodySmall?.copyWith(color: palette.goodText)),
                ]),
            ]),
          ]),
        ),
    ]);
  }
}

String _percent(double f) => '${f >= 0 ? '+' : '−'}${(f.abs() * 100).toStringAsFixed(1)}%';
