import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/vs_usual.dart';
import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// "3 × 2.99", "1.234 kg @ 1.52/kg", or null for a single item.
String? quantityDetail(DraftLine line) {
  final unitPrice = line.unitPriceCents ??
      (line.quantity == 0 ? null : (line.lineTotalCents / line.quantity).round());
  if (line.unit != 'each') {
    return '${_qty(line.quantity)} ${line.unit}'
        '${unitPrice == null ? '' : ' @ ${formatCents(unitPrice)}/${line.unit}'}';
  }
  if (line.quantity == 1) return null;
  return '${_qty(line.quantity)} × ${unitPrice == null ? '?' : formatCents(unitPrice)}';
}

String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

/// "↑ 5% vs usual 4.09", "↓ 10% vs usual 9.99" or "Your usual price", with an
/// arrow so the direction is not told by colour alone.
class VsUsualText extends StatelessWidget {
  const VsUsualText(this.vs, {super.key, this.unit = 'each'});
  final VsUsual vs;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final usual = '${formatCents(vs.usualUnitPrice.round())}${unit == 'each' ? '' : '/$unit'}';
    final (String text, Color color) = vs.isUsual
        ? ('Your usual price', t.ink2)
        : vs.isUp
            ? ('↑ ${vs.percent}% vs usual $usual', t.upText)
            : ('↓ ${vs.percent}% vs usual $usual', t.downText);
    return Text(text, style: slipText(12, 800, color: color, tabular: true));
  }
}

/// One purchased line, laid out like the receipt: name on the left, amount
/// on the right, details and how the price compares underneath.
class LineItemRow extends StatelessWidget {
  const LineItemRow({
    super.key,
    required this.line,
    required this.match,
    this.linked = false,
    this.onTap,
    this.onLink,
    this.note,
    this.vs,
    this.matching = false,
  });

  final DraftLine line;
  final MatchResult? match;

  /// Whether the user confirmed a fuzzy [match].
  final bool linked;

  /// Null makes the row read-only.
  final VoidCallback? onTap;
  final ValueChanged<bool>? onLink;

  /// Extra line under the details.
  final Widget? note;

  /// The price against the usual one, when the item is known.
  final VsUsual? vs;

  /// Known products are still loading.
  final bool matching;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final muted = slipText(12, 700, color: t.ink2);
    final detail = quantityDetail(line);
    final empty = line.name.trim().isEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empty ? 'Tap to name this item' : line.name,
                    style: slipText(14, 900, color: empty ? t.upText : t.ink),
                  ),
                  if (detail != null) Text(detail, style: muted),
                  if (line.discountCents > 0)
                    Text('Discount −${formatCents(line.discountCents)}',
                        style: slipText(12, 800, color: t.downText)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: KeyedSubtree(
                        key: ValueKey((matching, linked, vs?.percent)), child: _status(context)),
                  ),
                  ?note,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatCents(line.netCents), style: slipText(15, 900, color: t.ink, tabular: true)),
                if (line.discountCents > 0)
                  Text(
                    formatCents(line.lineTotalCents),
                    style: muted.copyWith(decoration: TextDecoration.lineThrough),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(BuildContext context) {
    final t = SlipTokens.of(context);
    final muted = slipText(12, 700, color: t.ink2);
    if (matching) return _Pulse(child: Text('Matching…', style: muted));
    final m = match;
    if (m != null && m.kind == MatchKind.fuzzy) {
      final name = m.product!.displayName;
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Flexible(child: Text(linked ? 'Linked to $name' : 'Same as $name?', style: muted)),
          const SizedBox(width: 6),
          if (onLink != null && linked)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 30),
              ),
              onPressed: () => onLink!(false),
              child: const Text('Undo'),
            )
          else if (onLink != null)
            _Shake(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: slipText(12, 900),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onLink!(true);
                },
                child: const Text('Link'),
              ),
            ),
        ]),
      );
    }
    if (vs case final vs?) return VsUsualText(vs, unit: line.unit);
    if (m != null && m.isConfident && m.product!.displayName.toLowerCase() != line.name.toLowerCase()) {
      return Text('Saved as ${m.product!.displayName}', style: muted);
    }
    return const SizedBox.shrink();
  }
}

/// Fades its child in and out while something loads.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});
  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!Motion.reduced(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: Tween(begin: .35, end: 1.0).animate(_c), child: widget.child);
}

/// Two little shakes shortly after it appears (the Link button).
class _Shake extends StatefulWidget {
  const _Shake({required this.child});
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  Timer? _start;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_start == null && !Motion.reduced(context)) {
      _start = Timer(const Duration(milliseconds: 500), _c.forward);
    }
  }

  @override
  void dispose() {
    _start?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.rotate(
          // Two wiggles, dying down.
          angle: .12 * (1 - _c.value) * math.sin(_c.value * 4 * math.pi),
          child: child,
        ),
        child: widget.child,
      );
}

