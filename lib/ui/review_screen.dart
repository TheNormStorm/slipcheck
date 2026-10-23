import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../data/receipt_repository.dart';
import 'line_item_row.dart';
import 'scan_flow.dart';

/// Shows the parsed receipt so every field can be corrected before saving.
/// For a scan, its photos can be added, retaken or removed, which reads the
/// receipt again. Also used, starting empty, for manual entry, and with
/// [editingReceiptId] to correct a receipt that is already saved.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.repo,
    this.draft,
    this.session,
    this.editingReceiptId,
  }) : assert(draft != null || session != null);

  final ReceiptRepository repo;
  final ReceiptDraft? draft;
  final ScanSession? session;
  final int? editingReceiptId;

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
  bool _saved = false;

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
      await _changePages((s) => s.removePage(index));
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
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 72,
                  height: 92,
                  child: OutlinedButton(
                    onPressed: _reading ? null : _addPhotos,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.add_a_photo), SizedBox(height: 4), Text('Add')],
                    ),
                  ),
                ),
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
      line.name.trim().isEmpty
          ? null
          : _matcher?.match(line.name, storeId: _storeId, code: line.code);

  int get _itemsSum => draft.lines.fold(0, (s, l) => s + l.netCents);

  /// Asks for a store name when none was read; returns false to stay.
  Future<bool> _ensureStore() async {
    if (draft.storeName.trim().isNotEmpty) return true;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Which store?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Market Basket'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return false;
    setState(() {
      draft.storeName = name;
      _generation++;
    });
    return true;
  }

  /// Warns when the same receipt looks already saved; returns false to stay.
  Future<bool> _checkDuplicate() async {
    final dup = await widget.repo.findDuplicate(draft, exceptId: widget.editingReceiptId);
    if (dup == null || !mounted) return true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already saved?'),
        content: Text('A receipt from ${dup.storeName ?? 'this store'} on '
            '${DateFormat.yMMMd().format(dup.purchasedAt)} for \$${formatCents(dup.spentCents)} '
            'is already saved. Saving again would count these items twice.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Don't save")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save anyway')),
        ],
      ),
    );
    return save == true;
  }

  /// Leaving without saving: asks first, and removes the scan's photos.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.editingReceiptId == null ? 'Discard this receipt?' : 'Discard changes?'),
        content: Text(widget.editingReceiptId == null
            ? 'It has not been saved. Your corrections and the photos will be lost.'
            : 'The saved receipt stays as it was.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
        ],
      ),
    );
    if (discard != true) return false;
    await widget.session?.deleteFiles();
    return true;
  }

  Future<void> _save() async {
    if (!await _ensureStore() || !mounted) return;
    if (!await _checkDuplicate() || !mounted) return;
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
    if (widget.editingReceiptId case final id?) {
      await widget.repo.updateReceipt(id, draft);
    } else {
      await widget.repo.saveReceipt(draft);
    }
    _saved = true;
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editLine(DraftLine line) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => LineEditSheet(line: line),
    );
    if (result == 'delete') {
      setState(() => draft.lines.remove(line));
    } else if (result == 'save') {
      setState(() => _acceptedFuzzy.remove(line));
    } else if (line.name.trim().isEmpty && line.lineTotalCents == 0) {
      // A new line that was dismissed without being filled in.
      setState(() => draft.lines.remove(line));
    }
  }

  Future<void> _addLine() async {
    final line = DraftLine(name: '', lineTotalCents: 0);
    setState(() => draft.lines.add(line));
    await _editLine(line);
  }

  /// What the items add up to compared with what the receipt says.
  Widget _summary() {
    final theme = Theme.of(context);
    final expected = draft.subtotalCents ??
        (draft.totalCents == null ? null : draft.totalCents! - (draft.taxCents ?? 0));
    final count = draft.lines.length;
    final (String text, Color color, IconData icon) = switch (expected) {
      null => (
          widget.session == null
              ? 'Type the receipt total below to check the items.'
              : 'No TOTAL found, so the items could not be checked. Add a photo of '
                  'the bottom of the receipt, or type the total below.',
          theme.colorScheme.onSurfaceVariant,
          Icons.help_outline,
        ),
      final e when e == _itemsSum => (
          'Matches the receipt ${draft.subtotalCents != null ? 'subtotal' : 'total'}',
          Colors.green.shade700,
          Icons.check_circle,
        ),
      final e => (
          'Receipt says ${formatCents(e)}: off by ${formatCents((_itemsSum - e).abs())}. '
              'Check for a missing, doubled or misread line.',
          theme.colorScheme.error,
          Icons.error,
        ),
    };
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('$count item${count == 1 ? '' : 's'}',
                    style: theme.textTheme.titleMedium),
              ),
              Text(formatCents(_itemsSum),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(text, style: TextStyle(color: color))),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _saved = true;
          Navigator.of(context).pop(false);
        }
      },
      child: _scaffold(context, theme),
    );
  }

  Widget _scaffold(BuildContext context, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.editingReceiptId == null ? 'Check receipt' : 'Edit receipt')),
      body: ListView(
        key: ValueKey(_generation),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              Expanded(
                child: TextFormField(
                  initialValue: draft.storeName,
                  style: theme.textTheme.titleLarge,
                  decoration: const InputDecoration(labelText: 'Store'),
                  onChanged: (v) => draft.storeName = v,
                  onFieldSubmitted: (_) => _loadMatching(),
                ),
              ),
              const SizedBox(width: 12),
              ActionChip(
                avatar: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat.yMMMd().format(draft.purchasedAt)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: draft.purchasedAt,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null) setState(() => draft.purchasedAt = d);
                },
              ),
            ]),
          ),
          if (widget.session != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _photos(widget.session!),
            ),
          _summary(),
          for (final (i, line) in draft.lines.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            LineItemRow(
              key: ObjectKey(line),
              line: line,
              match: _match(line),
              linked: _acceptedFuzzy.contains(line),
              onTap: () => _editLine(line),
              onLink: (v) => setState(
                  () => v ? _acceptedFuzzy.add(line) : _acceptedFuzzy.remove(line)),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addLine,
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('As printed on the receipt', style: theme.textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: _moneyField('Subtotal', draft.subtotalCents,
                  (v) => draft.subtotalCents = v)),
              const SizedBox(width: 8),
              Expanded(child: _moneyField('Tax', draft.taxCents, (v) => draft.taxCents = v)),
              const SizedBox(width: 8),
              Expanded(child: _moneyField('Total', draft.totalCents,
                  (v) => draft.totalCents = v)),
            ]),
          ),
          if (draft.ocrText != null)
            ExpansionTile(
              title: const Text('OCR text'),
              children: [
                SelectableText(draft.ocrText ?? '',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(
              child: Text(
                draft.totalCents == null
                    ? 'Items ${formatCents(_itemsSum)}'
                    : 'Total ${formatCents(draft.totalCents!)}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: _saving || _reading || _matcher == null ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Save receipt'),
            ),
          ]),
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
}
