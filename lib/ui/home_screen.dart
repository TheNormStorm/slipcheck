import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';

import '../data/receipt_repository.dart';
import '../data/sample_data.dart';
import 'app_actions.dart';
import 'chart_palette.dart';
import 'components/brand.dart';
import 'components/kit.dart';
import 'motion/motion.dart';
import 'receipt_detail_screen.dart';
import 'receipts_screen.dart';
import 'reload_on_change.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// Home: the scan card and this month's receipts. (Phase 1 layout; the
/// count-ups, price chips and mascot moments arrive in phase 2.)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.actions});
  final AppActions actions;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ReloadOnChange {
  @override
  ReceiptRepository get repo => widget.actions.repo;

  late Future<(List<ReceiptSummary>, List<StoreSummary>)> _data = _load();

  Future<(List<ReceiptSummary>, List<StoreSummary>)> _load() async =>
      (await repo.receipts(), await repo.stores());

  @override
  void reload() {
    _data = _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            final receipts = snap.data?.$1;
            final thisMonth = receipts
                ?.where((r) => r.purchasedAt.year == now.year && r.purchasedAt.month == now.month)
                .toList();
            final shown = (thisMonth == null || thisMonth.isEmpty) ? receipts?.take(5).toList() : thisMonth;
            final palette = ChartPalette.of(context);
            final slots = storeSlots((snap.data?.$2 ?? const <StoreSummary>[])
                .where((s) => s.receiptCount > 0)
                .map((s) => (s.id, s.name)));
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                _Header(actions: widget.actions, onSamples: kDebugMode ? () => loadSampleReceipts(repo) : null),
                const SizedBox(height: 14),
                _ScanCard(actions: widget.actions),
                const SizedBox(height: 18),
                if (receipts == null)
                  for (var i = 0; i < 4; i++)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: Skeleton(height: 64, radius: t.rRow))
                else if (receipts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(children: [
                      const SlipMascot(width: 64, mood: SlipMood.sleepy),
                      const SizedBox(height: 12),
                      Text('Nothing here yet', style: slipText(17, 900, color: t.ink)),
                      Text("Scan your first receipt. Slip's hungry.", style: slipText(13, 600, color: t.ink2)),
                    ]),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 8),
                    child: Text(
                      thisMonth!.isEmpty ? 'Latest receipts' : '${DateFormat.MMMM().format(now)} so far',
                      style: slipText(13, 800, color: t.ink2),
                    ),
                  ),
                  for (final (i, r) in shown!.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Rise(
                        index: i,
                        child: ReceiptCard(
                          receipt: r,
                          color: palette.series(slots[r.storeName] ?? 8),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ReceiptDetailScreen(repo: repo, receiptId: r.id),
                          )),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.actions, this.onSamples});
  final AppActions actions;
  final VoidCallback? onSamples;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(DateFormat('EEEE, MMM d').format(DateTime.now()), style: slipText(13, 700, color: t.ink2)),
          const SizedBox(height: 2),
          GestureDetector(
            // Debug builds only: long-press the title to load sample receipts.
            onLongPress: onSamples,
            child: Row(children: [
              const LogoMark(size: 32, dark: false),
              const SizedBox(width: 8),
              Text('Slipcheck', style: slipText(28, 900, color: t.ink, letterSpacing: -.5)),
            ]),
          ),
        ]),
      ),
      _MoreMenu(actions: actions),
    ]);
  }
}

/// The ⋮ menu: export, back up, restore, clear all.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.actions});
  final AppActions actions;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    PopupMenuItem<String> item(String value, IconData icon, String title, String sub, {bool danger = false}) =>
        PopupMenuItem(
          value: value,
          child: Row(children: [
            SlipIcon(icon, size: 20, color: danger ? t.upText : t.ink),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: slipText(14, 800, color: danger ? t.upText : t.ink)),
              Text(sub, style: slipText(11.5, 600, color: t.ink2)),
            ]),
          ]),
        );
    return PopupMenuButton<String>(
      tooltip: 'More',
      position: PopupMenuPosition.under,
      onSelected: (v) => switch (v) {
        'csv' => actions.exportCsv(),
        'backup' => actions.backup(),
        'restore' => actions.restore(context),
        _ => actions.clearAll(context),
      },
      itemBuilder: (_) => [
        item('csv', Symbols.table_view_rounded, 'Export spreadsheet', 'CSV of every line'),
        item('backup', Symbols.cloud_upload_rounded, 'Back up', 'You pick where it goes'),
        item('restore', Symbols.settings_backup_restore_rounded, 'Restore', 'From a backup file'),
        const PopupMenuDivider(),
        item('clear', Symbols.delete_sweep_rounded, 'Clear all receipts', "Can't be undone", danger: true),
        PopupMenuItem(
          enabled: false,
          height: 36,
          child: Row(children: [
            SlipIcon(Symbols.lock_rounded, size: 16, color: t.downText),
            const SizedBox(width: 8),
            Text('Everything stays on this phone.', style: slipText(12, 700, color: t.ink2)),
          ]),
        ),
      ],
      child: IgnorePointer(
        child: CircleAction(icon: Symbols.more_horiz_rounded, onTap: () {}, tooltip: 'More'),
      ),
    );
  }
}

/// "Got a receipt? Let's read it." with Scan, Gallery and Type it.
class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.actions});
  final AppActions actions;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    final heroBtn = t.punchy ? t.accInk : Colors.white;
    final heroBtnInk = t.punchy ? t.acc : t.accDeep;
    final chip = t.punchy ? const Color(0x2E1A0E06) : const Color(0x38FFFFFF);
    return Stack(clipBehavior: Clip.none, children: [
      HeroCard(
        child: ValueListenableBuilder(
          valueListenable: actions.busy,
          builder: (context, busy, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(right: 56),
              child: Text("Got a receipt? Let's read it.",
                  style: slipText(22, 900, color: t.punchy ? t.accInk : Colors.white, height: 1.15)),
            ),
            const SizedBox(height: 14),
            PulseRing(
              color: heroBtn,
              radius: t.punchy ? 12 : 999,
              child: SizedBox(
                height: 58,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: heroBtn,
                    foregroundColor: heroBtnInk,
                    textStyle: slipText(18, 900),
                  ),
                  onPressed: busy ? null : () => actions.scan(context),
                  icon: busy
                      ? SizedBox.square(
                          dimension: 22, child: CircularProgressIndicator(strokeWidth: 3, color: heroBtnInk))
                      : const SlipIcon(Symbols.document_scanner_rounded, size: 26),
                  label: Text(busy ? 'Reading…' : 'Scan receipt'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              for (final (i, (icon, label, onTap)) in [
                (Symbols.photo_library_rounded, 'Gallery', () => actions.gallery(context)),
                (Symbols.edit_rounded, 'Type it', () => actions.typeIt(context)),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: chip,
                        foregroundColor: t.punchy ? t.accInk : Colors.white,
                        textStyle: slipText(14, 800),
                        minimumSize: const Size(0, 40),
                      ),
                      onPressed: busy ? null : onTap,
                      icon: SlipIcon(icon, size: 18),
                      label: Text(label),
                    ),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 10),
            Text('Long one? Overlap photos by 2–3 lines.',
                style: slipText(13, 700, color: t.onAccSmall)),
          ]),
        ),
      ),
      const Positioned(
        right: 18,
        top: -14,
        child: Bob(amplitude: 3, period: 2600, angle: .06, child: SlipMascot(width: 40)),
      ),
    ]);
  }
}
