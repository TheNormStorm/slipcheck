import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/purchase.dart' show median;
import '../core/categories.dart';
import '../core/matching/cross_store.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// One item: its price on each visit in the store's colour, what it usually
/// costs at each store, the names receipts printed it as, and likely
/// matches at other stores to link it with. Rename and category are here.
class PriceHistoryScreen extends StatefulWidget {
  const PriceHistoryScreen({super.key, required this.repo, required this.product});

  final ReceiptRepository repo;
  final ProductSummary product;

  @override
  State<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _ItemData {
  _ItemData(this.product, this.points, this.suggestions, this.slots, this.namesRead);
  final ProductSummary product;
  final List<PricePoint> points;
  final List<(ProductSummary, String)> suggestions;
  final Map<String, int> slots;
  final List<String> namesRead;
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
    final suggestions = suggestSameProduct(info(me), [for (final p in products) info(p)]);
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
      await widget.repo.namesRead(me.id),
    );
  }

  void _reload() => setState(() {
        _data = _load();
      });

  Future<void> _changeCategory(ProductSummary product) async {
    final t = SlipTokens.of(context);
    final picked = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .75),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 0, 8, 12), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text('Category', style: slipText(20, 900, color: t.ink)),
            ),
            for (final c in Category.values)
              ListTile(
                leading: CategoryTile(category: c, color: categoryColor(c, ChartPalette.of(context)), size: 32),
                title: Text(c.label, style: slipText(15, 800, color: t.ink)),
                trailing: c == product.category ? SlipIcon(Symbols.check_rounded, color: t.accText) : null,
                onTap: () => Navigator.pop(context, c),
              ),
          ]),
        ),
      ),
    );
    if (picked == null || picked == product.category) return;
    await widget.repo.setCategory(product.id, picked);
    _reload();
  }

  Future<void> _link(ProductSummary me, ProductSummary other, String where) async {
    HapticFeedback.selectionClick();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: SlipIcon(Symbols.link_rounded, size: 32, color: SlipTokens.of(context).accText),
        title: const Text('Same item?'),
        content: Text('"${other.displayName}" at $where will be treated as '
            '"${me.displayName}", so their prices are compared. '
            'Future receipts with either name match it automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not the same')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Link')),
        ],
      ),
    );
    if (ok != true) return;
    final undo = await widget.repo.mergeProducts(keepId: me.id, mergeId: other.id);
    _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Linked ${sentenceCase(other.displayName)}.'),
      duration: const Duration(seconds: 8),
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await widget.repo.undoMerge(undo);
          _reload();
        },
      ),
    ));
  }

  Future<void> _rename(ProductSummary product) async {
    final controller = TextEditingController(text: product.displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || name == product.displayName) return;
    await widget.repo.renameProduct(product.id, name);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            final data = snap.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                Row(children: [
                  CircleAction(
                      icon: Symbols.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.maybePop(context)),
                  const Spacer(),
                  if (data != null) ...[
                    ActionChip(
                      avatar: SlipIcon(categoryIcon(data.product.category), size: 16, color: t.ink),
                      label: Text(data.product.category.label),
                      labelStyle: slipText(12.5, 900, color: t.ink),
                      backgroundColor: t.surf2,
                      side: t.outline ?? BorderSide.none,
                      shape: const StadiumBorder(),
                      tooltip: 'Change category',
                      onPressed: () => _changeCategory(data.product),
                    ),
                    const SizedBox(width: 8),
                    CircleAction(
                        icon: Symbols.edit_rounded, tooltip: 'Rename item', onTap: () => _rename(data.product)),
                  ],
                ]),
                const SizedBox(height: 10),
                if (data == null)
                  for (final h in <double>[40, 230, 80])
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Skeleton(height: h, radius: t.rCard))
                else
                  ..._body(context, data),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, _ItemData data) {
    final t = SlipTokens.of(context);
    final palette = ChartPalette.of(context);
    final p = data.product;
    final also = data.namesRead.where((n) => n.toLowerCase() != p.displayName.toLowerCase()).take(2).toList();
    final points = data.points;
    final unit = points.lastOrNull?.unit ?? 'each';
    final sameUnit = points.where((x) => x.unit == unit).toList();
    final per = unit == 'each' ? '' : '/$unit';
    Color colorOf(String? store) => palette.series(data.slots[store] ?? 8);

    // What it usually costs at each store, cheapest first.
    final byStore = <String, List<double>>{};
    for (final x in sameUnit) {
      byStore.putIfAbsent(x.storeName ?? 'Unknown store', () => []).add(x.unitPriceCents.toDouble());
    }
    final usual = [for (final e in byStore.entries) (e.key, median(e.value))]..sort((a, b) => a.$2.compareTo(b.$2));

    return [
      Rise(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sentenceCase(p.displayName), style: slipText(24, 900, color: t.ink, height: 1.15)),
          if (also.isNotEmpty)
            Text('Also read as ${also.map((n) => '"$n"').join(', ')}', style: slipText(12.5, 700, color: t.ink2)),
        ]),
      ),
      const SizedBox(height: 12),
      if (sameUnit.isNotEmpty) Rise(index: 1, child: _PriceCard(points: sameUnit, per: per, colorOf: colorOf)),
      if (usual.length > 1 || (usual.length == 1 && sameUnit.length > 1)) ...[
        const SizedBox(height: 10),
        Rise(
          index: 2,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (i, (store, price)) in usual.take(3).indexed) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: store,
                  color: i == 0 && usual.length > 1 ? t.downSoft : null,
                  ink: i == 0 && usual.length > 1 ? t.downText : null,
                  value: Text('${formatCents(price.round())}$per', style: slipText(20, 900, tabular: true)),
                  footer: Text(
                    usual.length == 1
                        ? 'usual'
                        : i == 0
                            ? 'usual · cheapest'
                            : 'usual · +${(price / usual.first.$2 * 100 - 100).round()}%',
                    style: slipText(11.5, 800, color: i == 0 && usual.length > 1 ? t.downText : t.ink2),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ],
      for (final (other, where) in data.suggestions) ...[
        const SizedBox(height: 10),
        Rise(
          index: 3,
          child: _LinkCard(
            text: 'Same as ${sentenceCase(other.displayName)}${where.isEmpty ? '' : ' at $where'}?',
            onLink: () => _link(p, other, where),
          ),
        ),
      ],
      if (points.length > 8) ...[
        const SectionTitle('Every visit'),
        SlipCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (final (i, x) in points.reversed.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(
                      width: 9, height: 9, decoration: BoxDecoration(color: colorOf(x.storeName), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${DateFormat.yMMMd().format(x.date)} · ${x.storeName ?? 'Unknown store'}',
                        style: slipText(13, 700, color: t.ink)),
                  ),
                  Text('${formatCents(x.unitPriceCents)}${x.unit == 'each' ? '' : '/${x.unit}'}',
                      style: slipText(13.5, 900, color: t.ink, tabular: true)),
                ]),
              ),
            ],
          ]),
        ),
      ],
    ];
  }
}

