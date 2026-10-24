import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/database.dart';
import 'data/device_currency.dart';
import 'data/receipt_files.dart';
import 'data/receipt_repository.dart';
import 'ocr/receipt_reader.dart';
import 'ui/app_actions.dart';
import 'ui/currency_scope.dart';
import 'ui/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // The bundled fonts' open font licences, shown on the licences page.
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Nunito', 'JetBrainsMono']) {
      yield LicenseEntryWithLineBreaks(
          [font], await rootBundle.loadString('assets/fonts/$font-OFL.txt'));
    }
  });
  final repo = ReceiptRepository(AppDatabase());
  // Older OCR dumps may still hold a card section; clean them once.
  ReceiptFiles.redactExistingDumps().catchError((Object _) {});
  runApp(SlipcheckApp(repo: repo, reader: ReceiptReader()));
}

class SlipcheckApp extends StatelessWidget {
  const SlipcheckApp({super.key, required this.repo, required this.reader});

  final ReceiptRepository repo;
  final ReceiptReader reader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Slipcheck',
      theme: buildSlipTheme(Brightness.light),
      darkTheme: buildSlipTheme(Brightness.dark),
      home: _FirstRun(actions: AppActions(repo, reader)),
      builder: (context, child) => _CurrencyHost(repo: repo, child: child!),
    );
  }
}

/// Keeps the main currency (the one most receipts are in) current for
/// every screen and dialog.
class _CurrencyHost extends StatefulWidget {
  const _CurrencyHost({required this.repo, required this.child});
  final ReceiptRepository repo;
  final Widget child;

  @override
  State<_CurrencyHost> createState() => _CurrencyHostState();
}

class _CurrencyHostState extends State<_CurrencyHost> {
  final _main = ValueNotifier(deviceCurrency());
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    _refresh();
    _changes = widget.repo.changes.listen((_) => _refresh());
  }

  Future<void> _refresh() async {
    final main = await widget.repo.mainCurrency();
    if (main != null && mounted) _main.value = main;
  }

  @override
  void dispose() {
    _changes?.cancel();
    _main.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CurrencyScope(main: _main, child: widget.child);
}

/// Onboarding on the first launch, then the app.
class _FirstRun extends StatefulWidget {
  const _FirstRun({required this.actions});
  final AppActions actions;

  @override
  State<_FirstRun> createState() => _FirstRunState();
}

class _FirstRunState extends State<_FirstRun> {
  static const _key = 'onboardingSeen';
  late final Future<bool> _seen = widget.actions.repo.hasSeen(_key);
  bool _done = false;

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _seen,
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          if (snap.data! || _done) return AppShell(actions: widget.actions);
          return OnboardingScreen(onDone: () {
            widget.actions.repo.markSeen(_key);
            setState(() => _done = true);
          });
        },
      );
}
