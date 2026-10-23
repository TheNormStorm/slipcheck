import 'package:flutter_test/flutter_test.dart';
import 'package:slipcheck/core/parsing/ocr_line.dart';
import 'package:slipcheck/core/parsing/receipt_parser.dart';
import 'package:slipcheck/core/parsing/redaction.dart';

void main() {
  // The end of a Market Basket receipt, card details made up.
  const tail = [
    'TZERO PLAIN  10.98 F', '2 @ 5.49', 'SUBTOTAL  361.33', 'MA 6.25% Sales Tax  1.57',
    'TOTAL  362.90', 'Credit  362.90', 'TOTAL TENDERED  362.90', 'Change  0.00',
    'CARD INFORMATION:', 'Card Type:  Maste', 'Account:  1111', 'Amount:  USD \$362.90',
    'Approval #:  999999', 'Entry:  Contactless', 'Reference #:  123456789012',
    'AID:  A0000000000000', 'TVR:  0000000000', 'MID:  *0000', 'Card Name:  DEBIT',
  ];

  test('cuts at the card section, keeping totals', () {
    final kept = withoutPaymentSection(tail);
    expect(kept.last, 'Change  0.00');
    expect(kept.any((r) => r.contains('1111') || r.contains('999999')), isFalse);
    final r = const ReceiptParser().parse(kept);
    expect((r.subtotalCents, r.taxCents, r.totalCents), (36133, 157, 36290));
  });

  test('a masked card number on a payment line is cut too', () {
    expect(withoutPaymentSection(['MILK  3.99', 'TOTAL  3.99', 'VISA ************4321  3.99']),
        ['MILK  3.99', 'TOTAL  3.99']);
  });

  test('receipts without a card section are unchanged', () {
    const rows = ['MILK  3.99', 'TOTAL  3.99', 'CASH  5.00', 'CHANGE  1.01'];
    expect(withoutPaymentSection(rows), rows);
  });

  test('OCR lines below the card section are dropped', () {
    OcrLine at(String t, double y) => OcrLine(t, left: 0, top: y, right: 100, bottom: y + 20);
    final kept = withoutPaymentLines([
      at('TOTAL', 100), at('362.90', 100), at('CARD INFORMATION:', 160), at('Account:', 190),
      at('1111', 190),
    ]);
    expect(kept.map((l) => l.text), ['TOTAL', '362.90']);
  });
}
