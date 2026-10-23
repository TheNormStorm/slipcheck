import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/analytics/price_insights.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'charts.dart';
import 'compare_screen.dart';
import 'receipt_detail_screen.dart';

/// One store: what you spend there, its receipts, and what changed price
/// there. Any two of its receipts can be compared.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.repo, required this.storeId});
  final ReceiptRepository repo;
  final int storeId;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreData {
  _StoreData(this.store, this.allStores, this.receipts, this.changes, this.slots);
  final StoreSummary store;
  final List<StoreSummary> allStores;
  final List<ReceiptSummary> receipts;
  final List<PriceChange> changes;
  final Map<String, int> slots;
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<_StoreData> _data = _load();

  Future<_StoreData> _load() async {
    final stores = await widget.repo.stores();
    final all = await widget.repo.receipts();
    final purchases = await widget.repo.purchases();
    return _StoreData(
      stores.firstWhere((s) => s.id == widget.storeId),
      stores,
      all.where((r) => r.storeId == widget.storeId).toList(),
      priceChanges(purchases.where((p) => p.storeId == widget.storeId).toList()),
      storeSlots(all.map((r) => (r.storeId, r.storeName))),
    );
  }

  void _reload() => setState(() {
        _data = _load();
      });

  /// Compares two of this store's receipts, older first.
  Future<void> _compare(ReceiptSummary a, ReceiptSummary b) async {
    final (before, after) = a.purchasedAt.isAfter(b.purchasedAt) ? (b, a) : (a, b);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) =>
          CompareScreen(repo: widget.repo, beforeId: before.id, afterId: after.id),
    ));
  }

  Future<void> _pickTwo(List<ReceiptSummary> receipts) async {
    final picked = <ReceiptSummary>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Pick two receipts to compare'),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final r in receipts)
                  CheckboxListTile(
                    value: picked.contains(r),
                    title: Text(DateFormat.yMMMEd().format(r.purchasedAt)),
                    subtitle: Text('${r.itemCount} item${r.itemCount == 1 ? '' : 's'}'),
                    secondary: Text('\$${formatCents(r.spentCents)}'),
                    onChanged: (v) => setSheet(() {
                      if (v == true && picked.length < 2) picked.add(r);
                      if (v == false) picked.remove(r);
                    }),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: picked.length == 2 ? () => Navigator.pop(context, true) : null,
                child: const Text('Compare'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (ok == true && mounted) await _compare(picked.first, picked.last);
  }

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
              child: Text('${s.name} (${s.receiptCount} receipts)'),
            ),
        ],
      ),
    );
    if (target == null) return;
    await widget.repo.mergeStores(keepId: target.id, mergeId: widget.storeId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!;
        final theme = Theme.of(context);
        final palette = ChartPalette.of(context);
        final receipts = data.receipts;
        final perTrip = receipts.isEmpty ? 0 : data.store.spentCents ~/ receipts.length;

        Widget stat(String label, String value) => Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: theme.textTheme.bodySmall),
                    Text(value, style: theme.textTheme.titleLarge),
                  ]),
                ),
              ),
            );

        return Scaffold(
          appBar: AppBar(
            title: Text(data.store.name),
            actions: [
              if (data.allStores.length > 1)
                PopupMenuButton<String>(
                  onSelected: (_) => _merge(data),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'merge', child: Text('Same store as…')),
                  ],
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(children: [
                stat('Spent', '\$${formatCents(data.store.spentCents)}'),
                const SizedBox(width: 8),
                stat('Trips', '${receipts.length}'),
                const SizedBox(width: 8),
                stat('Per trip', '\$${formatCents(perTrip)}'),
              ]),
              if (receipts.length >= 2) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _compare(receipts[1], receipts[0]),
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('Last two trips'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTwo(receipts),
                      child: const Text('Pick two'),
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 24),
              Text('Spending by month', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              MonthlySpendingChart(receipts: receipts, slots: data.slots),
              if (data.changes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Price changes here', style: theme.textTheme.titleMedium),
                for (final c in data.changes.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(c.name),
                    subtitle: Text('usually \$${formatCents(c.typicalUnitPrice.round())}'
                        ' · now \$${formatCents(c.latest.unitPrice.round())}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.changeFraction > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                          color: c.changeFraction > 0 ? palette.badText : palette.goodText),
                      Text('${(c.changeFraction.abs() * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              color: c.changeFraction > 0 ? palette.badText : palette.goodText)),
                    ]),
                  ),
              ],
              const SizedBox(height: 24),
              Text('Receipts', style: theme.textTheme.titleMedium),
              for (final r in receipts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(DateFormat.yMMMEd().format(r.purchasedAt)),
                  subtitle: Text('${r.itemCount} item${r.itemCount == 1 ? '' : 's'}'),
                  trailing: Text('\$${formatCents(r.spentCents)}'),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ReceiptDetailScreen(repo: widget.repo, receiptId: r.id),
                    ));
                    _reload();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
