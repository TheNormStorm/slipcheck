import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Stores extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// Lowercased, whitespace-collapsed name used to find the store again.
  TextColumn get normalizedName => text().unique()();
}

class Receipts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get storeId => integer().nullable().references(Stores, #id)();
  DateTimeColumn get purchasedAt => dateTime()();
  IntColumn get subtotalCents => integer().nullable()();
  IntColumn get taxCents => integer().nullable()();
  IntColumn get totalCents => integer().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  /// Local path of the receipt photo, kept so it can be re-read later.
  TextColumn get imagePath => text().nullable()();

  /// Raw OCR rows, kept so an improved parser can re-parse old receipts.
  TextColumn get ocrText => text().nullable()();

  /// 'photo' or 'manual'.
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A normalised product that price history attaches to.
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// `NormalizedProduct.key`, e.g. "milk 2% 1000ml".
  TextColumn get canonicalKey => text().unique()();
  TextColumn get displayName => text()();
  RealColumn get sizeValue => real().nullable()();
  TextColumn get sizeUnit => text().nullable()();
  IntColumn get packCount => integer().nullable()();
}

/// Remembered "this receipt text means that product", learned on save.
class ProductAliases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get aliasKey => text()();
  IntColumn get productId => integer().references(Products, #id)();

  /// Null means the alias applies at every store.
  IntColumn get storeId => integer().nullable().references(Stores, #id)();
}

class LineItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get receiptId =>
      integer().references(Receipts, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  /// The line as printed (or as first read by OCR).
  TextColumn get rawText => text()();
  IntColumn get productId => integer().nullable().references(Products, #id)();
  RealColumn get quantity => real().withDefault(const Constant(1))();

  /// 'each', 'kg' or 'lb'.
  TextColumn get unit => text().withDefault(const Constant('each'))();
  IntColumn get unitPriceCents => integer().nullable()();
  IntColumn get lineTotalCents => integer()();
  IntColumn get discountCents => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [Stores, Receipts, Products, ProductAliases, LineItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'slipcheck'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