/// The latest price, how it moved since the first visit, and a bar per
/// visit (the last eight) in the store's colour with its price above.
class _PriceCard extends StatelessWidget {
  const _PriceCard({required this.points, required this.per, required this.colorOf});
  final List<PricePoint> points;
  final String per;
  final Color Function(String?) colorOf;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final shown = points.length > 8 ? points.sublist(points.length - 8) : points;
    final latest = points.last.unitPriceCents, first = points.first.unitPriceCents;
    final change = points.length < 2 || first == 0 ? null : latest / first - 1;
    final hi = shown.map((p) => p.unitPriceCents).reduce(math.max).toDouble();
    final lo = shown.map((p) => p.unitPriceCents).reduce(math.min).toDouble();
    final stores = {for (final p in shown) p.storeName};
    return SlipCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Wraps so a long "since" chip drops below the price on a narrow phone.
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 4, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            CountUp(cents: latest, style: slipText(32, 900, color: t.ink, tabular: true)),
            if (per.isNotEmpty) Text(per, style: slipText(16, 900, color: t.ink2)),
          ]),
          if (change != null && (change.abs() >= .01))
            TrendChip(
              label: '${change > 0 ? '↑' : '↓'} ${(change.abs() * 100).round()}% since '
                  '${DateFormat.MMM().format(points.first.date)}',
              trend: change > 0 ? Trend.up : Trend.down,
            )
          else if (change != null)
            const TrendChip(label: 'steady'),
        ]),
        const SizedBox(height: 12),
        Semantics(
          label: [
            for (final p in shown)
              '${DateFormat.MMMd().format(p.date)} at ${p.storeName ?? 'unknown store'}: ${formatCents(p.unitPriceCents)}'
          ].join('. '),
          excludeSemantics: true,
          child: SizedBox(
            height: 130,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (i, p) in shown.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    FittedBox(
                      child: Text(formatCents(p.unitPriceCents), style: slipText(11, 900, color: t.ink, tabular: true)),
                    ),
                    const SizedBox(height: 3),
                    GrowIn(
                      delayMs: 80 * i,
                      child: Container(
                        height: 24 + 64 * (hi == lo ? .6 : (p.unitPriceCents - lo) / (hi - lo)),
                        decoration: BoxDecoration(color: colorOf(p.storeName), borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(child: Text(DateFormat.MMMd().format(p.date), style: slipText(10.5, 800, color: t.ink2))),
                  ]),
                ),
              ],
            ]),
          ),
        ),
        if (stores.length > 1) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 4, children: [
            for (final s in stores)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 9, height: 9, decoration: BoxDecoration(color: colorOf(s), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
                Text(s ?? 'Unknown store', style: slipText(12, 800, color: t.ink)),
              ]),
          ]),
        ],
      ]),
    );
  }
}

/// "Same as 365 MILK 2% GAL at Whole Foods?" in a dashed orange card.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.text, required this.onLink});
  final String text;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return CustomPaint(
      painter: _DashedBorder(color: t.acc, radius: t.rRow),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(children: [
          SlipIcon(Symbols.link_rounded, color: t.accText),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: slipText(13.5, 800, color: t.ink))),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              textStyle: slipText(13, 900),
            ),
            onPressed: onLink,
            child: const Text('Link'),
          ),
        ]),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color || old.radius != radius;
}
