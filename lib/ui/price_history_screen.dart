import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';

/// Testing UI: one product's unit price over time, coloured by store.
class PriceHistoryScreen extends StatelessWidget {
  const PriceHistoryScreen({super.key, required this.repo, required this.product});

  final ReceiptRepository repo;
  final ProductSummary product;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.displayName)),
      body: FutureBuilder(
        future: repo.priceHistory(product.id),
        builder: (context, snap) {
          final points = snap.data ?? const <PricePoint>[];
          if (points.isEmpty) return const SizedBox.shrink();
          final palette = ChartPalette.of(context);
          final slots = storeSlots(points.map((p) => (p.storeId, p.storeName)));
          final stores = slots.keys.toList()..sort((a, b) => slots[a]!.compareTo(slots[b]!));
          Color colorOf(PricePoint p) => palette.series(slots[p.storeName] ?? 8);
          final weighed = points.where((p) => p.unit != 'each').firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(weighed == null ? 'Price each' : 'Price per ${weighed.unit}',
                  style: Theme.of(context).textTheme.titleSmall),
              SizedBox(
                height: 200,
                child: CustomPaint(
                  painter: _PriceChartPainter(points, colorOf,
                      Theme.of(context).colorScheme.outlineVariant),
                  size: Size.infinite,
                ),
              ),
              Wrap(spacing: 12, children: [
                for (final s in stores)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.circle, size: 10,
                        color: palette.series(slots[s]!)),
                    const SizedBox(width: 4),
                    Text(s),
                  ]),
              ]),
              const Divider(),
              for (final p in points.reversed)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 10, color: colorOf(p)),
                  title: Text(formatCents(p.unitPriceCents)),
                  subtitle: Text('${DateFormat.yMMMd().format(p.date)} · ${p.storeName ?? '?'}'),
                  trailing: Text(p.quantity == 1
                      ? ''
                      : '${p.quantity} ${p.unit} = ${formatCents(p.netCents)}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PriceChartPainter extends CustomPainter {
  _PriceChartPainter(this.points, this.colorOf, this.gridColor);

  final List<PricePoint> points;
  final Color Function(PricePoint) colorOf;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 36.0;
    final prices = points.map((p) => p.unitPriceCents);
    var lo = prices.reduce(min).toDouble(), hi = prices.reduce(max).toDouble();
    if (hi == lo) {
      lo -= 50;
      hi += 50;
    }
    final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = max(points.last.date.millisecondsSinceEpoch.toDouble(), t0 + 1);
    Offset at(PricePoint p) => Offset(
          points.length == 1
              ? size.width / 2
              : pad + (p.date.millisecondsSinceEpoch - t0) / (t1 - t0) * (size.width - pad - 8),
          8 + (hi - p.unitPriceCents) / (hi - lo) * (size.height - 24),
        );

    final grid = Paint()..color = gridColor;
    for (final v in [lo, hi]) {
      final y = 8 + (hi - v) / (hi - lo) * (size.height - 24);
      canvas.drawLine(Offset(pad, y), Offset(size.width, y), grid);
      final label = TextPainter(
        text: TextSpan(text: formatCents(v.round()),
            style: TextStyle(color: gridColor, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - label.height / 2));
    }

    final line = Paint()
      ..color = gridColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()..addPolygon([for (final p in points) at(p)], false), line);
    for (final p in points) {
      canvas.drawCircle(at(p), 5, Paint()..color = colorOf(p));
    }
  }

  @override
  bool shouldRepaint(_PriceChartPainter old) => old.points != points;
}
