const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _iso = RegExp(r'\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b');
final _numeric = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})\b');
final _dayMonthName = RegExp(
    r'\b(\d{1,2})[\s-]*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?[\s,-]*(\d{4}|\d{2})\b',
    caseSensitive: false);
final _monthNameDay = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*(\d{1,2}),?\s*(\d{4}|\d{2})\b',
    caseSensitive: false);

/// Finds the first plausible purchase date in [rows].
///
/// [dayFirst] decides ambiguous numeric dates (03/04/2026); when one part is
/// above 12 the order is unambiguous and [dayFirst] is ignored.
DateTime? findDate(List<String> rows, {bool dayFirst = true}) {
  for (final row in rows) {
    final d = _parseRow(row, dayFirst);
    if (d != null) return d;
  }
  return null;
}

DateTime? _parseRow(String row, bool dayFirst) {
  var m = _iso.firstMatch(row);
  if (m != null) {
    return _make(_i(m[1]), _i(m[2]), _i(m[3]));
  }
  m = _dayMonthName.firstMatch(row);
  if (m != null) {
    return _make(_year(m[3]!), _months[m[2]!.toLowerCase()]!, _i(m[1]));
  }
  m = _monthNameDay.firstMatch(row);
  if (m != null) {
    return _make(_year(m[3]!), _months[m[1]!.toLowerCase()]!, _i(m[2]));
  }
  m = _numeric.firstMatch(row);
  if (m != null) {
    final a = _i(m[1]), b = _i(m[2]), y = _year(m[3]!);
    final bool dayIsFirst;
    if (a > 12) {
      dayIsFirst = true;
    } else if (b > 12) {
      dayIsFirst = false;
    } else {
      dayIsFirst = dayFirst;
    }
    return dayIsFirst ? _make(y, b, a) : _make(y, a, b);
  }
  return null;
}

int _i(String? s) => int.parse(s!);
int _year(String s) => s.length == 2 ? 2000 + int.parse(s) : int.parse(s);

DateTime? _make(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) return null;
  final date = DateTime(y, m, d);
  // Reject rollovers such as 31 February.
  return date.month == m ? date : null;
}
