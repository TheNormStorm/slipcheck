import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/text.dart';
import '../core/update.dart';
import '../data/backup.dart';
import '../data/receipt_repository.dart';
import '../data/update_checker.dart';
import '../ocr/receipt_reader.dart';
import 'components/dialogs.dart';
import 'components/kit.dart';
import 'onboarding_screen.dart';
import 'reading_screen.dart';
import 'review_screen.dart';
import 'saved_screen.dart';
import 'scan_flow.dart';
import 'theme/tokens.dart';

/// What the app can do from anywhere: capture a receipt (scanner, gallery,
/// typed in) and the data actions of the ⋮ menu. Screens refresh themselves
/// from `ReceiptRepository.changes`, so nothing here reloads them.
class AppActions {
  AppActions(this.repo, this.reader, {this.updates = const UpdateChecker()});
  final ReceiptRepository repo;
  final ReceiptReader reader;
  final UpdateChecker updates;

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
    final ok = await confirmDialog(
      context,
      icon: Symbols.settings_backup_restore_rounded,
      title: 'Restore this backup?',
      body: 'Replace everything with this backup? Slipcheck restarts after.',
      confirm: 'Restore',
      danger: true,
    );
    if (!ok) return;
    await repo.db.close();
    await Backup.restore(file);
    // The open database connection cannot be swapped in place; a fresh start
    // opens (and if needed upgrades) the restored file.
    exit(0);
  }

  /// Asks GitHub whether a newer Slipcheck is out and, if so, offers to
  /// open its download. Only runs when the user taps it.
  Future<void> checkForUpdates(BuildContext context) async {
    final current = (await PackageInfo.fromPlatform()).version;
    if (!context.mounted) return;
    // Started before the dialog listens: a quick failure must not count as
    // unhandled before the dialog shows it.
    final release = updates.latest()..ignore();
    await showDialog<void>(
      context: context,
      builder: (context) => FutureBuilder(
        future: release,
        builder: (context, snap) {
          final t = SlipTokens.of(context);
          Widget dialog(IconData icon, String title, String body, List<Widget> actions) => AlertDialog(
                icon: SlipIcon(icon, size: 36, color: t.accText),
                title: Text(title, textAlign: TextAlign.center),
                content: Text(body, textAlign: TextAlign.center),
                actionsAlignment: MainAxisAlignment.center,
                actions: actions,
              );
          final close = TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'));
          if (snap.connectionState != ConnectionState.done) {
            return AlertDialog(
              content: Row(children: [
                SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 3, color: t.acc)),
                const SizedBox(width: 16),
                const Expanded(child: Text('Asking GitHub…')),
              ]),
            );
          }
          if (snap.hasError) {
            return dialog(Symbols.wifi_off_rounded, "Couldn't check",
                'GitHub could not be reached. Check your connection and try again.', [close]);
          }
          final r = snap.data;
          if (r == null || !isNewer(r.version, current)) {
            return dialog(Symbols.verified_rounded, "You're up to date", 'Slipcheck $current is the latest.', [close]);
          }
          return dialog(
            Symbols.system_update_rounded,
            'Slipcheck ${r.version} is out',
            [
              'You have $current.',
              if (r.notes.isNotEmpty) r.notes,
              'Download it, then open the file to install. Your receipts stay as they are.',
            ].join('\n\n'),
            [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse(r.apkUrl ?? r.pageUrl), mode: LaunchMode.externalApplication);
                },
                child: const Text('Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> clearAll(BuildContext context) async {
    final count = (await repo.receipts()).length;
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      icon: Symbols.delete_sweep_rounded,
      title: 'Clear all ${plural(count, 'receipt')}?',
      body: 'Items, stores, photos and price history go too. No undo.',
      confirm: 'Delete all',
      danger: true,
    );
    if (!ok) return;
    await repo.clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everything cleared.')));
    }
  }
}
