import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/categories.dart';
import '../core/matching/cross_store.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';

/// One item: its unit price over time coloured by store, its category, and
/// likely matches at other stores to link it with.
class PriceHistoryScreen extends StatefulWidget {
  const PriceHistoryScreen({super.key, required this.repo, required this.product});

  final ReceiptRepository repo;
  final ProductSummary product;

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _ItemData {
  _ItemData(this.product, this.points, this.suggestions, this.slots);
  final ProductSummary product;
  final List<PricePoint> points;
  final List<(ProductSummary, String)> suggestions;
  final Map<String, int> slots;
}

class _PriceHistoryScreenState extends State<PriceHistoryScreen> {
  late Future<_ItemData> _data = _load();

  Future<_ItemData> _load() async {
    final products = await widget.repo.products();
    final stores = await widget.repo.stores();
    final storeNames = {for (final s in stores) s.id: s.name};
    final me = products.firstWhere((p) => p.id == widget.product.id);
    // "Other" means not yet known, so it never rules a match out.
    ProductInfo info(ProductSummary p) => ProductInfo(
        id: p.id,
        name: p.displayName,
        storeIds: p.storeIds,
        category: p.category == Category.other ? null : p.category.name);
    final suggestions = suggestSameProduct(
      info(me),
      [for (final p in products) info(p)],
    );
    return _ItemData(
      me,
      await widget.repo.priceHistory(me.id),
      [
        for (final s in suggestions)
          () {
            final p = products.firstWhere((p) => p.id == s.product.id);
            return (p, p.storeIds.map((id) => storeNames[id]).whereType<String>().join(', '));
          }(),
      ],
      storeSlots(stores.where((s) => s.receiptCount > 0).map((s) => (s.id, s.name))),
    );
  }

  void _reload() => setState(() {
        _data = _load();
      });

  Future<void> _changeCategory(ProductSummary product) async {
    final picked = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Category'),
        children: [
          for (final c in Category.values)
            ListTile(
              leading: Icon(c == product.category ? Icons.check : null),
              title: Text(c.label),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await widget.repo.setCategory(product.id, picked);
    _reload();
  }

  Future<void> _link(ProductSummary me, ProductSummary other, String where) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Same item?'),
        content: Text('"${other.displayName}" at $where will be treated as '
            '"${me.displayName}", so their prices are compared. '
            'Future receipts with either name match it automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Link')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.mergeProducts(keepId: me.id, mergeId: other.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product.displayName)),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!;
          final points = data.points;
          final theme = Theme.of(context);
          final palette = ChartPalette.of(context);
          final slots = data.slots;
          final stores = {for (final p in points) p.storeName ?? '?'}.toList()
            ..sort((a, b) => (slots[a] ?? 99).compareTo(slots[b] ?? 99));
          Color colorOf(PricePoint p) => palette.series(slots[p.storeName] ?? 8);
          final weighed = points.where((p) => p.unit != 'each').firstOrNull;

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: Text(data.product.category.label),
                  onPressed: () => _changeCategory(data.product),
                ),
              ),
              const SizedBox(height: 8),
              if (points.isNotEmpty) ...[
                Text(weighed == null ? 'Price each' : 'Price per ${weighed.unit}',
                    style: theme.textTheme.titleSmall),
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: _PriceChartPainter(points, colorOf,
                        theme.colorScheme.outlineVariant),
                    size: Size.infinite,
                  ),
                ),
                Wrap(spacing: 12, children: [
                  for (final s in stores)
                    LegendChip(color: palette.series(slots[s] ?? 8), label: s),
                ]),
              ],
              if (data.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Same item at another store?', style: theme.textTheme.titleSmall),
                Text('Link them to compare prices across stores.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                for (final (other, where) in data.suggestions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(other.displayName),
                    subtitle: Text('$where · ${other.lastUnitPriceCents == null ? '' : '\$${formatCents(other.lastUnitPriceCents!)}'}'),
                    trailing: OutlinedButton(
                      onPressed: () => _link(data.product, other, where),
                      child: const Text('Link'),
                    ),
                  ),
              ],
              const Divider(),
              for (final p in points.reversed)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 10, color: colorOf(p)),
                  title: Text(formatCents(p.unitPriceCents)),
                  subtitle: Text('${DateFormat.yMMMd().format(p.date)} · ${p.storeName ?? '?'}'),
                  trailing: Text(p.quantity == 1
                      ? ''
                      : '${p.quantity == p.quantity.roundToDouble() ? p.quantity.toInt() : p.quantity} '
                          '${p.unit} = ${formatCents(p.netCents)}'),
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
