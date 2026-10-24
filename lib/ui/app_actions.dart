import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup.dart';
import '../data/receipt_repository.dart';
import '../ocr/receipt_reader.dart';
import 'review_screen.dart';
import 'scan_flow.dart';

/// What the app can do from anywhere: capture a receipt (scanner, gallery,
/// typed in) and the data actions of the ⋮ menu. Screens refresh themselves
/// from `ReceiptRepository.changes`, so nothing here reloads them.
class AppActions {
  AppActions(this.repo, this.reader);
  final ReceiptRepository repo;
  final ReceiptReader reader;

  /// True while photos are being read.
  final busy = ValueNotifier(false);

  Future<void> scan(BuildContext context) async {
    final paths = await capturePages(context);
    if (paths != null && context.mounted) await _read(context, paths);
  }

  Future<void> gallery(BuildContext context) async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty && context.mounted) {
      await _read(context, [for (final f in picked) f.path]);
    }
  }

  Future<void> typeIt(BuildContext context) => Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ReviewScreen(
          repo: repo,
          draft: ReceiptDraft(
            storeName: '',
            purchasedAt: DateTime.now(),
            lines: [DraftLine(name: '', lineTotalCents: 0)],
            source: 'manual',
          ),
        ),
      ));

  /// OCRs every photo (top of the receipt first) and opens the review.
  Future<void> _read(BuildContext context, List<String> paths) async {
    busy.value = true;
    try {
      final pages = [for (final path in paths) await reader.readPage(path)];
      if (!context.mounted) return;
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ReviewScreen(repo: repo, session: ScanSession(reader, pages)),
      ));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not read receipt: $e')));
      }
    } finally {
      busy.value = false;
    }
  }

  /// Hands a file to the share sheet; the user picks where it goes (Files,
  /// Drive, email...). Nothing is sent anywhere otherwise.
  Future<void> _share(File file, String title) => SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], title: title, subject: title),
      );

  Future<void> exportCsv() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'slipcheck-purchases.csv'));
    await file.writeAsString(await repo.csvExport());
    await _share(file, 'Slipcheck purchases');
  }

  Future<void> backup() async => _share(await Backup.create(repo.db), 'Slipcheck backup');

  Future<void> restore(BuildContext context) async {
    final picked = await FilePicker.pickFiles(dialogTitle: 'Choose a Slipcheck backup');
    final path = picked.firstOrNull?.path;
    if (path == null || !context.mounted) return;
    final file = File(path);
    if (!await Backup.isBackup(file)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That file is not a Slipcheck backup.')));
      }
      return;
    }
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: const Text('Replace everything with this backup? Slipcheck restarts after.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;
    await repo.db.close();
    await Backup.restore(file);
    // The open database connection cannot be swapped in place; a fresh start
    // opens (and if needed upgrades) the restored file.
    exit(0);
  }

  Future<void> clearAll(BuildContext context) async {
    final count = (await repo.receipts()).length;
    if (!context.mounted) return;
    var forgetItems = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Clear all $count receipt${count == 1 ? '' : 's'}?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Photos and price history go too. No undo.'),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: forgetItems,
              onChanged: (v) => setDialog(() => forgetItems = v ?? false),
              title: const Text('Forget items and stores too'),
              subtitle: const Text('Leave off to keep recognising your stuff.'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
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
    await repo.clearAll(forgetItems: forgetItems);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(forgetItems ? 'Everything cleared.' : 'All receipts cleared.')));
    }
  }
}
