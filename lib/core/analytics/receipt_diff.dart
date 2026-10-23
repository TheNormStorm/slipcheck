import '../money.dart';
import 'purchase.dart';

enum ChangeKind { priceAndQuantity, added, removed, unchanged }

/// How one product contributed to the difference between two receipts.
class ItemChange {
  const ItemChange({
    required this.productId,
    required this.name,
    required this.kind,
    required this.unit,
    this.before,
    this.after,
    this.priceEffectCents = 0,
    this.quantityEffectCents = 0,
  });

  final int productId;
  final String name;
  final ChangeKind kind;
  final String unit;
  final Purchase? before, after;

  /// Part of the change caused by the unit price moving.
  final int priceEffectCents;

  /// Part caused by buying more or less of it.
  final int quantityEffectCents;

  int get totalCents => (after?.netCents ?? 0) - (before?.netCents ?? 0);
}

/// Why receipt B cost more or less than receipt A, split exactly into:
/// price changes, quantity changes, items only on B, items only on A, tax.
///
/// For a product on both, the change in what was paid, pB·qB − pA·qA, is
/// split with the midpoint (Bennet) decomposition:
///   price effect    = (pB − pA) × (qA + qB) / 2
///   quantity effect = (qB − qA) × (pA + pB) / 2
/// which add up to the change exactly, whichever receipt came first. The
/// buckets therefore always sum to the difference in totals, to the cent.
class ReceiptDiff {
  ReceiptDiff({
    required this.items,
    required this.beforeItemsCents,
    required this.afterItemsCents,
    required this.beforeTaxCents,
    required this.afterTaxCents,
  });

  final List<ItemChange> items;
  final int beforeItemsCents, afterItemsCents, beforeTaxCents, afterTaxCents;

  int get beforeTotalCents => beforeItemsCents + beforeTaxCents;
  int get afterTotalCents => afterItemsCents + afterTaxCents;
  int get differenceCents => afterTotalCents - beforeTotalCents;

  int get priceEffectCents => items.fold(0, (s, i) => s + i.priceEffectCents);
  int get quantityEffectCents => items.fold(0, (s, i) => s + i.quantityEffectCents);
  int get addedCents => _sum(ChangeKind.added);
  int get removedCents => _sum(ChangeKind.removed);
  int get taxChangeCents => afterTaxCents - beforeTaxCents;

  int _sum(ChangeKind kind) =>
      items.where((i) => i.kind == kind).fold(0, (s, i) => s + i.totalCents);

  /// Items ordered by how much they moved the total, largest first.
  List<ItemChange> get biggestChanges =>
      [...items.where((i) => i.totalCents != 0)]
        ..sort((a, b) => b.totalCents.abs().compareTo(a.totalCents.abs()));

