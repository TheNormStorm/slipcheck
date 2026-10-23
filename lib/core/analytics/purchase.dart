/// One product bought on one receipt: the unit of every analysis.
///
/// Several lines of the same product on one receipt are merged into one
/// purchase (see [mergeByProduct]), so comparisons are per product.
class Purchase {
  const Purchase({
    required this.receiptId,
    required this.date,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.netCents,
    this.storeId,
    this.storeName,
  });

  final int receiptId;
  final DateTime date;
  final int? storeId;
  final String? storeName;
  final int productId;
  final String productName;

  /// Count, or weight in [unit].
  final double quantity;

  /// 'each', 'kg' or 'lb'.
  final String unit;

  /// What was paid after discounts, in cents.
  final int netCents;

  /// Price per unit in cents, unrounded.
  double get unitPrice => quantity == 0 ? netCents.toDouble() : netCents / quantity;
}

/// Merges lines of the same product (and unit) within each receipt.
List<Purchase> mergeByProduct(Iterable<Purchase> lines) {
  final merged = <(int, int, String), Purchase>{};
  for (final p in lines) {
    final key = (p.receiptId, p.productId, p.unit);
    final prev = merged[key];
    merged[key] = prev == null
        ? p
        : Purchase(
            receiptId: p.receiptId,
            date: p.date,
            storeId: p.storeId,
            storeName: p.storeName,
            productId: p.productId,
            productName: p.productName,
            quantity: prev.quantity + p.quantity,
            unit: p.unit,
            netCents: prev.netCents + p.netCents,
          );
  }
  return merged.values.toList();
}

double median(List<double> values) {
  final s = [...values]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}
