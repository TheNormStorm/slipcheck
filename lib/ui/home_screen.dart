import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/money.dart';
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
                subtitle: Text('${DateFormat.yMMMd().format(r.purchasedAt)} · ${r.itemCount} items'),
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
