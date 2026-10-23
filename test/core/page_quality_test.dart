import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/page_quality.dart';

OcrLine line(double height, {double? confidence}) => OcrLine('MILK 4.99',
    left: 0, top: 0, right: 200, bottom: height, confidence: confidence);

void main() {
  test('clear photo has no problem', () {
    expect(pageProblem([for (var i = 0; i < 10; i++) line(40, confidence: 0.9)]), isNull);
  });
  test('almost no text', () {
    expect(pageProblem([line(40)]), 'No receipt text found');
  });
  test('tiny text', () {
    expect(pageProblem([for (var i = 0; i < 10; i++) line(12)]), contains('small'));
  });
  test('low confidence', () {
    expect(pageProblem([for (var i = 0; i < 10; i++) line(40, confidence: 0.3)]),
        'Blurry or faded');
  });
}
