import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/mismatch.dart';

void main() {
  test('adds up: nothing to suggest', () {
    expect(suggestFixes([100, 200], 300), isEmpty);
  });

  test('a digit misread: 6.46 that was 8.46', () {
    final fixes = suggestFixes([846, 646, 299], 846 + 846 + 299);
    expect(fixes.first, isA<ChangeAmount>());
    final f = fixes.first as ChangeAmount;
    expect((f.index, f.cents), (1, 846));
  });

  test('a digit lost in front: 850.00 for 2,850.00', () {
    final fixes = suggestFixes([85000, 96000, 165000], 546000);
    expect(fixes.whereType<ChangeAmount>().map((f) => (f.index, f.cents)), contains((0, 285000)));
  });

  test('a line read twice', () {
    final fixes = suggestFixes([399, 249, 399], 648);
    expect(fixes.whereType<ReadTwice>().map((f) => f.index), containsAll([0, 2]));
  });

  test('short of the total: a line may be missing', () {
    final fixes = suggestFixes([399, 249], 1047);
    expect(fixes.single, isA<MissingLine>());
    expect((fixes.single as MissingLine).cents, 399);
  });

  test("repeated amounts aren't suspects; short means a line may be missing", () {
    // Five buns at 156.53 and a phone card lost under a signature.
    final lines = [15653, 15653, 15653, 15653, 15653, 58000, 10610, 24750, 19264, 50000];
    final fixes = suggestFixes(lines, lines.fold(0, (s, c) => s + c) + 100000);
    expect(fixes.whereType<ChangeAmount>(), isEmpty); // not "580.00 may be 1,580.00"
    expect(fixes.last, isA<MissingLine>());
    expect((fixes.last as MissingLine).cents, 100000);
  });

  test('every suggestion makes it add up', () {
    final lines = [129, 999, 1648, 349, 2050];
    const expected = 129 + 999 + 1048 + 349 + 2050;
    for (final f in suggestFixes(lines, expected)) {
      final fixed = [...lines];
      switch (f) {
        case ChangeAmount(:final index, :final cents):
          fixed[index] = cents;
        case ReadTwice(:final index):
          fixed.removeAt(index);
        case MissingLine(:final cents):
          fixed.add(cents);
      }
      expect(fixed.fold(0, (s, c) => s + c), expected, reason: f.toString());
    }
  });
}
