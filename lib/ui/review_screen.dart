import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'scan_flow.dart';

/// Testing UI: shows the parsed receipt so every field can be corrected
/// before saving. For a scan, its photos can be added, retaken or removed,
/// which reads the receipt again. Also used, starting empty, for manual entry.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.repo, this.draft, this.session})
      : assert(draft != null || session != null);

  final ReceiptRepository repo;
  final ReceiptDraft? draft;
  final ScanSession? session;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ProductMatcher? _matcher;
  int? _storeId;

  /// Lines whose fuzzy suggestion the user accepted.
  final _acceptedFuzzy = <DraftLine>{};
  bool _saving = false;
  bool _reading = false;

  late ReceiptDraft _draft = widget.draft ?? widget.session!.toDraft();

  /// Bumped when the draft is rebuilt from the photos, so the form fields
  /// (which only read their initial value) are recreated.
  int _generation = 0;

  ReceiptDraft get draft => _draft;

  @override
  void initState() {
    super.initState();
    _loadMatching();
  }

  /// Runs a change to the photos, then rebuilds the draft from them.
  /// Edits made so far are replaced, so photo changes come first.
  Future<void> _changePages(Future<void> Function(ScanSession) change) async {
    final session = widget.session!;
    setState(() => _reading = true);
    try {
      await change(session);
      setState(() {
        _draft = session.toDraft();
        _generation++;
        _acceptedFuzzy.clear();
      });
      await _loadMatching();
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _addPhotos() async {
    final paths = await capturePages(context);
    if (paths != null) await _changePages((s) => s.addPages(paths));
  }

  Future<void> _pageActions(int index) async {
    final session = widget.session!;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Image.file(File(session.pages[index].imagePath), height: 260),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: Text('Retake photo ${index + 1}'),
            onTap: () => Navigator.pop(context, 'retake'),
          ),
          if (session.pages.length > 1)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('Remove photo ${index + 1}'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'retake') {
      final paths = await capturePages(context, pageLimit: 1);
      if (paths != null) await _changePages((s) => s.replacePage(index, paths.first));
    } else if (action == 'remove') {
      await _changePages((s) async => s.removePage(index));
    }
  }

  Widget _photos(ScanSession session) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(session.summary(), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (i, page) in session.pages.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: _reading ? null : () => _pageActions(i),
                    child: Column(children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: page.problem != null ? error : Colors.transparent,
                              width: 2),
                        ),
                        child: Image.file(File(page.imagePath), height: 92, width: 64,
                            fit: BoxFit.cover, cacheHeight: 200),
                      ),
                      Text('${i + 1}',
                          style: TextStyle(color: page.problem != null ? error : null)),
                    ]),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _reading ? null : _addPhotos,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Add photo'),
              ),
            ],
          ),
        ),
        if (_reading) const LinearProgressIndicator(),
        for (final note in session.notes())
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(note, style: TextStyle(color: error)),
          ),
      ],
    );
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
            onPressed: _saving || _reading || _matcher == null ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        key: ValueKey(_generation),
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.session != null) _photos(widget.session!),
          if (draft.ocrText != null)
            ExpansionTile(
              title: const Text('OCR text'),
              children: [
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
                  decoration: InputDecoration(labelText: line.unit == 'each' ? 'Qty' : line.unit),
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
