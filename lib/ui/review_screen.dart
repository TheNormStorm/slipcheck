import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';

/// Testing UI: shows the parsed receipt so every field can be corrected
/// before saving. Also used, starting empty, for manual entry.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.repo,
    required this.draft,
    required this.warnings,
  });

  final ReceiptRepository repo;
  final ReceiptDraft draft;
  final List<String> warnings;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ProductMatcher? _matcher;
  int? _storeId;

  /// Lines whose fuzzy suggestion the user accepted.
  final _acceptedFuzzy = <DraftLine>{};
  bool _saving = false;

  ReceiptDraft get draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _loadMatching();
  }

  Future<void> _loadMatching() async {
    final matcher = await widget.repo.loadMatcher();
    final storeId = await widget.repo.findStoreId(draft.storeName);
    if (mounted) {
      setState(() {
        _matcher = matcher;
        _storeId = storeId;
      });
    }
  }

  MatchResult? _match(DraftLine line) =>
      line.name.trim().isEmpty ? null : _matcher?.match(line.name, storeId: _storeId);

  int get _itemsSum => draft.lines.fold(0, (s, l) => s + l.lineTotalCents - l.discountCents);

  Future<void> _save() async {
    setState(() => _saving = true);
    draft.lines.removeWhere((l) => l.name.trim().isEmpty);
    for (final line in draft.lines) {
      final m = _match(line);
      final accept = m != null &&
          (m.isConfident || (m.kind == MatchKind.fuzzy && _acceptedFuzzy.contains(line)));
      line.productId = accept ? m.product!.id : null;
      line.unitPriceCents =
          line.quantity == 1 ? null : (line.lineTotalCents / line.quantity).round();
    }
    await widget.repo.saveReceipt(draft);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final expected = draft.subtotalCents ??
        (draft.totalCents == null ? null : draft.totalCents! - (draft.taxCents ?? 0));
    final mismatch = expected != null && expected != _itemsSum;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check receipt'),
        actions: [
          TextButton(
            onPressed: _saving || _matcher == null ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final w in widget.warnings)
            Text(w, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (draft.imagePath != null)
            ExpansionTile(
              title: const Text('Photo and OCR text'),
              children: [
                Image.file(File(draft.imagePath!), height: 320),
                SelectableText(draft.ocrText ?? '',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
          TextFormField(
            initialValue: draft.storeName,
            decoration: const InputDecoration(labelText: 'Store'),
            onChanged: (v) => draft.storeName = v,
            onFieldSubmitted: (_) => _loadMatching(),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date: ${DateFormat.yMMMd().format(draft.purchasedAt)}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: draft.purchasedAt,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (d != null) setState(() => draft.purchasedAt = d);
            },
          ),
          const Divider(),
          for (final line in draft.lines) _lineEditor(line),
          TextButton.icon(
            onPressed: () => setState(
                () => draft.lines.add(DraftLine(name: '', lineTotalCents: 0))),
            icon: const Icon(Icons.add),
            label: const Text('Add line'),
          ),
          const Divider(),
          Row(children: [
            Expanded(child: _moneyField('Subtotal', draft.subtotalCents,
                (v) => draft.subtotalCents = v)),
            const SizedBox(width: 8),
            Expanded(child: _moneyField('Tax', draft.taxCents, (v) => draft.taxCents = v)),
            const SizedBox(width: 8),
            Expanded(child: _moneyField('Total', draft.totalCents,
                (v) => draft.totalCents = v)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Items add up to ${formatCents(_itemsSum)}'
            '${mismatch ? ' — receipt says ${formatCents(expected)}' : ''}',
            style: TextStyle(
                color: mismatch ? Theme.of(context).colorScheme.error : null),
          ),
        ],
      ),
    );
  }

  Widget _lineEditor(DraftLine line) {
    final m = _match(line);
    final String status;
    switch (m?.kind) {
      case MatchKind.storeAlias || MatchKind.alias || MatchKind.exact:
        status = '→ ${m!.product!.displayName}';
      case MatchKind.fuzzy:
        status = 'Similar: ${m!.product!.displayName} '
            '(${(m.score * 100).round()}%)';
      case MatchKind.none:
        status = 'New item';
      case null:
        status = '';
    }
    return Card(
      key: ObjectKey(line),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: line.name,
                  decoration: const InputDecoration(labelText: 'Item'),
                  onChanged: (v) => setState(() => line.name = v),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => draft.lines.remove(line)),
              ),
            ]),
            Row(children: [
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: _qtyText(line.quantity),
                  decoration: InputDecoration(labelText: line.unit == 'kg' ? 'kg' : 'Qty'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) {
                    final q = double.tryParse(v.replaceAll(',', '.'));
                    if (q != null && q > 0) line.quantity = q;
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _moneyField('Line total', line.lineTotalCents,
                  (v) => line.lineTotalCents = v ?? 0)),
              const SizedBox(width: 8),
              Expanded(child: _moneyField('Discount', line.discountCents,
                  (v) => line.discountCents = (v ?? 0).abs())),
              const SizedBox(width: 8),
            ]),
            if (status.isNotEmpty)
              Row(children: [
                Expanded(child: Text(status, style: Theme.of(context).textTheme.bodySmall)),
                if (m?.kind == MatchKind.fuzzy) ...[
                  const Text('Same item?'),
                  Checkbox(
                    value: _acceptedFuzzy.contains(line),
                    onChanged: (v) => setState(() => v == true
                        ? _acceptedFuzzy.add(line)
                        : _acceptedFuzzy.remove(line)),
                  ),
                ],
              ]),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(String label, int? cents, void Function(int?) onChanged) {
    return TextFormField(
      initialValue: cents == null ? '' : formatCents(cents),
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (v) => setState(() => onChanged(v.trim().isEmpty ? null : parseTypedCents(v))),
    );
  }

  static String _qtyText(double q) =>
      q == q.roundToDouble() ? q.toInt().toString() : q.toString();
}
