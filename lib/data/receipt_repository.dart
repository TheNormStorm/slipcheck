import 'package:drift/drift.dart';

import '../core/matching/product_matcher.dart';
import '../core/matching/product_normalizer.dart';
import 'database.dart';

/// One line on the review screen, as the user left it.
class DraftLine {
  DraftLine({
    required this.name,
    required this.lineTotalCents,
    String? originalText,
    this.quantity = 1,
    this.unit = 'each',
    this.unitPriceCents,
    this.discountCents = 0,
    this.productId,
  }) : originalText = originalText ?? name;

  /// The product name as corrected by the user.
  String name;

  /// What OCR read, before correction. Saved as an alias so the same
  /// receipt text matches automatically next time.
  final String originalText;
  double quantity;
  String unit;
  int? unitPriceCents;
  int lineTotalCents;
  int discountCents;

  /// An existing product the user confirmed; null creates or finds one by name.
  int? productId;
}

class ReceiptDraft {
  ReceiptDraft({
    required this.storeName,
    required this.purchasedAt,
    required this.lines,
    this.subtotalCents,
    this.taxCents,
    this.totalCents,
    this.imagePath,
    this.ocrText,
    this.source = 'photo',
    this.currency = 'USD',
  });

  String storeName;
  DateTime purchasedAt;
  final List<DraftLine> lines;
  int? subtotalCents;
  int? taxCents;
  int? totalCents;
  final String? imagePath;
  final String? ocrText;
  final String source;
  final String currency;
}

class ReceiptSummary {
  ReceiptSummary(this.id, this.storeName, this.purchasedAt, this.totalCents, this.itemCount);
  final int id;
  final String? storeName;
  final DateTime purchasedAt;
  final int? totalCents;
  final int itemCount;
}

class ProductSummary {
  ProductSummary(this.id, this.displayName, this.purchaseCount, this.lastUnitPriceCents);
  final int id;
  final String displayName;
  final int purchaseCount;
  final int? lastUnitPriceCents;
}

class PricePoint {
  PricePoint({
    required this.receiptId,
    required this.date,
    required this.storeName,
    required this.quantity,
    required this.unit,
    required this.netCents,
  });
  final int receiptId;
  final DateTime date;
  final String? storeName;
  final double quantity;
  final String unit;
  final int netCents;

  /// Price per one unit (each, per kg or per lb) after discounts.
  int get unitPriceCents => quantity == 0 ? netCents : (netCents / quantity).round();
}

