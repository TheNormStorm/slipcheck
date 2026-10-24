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
import 'onboarding_screen.dart';
import 'reading_screen.dart';
import 'review_screen.dart';
import 'saved_screen.dart';
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

  /// The last receipt saved, for the Home message.
  final saved = ValueNotifier<SavedNote?>(null);

  void _onSaved(SavedNote note) => saved.value = note;

  static const _tipsKey = 'scanTipsSeen';

  /// The scanner, after its tips the first time.
  Future<void> scan(BuildContext context) async {
    if (!await repo.hasSeen(_tipsKey)) {
      if (!context.mounted) return;
      final go = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const ScanTipsScreen(), fullscreenDialog: true));
      if (go != true) return;
      await repo.markSeen(_tipsKey);
    }
    if (!context.mounted) return;
    final paths = await capturePages(context);
    if (paths != null && context.mounted) await _read(context, paths, scanned: true);
  }

  Future<void> gallery(BuildContext context) async {
    final picked = await ImagePicker().pickMultiImage();
    if (picked.isNotEmpty && context.mounted) {
      await _read(context, [for (final f in picked) f.path], scanned: false);
    }
  }

  Future<void> typeIt(BuildContext context) => Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ReviewScreen(
          repo: repo,
          onSaved: _onSaved,
          draft: ReceiptDraft(
            storeName: '',
            purchasedAt: DateTime.now(),
            lines: [DraftLine(name: '', lineTotalCents: 0)],
            source: 'manual',
          ),
        ),
      ));

  /// Reads the photos on the Reading screen, which opens "Check it".
  Future<void> _read(BuildContext context, List<String> paths, {required bool scanned}) async {
    // The last "Saved!" message is old news once the next receipt is read.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    busy.value = true;
    try {
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => ReadingScreen(
          repo: repo,
          reader: reader,
          paths: paths,
          scanned: scanned,
          onSaved: _onSaved,
        ),
      ));
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear all $count receipt${count == 1 ? '' : 's'}?'),
        content: const Text('Items, stores, photos and price history go too. No undo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everything cleared.')));
    }
  }
}
