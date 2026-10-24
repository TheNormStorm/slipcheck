import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/price_insights.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'compare_screen.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'receipt_detail_screen.dart';
import 'reload_on_change.dart';
import 'theme/app_theme.dart';
import 'theme/contrast.dart';
import 'theme/tokens.dart';

/// One store: a header in its colour, what you spend there, what changed
/// price there, and its trips. Tick any two trips to compare them.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.repo, required this.storeId});
  final ReceiptRepository repo;
  final int storeId;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreData {
  _StoreData(this.store, this.allStores, this.receipts, this.changes, this.itemCount, this.slot);
  final StoreSummary store;
  final List<StoreSummary> allStores;
  final List<ReceiptSummary> receipts;
  final List<PriceChange> changes;

  /// Different items bought here.
  final int itemCount;
  final int? slot;
}

class _StoreScreenState extends State<StoreScreen> with ReloadOnChange {
  @override
  ReceiptRepository get repo => widget.repo;

  late Future<_StoreData?> _data = _load();

  /// Trips ticked for comparing, at most two.
  final _picked = <int>{};

  Future<_StoreData?> _load() async {
    final stores = await repo.stores();
    final store = stores.where((s) => s.id == widget.storeId).firstOrNull;
    // Merged into another store, or cleared.
    if (store == null) return null;
    final all = await repo.receipts();
    final here = (await repo.purchases()).where((p) => p.storeId == widget.storeId).toList();
    final slots = storeSlots(stores.where((s) => s.receiptCount > 0).map((s) => (s.id, s.name)));
    return _StoreData(
      store,
      stores,
      all.where((r) => r.storeId == widget.storeId).toList(),
      priceChanges(here),
      here.map((p) => p.productId).toSet().length,
      slots[store.name],
    );
  }

  @override
  void reload() {
    _data = _load();
  }

  Future<void> _compare(List<ReceiptSummary> receipts) async {
    final two = receipts.where((r) => _picked.contains(r.id)).toList()
      ..sort((a, b) => a.purchasedAt.compareTo(b.purchasedAt));
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CompareScreen(repo: repo, beforeId: two.first.id, afterId: two.last.id),
    ));
  }

  void _toggle(int id) => setState(() {
        if (!_picked.remove(id)) {
          // A third tick replaces the oldest of the two.
          if (_picked.length == 2) _picked.remove(_picked.first);
          _picked.add(id);
        }
      });

  Future<void> _merge(_StoreData data) async {
    final others = data.allStores.where((s) => s.id != widget.storeId).toList();
    final target = await showDialog<StoreSummary>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${data.store.name} is the same store as…'),
        children: [
          for (final s in others)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, s),
              child: Text('${s.name} (${plural(s.receiptCount, 'receipt')})'),
            ),
        ],
      ),
    );
    if (target == null) return;
    await repo.mergeStores(keepId: target.id, mergeId: widget.storeId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return Scaffold(
            body: SafeArea(
              child: ListView(padding: const EdgeInsets.all(14), children: [
                for (final h in <double>[140, 70, 64, 64])
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Skeleton(height: h, radius: t.rRow)),
              ]),
            ),
          );
        }
        final receipts = data.receipts;
        final picked = receipts.where((r) => _picked.contains(r.id)).length;
        final band = ChartPalette.of(context).series(data.slot ?? 8);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          // Status bar icons readable on the store's colour.
          value: readableOn(band) == Colors.white ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(data: data, onMerge: data.allStores.length > 1 ? () => _merge(data) : null),
              Padding(
                // Room for the tiles hanging 34 px below the header.
                padding: const EdgeInsets.fromLTRB(14, 34 + 14, 14, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (data.changes.isNotEmpty) ...[
                    Text('Price changes here', style: slipText(15, 900, color: t.ink)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final (i, c) in data.changes.take(8).indexed)
                        PopIn(
                          delayMs: 60 * i,
                          child: Semantics(
                            label: '${c.name} ${c.changeFraction > 0 ? 'up' : 'down'} '
                                '${(c.changeFraction.abs() * 100).round()} percent, '
                                'usually ${formatCents(c.typicalUnitPrice.round())}',
                            excludeSemantics: true,
                            child: TrendChip(
                              label: '${sentenceCase(c.name)} ${c.changeFraction > 0 ? '↑' : '↓'} '
                                  '${math.max(1, (c.changeFraction.abs() * 100).round())}%',
                              trend: c.changeFraction > 0 ? Trend.up : Trend.down,
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 6),
                  ],
                  SectionTitle(
                    'Trips',
                    trailing: receipts.length >= 2
                        ? Text(picked == 2 ? 'Ready to compare' : 'Pick 2 to compare',
                            style: slipText(12.5, 900, color: t.accText))
                        : null,
                  ),
                  for (final (i, r) in receipts.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Rise(
                        index: i.clamp(0, 10),
                        child: _TripRow(
                          receipt: r,
                          picked: _picked.contains(r.id),
                          canPick: receipts.length >= 2,
                          onPick: () => _toggle(r.id),
                          onOpen: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ReceiptDetailScreen(repo: repo, receiptId: r.id),
                          )),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ),
          bottomNavigationBar: picked == 2
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => _compare(receipts),
                        icon: const SlipIcon(Symbols.compare_arrows_rounded),
                        label: const Text('Compare these two'),
                      ),
                    ),
                  ),
                )
              : null,
        ),
        );
      },
    );
  }
}

