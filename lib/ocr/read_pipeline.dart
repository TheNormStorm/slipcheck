import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../core/parsing/receipt_parser.dart';
import '../core/parsing/redaction.dart';
import '../core/text.dart';
import 'receipt_reader.dart';

/// The steps of reading a receipt, as the Reading screen lists them.
enum ReadStep {
  edges('Finding edges', 'Lining up the edges…'),
  text('Reading text', 'Squinting at the fine print…'),
  straighten('Straightening', 'Straightening things out…'),
  join('Joining photos', 'Stitching photos together…'),
  items('Finding items', 'Spotting items…'),
  card('Hiding card info', 'Hiding your card details…'),
  match('Matching items', 'Remembering your usuals…'),
  total('Checking total', 'Adding it up…');

  const ReadStep(this.label, this.mood);
  final String label;

  /// The line under the percentage while this step runs.
  final String mood;
}

enum LogKind { text, stitch, card, match, guess, warn }

/// One line of the Details log. Text comes from rows with the card section
/// already removed, so card details never reach the screen.
class LogLine {
  const LogLine(this.kind, this.text);
  final LogKind kind;
  final String text;
}

/// Where reading has got to. Updated in place and handed to the listener
/// after every change.
class ReadProgress {
  ReadProgress({required this.photoCount, required this.scanned})
      : pages = List.filled(photoCount, null, growable: true);

  final int photoCount;

  /// Photos from the document scanner, whose edges it already found.
  final bool scanned;

  List<ReadStep> get steps => [
        if (scanned) ReadStep.edges,
        ...ReadStep.values.where((s) => s != ReadStep.edges),
      ];

  ReadStep? running;

  /// The step that ran last, so the mood line holds between steps.
  ReadStep? last;
  final done = <ReadStep>{};

  /// The number shown at the right of a step ("26 lines", "2 cut").
  final counts = <ReadStep, String>{};
  final log = <LogLine>[];

  /// The photos read so far: in capture order until they are joined, then
  /// in receipt order. Null for a photo not read yet.
  List<PageRead?> pages;

  /// Set once the photos are joined and parsed.
  ReadResult? result;

  /// The photo being read, as an index into [pages] before joining.
  int? readingPhoto;

  int photosRead = 0;

  /// The receipt's items add up to what it says (null: nothing to check).
  bool? totalMatches;

  bool get finished => running == null && done.contains(ReadStep.total);

  /// Share of the work finished: each photo read is one unit, every other
  /// step one more. Never driven by a clock.
  double get fraction {
    final total = steps.length - 1 + photoCount;
    final finishedSteps = done.where((s) => s != ReadStep.text).length;
    return (finishedSteps + photosRead) / total;
  }

  String get mood => finished
      ? (totalMatches == false ? 'Done. One thing to check.' : 'All good!')
      : (running ?? last)?.mood ?? 'Getting ready…';
}

/// Runs the reading steps for photos, reporting each one as it really
/// happens. OCR, joining and matching are passed in, so the pipeline can run
/// in tests without ML Kit.
class ReadPipeline {
  ReadPipeline({
    required this.readPage,
    required this.combine,
    required this.match,
    this.pause,
  });

  final Future<PageRead> Function(String path) readPage;
  final ReadResult Function(List<PageRead> pages) combine;

  /// Looks up each parsed item among the known products.
  final Future<List<MatchResult?>> Function(ParsedReceipt parsed) match;

  /// Awaited after each step so it can be seen; not part of the progress.
  final Future<void> Function()? pause;

