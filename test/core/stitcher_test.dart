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

  test('photos picked out of order are put back in receipt order', () {
    final top = full.sublist(0, 30), middle = full.sublist(27, 55), bottom = full.sublist(52);
    expect(bestPageOrder([middle, top, bottom]), [1, 0, 2]);
    expect(bestPageOrder([bottom, middle, top]), [2, 1, 0]);
    expect(bestPageOrder([top, middle, bottom]), [0, 1, 2]);
  });

  test('order is left alone when no overlaps are found', () {
    expect(bestPageOrder([full.sublist(40, 60), full.sublist(0, 20)]), [0, 1]);
  });

  test('real photos: the Market Basket receipt in three overlapping photos', () {
    List<String> rowsOf(String name) {
      final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List;
      return groupIntoRows([for (final l in json) OcrLine.fromJson(l)]);
    }

    // Given in the wrong order, as a gallery picker might.
    final pages = [rowsOf('market_basket_part2'), rowsOf('market_basket_part3'),
        rowsOf('market_basket_part1')];
    final order = bestPageOrder(pages);
    expect(order, [2, 0, 1]);

    final stitched = stitchPages([for (final i in order) pages[i]]);
    expect(stitched.joins.every((j) => j.found), isTrue);
    final fromPhotos = const ReceiptParser().parse(stitched.rows);
    final fromOnePhoto = const ReceiptParser().parse(full);
    expect(fromPhotos.items.map((i) => i.lineTotalCents),
        fromOnePhoto.items.map((i) => i.lineTotalCents));
    expect(fromPhotos.items.map((i) => i.quantity),
        fromOnePhoto.items.map((i) => i.quantity));
    expect(fromPhotos.storeName, 'MARKET BASKET');
  });

  test('real photos: 96-item receipt in three heavily overlapping photos', () {
    List<String> rowsOf(String name) {
      final json = jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List;
      return groupIntoRows([for (final l in json) OcrLine.fromJson(l)]);
    }

    // Shuffled. They overlap by 30-60 lines, and the photos split some lines
    // differently ("4235" / "PLANTAINS" against "4235  PLANTAINS  1.50 F").
    final pages = [rowsOf('market_basket3_bottom'), rowsOf('market_basket3_top'),
        rowsOf('market_basket3_middle')];
    final order = bestPageOrder(pages);
    expect(order, [1, 2, 0]);

    final stitched = stitchPages([for (final i in order) pages[i]]);
    expect(stitched.joins.every((j) => j.found), isTrue);
    final r = const ReceiptParser().parse(stitched.rows);
    expect((r.subtotalCents, r.taxCents, r.totalCents), (36133, 157, 36290));
    expect(r.items, hasLength(64));
    // Every line read: the items add up to the printed subtotal exactly.
    expect(r.itemsSumCents, 36133);
    // Where photos disagree, the better reading wins (the bottom photo read
    // these as 6.46 and 1.55).
    expect(r.items.where((i) => i.rawText.startsWith('93% X-LEAN')).map((i) => i.lineTotalCents),
        [846, 755]);
  });
}
