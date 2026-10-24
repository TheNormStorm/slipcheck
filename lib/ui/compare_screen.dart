import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/receipt_diff.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// "What changed?": why one receipt cost more or less than another. The
/// difference is split into price changes, buying more or less, items on
/// only one receipt, and tax. All five parts are always shown, and they add
/// up to the difference exactly. Then the items that moved it most.
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
    final t = SlipTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _load(),
          builder: (context, snap) {
            final header = Row(children: [
              CircleAction(
                  icon: Symbols.arrow_back_rounded, tooltip: 'Back', onTap: () => Navigator.maybePop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text('What changed?',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: slipText(22, 900, color: t.ink)),
              ),
            ]);
            if (!snap.hasData) {
              return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 24), children: [
                header,
                const SizedBox(height: 12),
                for (final h in <double>[64, 120, 200])
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Skeleton(height: h, radius: t.rRow)),
              ]);
            }
            final (a, b) = (snap.data!.$1, snap.data!.$2);
            final diff = snap.data!.$3;
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 32),
              children: [
                header,
                const SizedBox(height: 12),
                Rise(
                  child: Row(children: [
                    Expanded(child: _ReceiptTile(detail: a, totalCents: diff.beforeTotalCents)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SlipIcon(Symbols.arrow_forward_rounded, color: t.ink2),
                    ),
                    Expanded(child: _ReceiptTile(detail: b, totalCents: diff.afterTotalCents)),
                  ]),
                ),
                const SizedBox(height: 10),
                Rise(index: 1, child: _Headline(diff: diff)),
                const SizedBox(height: 10),
                Rise(
                  index: 2,
                  // Two receipts from one day are told apart as the notes below do.
                  child: _label(a) == _label(b)
                      ? _WhereFrom(diff: diff, before: 'the first receipt', after: 'the second receipt')
                      : _WhereFrom(diff: diff, before: _label(a), after: _label(b)),
                ),
                const SizedBox(height: 10),
                for (final (i, line) in diff.explain().skip(1).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Rise(index: 3 + i, child: _Note(line)),
                  ),
                if (diff.biggestChanges.isNotEmpty) ...[
                  const SectionTitle('Items that moved it most'),
                  SlipCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: Column(children: [
                      for (final (i, item) in diff.biggestChanges.take(15).indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _ItemChangeRow(item),
                      ],
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Totals here are the saved items plus tax, so they can differ from the '
                  'printed total if a line was not saved.',
                  style: slipText(12, 600, color: t.ink2),
                ),
              ],
            );
          },
        ),
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
    final t = SlipTokens.of(context);
    final s = detail.summary;
    return SlipCard(
      radius: t.rRow,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${DateFormat.MMMd().format(s.purchasedAt)} · ${s.storeName ?? 'Unknown store'}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: slipText(12, 800, color: t.ink2)),
        Text(formatCents(totalCents), style: slipText(20, 900, color: t.ink, tabular: true)),
      ]),
    );
  }
}

/// "You spent +9.00 more this trip. Mostly prime shaved steak."
class _Headline extends StatelessWidget {
  const _Headline({required this.diff});
  final ReceiptDiff diff;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final onAcc = t.punchy ? t.accInk : Colors.white;
    final d = diff.differenceCents;
    final mostly = diff.biggestChanges.where((i) => i.totalCents.sign == d.sign).firstOrNull;
    final line = d == 0
        ? 'Both trips cost the same.'
        : '${d > 0 ? 'more' : 'less'} this trip.${mostly == null ? '' : ' Mostly ${sentenceCase(mostly.name).toLowerCase()}.'}';
    return Semantics(
      label: d == 0
          ? 'Both trips cost the same.'
          : 'You spent ${formatCents(d.abs())} ${d > 0 ? 'more' : 'less'} this trip.'
              '${mostly == null ? '' : ' Mostly ${mostly.name}.'}',
      excludeSemantics: true,
      child: HeroCard(
        child: Column(children: [
          Text('You spent', style: slipText(13, 800, color: t.onAccSmall)),
          CountUp(cents: d, signed: true, style: slipText(40, 900, color: onAcc, tabular: true, height: 1.1)),
          const SizedBox(height: 2),
          Text(line, textAlign: TextAlign.center, style: slipText(13.5, 800, color: t.onAccSmall)),
        ]),
      ),
    );
  }
}