  Future<ReadResult> run(
    List<String> paths, {
    required bool scanned,
    required void Function(ReadProgress) onUpdate,
  }) async {
    final p = ReadProgress(photoCount: paths.length, scanned: scanned);

    void start(ReadStep step) {
      p.running = p.last = step;
      onUpdate(p);
    }

    Future<void> finish(ReadStep step, [String? count]) async {
      p.done.add(step);
      if (count != null) p.counts[step] = count;
      p.running = null;
      onUpdate(p);
      await pause?.call();
    }

    if (scanned) {
      start(ReadStep.edges);
      await finish(ReadStep.edges, plural(paths.length, 'photo'));
    }

    start(ReadStep.text);
    var lines = 0;
    for (final (i, path) in paths.indexed) {
      p.readingPhoto = i;
      onUpdate(p);
      final page = await readPage(path);
      p.pages[i] = page;
      p.photosRead++;
      lines += page.lineCount;
      p.counts[ReadStep.text] = plural(lines, 'line');
      final shown = withoutPaymentSection(page.rows);
      p.log.add(LogLine(LogKind.stitch, 'photo ${i + 1}: ${plural(page.lineCount, 'line')}'));
      p.log.addAll([for (final row in shown) LogLine(LogKind.text, row)]);
      if (shown.length < page.rows.length) p.log.add(const LogLine(LogKind.card, '·· card hidden ··'));
      if (page.problem != null) p.log.add(LogLine(LogKind.warn, 'photo ${i + 1}: ${page.problem}'));
      onUpdate(p);
    }
    p.readingPhoto = null;
    await finish(ReadStep.text);

    // Rows were grouped and de-skewed while each photo was read.
    start(ReadStep.straighten);
    final rows = p.pages.fold(0, (n, page) => n + page!.rows.length);
    await finish(ReadStep.straighten, plural(rows, 'row'));

    start(ReadStep.join);
    final result = combine([for (final page in p.pages) page!]);
    p.result = result;
    p.pages = [...result.pages];
    final stitch = result.stitch;
    if (result.regrouping case final how?) {
      p.log.add(LogLine(LogKind.stitch, 'photo at an angle: re-read with $how'));
    }
    for (final join in stitch.joins) {
      p.log.add(join.found
          ? LogLine(LogKind.stitch, 'join ${join.page}+${join.page + 1}: ${join.matchingRows} rows agree')
          : LogLine(LogKind.warn, 'join ${join.page}+${join.page + 1}: no overlap found'));
    }
    await finish(
      ReadStep.join,
      paths.length == 1
          ? '1 photo'
          : stitch.joins.any((j) => !j.found)
              ? 'gap'
              : '${stitch.overlapRowsRemoved} cut',
    );

    start(ReadStep.items);
    final parsed = result.parsed;
    await finish(ReadStep.items, plural(parsed.items.length, 'item'));

    start(ReadStep.card);
    final cut = stitch.rows.length - withoutPaymentSection(stitch.rows).length;
    if (cut > 0) p.log.add(LogLine(LogKind.card, '${plural(cut, 'card line')} removed'));
    await finish(ReadStep.card, cut > 0 ? 'hidden' : 'none');

    start(ReadStep.match);
    final matches = await match(parsed);
    var known = 0;
    for (final (i, m) in matches.indexed) {
      final name = parsed.items[i].rawText;
      if (m == null || m.kind == MatchKind.none) continue;
      if (m.isConfident) {
        known++;
        p.log.add(LogLine(LogKind.match, '$name → ${m.product!.displayName}'));
      } else {
        p.log.add(LogLine(LogKind.guess, '$name ≈ ${m.product!.displayName}?'));
      }
    }
    await finish(ReadStep.match, '$known known');

    start(ReadStep.total);
    final expected = parsed.subtotalCents ??
        (parsed.totalCents == null ? null : parsed.totalCents! - (parsed.taxCents ?? 0));
    final sum = parsed.itemsSumCents;
    p.totalMatches = expected == null ? null : expected == sum;
    final String count;
    if (expected == null) {
      count = 'no total';
      p.log.add(const LogLine(LogKind.warn, 'no TOTAL line found'));
    } else if (expected == sum) {
      count = 'matches';
      p.log.add(LogLine(LogKind.match, 'items ${formatCents(sum)} = receipt ${formatCents(expected)}'));
    } else {
      count = 'off ${formatCents((sum - expected).abs())}';
      p.log.add(LogLine(LogKind.warn, 'items ${formatCents(sum)} ≠ receipt ${formatCents(expected)}'));
    }
    await finish(ReadStep.total, count);
    return result;
  }
}
