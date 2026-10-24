import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../core/analytics/purchase.dart';
import '../core/analytics/vs_usual.dart';
import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../core/text.dart';
import '../data/receipt_repository.dart';
import 'components/kit.dart';
import 'line_item_row.dart';
import 'motion/motion.dart';
import 'saved_screen.dart';
import 'scan_flow.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// "Check it": the parsed receipt, so every field can be corrected before
/// saving. For a scan, its photos can be added, retaken or removed, which
/// reads the receipt again. Also used, starting empty, for manual entry, and
/// with [editingReceiptId] to correct a receipt that is already saved.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.repo,
    this.draft,
    this.session,
    this.editingReceiptId,
    this.onSaved,
  }) : assert(draft != null || session != null);

  final ReceiptRepository repo;
  final ReceiptDraft? draft;
  final ScanSession? session;
  final int? editingReceiptId;

  /// Called after a new receipt is saved and celebrated.
  final ValueChanged<SavedNote>? onSaved;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  ProductMatcher? _matcher;
  UsualPrices? _usual;
  int? _storeId;

  /// Lines whose fuzzy suggestion the user accepted.
  final _acceptedFuzzy = <DraftLine>{};
  bool _saving = false;
  bool _reading = false;
  bool _saved = false;

  late ReceiptDraft _draft = widget.draft ?? widget.session!.toDraft();

  /// Bumped when the draft is rebuilt from the photos, so the rows animate in
  /// again and the form fields (which only read their initial value) reset.
  int _generation = 0;

  ReceiptDraft get draft => _draft;
  bool get _editing => widget.editingReceiptId != null;

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

  /// The photos behind the receipt: retake or remove one, or add more.
  Future<void> _photosSheet() async {
    final session = widget.session!;
    final t = SlipTokens.of(context);
    final action = await showModalBottomSheet<(String, int)>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Photos', style: slipText(20, 900, color: t.ink)),
            Text(session.summary(), style: slipText(12.5, 700, color: t.ink2)),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final (i, page) in session.pages.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Column(children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: page.problem != null ? t.warning : Colors.transparent, width: 3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Image.file(File(page.imagePath),
                              height: 120,
                              width: 84,
                              fit: BoxFit.cover,
                              cacheHeight: 300,
                              errorBuilder: (_, _, _) =>
                                  SizedBox(height: 120, width: 84, child: ColoredBox(color: t.surf2))),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Photo ${i + 1}',
                          style: slipText(12, 800, color: page.problem != null ? t.warning : t.ink2)),
                      Row(children: [
                        IconButton(
                          tooltip: 'Retake photo ${i + 1}',
                          onPressed: () => Navigator.pop(context, ('retake', i)),
                          icon: SlipIcon(Symbols.refresh_rounded, size: 20, color: t.ink),
                        ),
                        if (session.pages.length > 1)
                          IconButton(
                            tooltip: 'Remove photo ${i + 1}',
                            onPressed: () => Navigator.pop(context, ('remove', i)),
                            icon: SlipIcon(Symbols.delete_rounded, size: 20, color: t.upText),
                          ),
                      ]),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 58),
                  child: SizedBox(
                    width: 84,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, ('add', -1)),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SlipIcon(Symbols.add_a_photo_rounded, color: t.accText),
                        const SizedBox(height: 4),
                        Text('Add', style: slipText(13, 900, color: t.accText)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
            Text('Long receipt? Overlap each photo with the last by 2–3 lines.',
                style: slipText(12.5, 700, color: t.ink2)),
          ]),
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ('add', _):
        await _addPhotos();
      case ('retake', final i):
        final paths = await capturePages(context, pageLimit: 1);
        if (paths != null) await _changePages((s) => s.replacePage(i, paths.first));
      case ('remove', final i):
        await _changePages((s) => s.removePage(i));
    }
  }

  Future<void> _loadMatching() async {
    final matcher = await widget.repo.loadMatcher();
    final storeId = await widget.repo.findStoreId(draft.storeName);
    final history = await widget.repo.purchases();
    if (mounted) {
      setState(() {
        _matcher = matcher;
        _storeId = storeId;
        _usual = UsualPrices(mergeByProduct(history.where((p) => p.receiptId != widget.editingReceiptId)));
      });
    }
  }

  MatchResult? _match(DraftLine line) =>
      line.name.trim().isEmpty
          ? null
          : _matcher?.match(line.name, storeId: _storeId, code: line.code);

  /// The product a line will be saved under, when known: a confident match,
  /// or a suggestion the user linked.
  int? _productOf(DraftLine line, MatchResult? m) {
    if (m == null) return null;
    final linked = m.kind == MatchKind.fuzzy && _acceptedFuzzy.contains(line);
    return m.isConfident || linked ? m.product!.id : null;
  }

  VsUsual? _vs(DraftLine line, MatchResult? m) {
    final id = _productOf(line, m);
    if (id == null || line.quantity <= 0) return null;
    return _usual?.compare(id, line.unit, _storeId, line.netCents / line.quantity);
  }

  int get _itemsSum => draft.lines.fold(0, (s, l) => s + l.netCents);

  /// What the items should add up to, from the receipt's own numbers.
  int? get _expected =>
      draft.subtotalCents ?? (draft.totalCents == null ? null : draft.totalCents! - (draft.taxCents ?? 0));

  bool get _matches => _expected != null && _expected == _itemsSum;

  /// What was paid: the receipt's total, else the items plus tax.
  int get _payCents => draft.totalCents ?? _itemsSum + (draft.taxCents ?? 0);

  Future<void> _editStore() async {
    final controller = TextEditingController(text: draft.storeName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Which store?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Market Basket'),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
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
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => draft.storeName = name);
    await _loadMatching();
  }

  Future<void> _editDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: draft.purchasedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => draft.purchasedAt = d);
  }

  /// Subtotal, tax and total as printed on the receipt.
  Future<void> _editTotals() async {
    final t = SlipTokens.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('As printed on the receipt', style: slipText(20, 900, color: t.ink)),
          const SizedBox(height: 4),
          Text('The items are checked against the subtotal, or the total minus tax.',
              style: slipText(12.5, 700, color: t.ink2)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _moneyField('Subtotal', draft.subtotalCents, (v) => draft.subtotalCents = v)),
            const SizedBox(width: 8),
            Expanded(child: _moneyField('Tax', draft.taxCents, (v) => draft.taxCents = v)),
            const SizedBox(width: 8),
            Expanded(child: _moneyField('Total', draft.totalCents, (v) => draft.totalCents = v)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ),
        ]),
      ),
    );
    if (mounted) setState(() {});
  }

  /// Asks for a store name when none was read; returns false to stay.
  Future<bool> _ensureStore() async {
    if (draft.storeName.trim().isEmpty) await _editStore();
    return draft.storeName.trim().isNotEmpty;
  }

  /// Warns when the same receipt looks already saved; returns false to stay.
  Future<bool> _checkDuplicate() async {
    final dup = await widget.repo.findDuplicate(draft, exceptId: widget.editingReceiptId);
    if (dup == null || !mounted) return true;
    final t = SlipTokens.of(context);
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: SlipIcon(Symbols.content_copy_rounded, size: 32, color: t.warning),
        title: const Text('Already saved?'),
        content: Text('${dup.storeName ?? 'This store'}, ${DateFormat.MMMd().format(dup.purchasedAt)}, '
            '${formatCents(dup.spentCents)} is in already. Saving twice doubles it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save anyway')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text("Don't save")),
        ],
      ),
    );
    return save == true;
  }

  /// When the items do not add up to the receipt; returns false to stay.
  Future<bool> _checkTotal() async {
    final expected = _expected;
    if (expected == null || expected == _itemsSum) return true;
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Off by ${formatCents((_itemsSum - expected).abs())}, save anyway?'),
        content: const Text("The items don't add up to the receipt. A line may be missing, doubled "
            "or misread. Faded receipts sometimes can't be read in full."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save anyway')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Check it')),
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
        title: Text(_editing ? 'Discard changes?' : 'Discard this receipt?'),
        content: Text(_editing
            ? 'The saved receipt stays as it was.'
            : 'It has not been saved. Your corrections and the photos will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
        ],
      ),
    );
    if (discard != true) return false;
    await widget.session?.deleteFiles();
    return true;
  }

  Future<void> _save() async {
    if (!await _ensureStore() || !mounted) return;
    if (!await _checkTotal() || !mounted) return;
    if (!await _checkDuplicate() || !mounted) return;
    setState(() => _saving = true);
    draft.lines.removeWhere((l) => l.name.trim().isEmpty);
    for (final line in draft.lines) {
      line.productId = _productOf(line, _match(line));
      line.unitPriceCents =
          line.quantity == 1 ? null : (line.lineTotalCents / line.quantity).round();
    }
    final expected = _expected;
    final offBy = expected == null || expected == _itemsSum ? null : (_itemsSum - expected).abs();
    if (widget.editingReceiptId case final id?) {
      await widget.repo.updateReceipt(id, draft);
      _saved = true;
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final id = await widget.repo.saveReceipt(draft);
    final note = SavedNote(
      receiptId: id,
      itemCount: draft.lines.length,
      moves: receiptMoves(await widget.repo.purchases(), id),
    );
    _saved = true;
    if (!mounted) return;
    final onSaved = widget.onSaved;
    final shown = await Navigator.of(context).pushReplacement<SavedNote, bool>(MaterialPageRoute(
      builder: (_) => SavedScreen(draft: draft, note: note, offByCents: offBy),
    ));
    onSaved?.call(shown ?? note);
  }

  Future<void> _editLine(DraftLine line) async {
    final id = _productOf(line, _match(line));
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LineEditSheet(
        line: line,
        position: 'Line ${draft.lines.indexOf(line) + 1} of ${draft.lines.length}',
        usualUnitPrice: id == null ? null : _usual?.of(id, line.unit, _storeId),
      ),
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _saved = true;
          Navigator.of(context).pop(false);
        }
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    final t = SlipTokens.of(context);
    final session = widget.session;
    final title = _editing
        ? 'Edit receipt'
        : session == null
            ? 'Type it in'
            : 'Check it';
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 14, 6),
            child: Row(children: [
              CircleAction(
                icon: Symbols.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: slipText(22, 900, color: t.ink))),
              if (session != null)
                ActionChip(
                  avatar: SlipIcon(Symbols.photo_library_rounded, size: 18, color: t.ink),
                  label: Text(plural(session.pages.length, 'photo')),
                  labelStyle: slipText(12.5, 900, color: t.ink),
                  backgroundColor: t.surf2,
                  side: t.outline ?? BorderSide.none,
                  shape: const StadiumBorder(),
                  onPressed: _reading ? null : _photosSheet,
                ),
            ]),
          ),
          if (_reading) LinearProgressIndicator(color: t.acc, backgroundColor: t.accSoft, minHeight: 3),
          Expanded(
            child: ListView(
              key: ValueKey(_generation),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
              children: [
                _SummaryCard(
                  store: draft.storeName,
                  date: draft.purchasedAt,
                  payCents: _payCents,
                  itemCount: draft.lines.length,
                  itemsSum: _itemsSum,
                  expected: _expected,
                  checkedAgainstSubtotal: draft.subtotalCents != null,
                  ready: _matcher != null,
                  manual: session == null,
                  onStore: _editStore,
                  onDate: _editDate,
                  onTotals: _editTotals,
                ),
                for (final note in session?.notes() ?? const <String>[]) ...[
                  const SizedBox(height: 8),
                  _Warning(text: note, onTap: _reading ? null : _photosSheet),
                ],
                const SizedBox(height: 10),
                SlipCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, line) in draft.lines.indexed) ...[
                      if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
                      Rise(
                        key: ObjectKey(line),
                        index: i.clamp(0, 12),
                        stagger: 150,
                        child: _row(line),
                      ),
                    ],
                    if (draft.lines.isNotEmpty) const Divider(height: 1),
                    InkWell(
                      onTap: _addLine,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(children: [
                          SlipIcon(Symbols.add_circle_rounded, size: 20, color: t.accText),
                          const SizedBox(width: 8),
                          Text('Add item', style: slipText(14, 900, color: t.accText)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                _TotalsRow(draft: draft, onTap: _editTotals),
                if (draft.ocrText != null) ...[
                  const SizedBox(height: 6),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text('Text as read', style: slipText(14, 800, color: t.ink2)),
                      subtitle: Text('Card details removed', style: slipText(11.5, 700, color: t.ink2)),
                      children: [
                        SelectableText(draft.ocrText ?? '',
                            style: slipText(11, 500, mono: true, color: t.ink, height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _matches ? t.success : t.acc,
                // White on the light theme's green; the dark theme's mint needs dark ink.
                foregroundColor: _matches ? (t.punchy ? t.accInk : Colors.white) : t.accInk,
                textStyle: slipText(17, 900, tabular: true),
              ),
              onPressed: _saving || _reading || _matcher == null ? null : _save,
              icon: _saving
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 3))
                  : const SlipIcon(Symbols.check_rounded, size: 22),
              label: Text(_editing ? 'Save changes' : 'Save · ${formatCents(_payCents)}'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(DraftLine line) {
    final m = _match(line);
    return LineItemRow(
      line: line,
      match: m,
      vs: _vs(line, m),
      matching: _matcher == null,
      linked: _acceptedFuzzy.contains(line),
      onTap: () => _editLine(line),
      onLink: (v) => setState(() => v ? _acceptedFuzzy.add(line) : _acceptedFuzzy.remove(line)),
    );
  }

  Widget _moneyField(String label, int? cents, void Function(int?) onChanged) {
    return TextFormField(
      initialValue: cents == null ? '' : formatCents(cents),
      decoration: InputDecoration(labelText: label),
      style: slipText(16, 900, tabular: true),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (v) => setState(() => onChanged(v.trim().isEmpty ? null : parseTypedCents(v))),
    );
  }
}

/// The orange card: store, date, what was paid (counting up), the item count,
/// and whether the items add up to the receipt.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.store,
    required this.date,
    required this.payCents,
    required this.itemCount,
    required this.itemsSum,
    required this.expected,
    required this.checkedAgainstSubtotal,
    required this.ready,
    required this.manual,
    required this.onStore,
    required this.onDate,
    required this.onTotals,
  });

  final String store;
  final DateTime date;
  final int payCents, itemCount, itemsSum;
  final int? expected;
  final bool checkedAgainstSubtotal, ready, manual;
  final VoidCallback onStore, onDate, onTotals;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final onAcc = t.punchy ? t.accInk : Colors.white;
    final chipBg = t.punchy ? const Color(0x2E1A0E06) : const Color(0x38FFFFFF);
    final e = expected;
    final Widget badge;
    if (!ready) {
      badge = _Pill(key: const ValueKey('adding'), bg: chipBg, fg: onAcc, text: 'Adding it up…');
    } else if (e == null) {
      badge = _Pill(
        key: const ValueKey('none'),
        bg: t.warningSoft,
        fg: t.warning,
        icon: Symbols.help_rounded,
        text: manual ? 'Add the receipt total to check' : 'No total found · tap to add',
      );
    } else if (e == itemsSum) {
      badge = PopIn(
        key: const ValueKey('ok'),
        child: _Pill(
          bg: Colors.white,
          fg: t.downText,
          icon: Symbols.verified_rounded,
          text: 'Matches ${checkedAgainstSubtotal ? 'subtotal' : 'total'} ${formatCents(e)}',
        ),
      );
    } else {
      badge = PopIn(
        key: ValueKey('off$itemsSum'),
        child: _Pill(
          bg: Colors.white,
          fg: t.upText,
          icon: Symbols.error_rounded,
          text: 'Receipt says ${formatCents(e)}: off by ${formatCents((itemsSum - e).abs())}',
        ),
      );
    }
    return HeroCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: onStore,
              borderRadius: BorderRadius.circular(8),
              child: Text(store.isEmpty ? 'Which store? Tap to add' : store,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: slipText(17, 900, color: onAcc)),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: chipBg,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(DateFormat.MMMd().format(date),
                    semanticsLabel: 'Date ${DateFormat.yMMMd().format(date)}, tap to change',
                    style: slipText(12.5, 900, color: onAcc)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 2),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          CountUp(cents: payCents, ms: 1200, style: slipText(40, 900, color: onAcc, tabular: true, height: 1.1)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(plural(itemCount, 'item'),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: slipText(13, 800, color: t.onAccSmall)),
          ),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTotals,
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: badge),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.bg, required this.fg, required this.text, this.icon});
  final Color bg, fg;
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[SlipIcon(icon!, size: 16, color: fg, fill: 1), const SizedBox(width: 6)],
          Flexible(child: Text(text, style: slipText(12.5, 900, color: fg, tabular: true))),
        ]),
      );
}

/// A per-photo or reading problem, in amber.
class _Warning extends StatelessWidget {
  const _Warning({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return SlipCard(
      color: t.warningSoft,
      radius: t.rRow,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SlipIcon(Symbols.warning_rounded, size: 18, color: t.warning, fill: 1),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: slipText(12.5, 800, color: t.warning))),
      ]),
    );
  }
}

/// "Subtotal 58.81 · Tax 0.62 · Total 59.43", tap to edit.
class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.draft, required this.onTap});
  final ReceiptDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    String v(int? c) => c == null ? '—' : formatCents(c);
    return SlipCard(
      radius: t.rRow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('As printed', style: slipText(12, 800, color: t.ink2)),
            Text('Subtotal ${v(draft.subtotalCents)} · Tax ${v(draft.taxCents)} · Total ${v(draft.totalCents)}',
                style: slipText(13.5, 800, color: t.ink, tabular: true)),
          ]),
        ),
        SlipIcon(Symbols.edit_rounded, size: 20, color: t.ink2),
      ]),
    );
  }
}
