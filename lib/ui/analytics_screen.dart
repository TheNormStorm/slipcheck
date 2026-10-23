import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/analytics/price_insights.dart';
import '../core/analytics/purchase.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';

/// Spending by month and store, how the prices of what you buy have moved,
/// which items changed price most, and where the same item is cheaper.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.repo});
  final ReceiptRepository repo;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _Data {
  _Data(this.receipts, this.purchases);
  final List<ReceiptSummary> receipts;
  final List<Purchase> purchases;
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final Future<_Data> _data = _load();

  Future<_Data> _load() async =>
      _Data(await widget.repo.receipts(), await widget.repo.purchases());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
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
                child: _MonthlySpending(receipts: data.receipts, slots: slots),
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

/// Stacked bars: one per month, one segment per store.
class _MonthlySpending extends StatelessWidget {
  const _MonthlySpending({required this.receipts, required this.slots});
  final List<ReceiptSummary> receipts;
  final Map<String, int> slots;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final byMonth = <DateTime, Map<String, int>>{};
    for (final r in receipts) {
      final m = DateTime(r.purchasedAt.year, r.purchasedAt.month);
      final store = r.storeName ?? 'Unknown store';
      byMonth.putIfAbsent(m, () => {});
      byMonth[m]![store] = (byMonth[m]![store] ?? 0) + r.spentCents;
    }
    final months = byMonth.keys.toList()..sort();
    final shown = months.length > 12 ? months.sublist(months.length - 12) : months;
    final storeOrder = slots.keys.toList()..sort((a, b) => slots[a]!.compareTo(slots[b]!));
    Color colorOf(String store) => palette.series(slots[store] ?? 8);
    final maxY = shown
        .map((m) => byMonth[m]!.values.fold(0, (s, v) => s + v) / 100)
        .fold(0.0, math.max);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (storeOrder.length >= 2)
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (final s in storeOrder) LegendChip(color: colorOf(s), label: s),
        ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 200,
        child: BarChart(BarChartData(
          maxY: _niceMax(maxY),
          borderData: FlBorderData(
              show: true, border: Border(bottom: BorderSide(color: palette.baseline))),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: _niceMax(maxY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: palette.grid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: _niceMax(maxY) / 4,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text('\$${v.round()}',
                      style: TextStyle(color: palette.muted, fontSize: 11)),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(DateFormat.MMM().format(shown[v.toInt()]),
                      style: TextStyle(color: palette.muted, fontSize: 11)),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => palette.ink,
              getTooltipItem: (group, _, rod, _) {
                final m = shown[group.x];
                final parts = byMonth[m]!;
                return BarTooltipItem(
                  '${DateFormat.yMMM().format(m)}\n'
                  '${[for (final s in storeOrder.where(parts.containsKey)) '$s \$${formatCents(parts[s]!)}'].join('\n')}'
                  '${parts.keys.any((s) => !slots.containsKey(s)) ? '\n${parts.entries.where((e) => !slots.containsKey(e.key)).map((e) => '${e.key} \$${formatCents(e.value)}').join('\n')}' : ''}',
                  TextStyle(color: palette.surface, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: [
            for (final (i, m) in shown.indexed)
              () {
                var from = 0.0;
                final parts = byMonth[m]!;
                final stack = <BarChartRodStackItem>[];
                for (final s in [...storeOrder, ...parts.keys.where((k) => !slots.containsKey(k))]) {
                  final v = parts[s];
                  if (v == null) continue;
                  stack.add(BarChartRodStackItem(from, from + v / 100, colorOf(s),
                      borderSide: BorderSide(color: palette.surface, width: 1)));
                  from += v / 100;
                }
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: from,
                    width: 18,
                    rodStackItems: stack,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ]);
              }(),
          ],
        )),
      ),
      const SizedBox(height: 8),
      // The same numbers as text (the lighter colours are low-contrast).
      for (final m in shown.reversed.take(3))
        Text(
          '${DateFormat.yMMMM().format(m)}: \$${formatCents(byMonth[m]!.values.fold(0, (s, v) => s + v))}',
          style: Theme.of(context).textTheme.bodySmall,
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

double _niceMax(double v) {
  if (v <= 0) return 10;
  final step = math.pow(10, (math.log(v / 4) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (m * step * 4 >= v) return m * step * 4;
  }
  return v;
}

String _percent(double f) => '${f >= 0 ? '+' : '−'}${(f.abs() * 100).toStringAsFixed(1)}%';
