import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/matching/product_matcher.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/ocr/read_pipeline.dart';
import 'package:slipcheck/ocr/receipt_reader.dart';

const top = [
  'FRESHMART',
  '2026-10-18 14:32',
  'MILK 2% 1L            4.99',
  'BREAD WW 675G         3.49',
  'COKE 355ML            3.98',
  'EGGS 12               5.49',
];
const bottom = [
  'COKE 355ML            3.98',
  'EGGS 12               5.49',
  'CHEDDAR 400G          7.99',
  'SUBTOTAL             25.94',
  'TOTAL                25.94',
  'CARD INFORMATION',
  'VISA ************4417',
  'Approval 123456',
];

void main() {
  late List<ReadProgress> snapshots;
  late List<double> fractions;
  late List<String> moods;

  Future<ReadResult> run(List<List<String>> photos, {bool scanned = true}) {
    snapshots = [];
    fractions = [];
    moods = [];
    return ReadPipeline(
      readPage: (path) async {
        final rows = photos[int.parse(path)];
        return PageRead(path, rows, null, lineCount: rows.length + 1);
      },
      combine: (pages) => combinePages(pages, const ReceiptParser()),
      match: (parsed) async => [
        for (final item in parsed.items)
          item.rawText.startsWith('MILK')
              ? const MatchResult(MatchKind.exact,
                  product: ProductCandidate(id: 1, key: 'milk 2% 1l', displayName: 'Milk 2% 1L'))
              : null,
      ],
    ).run([for (var i = 0; i < photos.length; i++) '$i'], scanned: scanned, onUpdate: (p) {
      snapshots.add(p);
      fractions.add(p.fraction);
      moods.add(p.mood);
    });
  }

  test('reports every step with real counts, in order', () async {
    final result = await run([top, bottom]);
    final p = snapshots.last;
    expect(p.finished, isTrue);
    expect(p.fraction, 1);
    expect(p.done, containsAll(ReadStep.values));
    expect(p.counts[ReadStep.edges], '2 photos');
    expect(p.counts[ReadStep.text], '16 lines');
    expect(p.counts[ReadStep.join], '2 cut');
    expect(p.counts[ReadStep.items], '5 items');
    expect(p.counts[ReadStep.card], 'hidden');
    expect(p.counts[ReadStep.match], '1 known');
    expect(p.counts[ReadStep.total], 'matches');
    expect(p.totalMatches, isTrue);
    expect(p.mood, 'All good!');
    expect(result.parsed.items, hasLength(5));
  });

  test('progress only goes forward, and the mood line never blanks between steps', () async {
    await run([top, bottom]);
    expect(moods.skip(1), isNot(contains('Getting ready…')));
    for (var i = 1; i < fractions.length; i++) {
      expect(fractions[i], greaterThanOrEqualTo(fractions[i - 1]));
    }
    expect(fractions.first, 0);
  });

  test('the log never shows the card section', () async {
    await run([top, bottom]);
    final log = snapshots.last.log.map((l) => l.text).join('\n');
    expect(log, isNot(contains('4417')));
    expect(log, isNot(contains('Approval')));
    expect(log, isNot(contains('CARD INFORMATION')));
    expect(snapshots.last.log.where((l) => l.kind == LogKind.card), isNotEmpty);
  });

  test('gallery photos skip finding edges', () async {
    await run([top], scanned: false);
    final p = snapshots.last;
    expect(p.steps, isNot(contains(ReadStep.edges)));
    expect(p.counts[ReadStep.join], '1 photo');
    expect(p.fraction, 1);
  });

  test('a total that does not match is reported', () async {
    await run([
      [...top, 'TOTAL 1.00']
    ]);
    final p = snapshots.last;
    expect(p.totalMatches, isFalse);
    expect(p.counts[ReadStep.total], startsWith('off '));
    expect(p.mood, isNot('All good!'));
  });
}