/// The five parts of the difference as bars growing out from a centre line:
/// right (red) for what made the later trip cost more, left (green) for what
/// made it cost less. Every bar carries its signed amount as text.
class _WhereFrom extends StatelessWidget {
  const _WhereFrom({required this.diff, required this.before, required this.after});
  final ReceiptDiff diff;
  final String before, after;

  String _example(ChangeKind kind) {
    final items = diff.items.where((i) => i.kind == kind).toList()
      ..sort((x, y) => y.totalCents.abs().compareTo(x.totalCents.abs()));
    if (items.isEmpty) return '';
    final more = items.length > 1 ? ' +${items.length - 1}' : '';
    return ' · ${sentenceCase(items.first.name).toLowerCase()}$more';
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final palette = ChartPalette.of(context);
    final buckets = [
      ('Only on $after${_example(ChangeKind.added)}', diff.addedCents),
      ('Only on $before${_example(ChangeKind.removed)}', diff.removedCents),
      ('Price changes', diff.priceEffectCents),
      ('Bought more or less', diff.quantityEffectCents),
      ('Tax', diff.taxChangeCents),
    ];
    final maxAbs = buckets.map((b) => b.$2.abs()).fold(1, math.max);
    return SlipCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where it came from', style: slipText(15, 900, color: t.ink)),
        const SizedBox(height: 8),
        for (final (i, (label, cents)) in buckets.indexed)
          Semantics(
            label: '$label: ${cents == 0 ? 'no change' : '${cents > 0 ? 'plus' : 'minus'} ${formatCents(cents.abs())}'}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: slipText(12.5, 800, color: cents == 0 ? t.ink2 : t.ink)),
                  ),
                  Text(
                    cents == 0 ? '0.00' : '${cents > 0 ? '+' : '−'}${formatCents(cents.abs())}',
                    style: slipText(12.5, 900,
                        color: cents == 0
                            ? t.ink2
                            : cents > 0
                                ? t.upText
                                : t.downText,
                        tabular: true),
                  ),
                ]),
                const SizedBox(height: 4),
                LayoutBuilder(builder: (context, c) {
                  final half = c.maxWidth / 2;
                  final w = cents == 0 ? 0.0 : math.max(4.0, half * cents.abs() / maxAbs);
                  return Container(
                    height: 8,
                    decoration: BoxDecoration(color: t.surf2, borderRadius: BorderRadius.circular(999)),
                    child: Stack(children: [
                      Positioned(left: half - 1, top: 0, bottom: 0, child: Container(width: 2, color: palette.baseline)),
                      Positioned(
                        left: cents >= 0 ? half : half - w,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: GrowIn(
                          axis: Axis.horizontal,
                          delayMs: 150 * i,
                          alignment: cents >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            decoration: BoxDecoration(
                              color: cents >= 0 ? t.up : t.down,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// One sentence of the explanation, with an icon for its kind.
class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final icon = text.contains('from prices')
        ? Symbols.sell_rounded
        : text.contains('more or less')
            ? Symbols.shopping_basket_rounded
            : text.contains('only on the second')
                ? Symbols.add_shopping_cart_rounded
                : text.contains('only on the first')
                    ? Symbols.remove_shopping_cart_rounded
                    : Symbols.receipt_long_rounded;
    return SlipCard(
      color: t.surf2,
      radius: t.rRow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SlipIcon(icon, size: 18, color: t.accText),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: slipText(13, 700, color: t.ink))),
      ]),
    );
  }
}

class _ItemChangeRow extends StatelessWidget {
  const _ItemChangeRow(this.item);
  final ItemChange item;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    String unitPrice(double cents) => '${formatCents(cents.round())}${item.unit == 'each' ? '' : '/${item.unit}'}';
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
    final c = item.totalCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: slipText(14, 900, color: t.ink)),
            Text(why, style: slipText(12, 700, color: t.ink2)),
          ]),
        ),
        Text('${c > 0 ? '+' : '−'}${formatCents(c.abs())}',
            style: slipText(14, 900, color: c > 0 ? t.upText : t.downText, tabular: true)),
      ]),
    );
  }
}
