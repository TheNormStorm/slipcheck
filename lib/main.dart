import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/receipt_repository.dart';
import 'ocr/receipt_reader.dart';
import 'ui/home_screen.dart';

void main() {
  final repo = ReceiptRepository(AppDatabase());
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
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      home: HomeScreen(repo: repo, reader: reader),
    );
  }
}
