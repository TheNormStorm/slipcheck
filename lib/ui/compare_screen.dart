import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/analytics/receipt_diff.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';

/// Why one receipt cost more or less than another: the difference split
/// into price changes, buying more or less, items on only one receipt, and
/// tax (they add up exactly), then the items that moved it most.
class CompareScreen extends StatelessWidget {
  const CompareScreen({
    super.key,
    required this.repo,
    required this.beforeId,
    required this.afterId,
  });

  final ReceiptRepository repo;

  /// The earlier receipt, and the later one.
  final int beforeId, afterId;

  Future<(ReceiptDetail, ReceiptDetail, ReceiptDiff)> _load() async {
    final a = await repo.receipt(beforeId), b = await repo.receipt(afterId);
    return (
      a,
      b,
      compareReceipts(a.purchases, b.purchases,
          beforeTaxCents: a.summary.taxCents ?? 0, afterTaxCents: b.summary.taxCents ?? 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compare receipts')),
      body: FutureBuilder(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (a, b, diff) = snap.data!;
          final theme = Theme.of(context);
          final explanation = diff.explain();
          final buckets = [
            ('Price changes', diff.priceEffectCents),
            ('Bought more or less', diff.quantityEffectCents),
            ('Only on the ${_label(b)} receipt', diff.addedCents),
            ('Only on the ${_label(a)} receipt', diff.removedCents),
            ('Tax', diff.taxChangeCents),
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(children: [
                Expanded(child: _ReceiptTile(detail: a, totalCents: diff.beforeTotalCents)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(child: _ReceiptTile(detail: b, totalCents: diff.afterTotalCents)),
              ]),
              const SizedBox(height: 16),
              Text(explanation.first, style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              _ContributionBars(buckets: buckets),
              const SizedBox(height: 16),
              for (final line in explanation.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(line),
                ),
              const SizedBox(height: 8),
              Text('Items that moved the total most', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final item in diff.biggestChanges.take(15)) _ItemChangeRow(item),
              const SizedBox(height: 16),
              Text(
                'Totals here are the saved items plus tax, so they can differ from the '
                'printed total if a line was not saved.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _label(ReceiptDetail d) => DateFormat.MMMd().format(d.summary.purchasedAt);
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.detail, required this.totalCents});
  final ReceiptDetail detail;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(detail.summary.storeName ?? 'Unknown store',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(DateFormat.yMMMd().format(detail.summary.purchasedAt),
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text('\$${formatCents(totalCents)}', style: theme.textTheme.titleLarge),
        ]),
      ),
    );
  }
}

/// Diverging bars from a zero line: red to the right for what made the later
/// receipt cost more, blue to the left for what made it cost less. Every bar
/// carries its signed amount as text, so colour is never the only cue.
class _ContributionBars extends StatelessWidget {
  const _ContributionBars({required this.buckets});
  final List<(String, int)> buckets;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final theme = Theme.of(context);
    final maxAbs = buckets.map((b) => b.$2.abs()).fold(1, math.max);
    return Column(children: [
      for (final (label, cents) in buckets)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 130, child: Text(label, style: theme.textTheme.bodySmall)),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final half = c.maxWidth / 2;
                final w = cents == 0 ? 0.0 : math.max(2.0, half * cents.abs() / maxAbs);
                return SizedBox(
                  height: 18,
                  child: Stack(children: [
                    Positioned(
                      left: half - 0.5,
                      top: 0,
                      bottom: 0,
                      child: Container(width: 1, color: palette.baseline),
                    ),
                    Positioned(
                      left: cents >= 0 ? half : half - w,
                      top: 3,
                      bottom: 3,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cents >= 0 ? palette.more : palette.less,
                          borderRadius: cents >= 0
                              ? const BorderRadius.horizontal(right: Radius.circular(4))
                              : const BorderRadius.horizontal(left: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ]),
                );
              }),
            ),
            SizedBox(
              width: 72,
              child: Text(
                cents == 0 ? '\$0.00' : '${cents > 0 ? '+' : '−'}\$${formatCents(cents.abs())}',
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _ItemChangeRow extends StatelessWidget {
  const _ItemChangeRow(this.item);
  final ItemChange item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    String unitPrice(double cents) =>
        '\$${formatCents(cents.round())}${item.unit == 'each' ? '' : '/${item.unit}'}';
    String qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);
    final why = switch (item.kind) {
      ChangeKind.added => 'Only on the later receipt',
      ChangeKind.removed => 'Only on the earlier receipt',
      _ => [
          if (item.priceEffectCents != 0)
            'price ${unitPrice(item.before!.unitPrice)} → ${unitPrice(item.after!.unitPrice)}',
          if (item.before!.quantity != item.after!.quantity)
            'quantity ${qty(item.before!.quantity)} → ${qty(item.after!.quantity)}',
        ].join(' · '),
    };
    final t = item.totalCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name),
            Text(why, style: muted),
          ]),
        ),
        Text('${t > 0 ? '+' : '−'}\$${formatCents(t.abs())}',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
      ]),
    );
  }
}
