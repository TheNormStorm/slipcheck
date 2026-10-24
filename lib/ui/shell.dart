import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/text.dart';
import 'analytics_screen.dart';
import 'app_actions.dart';
import 'components/kit.dart';
import 'home_screen.dart';
import 'products_screen.dart';
import 'receipt_detail_screen.dart';
import 'receipts_screen.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

/// The app's frame: four tabs and a raised Scan button in the middle of a
/// 76px bottom bar (Home · Receipts · [Scan] · Insights · Items).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.actions});
  final AppActions actions;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.actions.saved.addListener(_showSaved);
  }

  @override
  void dispose() {
    widget.actions.saved.removeListener(_showSaved);
    super.dispose();
  }

  /// "Saved! 9 items tracked." with a way to open the receipt.
  void _showSaved() {
    final note = widget.actions.saved.value;
    if (note == null || !mounted) return;
    final up = note.moves.up;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Saved! ${plural(note.itemCount, 'item')} tracked.'
            '${up > 0 ? ' ${plural(up, 'price')} went up.' : ''}'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ReceiptDetailScreen(repo: widget.actions.repo, receiptId: note.receiptId),
          )),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.actions.repo;
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(actions: widget.actions),
          ReceiptsScreen(repo: repo),
          AnalyticsScreen(repo: repo),
          ProductsScreen(repo: repo),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _tab,
        busy: widget.actions.busy,
        onTab: (i) => setState(() => _tab = i),
        onScan: () => widget.actions.scan(context),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTab, required this.onScan, required this.busy});
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onScan;
  final ValueNotifier<bool> busy;

  static const _tabs = [
    (Symbols.home_rounded, 'Home'),
    (Symbols.receipt_long_rounded, 'Receipts'),
    (Symbols.insights_rounded, 'Insights'),
    (Symbols.sell_rounded, 'Items'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    Widget tab(int i) {
      final (icon, label) = _tabs[i];
      final on = i == index;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 32,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 52,
                height: 30,
                decoration: BoxDecoration(
                  color: on ? t.accSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: SlipIcon(icon, size: 22, color: on ? t.accText : t.ink2, fill: on ? 1 : 0),
              ),
              const SizedBox(height: 3),
              Text(label, style: slipText(11, 800, color: on ? t.accText : t.ink2)),
            ]),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.punchy ? const Color(0xFF1A1613) : t.surf,
        border: Border(
            top: BorderSide(
                color: t.punchy ? t.line : const Color(0xFFEFE6DC), width: t.punchy ? 2 : 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(children: [
            tab(0),
            tab(1),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Transform.translate(
                  offset: const Offset(0, -14),
                  child: ValueListenableBuilder(
                    valueListenable: busy,
                    builder: (context, reading, _) => _ScanButton(onTap: reading ? null : onScan),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -10),
                  child: Text('Scan', style: slipText(11, 800, color: t.ink2)),
                ),
              ]),
            ),
            tab(2),
            tab(3),
          ]),
        ),
      ),
    );
  }
}

/// The raised orange camera button.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SlipTokens.of(context);
    return Semantics(
      button: true,
      label: 'Scan a receipt',
      child: Material(
        color: onTap == null ? t.surf2 : t.acc,
        elevation: t.punchy ? 0 : 6,
        shadowColor: t.acc.withValues(alpha: .5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.punchy ? 16 : 29),
          side: t.outline ?? BorderSide.none,
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.punchy ? 16 : 29)),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 58,
            child: onTap == null
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: CircularProgressIndicator(strokeWidth: 3, color: t.acc),
                  )
                : SlipIcon(Symbols.photo_camera_rounded, size: 28, color: t.accInk, fill: 1),
          ),
        ),
      ),
    );
  }
}