  /// The difference in plain sentences, biggest causes first.
  List<String> explain({int examples = 3}) {
    final out = <String>[];
    final d = differenceCents;
    out.add(d == 0
        ? 'Both receipts cost the same.'
        : 'You spent ${_money(d.abs())} ${d > 0 ? 'more' : 'less'} on the second receipt.');

    final parts = <(int, String)>[];

    final priced = [...items.where((i) => i.priceEffectCents != 0)]
      ..sort((a, b) => b.priceEffectCents.abs().compareTo(a.priceEffectCents.abs()));
    if (priceEffectCents != 0 || priced.isNotEmpty) {
      final up = priced.where((i) => i.priceEffectCents > 0).length;
      final down = priced.where((i) => i.priceEffectCents < 0).length;
      parts.add((
        priceEffectCents,
        '${_signed(priceEffectCents)} from prices '
            '(${_count(up, 'item')} up, $down down): '
            '${priced.take(examples).map(_priceExample).join('; ')}.',
      ));
    }

    final qty = [...items.where((i) => i.quantityEffectCents != 0)]
      ..sort((a, b) => b.quantityEffectCents.abs().compareTo(a.quantityEffectCents.abs()));
    if (qty.isNotEmpty) {
      parts.add((
        quantityEffectCents,
        '${_signed(quantityEffectCents)} from buying more or less of the same items: '
            '${qty.take(examples).map(_quantityExample).join('; ')}.',
      ));
    }

    final added = [...items.where((i) => i.kind == ChangeKind.added)]
      ..sort((a, b) => b.totalCents.compareTo(a.totalCents));
    if (added.isNotEmpty) {
      parts.add((
        addedCents,
        '${_signed(addedCents)} from ${_count(added.length, 'item')} only on the second '
            'receipt: ${added.take(examples).map((i) => '${i.name} ${_money(i.totalCents)}').join(', ')}.',
      ));
    }

    final removed = [...items.where((i) => i.kind == ChangeKind.removed)]
      ..sort((a, b) => a.totalCents.compareTo(b.totalCents));
    if (removed.isNotEmpty) {
      parts.add((
        removedCents,
        '${_signed(removedCents)} from ${_count(removed.length, 'item')} only on the first '
            'receipt: ${removed.take(examples).map((i) => '${i.name} ${_money(-i.totalCents)}').join(', ')}.',
      ));
    }

    if (taxChangeCents != 0) parts.add((taxChangeCents, '${_signed(taxChangeCents)} from tax.'));

    parts.sort((a, b) => b.$1.abs().compareTo(a.$1.abs()));
    out.addAll(parts.map((p) => p.$2));
    return out;
  }

  String _priceExample(ItemChange i) =>
      '${i.name} ${_unitPrice(i.before!)} → ${_unitPrice(i.after!)}';

  String _quantityExample(ItemChange i) =>
      '${i.name} ${_qty(i.before!.quantity)} → ${_qty(i.after!.quantity)}'
      '${i.unit == 'each' ? '' : ' ${i.unit}'}';
}

ReceiptDiff compareReceipts(
  List<Purchase> before,
  List<Purchase> after, {
  int beforeTaxCents = 0,
  int afterTaxCents = 0,
}) {
  final a = {for (final p in mergeByProduct(before)) (p.productId, p.unit): p};
  final b = {for (final p in mergeByProduct(after)) (p.productId, p.unit): p};
  final items = <ItemChange>[];

  for (final entry in a.entries) {
    final pa = entry.value, pb = b[entry.key];
    if (pb == null) {
      items.add(ItemChange(
          productId: pa.productId, name: pa.productName, kind: ChangeKind.removed,
          unit: pa.unit, before: pa));
      continue;
    }
    final change = pb.netCents - pa.netCents;
    final priceEffect =
        ((pb.unitPrice - pa.unitPrice) * (pa.quantity + pb.quantity) / 2).round();
    items.add(ItemChange(
      productId: pa.productId,
      name: pb.productName,
      kind: change == 0 && pa.quantity == pb.quantity
          ? ChangeKind.unchanged
          : ChangeKind.priceAndQuantity,
      unit: pa.unit,
      before: pa,
      after: pb,
      priceEffectCents: priceEffect,
      // Whatever rounding leaves goes here, so the parts add up exactly.
      quantityEffectCents: change - priceEffect,
    ));
  }
  for (final entry in b.entries) {
    if (a.containsKey(entry.key)) continue;
    final pb = entry.value;
    items.add(ItemChange(
        productId: pb.productId, name: pb.productName, kind: ChangeKind.added,
        unit: pb.unit, after: pb));
  }

  return ReceiptDiff(
    items: items,
    beforeItemsCents: a.values.fold(0, (s, p) => s + p.netCents),
    afterItemsCents: b.values.fold(0, (s, p) => s + p.netCents),
    beforeTaxCents: beforeTaxCents,
    afterTaxCents: afterTaxCents,
  );
}

String _money(int cents) => '\$${formatCents(cents)}';
String _signed(int cents) => '${cents < 0 ? '−' : '+'}${_money(cents.abs())}';
String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(3);
String _unitPrice(Purchase p) =>
    p.unit == 'each' ? _money(p.unitPrice.round()) : '${_money(p.unitPrice.round())}/${p.unit}';
