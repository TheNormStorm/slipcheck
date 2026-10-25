import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/currency.dart';
import 'package:slipcheck/core/money.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/ocr/receipt_reader.dart';

import '../core/distort.dart';

/// What is printed on a receipt: the truth a reading is scored against.
class Printed {
  const Printed(this.name,
      {required this.lines, required this.itemsCents, required this.totalCents, required this.currency});
  final String name;

  /// What the money is in.
  final String currency;

  /// Item lines on the receipt (a line of 3 @ 2.99 is one line).
  final int lines;

  /// What the items come to (the printed subtotal, or total less tax).
  final int itemsCents;
  final int totalCents;
}

/// One way a receipt was read: the photos as ML Kit read them (`.json`, one
/// per photo, run through grouping, joining and parsing exactly as the
/// app does), or a phone's "Text as read" (`.txt`, already in rows).
class Reading {
  const Reading(this.receipt, this.how, this.files, {this.partial = false, this.warp});
  final Printed receipt;
  final String how;
  final List<String> files;

  /// The photos stop before the total, so the reading cannot be checked
  /// against it.
  final bool partial;

  /// The photos as if taken at an angle (see test/core/distort.dart).
  final Warp? warp;

  String get id => '${files.join('+')}${warp == null ? '' : ' / $how'}';

  /// The receipt as read, and its rows joined across photos.
  (ParsedReceipt, List<String>) read() {
    if (files.first.endsWith('.txt')) {
      final rows = File('test/fixtures/${files.single}').readAsLinesSync();
      return (const ReceiptParser().parse(rows), rows);
    }
    final pages = [
      for (final f in files)
        () {
          var lines = [
            for (final l in jsonDecode(File('test/fixtures/$f').readAsStringSync()) as List)
              OcrLine.fromJson(l as Map<String, dynamic>)
          ];
          if (warp != null) lines = distort(lines, warp!);
          return PageRead(f, groupIntoRows(lines), null, lines: lines);
        }(),
    ];
    final result = combinePages(pages, const ReceiptParser());
    return (result.parsed, result.stitch.rows);
  }
}

const marketBasket =
    Printed('Market Basket, Oct 22', lines: 64, itemsCents: 36133, totalCents: 36290, currency: 'USD');
const cmMeats = Printed('C&M Meats, Oct 24', lines: 3, itemsCents: 546000, totalCents: 546000, currency: 'JMD');
const jmSupermarket = Printed('Jamaican supermarket, GCT at 15% and 25%',
    lines: 53, itemsCents: 1803888, totalCents: 2009586, currency: 'JMD');
const freshMart =
    Printed('FreshMart (typed example)', lines: 6, itemsCents: 2370, totalCents: 2435, currency: 'CAD');
const valueStore =
    Printed('Value Store (typed example)', lines: 2, itemsCents: 971, totalCents: 971, currency: 'USD');
const cornerShop = Printed('Corner shop, day-first date (typed example)',
    lines: 3, itemsCents: 645, totalCents: 645, currency: 'GBP');

/// Every receipt reading we have. Add a line here for each new receipt that
/// reads badly (its photos' JSON from Send reading details, or its Text as
/// read typed out), with what the paper receipt says.
final _mb3 = ['market_basket3_top.json', 'market_basket3_middle.json', 'market_basket3_bottom.json'];

final readings = [
  Reading(marketBasket, '3 photos, Android emulator',
      ['market_basket3_top.json', 'market_basket3_middle.json', 'market_basket3_bottom.json']),
  Reading(marketBasket, '3 photos given bottom first',
      ['market_basket3_bottom.json', 'market_basket3_top.json', 'market_basket3_middle.json']),
  Reading(marketBasket, '3 photos, phone turned 12°', _mb3, warp: rotation(-12, cx: 1150)),
  Reading(marketBasket, '3 photos, phone tipped towards the top', _mb3, warp: keystone(0.00008, cx: 1150)),
  Reading(marketBasket, '3 photos, receipt curling', _mb3, warp: curl(-60, cx: 1150, halfWidth: 600)),
  Reading(marketBasket, '3 photos, turned, tipped and curling', _mb3,
      warp: then(then(keystone(-0.00007, cx: 1150, y0: 4000), curl(-50, cx: 1150, halfWidth: 600)),
          rotation(-10, cx: 1150))),
  Reading(marketBasket, 'iPhone, Text as read', ['market_basket3_iphone.txt']),
  Reading(marketBasket, '2 faded photos, not overlapping', ['market_basket2_bottom.json', 'market_basket2_top.json']),
  Reading(marketBasket, 'top half, 1 photo', ['market_basket_mlkit.json'], partial: true),
  Reading(marketBasket, 'top half, 3 photos',
      ['market_basket_part1.json', 'market_basket_part2.json', 'market_basket_part3.json'], partial: true),
  Reading(cmMeats, '1 photo, Android emulator', ['cm_meats_mlkit.json']),
  Reading(cmMeats, 'Android phone, Text as read', ['cm_meats_phone.txt']),
  Reading(cmMeats, 'iPhone, Text as read', ['cm_meats_iphone.txt']),
  Reading(jmSupermarket, 'Android phone, Text as read (3 photos)', ['jm_supermarket_phone.txt']),
  Reading(freshMart, 'typed', ['grocery_basic.txt']),
  Reading(freshMart, 'as ML Kit spaces it', ['mlkit_grocery_basic.txt']),
  Reading(valueStore, 'typed', ['qty_after_item.txt']),
  Reading(cornerShop, 'typed', ['dayfirst_comma.txt']),
];

enum Grade { exact, off, unchecked }

class Score {
  Score(this.reading, (ParsedReceipt, List<String>) read)
      : parsed = read.$1,
        currency = detectCurrency(read.$2);
  final Reading reading;
  final ParsedReceipt parsed;

