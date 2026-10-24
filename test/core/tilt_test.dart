import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/ocr/receipt_reader.dart';

import 'distort.dart';

List<OcrLine> load(String name) => [
      for (final l in jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as List)
        OcrLine.fromJson(l as Map<String, dynamic>)
    ];

/// The real 96-line, three-photo Market Basket receipt as if photographed
/// through [warp], read the way the app reads it.
ReadResult readThrough(Warp warp) {
  final pages = [
    for (final name in ['market_basket3_bottom', 'market_basket3_top', 'market_basket3_middle'])
      () {
        final lines = distort(load(name), warp);
        return PageRead(name, groupIntoRows(lines), null, lines: lines);
      }(),
  ];
  return combinePages(pages, const ReceiptParser());
}

void main() {
  // The photos are about 2300 px wide around x = 1150 and 4000 px tall.
  final angles = <String, Warp>{
    'turned 5° clockwise': rotation(5, cx: 1150),
    'turned 12° anticlockwise': rotation(-12, cx: 1150),
    'turned 20° anticlockwise': rotation(-20, cx: 1150),
    'phone tipped towards the top': keystone(0.00008, cx: 1150),
    'phone tipped towards the bottom': keystone(-0.00006, cx: 1150, y0: 4000),
    'receipt curling up at the sides': curl(40, cx: 1150, halfWidth: 600),
    'receipt curling down at the sides': curl(-60, cx: 1150, halfWidth: 600),
    'curling hard': curl(90, cx: 1150, halfWidth: 600),
    'turned and tipped': then(keystone(0.00008, cx: 1150), rotation(6, cx: 1150)),
    'turned and curling': then(curl(50, cx: 1150, halfWidth: 600), rotation(-8, cx: 1150)),
    'turned, tipped and curling': then(
        then(keystone(-0.00007, cx: 1150, y0: 4000), curl(-50, cx: 1150, halfWidth: 600)),
        rotation(-10, cx: 1150)),
  };

  for (final MapEntry(key: how, value: warp) in angles.entries) {
    test('a receipt photographed $how still adds up', () {
      final r = readThrough(warp).parsed;
      expect((r.subtotalCents, r.taxCents, r.totalCents), (36133, 157, 36290));
      expect(r.items, hasLength(64));
      expect(r.itemsSumCents, 36133);
    });
  }

  test('a straight photo keeps the usual grouping', () {
    final result = readThrough((x, y) => (x, y));
    expect(result.regrouping, isNull);
    expect(addsUp(result.parsed), isTrue);
  });

  test('a curling receipt is re-read a different way, and says so', () {
    final result = readThrough(curl(-60, cx: 1150, halfWidth: 600));
    expect(result.regrouping, isNotNull);
  });

  test('without a total to check against, the usual grouping stays', () {
    final lines = distort(load('market_basket_mlkit'), curl(60, cx: 1150, halfWidth: 600));
    final result = combinePages([PageRead('p', groupIntoRows(lines), null, lines: lines)], const ReceiptParser());
    expect(result.regrouping, isNull);
  });

  test('rows followed across the tilt match the usual rows on straight photos', () {
    for (final name in ['market_basket3_top', 'market_basket3_middle', 'market_basket_part2', 'market_basket_part3']) {
      expect(groupIntoRowsByLinking(load(name)), groupIntoRows(load(name)), reason: name);
    }
  });
}
