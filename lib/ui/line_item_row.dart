import 'package:flutter/material.dart';

import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';

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

/// One purchased line on the review screen, laid out like the receipt:
/// name on the left, amount on the right, details underneath.
class LineItemRow extends StatelessWidget {
  const LineItemRow({
    super.key,
    required this.line,
    required this.match,
    this.linked = false,
    this.onTap,
    this.onLink,
    this.note,
  });

  final DraftLine line;
  final MatchResult? match;

  /// Whether the user confirmed a fuzzy [match].
  final bool linked;

  /// Null makes the row read-only.
  final VoidCallback? onTap;
  final ValueChanged<bool>? onLink;

  /// Extra line under the details, e.g. how the price compares to usual.
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final detail = quantityDetail(line);
    final empty = line.name.trim().isEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empty ? 'Tap to name this item' : line.name,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: empty ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (detail != null) Text(detail, style: muted),
                  if (line.discountCents > 0)
                    Text('Discount −${formatCents(line.discountCents)}',
                        style: muted?.copyWith(color: Colors.green.shade700)),
                  _matchInfo(context, muted),
                  ?note,
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatCents(line.netCents),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (line.discountCents > 0)
                  Text(
                    formatCents(line.lineTotalCents),
                    style: muted?.copyWith(decoration: TextDecoration.lineThrough),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchInfo(BuildContext context, TextStyle? muted) {
    final m = match;
    if (m == null) return const SizedBox.shrink();
    switch (m.kind) {
      case MatchKind.barcode || MatchKind.storeAlias || MatchKind.alias || MatchKind.exact:
        // Known item: only worth a word when it is saved under another name.
        final same = m.product!.displayName.toLowerCase() == line.name.toLowerCase();
        return same
            ? const SizedBox.shrink()
            : Text('Saved as ${m.product!.displayName}', style: muted);
      case MatchKind.fuzzy:
        return Row(children: [
          Flexible(
            child: Text(
              linked
                  ? 'Linked to ${m.product!.displayName}'
                  : 'Same as ${m.product!.displayName}?',
              style: muted,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onLink == null ? null : () => onLink!(!linked),
            child: Text(linked ? 'Undo' : 'Yes, link'),
          ),
        ]);
      case MatchKind.none:
        return const SizedBox.shrink();
    }
  }
}

/// Bottom sheet for correcting one line. Pops 'save' or 'delete'.
class LineEditSheet extends StatefulWidget {
  const LineEditSheet({super.key, required this.line});

  final DraftLine line;

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

  void _save() {
    final line = widget.line;
    final qty = double.tryParse(_qtyCtl.text.replaceAll(',', '.'));
    line
      ..name = _name.text.trim()
      ..unit = _unit
      ..quantity = qty != null && qty > 0 ? qty : line.quantity
      ..lineTotalCents = parseTypedCents(_total.text) ?? line.lineTotalCents
      ..discountCents = (parseTypedCents(_discount.text) ?? 0).abs()
      // Recomputed from the total so it stays consistent with the edits.
      ..unitPriceCents = null;
    Navigator.pop(context, 'save');
  }

  @override
  Widget build(BuildContext context) {
    const money = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.line.name.isEmpty,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Item name'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'each', label: Text('Each')),
              ButtonSegment(value: 'kg', label: Text('kg')),
              ButtonSegment(value: 'lb', label: Text('lb')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => setState(() => _unit = s.single),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _qtyCtl,
                keyboardType: money,
                decoration:
                    InputDecoration(labelText: _unit == 'each' ? 'Quantity' : 'Weight ($_unit)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _total,
                keyboardType: money,
                decoration: const InputDecoration(labelText: 'Line total'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _discount,
                keyboardType: money,
                decoration: const InputDecoration(labelText: 'Discount'),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            TextButton.icon(
              onPressed: () => Navigator.pop(context, 'delete'),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            ),
            const Spacer(),
            FilledButton(onPressed: _save, child: const Text('Done')),
          ]),
        ],
      ),
    );
  }
}
