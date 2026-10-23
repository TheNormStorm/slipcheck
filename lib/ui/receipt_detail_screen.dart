import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/analytics/purchase.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'compare_screen.dart';
import 'line_item_row.dart';

/// A saved receipt: its lines, each with how its price compares to what you
/// usually pay, and actions to compare it with another receipt or delete it.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key, required this.repo, required this.receiptId});
  final ReceiptRepository repo;
  final int receiptId;

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late final Future<(ReceiptDetail, List<Purchase>)> _data = _load();

  Future<(ReceiptDetail, List<Purchase>)> _load() async =>
      (await widget.repo.receipt(widget.receiptId), await widget.repo.purchases());

  Future<void> _delete(ReceiptDetail detail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this receipt?'),
        content: Text('${detail.summary.storeName ?? 'This receipt'}, '
            '${DateFormat.yMMMd().format(detail.summary.purchasedAt)}, '
            'and its ${detail.lines.length} items will be removed from your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.deleteReceipt(widget.receiptId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _compare(ReceiptDetail detail) async {
    final all = await widget.repo.receipts();
    final others = all.where((r) => r.id != widget.receiptId).toList();
    if (!mounted) return;
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Save another receipt to compare with.')));
      return;
    }
    // Suggest the previous receipt from the same store, then any earlier one.
    final me = detail.summary;
    final earlier = others.where((r) => !r.purchasedAt.isAfter(me.purchasedAt)).toList();
    final suggested = earlier.where((r) => r.storeId == me.storeId).firstOrNull ??
        earlier.firstOrNull ??
        others.first;
    final picked = await showModalBottomSheet<ReceiptSummary>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Compare with'),
          ),
          for (final r in [suggested, ...others.where((r) => r != suggested)])
            ListTile(
              title: Text(r.storeName ?? 'Unknown store'),
              subtitle: Text('${DateFormat.yMMMd().format(r.purchasedAt)} · ${r.itemCount} items'
                  '${r == suggested ? ' · suggested' : ''}'),
              trailing: Text('\$${formatCents(r.spentCents)}'),
              onTap: () => Navigator.pop(context, r),
            ),
        ]),
      ),
    );
    if (picked == null || !mounted) return;
    // Older receipt first, so "more" and "less" read forwards in time.
    final (a, b) = picked.purchasedAt.isAfter(me.purchasedAt)
        ? (widget.receiptId, picked.id)
        : (picked.id, widget.receiptId);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CompareScreen(repo: widget.repo, beforeId: a, afterId: b),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final (detail, history) = snap.data!;
        final theme = Theme.of(context);
        final s = detail.summary;
        // Typical price of each product on your other receipts from the same
        // store; other stores are what the analytics store comparison is for.
        final typical = <(int, String), double>{};
        final byProduct = <(int, String), List<double>>{};
        for (final p in history.where(
            (p) => p.receiptId != widget.receiptId && p.storeId == s.storeId)) {
          byProduct.putIfAbsent((p.productId, p.unit), () => []).add(p.unitPrice);
        }
        byProduct.forEach((k, v) => typical[k] = median(v));

        return Scaffold(
          appBar: AppBar(
            title: Text(s.storeName ?? 'Receipt'),
            actions: [
              IconButton(
                tooltip: 'Compare with another receipt',
                icon: const Icon(Icons.compare_arrows),
                onPressed: () => _compare(detail),
              ),
              IconButton(
                tooltip: 'Delete receipt',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(detail),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ListTile(
                title: Text(DateFormat.yMMMMEEEEd().format(s.purchasedAt)),
                subtitle: Text('${s.itemCount} lines'
                    '${s.taxCents == null ? '' : ' · tax \$${formatCents(s.taxCents!)}'}'),
                trailing: Text('\$${formatCents(s.spentCents)}', style: theme.textTheme.titleLarge),
              ),
              if (detail.imagePaths.isNotEmpty)
                SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final path in detail.imagePaths)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: File(path).existsSync()
                              ? Image.file(File(path), width: 64, fit: BoxFit.cover, cacheHeight: 200)
                              : const SizedBox.shrink(),
                        ),
                    ],
                  ),
                ),
              const Divider(),
              for (final (i, line) in detail.lines.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                LineItemRow(
                  line: line,
                  match: null,
                  note: line.productId == null
                      ? null
                      : _VsUsual(line: line, typical: typical[(line.productId!, line.unit)]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "12% above usual" / "4% below usual", with an arrow so it is not colour alone.
class _VsUsual extends StatelessWidget {
  const _VsUsual({required this.line, required this.typical});
  final DraftLine line;
  final double? typical;

  @override
  Widget build(BuildContext context) {
    final t = typical;
    if (t == null || t <= 0 || line.quantity == 0) return const SizedBox.shrink();
    final change = line.netCents / line.quantity / t - 1;
    if (change.abs() < 0.01) {
      return Text('Your usual price', style: Theme.of(context).textTheme.bodySmall);
    }
    final palette = ChartPalette.of(context);
    final color = change > 0 ? palette.badText : palette.goodText;
    return Row(children: [
      Icon(change > 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: color),
      Text(
        ' ${(change.abs() * 100).toStringAsFixed(0)}% ${change > 0 ? 'above' : 'below'} '
        'your usual \$${formatCents(t.round())}${line.unit == 'each' ? '' : '/${line.unit}'} here',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
      ),
    ]);
  }
}
