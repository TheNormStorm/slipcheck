import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'receipt_detail_screen.dart';
import 'reload_on_change.dart';
import 'store_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// Every saved receipt, by month or grouped by store, with search by store
/// or by anything bought.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key, required this.repo});
  final ReceiptRepository repo;

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> with ReloadOnChange {
  @override
  ReceiptRepository get repo => widget.repo;

  late Future<List<ReceiptSummary>> _receipts = repo.receipts();
  late Future<List<StoreSummary>> _stores = repo.stores();
  bool _byStore = false;

  final _search = TextEditingController();
  String _query = '';

  /// Receipts with an item matching [_query].
  Set<int> _itemMatches = {};
  Timer? _debounce;

  @override
  void reload() {
    _receipts = repo.receipts();
    _stores = repo.stores();
    _lookUpItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    // Shows or hides the clear button straight away.
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _query = value.trim();
      _lookUpItems();
    });
  }

  Future<void> _lookUpItems() async {
    final query = _query;
    final ids = await repo.receiptsWithItem(query);
    if (mounted && query == _query) setState(() => _itemMatches = ids);
  }

  bool _matches(ReceiptSummary r) =>
      _query.isEmpty ||
      (r.storeName ?? '').toLowerCase().contains(_query.toLowerCase()) ||
      _itemMatches.contains(r.id);

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(children: [
              Expanded(child: Text('Receipts', style: slipText(28, 900, color: t.ink, letterSpacing: -.5))),
              _Segmented(
                value: _byStore,
                onChanged: (v) => setState(() => _byStore = v),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              style: slipText(15, 700, color: t.ink),
              decoration: InputDecoration(
                hintText: 'Search stores and items',
                hintStyle: slipText(15, 600, color: t.ink2),
                prefixIcon: SlipIcon(Symbols.search_rounded, color: t.ink2),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: SlipIcon(Symbols.close_rounded, color: t.ink2),
                        onPressed: () {
                          _search.clear();
                          _onSearch('');
                        },
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
          Expanded(child: _byStore ? _storeList() : _receiptList()),
        ]),
      ),
    );
  }

  Widget _empty(String text) {
    final t = SlipTokens.of(context);
    return ListView(padding: const EdgeInsets.only(top: 48), children: [
      Center(child: Text(text, style: slipText(14, 700, color: t.ink2))),
    ]);
  }

  Widget _receiptList() => FutureBuilder(
        future: Future.wait([_receipts, _stores]),
        builder: (context, snap) {
          if (!snap.hasData) return const _ListSkeleton();
          final all = snap.data![0] as List<ReceiptSummary>;
          final stores = snap.data![1] as List<StoreSummary>;
          if (all.isEmpty) return _empty('No receipts yet.');
          final receipts = all.where(_matches).toList();
          if (receipts.isEmpty) return _empty('Nothing matches “$_query”.');
          final t = SlipTokens.of(context);
          final palette = ChartPalette.of(context);
          final slots = storeSlots(stores.where((s) => s.receiptCount > 0).map((s) => (s.id, s.name)));
          // Newest first, with a heading and total for each month.
          final months = <DateTime, List<ReceiptSummary>>{};
          for (final r in receipts) {
            months.putIfAbsent(DateTime(r.purchasedAt.year, r.purchasedAt.month), () => []).add(r);
          }
          var index = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            children: [
              for (final MapEntry(key: month, value: list) in months.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(DateFormat.yMMMM().format(month), style: slipText(13, 800, color: t.ink2)),
                    ),
                    Text(formatCents(list.fold(0, (s, r) => s + r.spentCents)),
                        style: slipText(13, 900, color: t.ink2, tabular: true)),
                  ]),
                ),
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Rise(
                      index: (index++).clamp(0, 10),
                      child: ReceiptCard(
                        receipt: r,
                        color: palette.series(slots[r.storeName] ?? 8),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ReceiptDetailScreen(repo: repo, receiptId: r.id),
                        )),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      );

  Widget _storeList() => FutureBuilder(
        future: Future.wait([_receipts, _stores]),
        builder: (context, snap) {
          if (!snap.hasData) return const _ListSkeleton();
          final receipts = snap.data![0] as List<ReceiptSummary>;
          final all = (snap.data![1] as List<StoreSummary>).where((s) => s.receiptCount > 0).toList();
          if (all.isEmpty) return _empty('No receipts yet.');
          // A store matches by name, or by a receipt there with a matching item.
          final matchingStores = {for (final r in receipts.where(_matches)) r.storeId};
          final stores = all.where((s) => matchingStores.contains(s.id)).toList();
          if (stores.isEmpty) return _empty('Nothing matches “$_query”.');
          final palette = ChartPalette.of(context);
          final slots = storeSlots(all.map((s) => (s.id, s.name)));
          final t = SlipTokens.of(context);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            itemCount: stores.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = stores[i];
              return Rise(
                index: i,
                child: SlipCard(
                  radius: t.rRow,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StoreScreen(repo: repo, storeId: s.id),
                  )),
                  child: Row(children: [
                    StoreAvatar(name: s.name, color: palette.series(slots[s.name] ?? 8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(s.name, style: slipText(15.5, 800, color: t.ink)),
                        Text(
                          '${plural(s.receiptCount, 'trip')}'
                          '${s.lastVisit == null ? '' : ' · last ${DateFormat.MMMd().format(s.lastVisit!)}'}',
                          style: slipText(12.5, 600, color: t.ink2),
                        ),
                      ]),
                    ),
                    Text(formatCents(s.spentCents), style: slipText(16, 900, color: t.ink, tabular: true)),
                  ]),
                ),
              );
            },
          );
        },
      );
}

/// "By date / By store" as a small pill switch.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    Widget option(bool v, String label) {
      final on = v == value;
      return Semantics(
        selected: on,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: on ? t.surf : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: on && !t.punchy
                  ? [BoxShadow(color: t.ink.withValues(alpha: .08), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
              border: on && t.punchy ? Border.all(color: t.acc, width: 1.5) : null,
            ),
            child: Text(label, style: slipText(12.5, 900, color: on ? t.ink : t.ink2)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option(false, 'By date'), option(true, 'By store')]),
    );
  }
}

/// A receipt in a list: store-coloured avatar, store, date and item count,
/// and the amount.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.receipt, required this.color, this.onTap, this.highlight = false, this.trailingChip});
  final ReceiptSummary receipt;
  final Color color;
  final VoidCallback? onTap;
  final bool highlight;
  final Widget? trailingChip;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final r = receipt;
    return SlipCard(
      radius: t.rRow,
      color: highlight ? (t.punchy ? const Color(0xFF2E211A) : const Color(0xFFFFF1E7)) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        StoreAvatar(name: r.storeName ?? '?', color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.storeName ?? 'Unknown store', style: slipText(15.5, 800, color: t.ink)),
            Text('${DateFormat.MMMd().format(r.purchasedAt)} · ${plural(r.itemCount, 'item')}',
                style: slipText(12.5, 600, color: t.ink2)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatCents(r.spentCents), style: slipText(16, 900, color: t.ink, tabular: true)),
          ?trailingChip,
        ]),
      ]),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Skeleton(height: 64, radius: SlipTokens.of(context).rRow),
            ),
        ],
      );
}
