import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';

/// Stacked bars: one per month, one segment per store.
class MonthlySpendingChart extends StatelessWidget {
  const MonthlySpendingChart({super.key, required this.receipts, required this.slots});
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
          maxY: niceMax(maxY),
          borderData: FlBorderData(
              show: true, border: Border(bottom: BorderSide(color: palette.baseline))),
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: niceMax(maxY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: palette.grid, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: niceMax(maxY) / 4,
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

/// A round axis maximum at or above [v] that splits into four nice steps.
double niceMax(double v) {
  if (v <= 0) return 10;
  final step = math.pow(10, (math.log(v / 4) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (m * step * 4 >= v) return m * step * 4;
  }
  return v;
}

