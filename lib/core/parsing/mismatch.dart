/// When a receipt's items do not add up to its own subtotal: the likely
/// culprits, from how OCR goes wrong.
library;

sealed class Fix {
  const Fix();
}

/// Line [index] was probably [cents], not what was read: a digit OCR often
/// confuses (6 and 8, 1 and 7...), or one lost in front ("850.00" for
/// "2,850.00").
class ChangeAmount extends Fix {
  const ChangeAmount(this.index, this.cents);
  final int index, cents;
}

/// Line [index] was probably read twice.
class ReadTwice extends Fix {
  const ReadTwice(this.index);
  final int index;
}

/// A line costing [cents] is probably missing.
class MissingLine extends Fix {
  const MissingLine(this.cents);
  final int cents;
}

/// Digits OCR mixes up on receipt print, both ways round.
const _confusable = {
  '0': '689', '1': '47', '2': '7', '3': '58', '4': '1', '5': '368',
  '6': '058', '7': '12', '8': '03569', '9': '08',
};

/// Up to [max] fixes that each make [lines] (what each line cost, in
/// cents) add up to [expected] exactly, most likely first: a misread
/// amount, then a line read twice, else a missing line.
List<Fix> suggestFixes(List<int> lines, int expected, {int max = 3}) {
  final diff = lines.fold(0, (s, c) => s + c) - expected;
  if (diff == 0) return const [];
  final out = <Fix>[];
  for (final (i, cents) in lines.indexed) {
    if (cents <= 0) continue;
    final digits = cents.toString();
    final candidates = {
      for (var p = 0; p < digits.length; p++)
        for (final alt in (_confusable[digits[p]] ?? '').split(''))
          int.parse(digits.replaceRange(p, p + 1, alt)),
      // A digit lost in front: "850.00" for "2,850.00".
      for (var d = 1; d <= 9; d++) int.parse('$d$digits'),
    };
    for (final c in candidates) {
      if (cents - c == diff) out.add(ChangeAmount(i, c));
    }
  }
  if (diff > 0) {
    // A line costing exactly the difference, preferring one whose amount
    // appears twice (the same item read in two photos).
    final same = [for (final (i, c) in lines.indexed) if (c == diff) i];
    same.sort((a, b) => lines.where((c) => c == lines[b]).length.compareTo(lines.where((c) => c == lines[a]).length));
    out.addAll(same.map(ReadTwice.new));
  } else if (out.isEmpty) {
    out.add(MissingLine(-diff));
  }
  return out.take(max).toList();
}
