import 'dart:math' as math;

import '../matching/product_matcher.dart' show similarity;

/// How one page was joined onto the pages before it.
class PageJoin {
  const PageJoin({
    required this.page,
    required this.found,
    this.overlapRows = 0,
    this.matchingRows = 0,
  });

  /// Index of the page that was appended (1 for the second photo).
  final int page;

  /// False when no overlap was found and the page was simply appended;
  /// lines may then be missing or doubled at the join.
  final bool found;
  final int overlapRows;

  /// Rows inside the overlap that agreed between the two photos.
  final int matchingRows;
}

class StitchResult {
  StitchResult(this.rows, this.pageOfRow, this.joins);

  final List<String> rows;

  /// Which page each row came from, for pointing the user at a photo.
  final List<int> pageOfRow;
  final List<PageJoin> joins;

  int get overlapRowsRemoved => joins.fold(0, (s, j) => s + j.overlapRows);
}

/// Joins the text rows of several photos of one long receipt.
///
/// The user overlaps consecutive photos by a few lines. For each new page the
/// best alignment between the end of the text so far and the start of the
/// page is searched for; the overlapping rows are kept once. Rows are
/// compared fuzzily because OCR reads the same line slightly differently in
/// two photos, and at least [minMatches] rows must agree so that two
/// identical purchases in a row are not mistaken for an overlap.
StitchResult stitchPages(
  List<List<String>> pages, {
  int minMatches = 2,
  int maxOverlap = 15,
  int maxSkippedTop = 3,
  double rowThreshold = 0.8,
}) {
  final rows = <String>[];
  final pageOf = <int>[];
  final joins = <PageJoin>[];

  for (final (p, page) in pages.indexed) {
    if (p == 0 || rows.isEmpty) {
      rows.addAll(page);
      pageOf.addAll(List.filled(page.length, p));
      continue;
    }

    _Alignment? best;
    // i: where the overlap starts in the text so far.
    // j: rows skipped at the top of the new page (a line cut by the photo edge).
    for (var i = math.max(0, rows.length - maxOverlap); i < rows.length; i++) {
      for (var j = 0; j <= maxSkippedTop && j < page.length; j++) {
        final window = math.min(rows.length - i, page.length - j);
        var matches = 0;
        for (var t = 0; t < window; t++) {
          if (_sameRow(rows[i + t], page[j + t], rowThreshold)) matches++;
        }
        if (matches < minMatches || matches / window < 0.6) continue;
        final score = matches - 0.5 * (window - matches) - 0.1 * j;
        if (best == null || score > best.score) {
          best = _Alignment(i, j, window, matches, score);
        }
      }
    }

    if (best == null) {
      joins.add(PageJoin(page: p, found: false));
      rows.addAll(page);
      pageOf.addAll(List.filled(page.length, p));
      continue;
    }

    // Rows inside the overlap that disagree: one photo cut the line at its
    // edge, so keep the longer reading.
    for (var t = 0; t < best.window; t++) {
      final mine = rows[best.i + t], theirs = page[best.j + t];
      if (!_sameRow(mine, theirs, rowThreshold) && theirs.length > mine.length) {
        rows[best.i + t] = theirs;
        pageOf[best.i + t] = p;
      }
    }
    final rest = page.sublist(best.j + best.window);
    // Text left over after the window means the earlier page ended before the
    // overlap did; nothing to add from it.
    rows.addAll(rest);
    pageOf.addAll(List.filled(rest.length, p));
    joins.add(PageJoin(
        page: p, found: true, overlapRows: best.window, matchingRows: best.matches));
  }
  return StitchResult(rows, pageOf, joins);
}

class _Alignment {
  _Alignment(this.i, this.j, this.window, this.matches, this.score);
  final int i, j, window, matches;
  final double score;
}

String _key(String row) => row.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _sameRow(String a, String b, double threshold) {
  final ka = _key(a), kb = _key(b);
  if (ka.isEmpty || kb.isEmpty) return false;
  return ka == kb || similarity(ka, kb) >= threshold;
}

/// Finds the order of [pages] (photos of one receipt, in any order) whose
/// overlaps join up best, returned as indexes into [pages].
///
/// Photos picked from a gallery arrive in whatever order the picker gives,
/// so every order is tried for up to [maxPages] photos. An order wins with
/// more joins found, then more agreeing rows, then with no TOTAL line before
/// the last photo (what decides it when the photos do not overlap at all);
/// ties keep the given order.
List<int> bestPageOrder(List<List<String>> pages, {int maxPages = 5}) {
  final identity = [for (var i = 0; i < pages.length; i++) i];
  if (pages.length < 2 || pages.length > maxPages) return identity;

  final hasTotal = [for (final page in pages) page.any(_totalRow.hasMatch)];

  (int, int, int) score(List<int> order) {
    final joins = stitchPages([for (final i in order) pages[i]]).joins;
    return (
      joins.where((j) => j.found).length,
      joins.fold(0, (s, j) => s + j.matchingRows),
      -[for (final i in order.sublist(0, order.length - 1)) if (hasTotal[i]) i].length,
    );
  }

  bool better((int, int, int) a, (int, int, int) b) =>
      a.$1 != b.$1 ? a.$1 > b.$1 : a.$2 != b.$2 ? a.$2 > b.$2 : a.$3 > b.$3;

  var best = identity;
  var bestScore = score(identity);
  for (final order in _permutations(identity)) {
    final s = score(order);
    if (better(s, bestScore)) {
      best = order;
      bestScore = s;
    }
  }
  return best;
}

final _totalRow = RegExp(r'^\s*(sub\s*total|total)\b', caseSensitive: false);

Iterable<List<int>> _permutations(List<int> items) sync* {
  if (items.length <= 1) {
    yield items;
    return;
  }
  for (var i = 0; i < items.length; i++) {
    final rest = [...items]..removeAt(i);
    for (final p in _permutations(rest)) {
      yield [items[i], ...p];
    }
  }
}
