import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/core/parsing/stitcher.dart';

void main() {
  late List<String> full;
  setUpAll(() {
    final json = jsonDecode(
        File('test/fixtures/market_basket_mlkit.json').readAsStringSync()) as List;
    full = groupIntoRows([for (final l in json) OcrLine.fromJson(l)]);
  });

  test('three overlapping photos of one receipt rebuild it exactly', () {
    final pages = [
      full.sublist(0, 30),
      full.sublist(27, 55), // 3 rows of overlap
      full.sublist(52),
    ];
    final s = stitchPages(pages);
    expect(s.rows, full);
    expect(s.joins.map((j) => (j.found, j.overlapRows)), [(true, 3), (true, 3)]);
    expect(const ReceiptParser().parse(s.rows).items, hasLength(33));
  });

  test('OCR reads the overlap slightly differently in each photo', () {
    final second = full.sublist(27, 55);
    second[0] = second[0].replaceAll('BELL', 'BELI');
    second[1] = second[1].replaceAll('@', '©');
    final s = stitchPages([full.sublist(0, 30), second]);
    expect(s.rows, hasLength(55));
    expect(s.joins.single.overlapRows, 3);
  });

  test('a line cut by the top edge of the next photo is skipped', () {
    final second = ['ll   EVANS HAl', ...full.sublist(27, 40)];
    final s = stitchPages([full.sublist(0, 30), second]);
    expect(s.rows, full.sublist(0, 40));
  });

  test('a line cut by the bottom edge keeps the complete reading', () {
    final cut = full[29].substring(0, full[29].length ~/ 2);
    final first = [...full.sublist(0, 29), cut];
    final s = stitchPages([first, full.sublist(27, 40)]);
    expect(s.rows, full.sublist(0, 40));
    expect(s.pageOfRow[29], 1);
  });

  test('identical purchases in a row are not taken for an overlap', () {
    const item = 'MILK 2% 1L  4.99 F';
    final s = stitchPages([
      ['STORE', 'BREAD  3.49 F', item],
      [item, 'EGGS  2.99 F', 'TOTAL  11.47'],
    ]);
    // One shared row is too little evidence: both milks are kept and the
    // join is reported as uncertain.
    expect(s.rows.where((r) => r == item), hasLength(2));
    expect(s.joins.single.found, isFalse);
  });

  test('photos with no overlap are appended and flagged', () {
    final s = stitchPages([full.sublist(0, 20), full.sublist(40, 60)]);
    expect(s.rows, [...full.sublist(0, 20), ...full.sublist(40, 60)]);
    expect(s.joins.single.found, isFalse);
  });

  test('page numbers per row', () {
    final s = stitchPages([full.sublist(0, 10), full.sublist(8, 20)]);
    expect(s.pageOfRow.where((p) => p == 0), hasLength(10));
    expect(s.pageOfRow.where((p) => p == 1), hasLength(10));
  });
}
