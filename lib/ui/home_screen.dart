import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/money.dart';
import '../data/receipt_repository.dart';
import '../ocr/receipt_reader.dart';
import 'products_screen.dart';
import 'review_screen.dart';

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
  bool _busy = false;

  void _reload() => setState(() => _receipts = widget.repo.receipts());

  Future<void> _scan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final result = await widget.reader.read(picked.path);
      final parsed = result.parsed;
      final draft = ReceiptDraft(
        storeName: parsed.storeName ?? '',
        purchasedAt: parsed.date ?? DateTime.now(),
        lines: [
          for (final l in parsed.items)
            DraftLine(
              name: l.rawText,
              quantity: l.quantity,
              unit: l.unit,
              unitPriceCents: l.unitPriceCents,
              lineTotalCents: l.lineTotalCents,
              discountCents: l.discountCents,
            ),
        ],
        subtotalCents: parsed.subtotalCents,
        taxCents: parsed.taxCents,
        totalCents: parsed.totalCents,
        imagePath: result.imagePath,
        ocrText: result.rows.join('\n'),
      );
      if (!mounted) return;
      await _review(draft, parsed.warnings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read receipt: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manual() => _review(
        ReceiptDraft(
          storeName: '',
          purchasedAt: DateTime.now(),
          lines: [DraftLine(name: '', lineTotalCents: 0)],
          source: 'manual',
        ),
        const [],
      );

  Future<void> _review(ReceiptDraft draft, List<String> warnings) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ReviewScreen(repo: widget.repo, draft: draft, warnings: warnings),
    ));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slipcheck'),
        actions: [
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
                  onPressed: _busy ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.gallery),
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
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: FutureBuilder(
              future: _receipts,
              builder: (context, snap) {
                final receipts = snap.data ?? const [];
                if (receipts.isEmpty) {
                  return const Center(child: Text('No receipts yet.'));
                }
                return ListView.builder(
                  itemCount: receipts.length,
                  itemBuilder: (context, i) {
                    final r = receipts[i];
                    return ListTile(
                      title: Text(r.storeName ?? 'Unknown store'),
                      subtitle: Text(
                          '${DateFormat.yMMMd().format(r.purchasedAt)} · ${r.itemCount} items'),
                      trailing: Text(r.totalCents == null ? '' : formatCents(r.totalCents!)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
