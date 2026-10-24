import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/insights.dart';
import '../core/categories.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'price_history_screen.dart';
import 'reload_on_change.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// Every item you have bought: search, filter by what went up or by
/// category, and each item's recent prices at a glance.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.repo});

  final ReceiptRepository repo;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

/// What the list shows: everything, what went up, or one category.
sealed class _Filter {
  const _Filter();
}

class _All extends _Filter {
  const _All();
}

class _WentUp extends _Filter {
  const _WentUp();
}

class _InCategory extends _Filter {
  const _InCategory(this.category);
  final Category category;

  @override
  bool operator ==(Object other) => other is _InCategory && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

class _ItemsData {
  _ItemsData(this.products, this.trends);
  final List<ProductSummary> products;
  final Map<int, ItemTrend> trends;
}

class _ProductsScreenState extends State<ProductsScreen> with ReloadOnChange {
  @override
  ReceiptRepository get repo => widget.repo;

  late Future<_ItemsData> _data = _load();
  final _search = TextEditingController();
  _Filter _filter = const _All();

  Future<_ItemsData> _load() async => _ItemsData(await repo.products(), itemTrends(await repo.purchases()));

  @override
  void reload() {
    _data = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _shows(ProductSummary p, ItemTrend? trend) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty && !p.displayName.toLowerCase().contains(q)) return false;
    return switch (_filter) {
      _All() => true,
      _WentUp() => trend?.wentUp ?? false,
      _InCategory(:final category) => p.category == category,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            final data = snap.data;
            final products = (data?.products ?? const <ProductSummary>[]).where((p) => p.purchaseCount > 0).toList()
              ..sort((a, b) => b.spentCents.compareTo(a.spentCents));
            // Category chips for what you buy, most spent first.
            final spentBy = <Category, int>{};
            for (final p in products) {
              spentBy[p.category] = (spentBy[p.category] ?? 0) + p.spentCents;
            }
            final categories = spentBy.keys.toList()..sort((a, b) => spentBy[b]!.compareTo(spentBy[a]!));
            final shown = [for (final p in products) if (_shows(p, data?.trends[p.id])) p];
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  Text('Items', style: slipText(28, 900, color: t.ink, letterSpacing: -.5)),
                  const SizedBox(width: 6),
                  if (data != null) Text('${products.length}', style: slipText(15, 900, color: t.ink2)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: slipText(15, 700, color: t.ink),
                  decoration: InputDecoration(
                    hintText: 'Find an item',
                    hintStyle: slipText(15, 600, color: t.ink2),
                    prefixIcon: SlipIcon(Symbols.search_rounded, color: t.ink2),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: SlipIcon(Symbols.close_rounded, color: t.ink2),
                            onPressed: () => setState(_search.clear),
                          ),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999), borderSide: t.outline ?? BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: t.acc, width: 2)),
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                  children: [
                    _chip('All', const _All()),
                    _chip('Went up', const _WentUp()),
                    for (final c in categories) _chip(c.label, _InCategory(c)),
                  ],
                ),
              ),
              Expanded(
                child: data == null
                    ? ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 24), children: [
                        for (var i = 0; i < 6; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Skeleton(height: 60, radius: t.rRow),
                          ),
                      ])
                    : shown.isEmpty
                        ? ListView(padding: const EdgeInsets.only(top: 48), children: [
                            Center(
                              child: Text(
                                products.isEmpty ? 'No items yet.' : 'Nothing here.',
                                style: slipText(14, 700, color: t.ink2),
                              ),
                            ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final p = shown[i];
                              return Rise(
                                key: ValueKey(p.id),
                                index: i.clamp(0, 10),
                                child: _ItemRow(
                                  product: p,
                                  trend: data.trends[p.id],
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => PriceHistoryScreen(repo: repo, product: p),
                                  )),
                                ),
                              );
                            },
                          ),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _chip(String label, _Filter filter) {
    final t = SlipTokens.of(context);
    // _All and _WentUp are const, so the same instance; categories compare by value.
    final on = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () => setState(() => _filter = filter),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: on ? t.ink : t.surf2, borderRadius: BorderRadius.circular(999)),
            child: Text(label, style: slipText(12.5, 900, color: on ? t.bg : t.ink2)),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.product, required this.trend, required this.onTap});
  final ProductSummary product;
  final ItemTrend? trend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final p = product;
    final tr = trend;
    final stores = p.storeIds.length;
    final unit = tr?.unit ?? p.lastUnit;
    final price = tr?.latestUnitPrice.round() ?? p.lastUnitPriceCents;
    final (String change, Color changeColor, Trend dir) = tr == null || tr.isNew
        ? ('new', t.ink2, Trend.same)
        : tr.change == null
            ? ('', t.ink2, Trend.same)
            : tr.wentUp
                ? ('+${(tr.change! * 100).round()}%', t.upText, Trend.up)
                : tr.wentDown
                    ? ('−${(tr.change!.abs() * 100).round()}%', t.downText, Trend.down)
                    : ('same', t.ink2, Trend.same);
    final name = sentenceCase(p.displayName);
    return Semantics(
      button: true,
      label: '$name, ${p.category.label}, ${plural(stores, 'store')}'
          '${price == null ? '' : ', ${formatCents(price)}${unit == 'each' ? '' : ' per $unit'}'}'
          '${change.isEmpty ? '' : ', $change'}',
      excludeSemantics: true,
      child: SlipCard(
        radius: t.rRow,
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        onTap: onTap,
        child: Row(children: [
          CategoryTile(category: p.category, color: categoryColor(p.category, ChartPalette.of(context))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: slipText(14, 900, color: t.ink)),
              Text(
                '${p.category.label} · ${unit == 'each' ? plural(stores, 'store') : 'per $unit'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: slipText(12, 700, color: t.ink2),
              ),
            ]),
          ),
          if (tr != null) Sparkline(values: tr.recent, trend: dir),
          const SizedBox(width: 12),
          SizedBox(
            width: 58,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(price == null ? '—' : formatCents(price), style: slipText(14.5, 900, color: t.ink, tabular: true)),
              if (change.isNotEmpty) Text(change, style: slipText(11.5, 900, color: changeColor, tabular: true)),
            ]),
          ),
        ]),
      ),
    );
  }
}