/// The "Edit item" sheet. Pops 'save' or 'delete'.
class LineEditSheet extends StatefulWidget {
  const LineEditSheet({super.key, required this.line, this.position, this.usualUnitPrice});

  final DraftLine line;

  /// "Line 2 of 9".
  final String? position;

  /// What this item usually costs per unit at this store, in cents.
  final double? usualUnitPrice;

  @override
  State<LineEditSheet> createState() => _LineEditSheetState();
}

class _LineEditSheetState extends State<LineEditSheet> {
  late final _name = TextEditingController(text: widget.line.name);
  late final _qtyCtl = TextEditingController(text: _qty(widget.line.quantity));
  late final _total = TextEditingController(text: formatCents(widget.line.lineTotalCents));
  late final _discount = TextEditingController(
      text: widget.line.discountCents == 0 ? '' : formatCents(widget.line.discountCents));
  late String _unit = widget.line.unit;

  @override
  void dispose() {
    for (final c in [_name, _qtyCtl, _total, _discount]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _quantity {
    final q = double.tryParse(_qtyCtl.text.replaceAll(',', '.'));
    return q != null && q > 0 ? q : null;
  }

  void _save() {
    final line = widget.line;
    line
      ..name = _name.text.trim()
      ..unit = _unit
      ..quantity = _quantity ?? line.quantity
      ..lineTotalCents = parseTypedCents(_total.text) ?? line.lineTotalCents
      ..discountCents = (parseTypedCents(_discount.text) ?? 0).abs()
      // Recomputed from the total so it stays consistent with the edits.
      ..unitPriceCents = null;
    Navigator.pop(context, 'save');
  }

  /// "3 × 3.49 each · 17% above your usual here", from the fields as typed.
  String? _hint() {
    final q = _quantity;
    final total = parseTypedCents(_total.text);
    if (q == null || total == null) return null;
    final each = (total - (parseTypedCents(_discount.text) ?? 0).abs()) / q;
    final usual = widget.usualUnitPrice;
    final vs = usual == null || _unit != widget.line.unit ? null : VsUsual(each, usual);
    final parts = [
      if (q != 1 || _unit != 'each')
        '${_qty(q)} × ${formatCents(each.round())} ${_unit == 'each' ? 'each' : '/$_unit'}',
      if (vs != null)
        vs.isUsual ? 'your usual price here' : '${vs.percent}% ${vs.isUp ? 'above' : 'below'} your usual here',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    const money = TextInputType.numberWithOptions(decimal: true);
    final hint = _hint();
    Widget field(TextEditingController c, String label) => TextField(
          controller: c,
          keyboardType: money,
          onChanged: (_) => setState(() {}),
          style: slipText(16, 900, color: t.ink, tabular: true),
          decoration: InputDecoration(labelText: label, hintText: '—'),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('Edit item', style: slipText(20, 900, color: t.ink))),
            if (widget.position != null) Text(widget.position!, style: slipText(12, 800, color: t.ink2)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            autofocus: widget.line.name.isEmpty,
            textCapitalization: TextCapitalization.characters,
            style: slipText(16, 900, color: t.ink),
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          const SizedBox(height: 10),
          _UnitPicker(value: _unit, onChanged: (u) => setState(() => _unit = u)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: field(_qtyCtl, _unit == 'each' ? 'Qty' : 'Weight ($_unit)')),
            const SizedBox(width: 8),
            Expanded(child: field(_total, 'Total')),
            const SizedBox(width: 8),
            Expanded(child: field(_discount, 'Discount')),
          ]),
          if (hint != null) ...[
            const SizedBox(height: 10),
            Text(hint, style: slipText(12.5, 700, color: t.ink2)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.upSoft,
                  foregroundColor: t.upText,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: () => Navigator.pop(context, 'delete'),
                icon: const SlipIcon(Symbols.delete_rounded, size: 20),
                label: const Text('Delete'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(onPressed: _save, child: const Text('Done')),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Each / kg / lb.
class _UnitPicker extends StatelessWidget {
  const _UnitPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.surf2,
        borderRadius: BorderRadius.circular(t.rField),
        border: t.outline == null ? null : Border.fromBorderSide(t.outline!),
      ),
      child: Row(children: [
        for (final (unit, label) in [('each', 'Each'), ('kg', 'kg'), ('lb', 'lb')])
          Expanded(
            child: Semantics(
              selected: unit == value,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(unit),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: unit == value ? t.acc : Colors.transparent,
                    borderRadius: BorderRadius.circular(t.rField - 4),
                  ),
                  child: Text(label, style: slipText(13, 900, color: unit == value ? t.accInk : t.ink2)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
