import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/analytics/vs_usual.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'motion/motion.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// What the Home message says after a save.
class SavedNote {
  const SavedNote({required this.receiptId, required this.itemCount, required this.moves});
  final int receiptId;
  final int itemCount;
  final ReceiptMoves moves;
}

/// The "receipt prints and gets stamped SAVED" moment, then back to where
/// the scan started. Says so when the items did not add up to the receipt.
/// Pops the [note]; a tap skips ahead.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key, required this.draft, required this.note, this.offByCents});

  final ReceiptDraft draft;
  final SavedNote note;

  /// How far the items were from the receipt's own total, when they were.
  final int? offByCents;

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with SingleTickerProviderStateMixin {
  // 0–2.2s the paper feeds, 2.2–2.62s the stamp, then the summary; leaves at 5.2s.
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
  Timer? _leave;
  bool _stamped = false;
  bool _left = false;

  static const _feedEnd = 2200 / 5200, _stampEnd = 2620 / 5200;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (Motion.reduced(context)) {
      _c.value = 1;
      HapticFeedback.lightImpact();
      _leave = Timer(const Duration(milliseconds: 2200), _done);
    } else {
      _c.addListener(() {
        if (!_stamped && _c.value >= _feedEnd) {
          _stamped = true;
          HapticFeedback.lightImpact();
        }
      });
      _c.forward().whenComplete(_done);
    }
  }

  void _done() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pop(widget.note);
  }

  @override
  void dispose() {
    _leave?.cancel();
    _c.dispose();
    super.dispose();
  }

  double _seg(double from, double to) => ((_c.value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final note = widget.note;
    final moves = note.moves;
    final offBy = widget.offByCents;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done();
      },
      child: Scaffold(
        backgroundColor: t.punchy ? t.bg : t.accSoft,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _done,
          child: SafeArea(
            child: Semantics(
              liveRegion: true,
              label: 'Saved. Tracked ${plural(note.itemCount, 'item')}.'
                  '${moves.up > 0 ? ' ${moves.up} went up.' : ''}'
                  '${moves.down > 0 ? ' ${moves.down} went down.' : ''}'
                  '${offBy != null ? ' The items were off by ${formatCents(offBy)}.' : ''}',
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final feed = Motion.easeOutCubic.transform(_seg(0, _feedEnd));
                    final stamp = _seg(_feedEnd, _stampEnd);
                    final after = _seg(_stampEnd, _stampEnd + .1);
                    return Column(children: [
                      const SizedBox(height: 48),
                      // The printer slot.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF231D18),
                            borderRadius: BorderRadius.circular(6),
                            border: t.outline == null ? null : Border.fromBorderSide(t.outline!),
                          ),
                        ),
                      ),
                      // The paper feeds out of the slot: its bottom shows first.
                      Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                        ClipRect(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            heightFactor: feed,
                            child: _Paper(draft: widget.draft),
                          ),
                        ),
                        if (stamp > 0) _Stamp(progress: stamp),
                      ]),
                      Opacity(
                        opacity: after,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - after)),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                            child: Column(children: [
                              Text('Tracked! ${plural(note.itemCount, 'item')}',
                                  style: slipText(22, 900, color: t.ink)),
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                                if (moves.up > 0) _JumpChip('↑ ${moves.up} went up', t.upSoft, t.upText, 0),
                                if (moves.down > 0)
                                  _JumpChip('↓ ${moves.down} went down', t.downSoft, t.downText, 1),
                              ]),
                              if (offBy != null) ...[
                                const SizedBox(height: 10),
                                Text('The items were off by ${formatCents(offBy)}. Worth a look later.',
                                    textAlign: TextAlign.center, style: slipText(13, 700, color: t.warning)),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The printed receipt: monospace, dashed rules, up to 12 lines.
class _Paper extends StatelessWidget {
  const _Paper({required this.draft});
  final ReceiptDraft draft;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF231D18);
    final style = slipText(11, 500, mono: true, color: ink, height: 1.5);
    final lines = draft.lines;
    final shown = lines.take(12).toList();
    final total = draft.totalCents ?? lines.fold<int>(0, (s, l) => s + l.netCents) + (draft.taxCents ?? 0);
    Widget rule() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('-' * 40,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: style.copyWith(color: ink.withValues(alpha: .35))),
        );
    return Container(
      width: 260,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        boxShadow: [BoxShadow(color: ink.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(draft.storeName.toUpperCase(), style: style.copyWith(fontWeight: FontWeight.w800)),
        Text('${DateFormat.yMMMd().format(draft.purchasedAt)} · ${plural(lines.length, 'item')}',
            style: style.copyWith(color: ink.withValues(alpha: .55), fontSize: 10)),
        rule(),
        for (final l in shown)
          Row(children: [
            Expanded(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
            const SizedBox(width: 8),
            Text(formatCents(l.netCents), style: style),
          ]),
        if (lines.length > shown.length)
          Align(
            alignment: Alignment.centerLeft,
            child: Text('+ ${lines.length - shown.length} more',
                style: style.copyWith(color: ink.withValues(alpha: .55))),
          ),
        rule(),
        Row(children: [
          Expanded(child: Text('TOTAL', style: style.copyWith(fontWeight: FontWeight.w800))),
          Text(formatCents(total), style: style.copyWith(fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }
}

/// The green SAVED stamp: slams in from 2.6× at −24° to rest at −12°.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF1F8A5B);
    final p = Motion.stamp.transform(progress);
    return Opacity(
      opacity: progress,
      child: Transform.rotate(
        angle: (-24 + 12 * p) * math.pi / 180,
        child: Transform.scale(
          scale: 2.6 - 1.6 * p,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: green, width: 4),
              borderRadius: BorderRadius.circular(12),
              color: const Color(0x14FFFFFF),
            ),
            child: Text('SAVED', style: slipText(42, 900, color: green, letterSpacing: 2)),
          ),
        ),
      ),
    );
  }
}

/// A chip that does a little jump when it appears.
class _JumpChip extends StatelessWidget {
  const _JumpChip(this.label, this.bg, this.fg, this.index);
  final String label;
  final Color bg, fg;
  final int index;

  @override
  Widget build(BuildContext context) => PopIn(
        delayMs: 120 * index,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: slipText(13, 900, color: fg)),
        ),
      );
}
