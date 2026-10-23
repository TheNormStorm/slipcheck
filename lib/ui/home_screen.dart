import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/money.dart';
import '../data/backup.dart';
import '../data/receipt_repository.dart';
import '../data/sample_data.dart';
import '../ocr/receipt_reader.dart';
import 'analytics_screen.dart';
import 'products_screen.dart';
import 'chart_palette.dart';
import 'receipt_detail_screen.dart';
import 'store_screen.dart';
import 'review_screen.dart';
import 'scan_flow.dart';

/// Testing UI: capture buttons and the list of saved receipts.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repo, required this.reader});

  final ReceiptRepository repo;
  final ReceiptReader reader;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<ReceiptSummary>> _receipts = widget.repo.receipts();
  late Future<List<StoreSummary>> _stores = widget.repo.stores();
  bool _busy = false;
  bool _byStore = false;

  void _reload() => setState(() {
        _receipts = widget.repo.receipts();
        _stores = widget.repo.stores();
      });

  /// Hands a file to the share sheet; the user picks where it goes (Files,
  /// Drive, email...). Nothing is sent anywhere otherwise.
  Future<void> _share(File file, String title) => SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], title: title, subject: title),
      );

  Future<void> _exportCsv() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'slipcheck-purchases.csv'));
    await file.writeAsString(await widget.repo.csvExport());
    await _share(file, 'Slipcheck purchases');
  }

  Future<void> _backup() async {
    final file = await Backup.create(widget.repo.db);
    await _share(file, 'Slipcheck backup');
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Choose a Slipcheck backup');
    final path = picked.firstOrNull?.path;
    if (path == null || !mounted) return;
    final file = File(path);
    if (!await Backup.isBackup(file)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That file is not a Slipcheck backup.')));
      }
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text('Everything currently in Slipcheck is replaced by the backup. '
            'Slipcheck then closes; open it again to continue.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.repo.db.close();
    await Backup.restore(file);
    // The open database connection cannot be swapped in place; a fresh start
    // opens (and if needed upgrades) the restored file.
    exit(0);
  }

  Future<void> _clearAll() async {
    final count = (await widget.repo.receipts()).length;
    if (!mounted) return;
    var forgetItems = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Clear all receipts?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All $count receipt${count == 1 ? '' : 's'}, their photos and price history '
                'will be deleted from this phone. This cannot be undone.'),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: forgetItems,
              onChanged: (v) => setDialog(() => forgetItems = v ?? false),
              title: const Text('Also forget items and stores'),
              subtitle: const Text('Learned names, links between stores and categories. '
                  'Leave unticked to keep recognising your items.'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete all'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await widget.repo.clearAll(forgetItems: forgetItems);
    _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(forgetItems ? 'Everything cleared.' : 'All receipts cleared.')));
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _reload();
  }

  Future<void> _scan() async {
    final paths = await capturePages(context);
    if (paths != null) await _read(paths);
  }

  Future<void> _gallery() async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty) await _read([for (final f in picked) f.path]);
  }

  /// OCRs every photo (top of the receipt first) and opens the review.
  Future<void> _read(List<String> paths) async {
    setState(() => _busy = true);
    try {
      final pages = [for (final path in paths) await widget.reader.readPage(path)];
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ReviewScreen(
            repo: widget.repo, session: ScanSession(widget.reader, pages)),
      ));
      if (saved == true) _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read receipt: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manual() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ReviewScreen(
        repo: widget.repo,
        draft: ReceiptDraft(
          storeName: '',
          purchasedAt: DateTime.now(),
          lines: [DraftLine(name: '', lineTotalCents: 0)],
          source: 'manual',
        ),
      ),
    ));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          // Debug builds only: long-press the title to load sample receipts.
          onLongPress: kDebugMode
              ? () async {
                  await loadSampleReceipts(widget.repo);
                  _reload();
                }
              : null,
          child: const Text('Slipcheck'),
        ),
        actions: [
          IconButton(
            tooltip: 'Analytics',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AnalyticsScreen(repo: widget.repo),
            )),
          ),
          TextButton.icon(
            icon: const Icon(Icons.show_chart),
            label: const Text('Items'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductsScreen(repo: widget.repo),
            )),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'csv' => _exportCsv(),
              'backup' => _backup(),
              'restore' => _restore(),
              _ => _clearAll(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'csv', child: Text('Export as spreadsheet (CSV)')),
              PopupMenuItem(value: 'backup', child: Text('Back up…')),
              PopupMenuItem(value: 'restore', child: Text('Restore from backup…')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'clear', child: Text('Clear all receipts…')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _scan,
                  icon: const Icon(Icons.document_scanner),
                  label: const Text('Scan receipt'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _gallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _manual,
                  icon: const Icon(Icons.edit),
                  label: const Text('Manual'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Long receipt? Take several photos: start at the store name, '
              'overlap each photo with the last by 2–3 lines, and finish at TOTAL.',
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('By date'), icon: Icon(Icons.receipt_long)),
                ButtonSegment(value: true, label: Text('By store'), icon: Icon(Icons.store)),
              ],
              selected: {_byStore},
              onSelectionChanged: (v) => setState(() => _byStore = v.single),
            ),
          ),
          Expanded(child: _byStore ? _storeList() : _receiptList()),
        ],
      ),
    );
  }

  Widget _receiptList() => FutureBuilder(
        future: _receipts,
        builder: (context, snap) {
          final receipts = snap.data ?? const [];
          if (receipts.isEmpty) return const Center(child: Text('No receipts yet.'));
          return ListView.builder(
            itemCount: receipts.length,
            itemBuilder: (context, i) {
              final r = receipts[i];
              return ListTile(
                title: Text(r.storeName ?? 'Unknown store'),
                subtitle: Text('${DateFormat.yMMMd().format(r.purchasedAt)} · ${r.itemCount} item${r.itemCount == 1 ? '' : 's'}'),
                trailing: Text(formatCents(r.spentCents)),
                onTap: () => _open(ReceiptDetailScreen(repo: widget.repo, receiptId: r.id)),
              );
            },
          );
        },
      );

  Widget _storeList() => FutureBuilder(
        future: _stores,
        builder: (context, snap) {
          final stores = (snap.data ?? const <StoreSummary>[])
              .where((s) => s.receiptCount > 0)
              .toList();
          if (stores.isEmpty) return const Center(child: Text('No receipts yet.'));
          final palette = ChartPalette.of(context);
          final slots = storeSlots(stores.map((s) => (s.id, s.name)));
          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, i) {
              final s = stores[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: palette.series(slots[s.name] ?? 8),
                  foregroundColor: Colors.white,
                  child: Text(s.name.characters.first.toUpperCase()),
                ),
                title: Text(s.name),
                subtitle: Text('${s.receiptCount} receipt${s.receiptCount == 1 ? '' : 's'}'
                    '${s.lastVisit == null ? '' : ' · last ${DateFormat.yMMMd().format(s.lastVisit!)}'}'),
                trailing: Text(formatCents(s.spentCents)),
                onTap: () => _open(StoreScreen(repo: widget.repo, storeId: s.id)),
              );
            },
          );
        },
      );
}
