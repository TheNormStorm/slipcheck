import 'package:drift/drift.dart';
import 'package:intl/intl.dart' show DateFormat;


import '../core/analytics/purchase.dart';
import '../core/categories.dart';
import '../core/matching/product_matcher.dart';
import '../core/money.dart';
import '../core/matching/product_normalizer.dart';
import 'database.dart';
import 'receipt_files.dart';

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
    this.code,
    this.section,
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

  /// Barcode or PLU printed on the line.
  final String? code;

  /// Department heading the line was printed under.
  final String? section;

  int get netCents => lineTotalCents - discountCents;
}

class ReceiptDraft {
  ReceiptDraft({
    required this.storeName,
    required this.purchasedAt,
    required this.lines,
    this.subtotalCents,
    this.taxCents,
    this.totalCents,
    this.imagePaths = const [],
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
  /// Photos of the receipt, top first.
  final List<String> imagePaths;
  final String? ocrText;
  final String source;
  final String currency;
}

class ReceiptSummary {
  ReceiptSummary(this.id, this.storeName, this.purchasedAt, this.totalCents, this.itemCount,
      {this.storeId, this.itemsCents = 0, this.taxCents});
  final int id;
  final int? storeId;
  final String? storeName;
  final DateTime purchasedAt;
  final int? totalCents;
  final int itemCount;

  /// What the saved lines add up to, after discounts.
  final int itemsCents;
  final int? taxCents;

  /// The printed total when it was read, otherwise items plus tax.
  int get spentCents => totalCents ?? itemsCents + (taxCents ?? 0);
}

/// A saved receipt with its lines, for viewing and comparing.
class ReceiptDetail {
  ReceiptDetail({
    required this.summary,
    required this.lines,
    required this.purchases,
    required this.imagePaths,
    this.subtotalCents,
  });

  final ReceiptSummary summary;

  /// As printed, in receipt order.
  final List<DraftLine> lines;

  /// The same lines as purchases of known products, for analysis.
  final List<Purchase> purchases;
  final List<String> imagePaths;
  final int? subtotalCents;

  /// The receipt as plain text for sharing: store, date, each line and the
  /// totals. Built only from the saved lines, so no card details and no
  /// photo can go with it.
  String asText() {
    final s = summary;
    String row(String name, int cents) {
      final amount = formatCents(cents);
      return '${name.padRight(32 - amount.length)} $amount';
    }

    return [
      s.storeName ?? 'Receipt',
      DateFormat('EEE, MMM d, y').format(s.purchasedAt),
      '',
      for (final l in lines) ...[
        row(l.name, l.netCents),
        if (l.quantity != 1 || l.unit != 'each')
          '  ${l.quantity == l.quantity.roundToDouble() ? l.quantity.toInt() : l.quantity} '
              '${l.unit == 'each' ? '×' : l.unit}',
        if (l.discountCents > 0) '  saved ${formatCents(l.discountCents)}',
      ],
      '',
      if (subtotalCents != null) row('Subtotal', subtotalCents!),
      if (s.taxCents != null) row('Tax', s.taxCents!),
      row('Total', s.spentCents),
      '',
      'Shared from Slipcheck',
    ].join('\n');
  }
}

class ProductSummary {
  ProductSummary(this.id, this.displayName, this.purchaseCount, this.lastUnitPriceCents,
      [this.lastUnit = 'each', this.category = Category.other, this.storeIds = const {},
      this.spentCents = 0]);
  final int id;
  final String displayName;
  final int purchaseCount;
  final int? lastUnitPriceCents;

  /// What [lastUnitPriceCents] is per: 'each', 'kg' or 'lb'.
  final String lastUnit;
  final Category category;

  /// Stores it was bought at.
  final Set<int> storeIds;
  final int spentCents;
}

/// What [ReceiptRepository.mergeProducts] changed, for undoing it.
class MergeUndo {
  MergeUndo(this.merged, this.keptId, this.keptCategory, this.lineIds, this.aliasIds,
      this.addedAliasId);
  final Product merged;
  final int keptId;
  final String? keptCategory;
  final List<int> lineIds, aliasIds;
  final int addedAliasId;
}

class StoreSummary {
  StoreSummary(this.id, this.name, this.receiptCount, this.spentCents, this.lastVisit);
  final int id;
  final String name;
  final int receiptCount;
  final int spentCents;
  final DateTime? lastVisit;
}

class PricePoint {
  PricePoint({
    required this.receiptId,
    required this.date,
    required this.storeName,
    required this.quantity,
    required this.unit,
    required this.netCents,
    this.storeId,
  });
  final int receiptId;
  final DateTime date;
  final int? storeId;
  final String? storeName;
  final double quantity;
  final String unit;
  final int netCents;

  /// Price per one unit (each, per kg or per lb) after discounts.
  int get unitPriceCents => quantity == 0 ? netCents : (netCents / quantity).round();
}

/// Whether two normalised store names differ only by OCR slips: the same
/// words, where a word of four or more letters may have one character
/// wrong, added or missing ("markft basket"). Short words must match, so
/// "store a" and "store b", or "cvs 12" and "cvs 15", stay apart.
bool sameStoreName(String a, String b) {
  final wa = a.split(' '), wb = b.split(' ');
  if (wa.length != wb.length) return false;
  for (var i = 0; i < wa.length; i++) {
    if (wa[i] == wb[i]) continue;
    if (wa[i].length < 4 || wb[i].length < 4 || _editDistance(wa[i], wb[i]) > 1) return false;
  }
  return true;
}

int _editDistance(String a, String b) {
  var prev = List.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

String normalizeStoreName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class ReceiptRepository {
  ReceiptRepository(this.db);
  final AppDatabase db;

  /// Fires after every committed write (save, edit, delete, link, ...), so
  /// open screens can reload.
  Stream<void> get changes => db.tableUpdates();

  /// A one-off moment the app has shown (onboarding, scanner tips).
  Future<bool> hasSeen(String key) async =>
      await (db.select(db.settings)..where((s) => s.key.equals(key))).getSingleOrNull() != null;

  Future<void> markSeen(String key) =>
      db.into(db.settings).insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: '1'));

  /// The store [name] refers to: the same name, or one OCR read slightly
  /// differently ("MARKFT BASKET"), so one store is not split in two.
  Future<int?> findStoreId(String name) async {
    final normalized = normalizeStoreName(name);
    if (normalized.isEmpty) return null;
    final stores = await db.select(db.stores).get();
    for (final s in stores) {
      if (s.normalizedName == normalized) return s.id;
    }
    for (final s in stores) {
      if (sameStoreName(s.normalizedName, normalized)) return s.id;
    }
    return null;
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
            imagePath: Value(draft.imagePaths.firstOrNull),
            ocrText: Value(draft.ocrText),
            source: draft.source,
            currency: Value(draft.currency),
          ));
      for (final (i, path) in draft.imagePaths.indexed) {
        await db.into(db.receiptImages).insert(ReceiptImagesCompanion.insert(
              receiptId: receiptId,
              position: i,
              path: path,
            ));
      }
      await _insertLines(receiptId, storeId, draft.lines);
      return receiptId;
    });
  }

  /// Replaces a saved receipt's details and lines with [draft]; its photos
  /// and OCR text stay.
  Future<void> updateReceipt(int receiptId, ReceiptDraft draft) {
    return db.transaction(() async {
      final storeId = draft.storeName.trim().isEmpty
          ? null
          : await _findOrCreateStore(draft.storeName);
      await (db.update(db.receipts)..where((r) => r.id.equals(receiptId))).write(
        ReceiptsCompanion(
          storeId: Value(storeId),
          purchasedAt: Value(draft.purchasedAt),
          subtotalCents: Value(draft.subtotalCents),
          taxCents: Value(draft.taxCents),
          totalCents: Value(draft.totalCents),
        ),
      );
      await (db.delete(db.lineItems)..where((l) => l.receiptId.equals(receiptId))).go();
      await _insertLines(receiptId, storeId, draft.lines);
    });
  }

  Future<void> _insertLines(int receiptId, int? storeId, List<DraftLine> lines) async {
    for (final (i, line) in lines.indexed) {
      final productId =
          line.productId ?? await _findOrCreateProduct(line.name, section: line.section);
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
            code: Value(line.code),
            section: Value(line.section),
          ));
    }
  }

  Future<int> _findOrCreateStore(String name) async {
    final existing = await findStoreId(name);
    if (existing != null) return existing;
    return db.into(db.stores).insert(StoresCompanion.insert(
          name: name.trim(),
          normalizedName: normalizeStoreName(name),
        ));
  }

  Future<int> _findOrCreateProduct(String name, {String? section}) async {
    final norm = normalizeProduct(name);
    final existing = await (db.select(db.products)
          ..where((p) => p.canonicalKey.equals(norm.key)))
        .getSingleOrNull();
    if (existing != null) {
      if (existing.category == null) {
        await setCategory(existing.id, categorize(name, section: section));
      }
      return existing.id;
    }
    return db.into(db.products).insert(ProductsCompanion.insert(
          canonicalKey: norm.key,
          displayName: name.trim(),
          sizeValue: Value(norm.sizeValue),
          sizeUnit: Value(norm.sizeUnit),
          packCount: Value(norm.packCount),
          category: Value(categorize(name, section: section).name),
        ));
  }

  Future<void> setCategory(int productId, Category category) =>
      (db.update(db.products)..where((p) => p.id.equals(productId)))
          .write(ProductsCompanion(category: Value(category.name)));

  /// Makes [mergeId] the same product as [keepId]: its purchases and learned
  /// names move over and it is deleted. Used to link one item across stores.
  /// Returns what is needed to undo it (see [undoMerge]).
  Future<MergeUndo> mergeProducts({required int keepId, required int mergeId}) =>
      db.transaction(() async {
        final lineIds = [
          for (final l in await (db.select(db.lineItems)
                ..where((l) => l.productId.equals(mergeId)))
              .get())
            l.id,
        ];
        final aliasIds = [
          for (final a in await (db.select(db.productAliases)
                ..where((a) => a.productId.equals(mergeId)))
              .get())
            a.id,
        ];
        await (db.update(db.lineItems)..where((l) => l.productId.equals(mergeId)))
            .write(LineItemsCompanion(productId: Value(keepId)));
        await (db.update(db.productAliases)..where((a) => a.productId.equals(mergeId)))
            .write(ProductAliasesCompanion(productId: Value(keepId)));
        final merged = await (db.select(db.products)..where((p) => p.id.equals(mergeId)))
            .getSingle();
        final kept = await (db.select(db.products)..where((p) => p.id.equals(keepId)))
            .getSingle();
        if ((kept.category == null || kept.category == Category.other.name) &&
            merged.category != null) {
          await (db.update(db.products)..where((p) => p.id.equals(keepId)))
              .write(ProductsCompanion(category: Value(merged.category)));
        }
        // Its own name keeps matching the kept product on future receipts.
        final aliasId = await db.into(db.productAliases).insert(ProductAliasesCompanion.insert(
              aliasKey: merged.canonicalKey,
              productId: keepId,
            ));
        await (db.delete(db.products)..where((p) => p.id.equals(mergeId))).go();
        return MergeUndo(merged, keepId, kept.category, lineIds, aliasIds, aliasId);
      });

  /// Puts a linked product back as it was before [mergeProducts].
  Future<void> undoMerge(MergeUndo undo) => db.transaction(() async {
        await db.into(db.products).insert(undo.merged);
        await (db.update(db.lineItems)..where((l) => l.id.isIn(undo.lineIds)))
            .write(LineItemsCompanion(productId: Value(undo.merged.id)));
        await (db.update(db.productAliases)..where((a) => a.id.isIn(undo.aliasIds)))
            .write(ProductAliasesCompanion(productId: Value(undo.merged.id)));
        await (db.delete(db.productAliases)..where((a) => a.id.equals(undo.addedAliasId))).go();
        await (db.update(db.products)..where((p) => p.id.equals(undo.keptId)))
            .write(ProductsCompanion(category: Value(undo.keptCategory)));
      });

  /// Gives a product a clearer name ("BEPRTYWNGABF" → "Party wings"). The
  /// new name also matches it on future receipts.
  Future<void> renameProduct(int productId, String name) => db.transaction(() async {
        await (db.update(db.products)..where((p) => p.id.equals(productId)))
            .write(ProductsCompanion(displayName: Value(name.trim())));
        final key = normalizeProduct(name).key;
        final product =
            await (db.select(db.products)..where((p) => p.id.equals(productId))).getSingle();
        final exists = await (db.select(db.productAliases)
              ..where((a) => a.aliasKey.equals(key) & a.storeId.isNull()))
            .getSingleOrNull();
        if (key != product.canonicalKey && exists == null) {
          await db.into(db.productAliases).insert(
              ProductAliasesCompanion.insert(aliasKey: key, productId: productId));
        }
      });

  /// Folds [mergeId] into [keepId] when OCR or typing split one store in two.
  Future<void> mergeStores({required int keepId, required int mergeId}) =>
      db.transaction(() async {
        await (db.update(db.receipts)..where((r) => r.storeId.equals(mergeId)))
            .write(ReceiptsCompanion(storeId: Value(keepId)));
        await (db.update(db.productAliases)..where((a) => a.storeId.equals(mergeId)))
            .write(ProductAliasesCompanion(storeId: Value(keepId)));
        await (db.delete(db.stores)..where((s) => s.id.equals(mergeId))).go();
      });

  Future<List<StoreSummary>> stores() async {
    final receipts = await this.receipts();
    final stores = await db.select(db.stores).get();
    return [
      for (final s in stores)
        () {
          final mine = receipts.where((r) => r.storeId == s.id).toList();
          return StoreSummary(
            s.id,
            s.name,
            mine.length,
            mine.fold(0, (sum, r) => sum + r.spentCents),
            mine.isEmpty ? null : mine.first.purchasedAt,
          );
        }(),
    ]..sort((a, b) => b.spentCents.compareTo(a.spentCents));
  }

  /// Records the OCR text and the corrected name as store-specific aliases,
  /// unless they already normalise to the product's own key.
  Future<void> _rememberAliases(DraftLine line, int productId, int? storeId) async {
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(productId)))
        .getSingle();
    final keys = <String, int?>{
      for (final k in {normalizeProduct(line.originalText).key, normalizeProduct(line.name).key}
        ..remove(product.canonicalKey))
        k: storeId,
    };
    if (line.code != null) {
      final c = codeAlias(line.code!);
      keys[c.key] = c.storeOnly ? storeId : null;
    }
    for (final MapEntry(key: key, value: aliasStore) in keys.entries) {
      if (key.isEmpty) continue;
      final query = db.select(db.productAliases)
        ..where((a) => a.aliasKey.equals(key))
        ..where((a) =>
            aliasStore == null ? a.storeId.isNull() : a.storeId.equals(aliasStore));
      final existing = await query.getSingleOrNull();
      if (existing == null) {
        await db.into(db.productAliases).insert(ProductAliasesCompanion.insert(
              aliasKey: key,
              productId: productId,
              storeId: Value(aliasStore),
            ));
      } else if (existing.productId != productId) {
        // The user corrected an earlier mapping: the latest choice wins.
        await (db.update(db.productAliases)..where((a) => a.id.equals(existing.id)))
            .write(ProductAliasesCompanion(productId: Value(productId)));
      }
    }
  }

  Future<List<ReceiptSummary>> receipts({int? id}) async {
    final count = db.lineItems.id.count();
    final net = (db.lineItems.lineTotalCents - db.lineItems.discountCents).sum();
    final query = db.select(db.receipts).join([
      leftOuterJoin(db.stores, db.stores.id.equalsExp(db.receipts.storeId)),
      leftOuterJoin(db.lineItems, db.lineItems.receiptId.equalsExp(db.receipts.id)),
    ])
      ..addColumns([count, net])
      ..groupBy([db.receipts.id])
      ..orderBy([OrderingTerm.desc(db.receipts.purchasedAt), OrderingTerm.desc(db.receipts.id)]);
    if (id != null) query.where(db.receipts.id.equals(id));
    final rows = await query.get();
    return [
      for (final r in rows)
        ReceiptSummary(
          r.readTable(db.receipts).id,
          r.readTableOrNull(db.stores)?.name,
          r.readTable(db.receipts).purchasedAt,
          r.readTable(db.receipts).totalCents,
          r.read(count) ?? 0,
          storeId: r.readTable(db.receipts).storeId,
          itemsCents: r.read(net) ?? 0,
          taxCents: r.readTable(db.receipts).taxCents,
        ),
    ];
  }

  Future<ReceiptDetail> receipt(int id) async {
    final summary = (await receipts(id: id)).single;
    final receiptRow =
        await (db.select(db.receipts)..where((r) => r.id.equals(id))).getSingle();
    final rows = await (db.select(db.lineItems).join([
      leftOuterJoin(db.products, db.products.id.equalsExp(db.lineItems.productId)),
    ])
          ..where(db.lineItems.receiptId.equals(id))
          ..orderBy([OrderingTerm.asc(db.lineItems.position)]))
        .get();
    final images = await (db.select(db.receiptImages)
          ..where((i) => i.receiptId.equals(id))
          ..orderBy([(i) => OrderingTerm.asc(i.position)]))
        .get();
    return ReceiptDetail(
      summary: summary,
      subtotalCents: receiptRow.subtotalCents,
      lines: [
        for (final r in rows)
          () {
            final item = r.readTable(db.lineItems);
            return DraftLine(
              name: r.readTableOrNull(db.products)?.displayName ?? item.rawText,
              originalText: item.rawText,
              quantity: item.quantity,
              unit: item.unit,
              unitPriceCents: item.unitPriceCents,
              lineTotalCents: item.lineTotalCents,
              discountCents: item.discountCents,
              productId: item.productId,
              code: item.code,
              section: item.section,
            );
          }(),
      ],
      purchases: await purchases(receiptId: id),
      imagePaths: [for (final i in images) i.path],
    );
  }

  /// Receipts with a line whose printed text or saved item name contains
  /// [query], ignoring case.
  Future<Set<int>> receiptsWithItem(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return {};
    // LIKE wildcards in what was typed are searched for literally.
    final pattern = '%${q.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    final rows = await db.customSelect(
      'SELECT DISTINCT l.receipt_id AS id FROM line_items l '
      'LEFT JOIN products p ON p.id = l.product_id '
      "WHERE lower(l.raw_text) LIKE ?1 ESCAPE '\\' OR lower(p.display_name) LIKE ?1 ESCAPE '\\'",
      variables: [Variable.withString(pattern)],
      readsFrom: {db.lineItems, db.products},
    ).get();
    return {for (final r in rows) r.read<int>('id')};
  }

  /// Every purchase of a known product, oldest first; or one receipt's.
  Future<List<Purchase>> purchases({int? receiptId}) async {
    final query = db.select(db.lineItems).join([
      innerJoin(db.receipts, db.receipts.id.equalsExp(db.lineItems.receiptId)),
      innerJoin(db.products, db.products.id.equalsExp(db.lineItems.productId)),
      leftOuterJoin(db.stores, db.stores.id.equalsExp(db.receipts.storeId)),
    ])
      ..orderBy([OrderingTerm.asc(db.receipts.purchasedAt), OrderingTerm.asc(db.receipts.id)]);
    if (receiptId != null) query.where(db.lineItems.receiptId.equals(receiptId));
    final rows = await query.get();
    return [
      for (final r in rows)
        () {
          final item = r.readTable(db.lineItems);
          final receipt = r.readTable(db.receipts);
          final store = r.readTableOrNull(db.stores);
          return Purchase(
            receiptId: receipt.id,
            date: receipt.purchasedAt,
            storeId: store?.id,
            storeName: store?.name,
            productId: item.productId!,
            productName: r.readTable(db.products).displayName,
            quantity: item.quantity,
            unit: item.unit,
            netCents: item.lineTotalCents - item.discountCents,
          );
        }(),
    ];
  }

  /// Every saved line as CSV, one row per line, for spreadsheets.
  Future<String> csvExport() async {
    final rows = await (db.select(db.lineItems).join([
      innerJoin(db.receipts, db.receipts.id.equalsExp(db.lineItems.receiptId)),
      leftOuterJoin(db.stores, db.stores.id.equalsExp(db.receipts.storeId)),
      leftOuterJoin(db.products, db.products.id.equalsExp(db.lineItems.productId)),
    ])
          ..orderBy([
            OrderingTerm.asc(db.receipts.purchasedAt),
            OrderingTerm.asc(db.receipts.id),
            OrderingTerm.asc(db.lineItems.position),
          ]))
        .get();
    String cell(Object? v) {
      final s = v?.toString() ?? '';
      return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String money(int? cents) => cents == null ? '' : formatCents(cents);
    final out = StringBuffer(
        'date,store,item,category,quantity,unit,unit_price,line_total,discount,paid,barcode,receipt_id\n');
    for (final r in rows) {
      final item = r.readTable(db.lineItems);
      final receipt = r.readTable(db.receipts);
      final product = r.readTableOrNull(db.products);
      final d = receipt.purchasedAt;
      out.writeln([
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        r.readTableOrNull(db.stores)?.name,
        product?.displayName ?? item.rawText,
        Category.byName(product?.category)?.label,
        item.quantity == item.quantity.roundToDouble() ? item.quantity.toInt() : item.quantity,
        item.unit,
        money(item.quantity == 0 ? null : ((item.lineTotalCents - item.discountCents) / item.quantity).round()),
        money(item.lineTotalCents),
        money(item.discountCents),
        money(item.lineTotalCents - item.discountCents),
        item.code,
        receipt.id,
      ].map(cell).join(','));
    }
    return out.toString();
  }

  /// An already saved receipt that [draft] is probably a second scan of: same
  /// store, same day and same total (or the same items total when no total
  /// was read). [exceptId] is the receipt being edited.
  Future<ReceiptSummary?> findDuplicate(ReceiptDraft draft, {int? exceptId}) async {
    final storeId = await findStoreId(draft.storeName);
    final itemsCents = draft.lines.fold(0, (s, l) => s + l.netCents);
    final d = draft.purchasedAt;
    for (final r in await receipts()) {
      if (r.id == exceptId || r.storeId != storeId) continue;
      final p = r.purchasedAt;
      if (p.year != d.year || p.month != d.month || p.day != d.day) continue;
      final sameTotal = draft.totalCents != null && r.totalCents != null
          ? draft.totalCents == r.totalCents
          : itemsCents == r.itemsCents;
      if (sameTotal) return r;
    }
    return null;
  }

  /// Deletes a receipt, its lines and its photos. Products and learned
  /// names stay, as other receipts may use them.
  Future<void> deleteReceipt(int id, {bool deleteFiles = true}) async {
    final images = await (db.select(db.receiptImages)..where((i) => i.receiptId.equals(id))).get();
    await db.transaction(() async {
      await (db.delete(db.lineItems)..where((l) => l.receiptId.equals(id))).go();
      await (db.delete(db.receiptImages)..where((i) => i.receiptId.equals(id))).go();
      await (db.delete(db.receipts)..where((r) => r.id.equals(id))).go();
    });
    if (deleteFiles) {
      for (final image in images) {
        await ReceiptFiles.deleteFor(image.path);
      }
    }
  }

  /// A full reset: every receipt, its lines and photos, and the items,
  /// learned names, links, categories and stores. App settings (onboarding
  /// seen) stay.
  Future<void> clearAll({bool deleteFiles = true}) async {
    await db.transaction(() async {
      await db.delete(db.lineItems).go();
      await db.delete(db.receiptImages).go();
      await db.delete(db.receipts).go();
      await db.delete(db.productAliases).go();
      await db.delete(db.products).go();
      await db.delete(db.stores).go();
    });
    if (deleteFiles) await ReceiptFiles.deleteAll();
  }

  /// Every item, by name, with what was bought of it. One query for all
  /// items rather than one per item.
  Future<List<ProductSummary>> products() async {
    final products = await (db.select(db.products)
          ..orderBy([(p) => OrderingTerm.asc(p.displayName)]))
        .get();
    final history = <int, List<PricePoint>>{};
    for (final (productId, point) in await _pricePoints()) {
      history.putIfAbsent(productId, () => []).add(point);
    }
    return [
      for (final p in products)
        () {
          final h = history[p.id] ?? const <PricePoint>[];
          return ProductSummary(
            p.id,
            p.displayName,
            h.length,
            h.lastOrNull?.unitPriceCents,
            h.lastOrNull?.unit ?? 'each',
            Category.byName(p.category) ?? Category.other,
            {for (final x in h) if (x.storeId != null) x.storeId!},
            h.fold(0, (sum, x) => sum + x.netCents),
          );
        }(),
    ];
  }

  /// The different ways receipts printed [productId], most often first.
  Future<List<String>> namesRead(int productId) async {
    final rows = await (db.select(db.lineItems)..where((l) => l.productId.equals(productId))).get();
    final counts = <String, int>{};
    for (final r in rows) {
      final name = r.rawText.trim();
      if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
    }
    return counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  /// Every purchase of [productId], oldest first.
  Future<List<PricePoint>> priceHistory(int productId) async =>
      [for (final (_, point) in await _pricePoints(productId: productId)) point];

  /// Purchases of known products (or one product), oldest first, with the
  /// product each is of.
  Future<List<(int, PricePoint)>> _pricePoints({int? productId}) async {
    final query = db.select(db.lineItems).join([
      innerJoin(db.receipts, db.receipts.id.equalsExp(db.lineItems.receiptId)),
      leftOuterJoin(db.stores, db.stores.id.equalsExp(db.receipts.storeId)),
    ])
      ..where(productId == null ? db.lineItems.productId.isNotNull() : db.lineItems.productId.equals(productId))
      ..orderBy([OrderingTerm.asc(db.receipts.purchasedAt), OrderingTerm.asc(db.receipts.id)]);
    final rows = await query.get();
    return [
      for (final r in rows)
        () {
          final item = r.readTable(db.lineItems);
          final receipt = r.readTable(db.receipts);
          return (
            item.productId!,
            PricePoint(
              receiptId: receipt.id,
              date: receipt.purchasedAt,
              storeName: r.readTableOrNull(db.stores)?.name,
              storeId: r.readTableOrNull(db.stores)?.id,
              quantity: item.quantity,
              unit: item.unit,
              netCents: item.lineTotalCents - item.discountCents,
            ),
          );
        }(),
    ];
  }
}