  /// The currency worked out from the receipt; null when it doesn't say
  /// (the app then uses the store's or your usual one).
  final String? currency;

  String get currencyResult => currency == null
      ? '– (${reading.receipt.currency} not printed)'
      : currency == reading.receipt.currency
          ? '✓ $currency'
          : '✗ $currency, not ${reading.receipt.currency}';

  String get checks {
    final tax = parsed.taxCheck.agrees;
    final count = parsed.countCheck;
    return [
      tax == null ? 'tax –' : 'tax ${tax ? '✓' : '✗'}',
      count == null ? 'count –' : 'count ${count ? '✓' : '✗'}',
    ].join(', ');
  }

  int get lineGap => reading.receipt.lines - parsed.items.length;
  int get centsGap => parsed.itemsSumCents - reading.receipt.itemsCents;

  Grade get grade {
    if (reading.partial) return Grade.unchecked;
    final ok = lineGap == 0 && centsGap == 0 && parsed.totalCents == reading.receipt.totalCents;
    return ok ? Grade.exact : Grade.off;
  }

  String get result => switch (grade) {
        Grade.unchecked => 'not checked: photos stop before the total',
        Grade.exact => parsed.corrections.isEmpty
            ? 'exact'
            : 'exact (${parsed.corrections.length} price${parsed.corrections.length == 1 ? '' : 's'} fixed by the check)',
        Grade.off => [
            if (centsGap != 0) 'off by ${formatCents(centsGap.abs())}',
            if (lineGap > 0) '$lineGap line${lineGap == 1 ? '' : 's'} missing',
            if (lineGap < 0) '${-lineGap} extra line${lineGap == -1 ? '' : 's'}',
            if (parsed.totalCents != reading.receipt.totalCents) 'total not read',
          ].join(', '),
      };
}

final _baseline = File('test/scorecard/baseline.json');
final _report = File('docs/scorecard.md');

void main() {
  final scores = [for (final r in readings) Score(r, r.read())];

  String report() {
    final checked = scores.where((s) => s.grade != Grade.unchecked).toList();
    final exact = checked.where((s) => s.grade == Grade.exact).length;
    final b = StringBuffer()
      ..writeln('# Receipt scorecard')
      ..writeln()
      ..writeln('Every receipt reading we have, read the way the app reads it, against what the')
      ..writeln('paper receipt says. Regenerate with `UPDATE_SCORECARD=1 flutter test test/scorecard`.')
      ..writeln()
      ..writeln('**$exact of ${checked.length} readings exact.** Currency wrong: '
          '${scores.where((s) => s.currency != null && s.currency != s.reading.receipt.currency).length}. '
          'Tax or item-count check failing: ${scores.where((s) => s.parsed.taxCheck.agrees == false || s.parsed.countCheck == false).length}.')
      ..writeln()
      ..writeln('"Other checks": the printed tax rate of the taxed lines gives the printed tax; the')
      ..writeln('quantities match the printed item count. "–" means the receipt (or what was kept')
      ..writeln('of it: the card section, where some tills print the count, is cut) gives nothing to check.')
      ..writeln()
      ..writeln('| Receipt | How it was read | Lines read | Items come to | Printed | Result | Currency | Other checks |')
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final s in scores) {
      final r = s.reading;
      b.writeln('| ${r.receipt.name} | ${r.how} | ${s.parsed.items.length} of ${r.receipt.lines} | '
          '${formatCents(s.parsed.itemsSumCents)} | ${formatCents(r.receipt.itemsCents)} | '
          '${s.grade == Grade.exact ? '✓ ' : s.grade == Grade.off ? '✗ ' : ''}${s.result} | ${s.currencyResult} | ${s.checks} |');
    }
    return b.toString();
  }

  test('scorecard', () {
    final text = report();
    // ignore: avoid_print
    print(text);
    // Recorded per reading: the grade, the currency, and each check.
    final now = {
      for (final s in scores)
        s.reading.id: '${s.grade.name} ${s.currency ?? '-'} ${s.parsed.taxCheck.agrees} ${s.parsed.countCheck}',
    };
    if (Platform.environment['UPDATE_SCORECARD'] == '1' || !_baseline.existsSync()) {
      _baseline.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(now)}\n');
      _report.writeAsStringSync(text);
      return;
    }
    final before = (jsonDecode(_baseline.readAsStringSync()) as Map).cast<String, String>();
    final worse = [
      for (final s in scores)
        if (_worse(before[s.reading.id], now[s.reading.id]!))
          '${s.reading.receipt.name}, ${s.reading.how}: ${s.result}; ${s.currencyResult}; ${s.checks}',
    ];
    expect(worse, isEmpty, reason: 'These readings got worse.');
    final better = [
      for (final s in scores)
        if (before[s.reading.id] != now[s.reading.id] && !_worse(before[s.reading.id], now[s.reading.id]!)) s.reading.id,
    ];
    if (better.isNotEmpty) {
      // ignore: avoid_print
      print('Better: ${better.join(', ')}. Run UPDATE_SCORECARD=1 flutter test test/scorecard to record it.');
    }
  });
}

/// Whether a reading's record got worse: exact → not, a currency it found
/// lost or changed, or a check that passed now failing or silent.
bool _worse(String? before, String now) {
  if (before == null) return false;
  final b = before.split(' '), n = now.split(' ');
  if (b.length != 4) return b.first == Grade.exact.name && n.first != Grade.exact.name;
  if (b[0] == Grade.exact.name && n[0] != Grade.exact.name) return true;
  if (b[1] != '-' && b[1] != n[1]) return true;
  for (final i in [2, 3]) {
    if (b[i] == 'true' && n[i] != 'true') return true;
  }
  return false;
}
