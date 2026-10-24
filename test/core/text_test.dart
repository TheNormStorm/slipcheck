import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/text.dart';

void main() {
  test('plural', () {
    expect(plural(1, 'item'), '1 item');
    expect(plural(0, 'item'), '0 items');
    expect(plural(9, 'item'), '9 items');
  });

  test('sentence case', () {
    expect(sentenceCase('PRIME SHAVED STEAK'), 'Prime shaved steak');
    expect(sentenceCase('MILK 2% 1GAL'), 'Milk 2% 1gal');
    expect(sentenceCase('MILK 2% 1L'), 'Milk 2% 1L');
    expect(sentenceCase('WATER 1.5 L 6PK'), 'Water 1.5 L 6pk');
    expect(sentenceCase('LEMON SQUEEZE'), 'Lemon squeeze');
    expect(sentenceCase('Milk 2% 1L'), 'Milk 2% 1L');
    expect(sentenceCase(' 365 EGGS '), '365 eggs');
    expect(sentenceCase(''), '');
  });
}
