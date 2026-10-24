import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/database.dart';
import 'data/receipt_files.dart';
import 'data/receipt_repository.dart';
import 'ocr/receipt_reader.dart';
import 'ui/app_actions.dart';
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
      home: AppShell(actions: AppActions(repo, reader)),
    );
  }
}
