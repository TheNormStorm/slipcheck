import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

import '../core/parsing/redaction.dart';
import '../data/receipt_repository.dart';
import '../ocr/receipt_reader.dart';

/// Opens Google's on-device document scanner, which finds the receipt's
/// edges, crops, flattens and cleans up each photo. Returns the page images
/// top first, or null if the user backed out. Falls back to the plain camera
/// where the scanner is unavailable (no Play services).
Future<List<String>?> capturePages(BuildContext context, {int pageLimit = 8}) async {
  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      pageLimit: pageLimit,
      mode: ScannerMode.full,
      isGalleryImport: true,
      documentFormats: const {DocumentFormat.jpeg},
    ),
  );
  try {
    final result = await scanner.scanDocument();
    final images = result.images ?? const [];
    return images.isEmpty ? null : images;
  } on PlatformException catch (e) {
    if (e.message == 'Operation cancelled') return null;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Scanner unavailable, using the plain camera.')));
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    return picked == null ? null : [picked.path];
  } finally {
    await scanner.close();
  }
}

/// The photos behind a receipt being reviewed, so pages can be added or
/// retaken and the receipt read again.
class ScanSession {
  ScanSession(this.reader, List<PageRead> pages) : result = reader.combine(pages);

  final ReceiptReader reader;
  ReadResult result;

  /// The photos in receipt order, as worked out by the last read.
  List<PageRead> get pages => result.pages;

  Future<void> addPages(List<String> paths) async {
    final added = [for (final path in paths) await reader.readPage(path)];
    result = reader.combine([...pages, ...added]);
  }

  Future<void> replacePage(int index, String path) async {
    final updated = [...pages];
    updated[index] = await reader.readPage(path);
    result = reader.combine(updated);
  }

  void removePage(int index) {
    result = reader.combine([...pages]..removeAt(index));
  }

  ReceiptDraft toDraft() {
    final parsed = result.parsed;
    return ReceiptDraft(
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
            code: l.code,
            section: l.section,
          ),
      ],
      subtotalCents: parsed.subtotalCents,
      taxCents: parsed.taxCents,
      totalCents: parsed.totalCents,
      imagePaths: result.imagePaths,
      // Card numbers and approval codes are not kept.
      ocrText: withoutPaymentSection(result.stitch.rows).join('\n'),
    );
  }

  /// Things the user should look at, in plain words.
  List<String> notes() => [
        for (final (i, page) in pages.indexed)
          if (page.problem != null) 'Photo ${i + 1}: ${page.problem}. Retake it?',
        for (final join in result.stitch.joins)
          if (!join.found)
            'Photos ${join.page} and ${join.page + 1} do not overlap, so lines between '
                'them may be missing. Retake photo ${join.page + 1} starting 2–3 lines '
                'above where photo ${join.page} ends.',
        // A missing total and the items-vs-total check are shown in the
        // review screen's summary instead.
        for (final w in result.parsed.warnings)
          if (w == 'No items found.') w,
      ];

  String summary() {
    final n = pages.length;
    final removed = result.stitch.overlapRowsRemoved;
    return n == 1
        ? '1 photo'
        : '$n photos · $removed overlapping line${removed == 1 ? '' : 's'} removed';
  }
}
