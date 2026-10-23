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
/// The user overlaps consecutive photos, by a few lines or by half a photo.
/// Each new page is aligned against the text so far like a diff: the longest
/// sequence of rows that read (fuzzily) the same in both, in order. Rows are
/// compared fuzzily because OCR reads a line slightly differently in two
/// photos, and the alignment tolerates a line that one photo splits in two
/// ("4235" / "PLANTAINS" against "4235  PLANTAINS  1.50 F").
///
/// An overlap is accepted when at least [minMatches] rows agree (so two
/// identical purchases in a row are not mistaken for one), the agreement
/// reaches the end of the text so far, and starts near the top of the page.
/// Within it, of each pair of matching rows the better reading is kept;
/// unmatched rows after it at the bottom of the earlier photo, and before it
/// at the top of the new one, were cut by the photo edge and are dropped.
StitchResult stitchPages(
  List<List<String>> pages, {
  int minMatches = 2,
  int maxSkippedTop = 5,
  int maxSkippedBottom = 4,
  int searchRows = 150,
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

    final lo = math.max(0, rows.length - searchRows);
    final pairs = _align(rows.sublist(lo), page, rowThreshold);
    final ok = pairs.length >= minMatches &&
        lo + pairs.last.$1 >= rows.length - 1 - maxSkippedBottom &&
        pairs.first.$2 <= maxSkippedTop;

    if (!ok) {
      joins.add(PageJoin(page: p, found: false));
      rows.addAll(page);
      pageOf.addAll(List.filled(page.length, p));
      continue;
    }

    for (final (a, b) in pairs) {
      final i = lo + a;
      if (_quality(page[b]) > _quality(rows[i])) {
        rows[i] = page[b];
        pageOf[i] = p;
      }
    }
    final lastMine = lo + pairs.last.$1, lastTheirs = pairs.last.$2;
    rows.removeRange(lastMine + 1, rows.length);
    pageOf.removeRange(lastMine + 1, pageOf.length);
    final rest = page.sublist(lastTheirs + 1);
    rows.addAll(rest);
    pageOf.addAll(List.filled(rest.length, p));
    joins.add(PageJoin(
      page: p,
      found: true,
      overlapRows: lastTheirs + 1,
      matchingRows: pairs.length,
    ));
  }
  return StitchResult(rows, pageOf, joins);
}

/// Longest common subsequence of fuzzily equal rows, as index pairs.
List<(int, int)> _align(List<String> a, List<String> b, double threshold) {
  final ka = [for (final r in a) _key(r)], kb = [for (final r in b) _key(r)];
  final n = a.length, m = b.length;
  final same = List.generate(
      n, (i) => List.generate(m, (j) => _sameKey(ka[i], kb[j], threshold)));
  final len = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      len[i][j] = same[i][j]
          ? len[i + 1][j + 1] + 1
          : math.max(len[i + 1][j], len[i][j + 1]);
    }
  }
  final pairs = <(int, int)>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (same[i][j] && len[i][j] == len[i + 1][j + 1] + 1) {
      pairs.add((i, j));
      i++;
      j++;
    } else if (len[i + 1][j] >= len[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return pairs;
}

/// How complete a reading of a row looks: one ending in a price beats one
/// without, and a price followed by its tax code beats a bare price. Equal
/// readings keep the earlier photo's: a longer line is not a better one
/// ("1-2  6.46 F" misread against "1-2 8.46 F").
int _quality(String row) {
  if (RegExp(r'\d[.,]\d{2}\s*[A-Z]\s*$').hasMatch(row)) return 2;
  if (RegExp(r'\d[.,]\d{2}\s*$').hasMatch(row)) return 1;
  return 0;
}

String _key(String row) => row.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _sameKey(String ka, String kb, double threshold) {
  if (ka.isEmpty || kb.isEmpty) return false;
  return ka == kb || similarity(ka, kb) >= threshold;
}

/// Finds the order of [pages] (photos of one receipt, in any order) whose
/// overlaps join up best, returned as indexes into [pages].
///
/// Photos picked from a gallery arrive in whatever order the picker gives.
/// Every ordered pair of photos is aligned once, then the chain through all
/// photos with the most joins found, then the most agreeing rows, is chosen
/// (a longest-path search over subsets: fast for the scanner's 8 photos).
/// When the photos do not overlap at all, the given order is kept except
/// that a photo with a TOTAL line goes last. Ties keep the given order.
List<int> bestPageOrder(List<List<String>> pages, {int maxPages = 8}) {
  final n = pages.length;
  final identity = [for (var i = 0; i < n; i++) i];
  if (n < 2 || n > maxPages) return identity;

  // Pair scores: joins found (0/1) and agreeing rows when [b] follows [a].
  final pair = List.generate(n, (_) => List.filled(n, (0, 0)));
  for (var a = 0; a < n; a++) {
    for (var b = 0; b < n; b++) {
      if (a == b) continue;
      final join = stitchPages([pages[a], pages[b]]).joins.single;
      pair[a][b] = join.found ? (1, join.matchingRows) : (0, 0);
    }
  }
  (int, int) add((int, int) x, (int, int) y) => (x.$1 + y.$1, x.$2 + y.$2);
  bool better((int, int) x, (int, int) y) => x.$1 != y.$1 ? x.$1 > y.$1 : x.$2 > y.$2;
  (int, int) score(List<int> order) {
    var s = (0, 0);
    for (var i = 1; i < order.length; i++) {
      s = add(s, pair[order[i - 1]][order[i]]);
    }
    return s;
  }

  // best[mask][last]: best score of a chain using the photos in mask, ending at last.
  final size = 1 << n;
  final best = List.generate(size, (_) => List<(int, int)?>.filled(n, null));
  final prev = List.generate(size, (_) => List.filled(n, -1));
  for (var i = 0; i < n; i++) {
    best[1 << i][i] = (0, 0);
  }
  for (var mask = 1; mask < size; mask++) {
    for (var last = 0; last < n; last++) {
      final here = best[mask][last];
      if (here == null) continue;
      for (var next = 0; next < n; next++) {
        if (mask & (1 << next) != 0) continue;
        final m = mask | (1 << next);
        final s = add(here, pair[last][next]);
        final cur = best[m][next];
        if (cur == null || better(s, cur)) {
          best[m][next] = s;
          prev[m][next] = last;
        }
      }
    }
  }
  var end = 0;
  for (var i = 1; i < n; i++) {
    if (better(best[size - 1][i]!, best[size - 1][end]!)) end = i;
  }
  final top = best[size - 1][end]!;

  if (top.$1 == 0) {
    // No overlaps at all: keep the given order, TOTAL photo(s) last.
    final hasTotal = [for (final page in pages) page.any(_totalRow.hasMatch)];
    return [...identity.where((i) => !hasTotal[i]), ...identity.where((i) => hasTotal[i])];
  }
  if (!better(top, score(identity))) return identity;

  final order = <int>[];
  var mask = size - 1, at = end;
  while (at >= 0) {
    order.add(at);
    final p = prev[mask][at];
    mask &= ~(1 << at);
    at = p;
  }
  return order.reversed.toList();
}

final _totalRow = RegExp(r'^\s*(sub\s*total|total)\b', caseSensitive: false);