/// The coloured band with the store's name, and three tiles overlapping it.
class _Header extends StatelessWidget {
  const _Header({required this.data, this.onMerge});
  final _StoreData data;
  final VoidCallback? onMerge;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final color = ChartPalette.of(context).series(data.slot ?? 8);
    final s = data.store;
    final trips = data.receipts.length;
    final perTrip = trips == 0 ? 0 : s.spentCents ~/ trips;
    final onBand = readableOn(color);
    Widget tile(String label, String value) => Expanded(
          child: StatTile(label: label, value: Text(value, style: slipText(18, 900, color: t.ink, tabular: true))),
        );
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        color: color,
        padding: EdgeInsets.fromLTRB(14, MediaQuery.paddingOf(context).top + 8, 14, 52),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAction(
              icon: Symbols.arrow_back_rounded,
              tooltip: 'Back',
              color: onBand.withValues(alpha: .18),
              iconColor: onBand,
              onTap: () => Navigator.maybePop(context),
            ),
            const Spacer(),
            if (onMerge != null)
              PopupMenuButton<String>(
                tooltip: 'More',
                iconColor: onBand,
                onSelected: (_) => onMerge!(),
                itemBuilder: (_) => const [PopupMenuItem(value: 'merge', child: Text('Same store as…'))],
              ),
          ]),
          const SizedBox(height: 14),
          Text(s.name, style: slipText(24, 900, color: onBand)),
          Text(
            '${plural(trips, 'trip')}${s.lastVisit == null ? '' : ' · last ${DateFormat.MMMd().format(s.lastVisit!)}'}',
            style: slipText(13, 800, color: onBand),
          ),
        ]),
      ),
      Positioned(
        left: 14,
        right: 14,
        bottom: -34,
        child: Row(children: [
          tile('Spent', formatCents(s.spentCents)),
          const SizedBox(width: 8),
          tile('Avg trip', formatCents(perTrip)),
          const SizedBox(width: 8),
          tile('Items', '${data.itemCount}'),
        ]),
      ),
    ]);
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({
    required this.receipt,
    required this.picked,
    required this.canPick,
    required this.onPick,
    required this.onOpen,
  });
  final ReceiptSummary receipt;
  final bool picked, canPick;
  final VoidCallback onPick, onOpen;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final r = receipt;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.rRow),
        border: Border.all(color: picked ? t.acc : Colors.transparent, width: 2),
      ),
      child: SlipCard(
        radius: t.rRow - 2,
        padding: const EdgeInsets.fromLTRB(4, 6, 14, 6),
        onTap: onOpen,
        child: Row(children: [
          if (canPick)
            Semantics(
              checked: picked,
              label: 'Pick ${DateFormat.MMMd().format(r.purchasedAt)} to compare',
              child: Checkbox(value: picked, onChanged: (_) => onPick(), shape: const CircleBorder()),
            )
          else
            const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('EEE, MMM d').format(r.purchasedAt), style: slipText(15, 900, color: t.ink)),
              Text(plural(r.itemCount, 'item'), style: slipText(12.5, 700, color: t.ink2)),
            ]),
          ),
          Text(formatCents(r.spentCents), style: slipText(15, 900, color: t.ink, tabular: true)),
        ]),
      ),
    );
  }
}
