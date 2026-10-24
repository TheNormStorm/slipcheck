import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../core/analytics/purchase.dart';
import '../core/analytics/vs_usual.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'chart_palette.dart';
import 'compare_screen.dart';
import 'components/kit.dart';
import 'line_item_row.dart';
import 'motion/motion.dart';
import 'review_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// A saved receipt: what was spent, how it compares with what you usually
/// pay there, its photos, and each line with its price against usual. Edit,
/// share (as text, never the photo) and delete sit at the top.
class ReceiptDetailScreen extends StatefulWidget {
  const ReceiptDetailScreen({super.key, required this.repo, required this.receiptId});
  final ReceiptRepository repo;
  final int receiptId;

  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _DetailData {
  _DetailData(this.detail, this.usual, this.moves, this.others, this.storeColorSlot);
  final ReceiptDetail detail;
  final UsualPrices usual;
  final ReceiptMoves moves;

  /// The other receipts, newest first.
  final List<ReceiptSummary> others;
  final int? storeColorSlot;
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late Future<_DetailData> _data = _load();

  Future<_DetailData> _load() async {
    final repo = widget.repo;
    final detail = await repo.receipt(widget.receiptId);
    final all = await repo.purchases();
    final stores = await repo.stores();
    final receipts = await repo.receipts();
    final slots = storeSlots(stores.where((s) => s.receiptCount > 0).map((s) => (s.id, s.name)));
    return _DetailData(
      detail,
      usualBefore(all, widget.receiptId),
      receiptMoves(all, widget.receiptId),
      receipts.where((r) => r.id != widget.receiptId).toList(),
      slots[detail.summary.storeName],
    );
  }

  Future<void> _edit(ReceiptDetail detail) async {
    final s = detail.summary;
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => ReviewScreen(
        repo: widget.repo,
        editingReceiptId: widget.receiptId,
        draft: ReceiptDraft(
          storeName: s.storeName ?? '',
          purchasedAt: s.purchasedAt,
          lines: detail.lines,
          subtotalCents: detail.subtotalCents,
          taxCents: s.taxCents,
          totalCents: s.totalCents,
        ),
      ),
    ));
    if (saved == true) {
      setState(() {
        _data = _load();
      });
    }
  }

  Future<void> _share(ReceiptDetail detail) {
    final s = detail.summary;
    final title = '${s.storeName ?? 'Receipt'}, ${DateFormat.MMMd().format(s.purchasedAt)}';
    return SharePlus.instance.share(ShareParams(text: detail.asText(), title: title, subject: title));
  }

  Future<void> _delete(ReceiptDetail detail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this receipt?'),
        content: Text('${detail.summary.storeName ?? 'This receipt'}, '
            '${DateFormat.yMMMd().format(detail.summary.purchasedAt)}, '
            'and its ${plural(detail.lines.length, 'item')} go from your history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.deleteReceipt(widget.receiptId);
    if (mounted) Navigator.pop(context, true);
  }

  /// The receipt to compare with by default: the previous one from the same
  /// store, else any earlier one, else the newest other one.
  static ReceiptSummary? _suggested(ReceiptSummary me, List<ReceiptSummary> others) {
    final earlier = others.where((r) => !r.purchasedAt.isAfter(me.purchasedAt)).toList();
    return earlier.where((r) => r.storeId == me.storeId).firstOrNull ??
        earlier.firstOrNull ??
        others.firstOrNull;
  }

  Future<void> _compareWith(ReceiptSummary me, ReceiptSummary other) async {
    // Older receipt first, so "more" and "less" read forwards in time.
    final (a, b) = other.purchasedAt.isAfter(me.purchasedAt) ? (me.id, other.id) : (other.id, me.id);
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CompareScreen(repo: widget.repo, beforeId: a, afterId: b),
    ));
  }

  Future<void> _pickOther(ReceiptSummary me, List<ReceiptSummary> others) async {
    final t = SlipTokens.of(context);
    final suggested = _suggested(me, others);
    final picked = await showModalBottomSheet<ReceiptSummary>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Compare with', style: slipText(20, 900, color: t.ink)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), children: [
                for (final r in [?suggested, ...others.where((r) => r != suggested)])
                  ListTile(
                    title: Text(r.storeName ?? 'Unknown store', style: slipText(15, 800, color: t.ink)),
                    subtitle: Text('${DateFormat.yMMMd().format(r.purchasedAt)} · ${plural(r.itemCount, 'item')}'
                        '${r == suggested ? ' · suggested' : ''}'),
                    trailing:
                        Text(formatCents(r.spentCents), style: slipText(15, 900, color: t.ink, tabular: true)),
                    onTap: () => Navigator.pop(context, r),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (picked != null && mounted) await _compareWith(me, picked);
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
                    CircleAction(
                        icon: Symbols.edit_rounded, tooltip: 'Edit receipt', onTap: () => _edit(data.detail)),
                    const SizedBox(width: 8),
                    CircleAction(
                        icon: Symbols.ios_share_rounded, tooltip: 'Share as text', onTap: () => _share(data.detail)),
                    const SizedBox(width: 8),
                    CircleAction(
                      icon: Symbols.delete_rounded,
                      tooltip: 'Delete receipt',
                      iconColor: t.upText,
                      onTap: () => _delete(data.detail),
                    ),
                  ],
                ]),
                const SizedBox(height: 12),
                if (data == null)
                  for (final h in <double>[52, 92, 76, 64, 64, 64])
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Skeleton(height: h, radius: t.rRow))
                else
                  ..._body(context, data),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, _DetailData data) {
    final t = SlipTokens.of(context);
    final detail = data.detail;
    final s = detail.summary;
    final palette = ChartPalette.of(context);
    final suggested = _suggested(s, data.others);
    final moves = data.moves;
    final extra = moves.extraCents;
    final onAcc = t.punchy ? t.accInk : Colors.white;
    // Each product's price on this receipt, all its lines together, as the
    // "vs usual" tile counts it: two half chickens of different weights are
    // not two price changes.
    final unitPrices = {
      for (final p in mergeByProduct(detail.purchases)) (p.productId, p.unit): p.unitPrice,
    };
    final (vsColor, vsInk) = moves.known == 0 || extra == 0
        ? (t.surf2, t.ink)
        : extra > 0
            ? (t.upSoft, t.upText)
            : (t.downSoft, t.downText);
    return [
      Rise(
        child: Row(children: [
          StoreAvatar(name: s.storeName ?? '?', color: palette.series(data.storeColorSlot ?? 8), size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.storeName ?? 'Unknown store', style: slipText(22, 900, color: t.ink)),
              Text(
                '${DateFormat('EEE, MMM d').format(s.purchasedAt)} · ${plural(detail.lines.length, 'line')}'
                '${s.taxCents == null ? '' : ' · tax ${formatCents(s.taxCents!)}'}',
                style: slipText(13, 700, color: t.ink2),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Rise(
        index: 1,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              flex: 2,
              child: StatTile(
                label: 'Spent',
                color: t.acc,
                ink: onAcc,
                value: CountUp(cents: s.spentCents, style: slipText(28, 900, color: onAcc, tabular: true)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: StatTile(
                label: 'vs usual',
                color: vsColor,
                ink: vsInk,
                value: Text(moves.known == 0
                    ? 'New'
                    : extra == 0
                        ? 'Same'
                        : '${extra > 0 ? '+' : '−'}${formatCents(extra.abs())}'),
                footer: Text(
                  moves.known == 0 ? 'first prices here' : 'on ${plural(moves.known, 'known item')}',
                  style: slipText(11.5, 700, color: vsInk),
                ),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Rise(
        index: 2,
        child: SizedBox(
          height: 76,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final path in detail.imagePaths.take(2)) ...[
              _Thumb(path: path),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SlipCard(
                radius: t.rRow,
                padding: const EdgeInsets.only(left: 12),
                onTap: suggested == null ? null : () => _compareWith(s, suggested),
                child: Row(children: [
                  SlipIcon(Symbols.compare_arrows_rounded, color: suggested == null ? t.ink2 : t.accText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compare', style: slipText(14, 900, color: t.ink)),
                          Text(
                            suggested == null
                                ? 'Save another receipt first'
                                : 'with ${DateFormat.MMMd().format(suggested.purchasedAt)}'
                                    '${suggested.storeId == s.storeId ? '' : ' · ${suggested.storeName ?? ''}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: slipText(12, 700, color: t.ink2),
                          ),
                        ]),
                  ),
                  if (data.others.length > 1)
                    IconButton(
                      tooltip: 'Compare with another receipt',
                      onPressed: () => _pickOther(s, data.others),
                      icon: SlipIcon(Symbols.more_horiz_rounded, color: t.ink2),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Rise(
        index: 3,
        child: SlipCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, line) in detail.lines.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
              LineItemRow(line: line, match: null, chip: _chip(line, data.usual, s.storeId, unitPrices)),
            ],
          ]),
        ),
      ),
    ];
  }

  /// "+5%", "−10%" or "usual" against the usual price here before this trip.
  Widget? _chip(DraftLine line, UsualPrices usual, int? storeId, Map<(int, String), double> unitPrices) {
    final id = line.productId;
    final price = id == null ? null : unitPrices[(id, line.unit)];
    if (id == null || price == null) return null;
    final vs = usual.compare(id, line.unit, storeId, price);
    if (vs == null) return null;
    return Semantics(
      label: vs.isUsual
          ? 'Your usual price'
          : '${vs.percent}% ${vs.isUp ? 'above' : 'below'} your usual ${formatCents(vs.usualUnitPrice.round())}',
      excludeSemantics: true,
      child: TrendChip(
        label: vs.isUsual ? 'usual' : '${vs.isUp ? '+' : '−'}${vs.percent}%',
        trend: vs.isUsual
            ? Trend.same
            : vs.isUp
                ? Trend.up
                : Trend.down,
      ),
    );
  }
}

/// A small photo of the receipt. Kept small: the photo may show the card
/// section, which Slipcheck never shows.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(t.rRow - 4),
      child: SizedBox(
        width: 52,
        child: Image.file(File(path),
            fit: BoxFit.cover,
            cacheWidth: 120,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => ColoredBox(color: t.surf2)),
      ),
    );
  }
}