String normalizeStoreName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class ReceiptRepository {
  ReceiptRepository(this.db);
  final AppDatabase db;

  Future<int?> findStoreId(String name) async {
    final row = await (db.select(db.stores)
          ..where((s) => s.normalizedName.equals(normalizeStoreName(name))))
        .getSingleOrNull();
    return row?.id;
  }

  Future<ProductMatcher> loadMatcher() async {
    final products = await db.select(db.products).get();
    final aliases = await db.select(db.productAliases).get();
    return ProductMatcher(
      [
        for (final p in products)
          ProductCandidate(id: p.id, key: p.canonicalKey, displayName: p.displayName),
      ],
      [
        for (final a in aliases)
          ProductAlias(key: a.aliasKey, productId: a.productId, storeId: a.storeId),
      ],
    );
  }

  /// Saves the draft in one transaction and returns the new receipt id.
  Future<int> saveReceipt(ReceiptDraft draft) {
    return db.transaction(() async {
      final storeId = draft.storeName.trim().isEmpty
          ? null
          : await _findOrCreateStore(draft.storeName);
      final receiptId = await db.into(db.receipts).insert(ReceiptsCompanion.insert(
            storeId: Value(storeId),
            purchasedAt: draft.purchasedAt,
            subtotalCents: Value(draft.subtotalCents),
            taxCents: Value(draft.taxCents),
            totalCents: Value(draft.totalCents),
            imagePath: Value(draft.imagePath),
            ocrText: Value(draft.ocrText),
            source: draft.source,
            currency: Value(draft.currency),
          ));
      for (final (i, line) in draft.lines.indexed) {
        final productId = line.productId ?? await _findOrCreateProduct(line.name);
        await _rememberAliases(line, productId, storeId);
        await db.into(db.lineItems).insert(LineItemsCompanion.insert(
              receiptId: receiptId,
              position: i,
              rawText: line.originalText,
              productId: Value(productId),
              quantity: Value(line.quantity),
              unit: Value(line.unit),
              unitPriceCents: Value(line.unitPriceCents),
              lineTotalCents: line.lineTotalCents,
              discountCents: Value(line.discountCents),
            ));
      }
      return receiptId;
    });
  }

  Future<int> _findOrCreateStore(String name) async {
    final existing = await findStoreId(name);
    if (existing != null) return existing;
    return db.into(db.stores).insert(StoresCompanion.insert(
          name: name.trim(),
          normalizedName: normalizeStoreName(name),
        ));
  }

  Future<int> _findOrCreateProduct(String name) async {
    final norm = normalizeProduct(name);
    final existing = await (db.select(db.products)
          ..where((p) => p.canonicalKey.equals(norm.key)))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    return db.into(db.products).insert(ProductsCompanion.insert(
          canonicalKey: norm.key,
          displayName: name.trim(),
          sizeValue: Value(norm.sizeValue),
          sizeUnit: Value(norm.sizeUnit),
          packCount: Value(norm.packCount),
        ));
  }

  /// Records the OCR text and the corrected name as store-specific aliases,
  /// unless they already normalise to the product's own key.
  Future<void> _rememberAliases(DraftLine line, int productId, int? storeId) async {
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingle();
    final keys = {
      normalizeProduct(line.originalText).key,
      normalizeProduct(line.name).key,
    }..remove(product.canonicalKey);
    for (final key in keys) {
      if (key.isEmpty) continue;
      final query = db.select(db.productAliases)
        ..where((a) => a.aliasKey.equals(key))
        ..where((a) => storeId == null ? a.storeId.isNull() : a.storeId.equals(storeId));
      final existing = await query.getSingleOrNull();
      if (existing == null) {
        await db.into(db.productAliases).insert(ProductAliasesCompanion.insert(
              aliasKey: key,
              productId: productId,
              storeId: Value(storeId),
            ));
      } else if (existing.productId != productId) {
        // The user corrected an earlier mapping: the latest choice wins.
        await (db.update(db.productAliases)..where((a) => a.id.equals(existing.id)))
            .write(ProductAliasesCompanion(productId: Value(productId)));
      }
    }
  }

  Future<List<ReceiptSummary>> receipts() async {
    final count = db.lineItems.id.count();
    final query = db.select(db.receipts).join([
      leftOuterJoin(db.stores, db.stores.id.equalsExp(db.receipts.storeId)),
      leftOuterJoin(db.lineItems, db.lineItems.receiptId.equalsExp(db.receipts.id)),
    ])
      ..addColumns([count])
      ..groupBy([db.receipts.id])
      ..orderBy([OrderingTerm.desc(db.receipts.purchasedAt), OrderingTerm.desc(db.receipts.id)]);
    final rows = await query.get();
    return [
      for (final r in rows)
        ReceiptSummary(
          r.readTable(db.receipts).id,
          r.readTableOrNull(db.stores)?.name,
          r.readTable(db.receipts).purchasedAt,
          r.readTable(db.receipts).totalCents,
          r.read(count) ?? 0,
        ),
    ];
  }

  Future<List<ProductSummary>> products() async {
    final products = await (db.select(db.products)
          ..orderBy([(p) => OrderingTerm.asc(p.displayName)]))
        .get();
    final summaries = <ProductSummary>[];
    for (final p in products) {
      final history = await priceHistory(p.id);
      summaries.add(ProductSummary(p.id, p.displayName, history.length,
          history.isEmpty ? null : history.last.unitPriceCents));
    }
    return summaries;
  }

  /// Every purchase of [productId], oldest first.
  Future<List<PricePoint>> priceHistory(int productId) async {
    final query = db.select(db.lineItems).join([
      innerJoin(db.receipts, db.receipts.id.equalsExp(db.lineItems.receiptId)),
      leftOuterJoin(db.stores, db.stores.id.equalsExp(db.receipts.storeId)),
    ])
      ..where(db.lineItems.productId.equals(productId))
      ..orderBy([OrderingTerm.asc(db.receipts.purchasedAt), OrderingTerm.asc(db.receipts.id)]);
    final rows = await query.get();
    return [
      for (final r in rows)
        () {
          final item = r.readTable(db.lineItems);
          final receipt = r.readTable(db.receipts);
          return PricePoint(
            receiptId: receipt.id,
            date: receipt.purchasedAt,
            storeName: r.readTableOrNull(db.stores)?.name,
            quantity: item.quantity,
            unit: item.unit,
            netCents: item.lineTotalCents - item.discountCents,
          );
        }(),
    ];
  }
}
