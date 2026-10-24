import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'receipt_detail_screen.dart';
import 'reload_on_change.dart';
import 'store_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// Every saved receipt, by date or grouped by store.
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

  @override
  void reload() {
    _receipts = repo.receipts();
    _stores = repo.stores();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('By date')),
                ButtonSegment(value: true, label: Text('By store')),
              ],
              selected: {_byStore},
              onSelectionChanged: (v) => setState(() => _byStore = v.single),
            ),
          ),
        ],
      ),
      body: _byStore ? _storeList() : _receiptList(),
    );
  }

  Widget _receiptList() => FutureBuilder(
        future: Future.wait([_receipts, _stores]),
        builder: (context, snap) {
          if (!snap.hasData) return const _ListSkeleton();
          final receipts = snap.data![0] as List<ReceiptSummary>;
          final stores = snap.data![1] as List<StoreSummary>;
          if (receipts.isEmpty) return const Center(child: Text('No receipts yet.'));
          final palette = ChartPalette.of(context);
          final slots = storeSlots(stores.where((s) => s.receiptCount > 0).map((s) => (s.id, s.name)));
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            itemCount: receipts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = receipts[i];
              return Rise(
                index: i.clamp(0, 10),
                child: ReceiptCard(
                  receipt: r,
                  color: palette.series(slots[r.storeName] ?? 8),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ReceiptDetailScreen(repo: repo, receiptId: r.id),
                  )),
                ),
              );
            },
          );
        },
      );

  Widget _storeList() => FutureBuilder(
        future: _stores,
        builder: (context, snap) {
          if (!snap.hasData) return const _ListSkeleton();
          final stores = snap.data!.where((s) => s.receiptCount > 0).toList();
          if (stores.isEmpty) return const Center(child: Text('No receipts yet.'));
          final palette = ChartPalette.of(context);
          final slots = storeSlots(stores.map((s) => (s.id, s.name)));
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
                          '${s.receiptCount} trip${s.receiptCount == 1 ? '' : 's'}'
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
            Text('${DateFormat.MMMd().format(r.purchasedAt)} · ${r.itemCount} item${r.itemCount == 1 ? '' : 's'}',
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
