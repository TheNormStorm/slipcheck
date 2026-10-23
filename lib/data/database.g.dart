// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $StoresTable extends Stores with TableInfo<$StoresTable, Store> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, normalizedName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stores';
  @override
  VerificationContext validateIntegrity(
    Insertable<Store> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Store map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Store(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
    );
  }

  @override
  $StoresTable createAlias(String alias) {
    return $StoresTable(attachedDatabase, alias);
  }
}

class Store extends DataClass implements Insertable<Store> {
  final int id;
  final String name;

  /// Lowercased, whitespace-collapsed name used to find the store again.
  final String normalizedName;
  const Store({
    required this.id,
    required this.name,
    required this.normalizedName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    return map;
  }

  StoresCompanion toCompanion(bool nullToAbsent) {
    return StoresCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
    );
  }

  factory Store.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Store(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
    };
  }

  Store copyWith({int? id, String? name, String? normalizedName}) => Store(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
  );
  Store copyWithCompanion(StoresCompanion data) {
    return Store(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Store(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, normalizedName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Store &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName);
}

class StoresCompanion extends UpdateCompanion<Store> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> normalizedName;
  const StoresCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
  });
  StoresCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String normalizedName,
  }) : name = Value(name),
       normalizedName = Value(normalizedName);
  static Insertable<Store> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
    });
  }

  StoresCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? normalizedName,
  }) {
    return StoresCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoresCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName')
          ..write(')'))
        .toString();
  }
}

class $ReceiptsTable extends Receipts with TableInfo<$ReceiptsTable, Receipt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<int> storeId = GeneratedColumn<int>(
    'store_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id)',
    ),
  );
  static const VerificationMeta _purchasedAtMeta = const VerificationMeta(
    'purchasedAt',
  );
  @override
  late final GeneratedColumn<DateTime> purchasedAt = GeneratedColumn<DateTime>(
    'purchased_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalCentsMeta = const VerificationMeta(
    'subtotalCents',
  );
  @override
  late final GeneratedColumn<int> subtotalCents = GeneratedColumn<int>(
    'subtotal_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taxCentsMeta = const VerificationMeta(
    'taxCents',
  );
  @override
  late final GeneratedColumn<int> taxCents = GeneratedColumn<int>(
    'tax_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalCentsMeta = const VerificationMeta(
    'totalCents',
  );
  @override
  late final GeneratedColumn<int> totalCents = GeneratedColumn<int>(
    'total_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrTextMeta = const VerificationMeta(
    'ocrText',
  );
  @override
  late final GeneratedColumn<String> ocrText = GeneratedColumn<String>(
    'ocr_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    storeId,
    purchasedAt,
    subtotalCents,
    taxCents,
    totalCents,
    currency,
    imagePath,
    ocrText,
    source,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Receipt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    }
    if (data.containsKey('purchased_at')) {
      context.handle(
        _purchasedAtMeta,
        purchasedAt.isAcceptableOrUnknown(
          data['purchased_at']!,
          _purchasedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purchasedAtMeta);
    }
    if (data.containsKey('subtotal_cents')) {
      context.handle(
        _subtotalCentsMeta,
        subtotalCents.isAcceptableOrUnknown(
          data['subtotal_cents']!,
          _subtotalCentsMeta,
        ),
      );
    }
    if (data.containsKey('tax_cents')) {
      context.handle(
        _taxCentsMeta,
        taxCents.isAcceptableOrUnknown(data['tax_cents']!, _taxCentsMeta),
      );
    }
    if (data.containsKey('total_cents')) {
      context.handle(
        _totalCentsMeta,
        totalCents.isAcceptableOrUnknown(data['total_cents']!, _totalCentsMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('ocr_text')) {
      context.handle(
        _ocrTextMeta,
        ocrText.isAcceptableOrUnknown(data['ocr_text']!, _ocrTextMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Receipt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Receipt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}store_id'],
      ),
      purchasedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}purchased_at'],
      )!,
      subtotalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subtotal_cents'],
      ),
      taxCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tax_cents'],
      ),
      totalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cents'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      ocrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_text'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReceiptsTable createAlias(String alias) {
    return $ReceiptsTable(attachedDatabase, alias);
  }
}

class Receipt extends DataClass implements Insertable<Receipt> {
  final int id;
  final int? storeId;
  final DateTime purchasedAt;
  final int? subtotalCents;
  final int? taxCents;
  final int? totalCents;
  final String currency;

  /// Local path of the first receipt photo. All photos, in order, are in
  /// [ReceiptImages]; this column predates them.
  final String? imagePath;

  /// Raw OCR rows, kept so an improved parser can re-parse old receipts.
  final String? ocrText;

  /// 'photo' or 'manual'.
  final String source;
  final DateTime createdAt;
  const Receipt({
    required this.id,
    this.storeId,
    required this.purchasedAt,
    this.subtotalCents,
    this.taxCents,
    this.totalCents,
    required this.currency,
    this.imagePath,
    this.ocrText,
    required this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || storeId != null) {
      map['store_id'] = Variable<int>(storeId);
    }
    map['purchased_at'] = Variable<DateTime>(purchasedAt);
    if (!nullToAbsent || subtotalCents != null) {
      map['subtotal_cents'] = Variable<int>(subtotalCents);
    }
    if (!nullToAbsent || taxCents != null) {
      map['tax_cents'] = Variable<int>(taxCents);
    }
    if (!nullToAbsent || totalCents != null) {
      map['total_cents'] = Variable<int>(totalCents);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    if (!nullToAbsent || ocrText != null) {
      map['ocr_text'] = Variable<String>(ocrText);
    }
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReceiptsCompanion toCompanion(bool nullToAbsent) {
    return ReceiptsCompanion(
      id: Value(id),
      storeId: storeId == null && nullToAbsent
          ? const Value.absent()
          : Value(storeId),
      purchasedAt: Value(purchasedAt),
      subtotalCents: subtotalCents == null && nullToAbsent
          ? const Value.absent()
          : Value(subtotalCents),
      taxCents: taxCents == null && nullToAbsent
          ? const Value.absent()
          : Value(taxCents),
      totalCents: totalCents == null && nullToAbsent
          ? const Value.absent()
          : Value(totalCents),
      currency: Value(currency),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      ocrText: ocrText == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrText),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory Receipt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Receipt(
      id: serializer.fromJson<int>(json['id']),
      storeId: serializer.fromJson<int?>(json['storeId']),
      purchasedAt: serializer.fromJson<DateTime>(json['purchasedAt']),
      subtotalCents: serializer.fromJson<int?>(json['subtotalCents']),
      taxCents: serializer.fromJson<int?>(json['taxCents']),
      totalCents: serializer.fromJson<int?>(json['totalCents']),
      currency: serializer.fromJson<String>(json['currency']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      ocrText: serializer.fromJson<String?>(json['ocrText']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'storeId': serializer.toJson<int?>(storeId),
      'purchasedAt': serializer.toJson<DateTime>(purchasedAt),
      'subtotalCents': serializer.toJson<int?>(subtotalCents),
      'taxCents': serializer.toJson<int?>(taxCents),
      'totalCents': serializer.toJson<int?>(totalCents),
      'currency': serializer.toJson<String>(currency),
      'imagePath': serializer.toJson<String?>(imagePath),
      'ocrText': serializer.toJson<String?>(ocrText),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Receipt copyWith({
    int? id,
    Value<int?> storeId = const Value.absent(),
    DateTime? purchasedAt,
    Value<int?> subtotalCents = const Value.absent(),
    Value<int?> taxCents = const Value.absent(),
    Value<int?> totalCents = const Value.absent(),
    String? currency,
    Value<String?> imagePath = const Value.absent(),
    Value<String?> ocrText = const Value.absent(),
    String? source,
    DateTime? createdAt,
  }) => Receipt(
    id: id ?? this.id,
    storeId: storeId.present ? storeId.value : this.storeId,
    purchasedAt: purchasedAt ?? this.purchasedAt,
    subtotalCents: subtotalCents.present
        ? subtotalCents.value
        : this.subtotalCents,
    taxCents: taxCents.present ? taxCents.value : this.taxCents,
    totalCents: totalCents.present ? totalCents.value : this.totalCents,
    currency: currency ?? this.currency,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    ocrText: ocrText.present ? ocrText.value : this.ocrText,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  Receipt copyWithCompanion(ReceiptsCompanion data) {
    return Receipt(
      id: data.id.present ? data.id.value : this.id,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
      purchasedAt: data.purchasedAt.present
          ? data.purchasedAt.value
          : this.purchasedAt,
      subtotalCents: data.subtotalCents.present
          ? data.subtotalCents.value
          : this.subtotalCents,
      taxCents: data.taxCents.present ? data.taxCents.value : this.taxCents,
      totalCents: data.totalCents.present
          ? data.totalCents.value
          : this.totalCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      ocrText: data.ocrText.present ? data.ocrText.value : this.ocrText,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Receipt(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('subtotalCents: $subtotalCents, ')
          ..write('taxCents: $taxCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('currency: $currency, ')
          ..write('imagePath: $imagePath, ')
          ..write('ocrText: $ocrText, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    storeId,
    purchasedAt,
    subtotalCents,
    taxCents,
    totalCents,
    currency,
    imagePath,
    ocrText,
    source,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Receipt &&
          other.id == this.id &&
          other.storeId == this.storeId &&
          other.purchasedAt == this.purchasedAt &&
          other.subtotalCents == this.subtotalCents &&
          other.taxCents == this.taxCents &&
          other.totalCents == this.totalCents &&
          other.currency == this.currency &&
          other.imagePath == this.imagePath &&
          other.ocrText == this.ocrText &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class ReceiptsCompanion extends UpdateCompanion<Receipt> {
  final Value<int> id;
  final Value<int?> storeId;
  final Value<DateTime> purchasedAt;
  final Value<int?> subtotalCents;
  final Value<int?> taxCents;
  final Value<int?> totalCents;
  final Value<String> currency;
  final Value<String?> imagePath;
  final Value<String?> ocrText;
  final Value<String> source;
  final Value<DateTime> createdAt;
  const ReceiptsCompanion({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    this.purchasedAt = const Value.absent(),
    this.subtotalCents = const Value.absent(),
    this.taxCents = const Value.absent(),
    this.totalCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.ocrText = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReceiptsCompanion.insert({
    this.id = const Value.absent(),
    this.storeId = const Value.absent(),
    required DateTime purchasedAt,
    this.subtotalCents = const Value.absent(),
    this.taxCents = const Value.absent(),
    this.totalCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.ocrText = const Value.absent(),
    required String source,
    this.createdAt = const Value.absent(),
  }) : purchasedAt = Value(purchasedAt),
       source = Value(source);
  static Insertable<Receipt> custom({
    Expression<int>? id,
    Expression<int>? storeId,
    Expression<DateTime>? purchasedAt,
    Expression<int>? subtotalCents,
    Expression<int>? taxCents,
    Expression<int>? totalCents,
    Expression<String>? currency,
    Expression<String>? imagePath,
    Expression<String>? ocrText,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeId != null) 'store_id': storeId,
      if (purchasedAt != null) 'purchased_at': purchasedAt,
      if (subtotalCents != null) 'subtotal_cents': subtotalCents,
      if (taxCents != null) 'tax_cents': taxCents,
      if (totalCents != null) 'total_cents': totalCents,
      if (currency != null) 'currency': currency,
      if (imagePath != null) 'image_path': imagePath,
      if (ocrText != null) 'ocr_text': ocrText,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReceiptsCompanion copyWith({
    Value<int>? id,
    Value<int?>? storeId,
    Value<DateTime>? purchasedAt,
    Value<int?>? subtotalCents,
    Value<int?>? taxCents,
    Value<int?>? totalCents,
    Value<String>? currency,
    Value<String?>? imagePath,
    Value<String?>? ocrText,
    Value<String>? source,
    Value<DateTime>? createdAt,
  }) {
    return ReceiptsCompanion(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      taxCents: taxCents ?? this.taxCents,
      totalCents: totalCents ?? this.totalCents,
      currency: currency ?? this.currency,
      imagePath: imagePath ?? this.imagePath,
      ocrText: ocrText ?? this.ocrText,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<int>(storeId.value);
    }
    if (purchasedAt.present) {
      map['purchased_at'] = Variable<DateTime>(purchasedAt.value);
    }
    if (subtotalCents.present) {
      map['subtotal_cents'] = Variable<int>(subtotalCents.value);
    }
    if (taxCents.present) {
      map['tax_cents'] = Variable<int>(taxCents.value);
    }
    if (totalCents.present) {
      map['total_cents'] = Variable<int>(totalCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (ocrText.present) {
      map['ocr_text'] = Variable<String>(ocrText.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptsCompanion(')
          ..write('id: $id, ')
          ..write('storeId: $storeId, ')
          ..write('purchasedAt: $purchasedAt, ')
          ..write('subtotalCents: $subtotalCents, ')
          ..write('taxCents: $taxCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('currency: $currency, ')
          ..write('imagePath: $imagePath, ')
          ..write('ocrText: $ocrText, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ReceiptImagesTable extends ReceiptImages
    with TableInfo<$ReceiptImagesTable, ReceiptImage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReceiptImagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<int> receiptId = GeneratedColumn<int>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, receiptId, position, path];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'receipt_images';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReceiptImage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReceiptImage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReceiptImage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
    );
  }

  @override
  $ReceiptImagesTable createAlias(String alias) {
    return $ReceiptImagesTable(attachedDatabase, alias);
  }
}

class ReceiptImage extends DataClass implements Insertable<ReceiptImage> {
  final int id;
  final int receiptId;
  final int position;
  final String path;
  const ReceiptImage({
    required this.id,
    required this.receiptId,
    required this.position,
    required this.path,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['receipt_id'] = Variable<int>(receiptId);
    map['position'] = Variable<int>(position);
    map['path'] = Variable<String>(path);
    return map;
  }

  ReceiptImagesCompanion toCompanion(bool nullToAbsent) {
    return ReceiptImagesCompanion(
      id: Value(id),
      receiptId: Value(receiptId),
      position: Value(position),
      path: Value(path),
    );
  }

  factory ReceiptImage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReceiptImage(
      id: serializer.fromJson<int>(json['id']),
      receiptId: serializer.fromJson<int>(json['receiptId']),
      position: serializer.fromJson<int>(json['position']),
      path: serializer.fromJson<String>(json['path']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'receiptId': serializer.toJson<int>(receiptId),
      'position': serializer.toJson<int>(position),
      'path': serializer.toJson<String>(path),
    };
  }

  ReceiptImage copyWith({
    int? id,
    int? receiptId,
    int? position,
    String? path,
  }) => ReceiptImage(
    id: id ?? this.id,
    receiptId: receiptId ?? this.receiptId,
    position: position ?? this.position,
    path: path ?? this.path,
  );
  ReceiptImage copyWithCompanion(ReceiptImagesCompanion data) {
    return ReceiptImage(
      id: data.id.present ? data.id.value : this.id,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      position: data.position.present ? data.position.value : this.position,
      path: data.path.present ? data.path.value : this.path,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptImage(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('position: $position, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, receiptId, position, path);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReceiptImage &&
          other.id == this.id &&
          other.receiptId == this.receiptId &&
          other.position == this.position &&
          other.path == this.path);
}

class ReceiptImagesCompanion extends UpdateCompanion<ReceiptImage> {
  final Value<int> id;
  final Value<int> receiptId;
  final Value<int> position;
  final Value<String> path;
  const ReceiptImagesCompanion({
    this.id = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.position = const Value.absent(),
    this.path = const Value.absent(),
  });
  ReceiptImagesCompanion.insert({
    this.id = const Value.absent(),
    required int receiptId,
    required int position,
    required String path,
  }) : receiptId = Value(receiptId),
       position = Value(position),
       path = Value(path);
  static Insertable<ReceiptImage> custom({
    Expression<int>? id,
    Expression<int>? receiptId,
    Expression<int>? position,
    Expression<String>? path,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiptId != null) 'receipt_id': receiptId,
      if (position != null) 'position': position,
      if (path != null) 'path': path,
    });
  }

  ReceiptImagesCompanion copyWith({
    Value<int>? id,
    Value<int>? receiptId,
    Value<int>? position,
    Value<String>? path,
  }) {
    return ReceiptImagesCompanion(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      position: position ?? this.position,
      path: path ?? this.path,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<int>(receiptId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReceiptImagesCompanion(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('position: $position, ')
          ..write('path: $path')
          ..write(')'))
        .toString();
  }
}

class $ProductsTable extends Products with TableInfo<$ProductsTable, Product> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _canonicalKeyMeta = const VerificationMeta(
    'canonicalKey',
  );
  @override
  late final GeneratedColumn<String> canonicalKey = GeneratedColumn<String>(
    'canonical_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeValueMeta = const VerificationMeta(
    'sizeValue',
  );
  @override
  late final GeneratedColumn<double> sizeValue = GeneratedColumn<double>(
    'size_value',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeUnitMeta = const VerificationMeta(
    'sizeUnit',
  );
  @override
  late final GeneratedColumn<String> sizeUnit = GeneratedColumn<String>(
    'size_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packCountMeta = const VerificationMeta(
    'packCount',
  );
  @override
  late final GeneratedColumn<int> packCount = GeneratedColumn<int>(
    'pack_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    canonicalKey,
    displayName,
    sizeValue,
    sizeUnit,
    packCount,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'products';
  @override
  VerificationContext validateIntegrity(
    Insertable<Product> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('canonical_key')) {
      context.handle(
        _canonicalKeyMeta,
        canonicalKey.isAcceptableOrUnknown(
          data['canonical_key']!,
          _canonicalKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalKeyMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('size_value')) {
      context.handle(
        _sizeValueMeta,
        sizeValue.isAcceptableOrUnknown(data['size_value']!, _sizeValueMeta),
      );
    }
    if (data.containsKey('size_unit')) {
      context.handle(
        _sizeUnitMeta,
        sizeUnit.isAcceptableOrUnknown(data['size_unit']!, _sizeUnitMeta),
      );
    }
    if (data.containsKey('pack_count')) {
      context.handle(
        _packCountMeta,
        packCount.isAcceptableOrUnknown(data['pack_count']!, _packCountMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Product map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Product(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      canonicalKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_key'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      sizeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}size_value'],
      ),
      sizeUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size_unit'],
      ),
      packCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pack_count'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
    );
  }

  @override
  $ProductsTable createAlias(String alias) {
    return $ProductsTable(attachedDatabase, alias);
  }
}

class Product extends DataClass implements Insertable<Product> {
  final int id;

  /// `NormalizedProduct.key`, e.g. "milk 2% 1000ml".
  final String canonicalKey;
  final String displayName;
  final double? sizeValue;
  final String? sizeUnit;
  final int? packCount;

  /// `Category.name`; set from the receipt's department heading or keyword
  /// rules when the product is created, and changeable by the user.
  final String? category;
  const Product({
    required this.id,
    required this.canonicalKey,
    required this.displayName,
    this.sizeValue,
    this.sizeUnit,
    this.packCount,
    this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['canonical_key'] = Variable<String>(canonicalKey);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || sizeValue != null) {
      map['size_value'] = Variable<double>(sizeValue);
    }
    if (!nullToAbsent || sizeUnit != null) {
      map['size_unit'] = Variable<String>(sizeUnit);
    }
    if (!nullToAbsent || packCount != null) {
      map['pack_count'] = Variable<int>(packCount);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    return map;
  }

  ProductsCompanion toCompanion(bool nullToAbsent) {
    return ProductsCompanion(
      id: Value(id),
      canonicalKey: Value(canonicalKey),
      displayName: Value(displayName),
      sizeValue: sizeValue == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeValue),
      sizeUnit: sizeUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeUnit),
      packCount: packCount == null && nullToAbsent
          ? const Value.absent()
          : Value(packCount),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory Product.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Product(
      id: serializer.fromJson<int>(json['id']),
      canonicalKey: serializer.fromJson<String>(json['canonicalKey']),
      displayName: serializer.fromJson<String>(json['displayName']),
      sizeValue: serializer.fromJson<double?>(json['sizeValue']),
      sizeUnit: serializer.fromJson<String?>(json['sizeUnit']),
      packCount: serializer.fromJson<int?>(json['packCount']),
      category: serializer.fromJson<String?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'canonicalKey': serializer.toJson<String>(canonicalKey),
      'displayName': serializer.toJson<String>(displayName),
      'sizeValue': serializer.toJson<double?>(sizeValue),
      'sizeUnit': serializer.toJson<String?>(sizeUnit),
      'packCount': serializer.toJson<int?>(packCount),
      'category': serializer.toJson<String?>(category),
    };
  }

  Product copyWith({
    int? id,
    String? canonicalKey,
    String? displayName,
    Value<double?> sizeValue = const Value.absent(),
    Value<String?> sizeUnit = const Value.absent(),
    Value<int?> packCount = const Value.absent(),
    Value<String?> category = const Value.absent(),
  }) => Product(
    id: id ?? this.id,
    canonicalKey: canonicalKey ?? this.canonicalKey,
    displayName: displayName ?? this.displayName,
    sizeValue: sizeValue.present ? sizeValue.value : this.sizeValue,
    sizeUnit: sizeUnit.present ? sizeUnit.value : this.sizeUnit,
    packCount: packCount.present ? packCount.value : this.packCount,
    category: category.present ? category.value : this.category,
  );
  Product copyWithCompanion(ProductsCompanion data) {
    return Product(
      id: data.id.present ? data.id.value : this.id,
      canonicalKey: data.canonicalKey.present
          ? data.canonicalKey.value
          : this.canonicalKey,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      sizeValue: data.sizeValue.present ? data.sizeValue.value : this.sizeValue,
      sizeUnit: data.sizeUnit.present ? data.sizeUnit.value : this.sizeUnit,
      packCount: data.packCount.present ? data.packCount.value : this.packCount,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Product(')
          ..write('id: $id, ')
          ..write('canonicalKey: $canonicalKey, ')
          ..write('displayName: $displayName, ')
          ..write('sizeValue: $sizeValue, ')
          ..write('sizeUnit: $sizeUnit, ')
          ..write('packCount: $packCount, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    canonicalKey,
    displayName,
    sizeValue,
    sizeUnit,
    packCount,
    category,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Product &&
          other.id == this.id &&
          other.canonicalKey == this.canonicalKey &&
          other.displayName == this.displayName &&
          other.sizeValue == this.sizeValue &&
          other.sizeUnit == this.sizeUnit &&
          other.packCount == this.packCount &&
          other.category == this.category);
}

class ProductsCompanion extends UpdateCompanion<Product> {
  final Value<int> id;
  final Value<String> canonicalKey;
  final Value<String> displayName;
  final Value<double?> sizeValue;
  final Value<String?> sizeUnit;
  final Value<int?> packCount;
  final Value<String?> category;
  const ProductsCompanion({
    this.id = const Value.absent(),
    this.canonicalKey = const Value.absent(),
    this.displayName = const Value.absent(),
    this.sizeValue = const Value.absent(),
    this.sizeUnit = const Value.absent(),
    this.packCount = const Value.absent(),
    this.category = const Value.absent(),
  });
  ProductsCompanion.insert({
    this.id = const Value.absent(),
    required String canonicalKey,
    required String displayName,
    this.sizeValue = const Value.absent(),
    this.sizeUnit = const Value.absent(),
    this.packCount = const Value.absent(),
    this.category = const Value.absent(),
  }) : canonicalKey = Value(canonicalKey),
       displayName = Value(displayName);
  static Insertable<Product> custom({
    Expression<int>? id,
    Expression<String>? canonicalKey,
    Expression<String>? displayName,
    Expression<double>? sizeValue,
    Expression<String>? sizeUnit,
    Expression<int>? packCount,
    Expression<String>? category,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (canonicalKey != null) 'canonical_key': canonicalKey,
      if (displayName != null) 'display_name': displayName,
      if (sizeValue != null) 'size_value': sizeValue,
      if (sizeUnit != null) 'size_unit': sizeUnit,
      if (packCount != null) 'pack_count': packCount,
      if (category != null) 'category': category,
    });
  }

  ProductsCompanion copyWith({
    Value<int>? id,
    Value<String>? canonicalKey,
    Value<String>? displayName,
    Value<double?>? sizeValue,
    Value<String?>? sizeUnit,
    Value<int?>? packCount,
    Value<String?>? category,
  }) {
    return ProductsCompanion(
      id: id ?? this.id,
      canonicalKey: canonicalKey ?? this.canonicalKey,
      displayName: displayName ?? this.displayName,
      sizeValue: sizeValue ?? this.sizeValue,
      sizeUnit: sizeUnit ?? this.sizeUnit,
      packCount: packCount ?? this.packCount,
      category: category ?? this.category,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (canonicalKey.present) {
      map['canonical_key'] = Variable<String>(canonicalKey.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (sizeValue.present) {
      map['size_value'] = Variable<double>(sizeValue.value);
    }
    if (sizeUnit.present) {
      map['size_unit'] = Variable<String>(sizeUnit.value);
    }
    if (packCount.present) {
      map['pack_count'] = Variable<int>(packCount.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductsCompanion(')
          ..write('id: $id, ')
          ..write('canonicalKey: $canonicalKey, ')
          ..write('displayName: $displayName, ')
          ..write('sizeValue: $sizeValue, ')
          ..write('sizeUnit: $sizeUnit, ')
          ..write('packCount: $packCount, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }
}

class $ProductAliasesTable extends ProductAliases
    with TableInfo<$ProductAliasesTable, ProductAliase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _aliasKeyMeta = const VerificationMeta(
    'aliasKey',
  );
  @override
  late final GeneratedColumn<String> aliasKey = GeneratedColumn<String>(
    'alias_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _storeIdMeta = const VerificationMeta(
    'storeId',
  );
  @override
  late final GeneratedColumn<int> storeId = GeneratedColumn<int>(
    'store_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stores (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id, aliasKey, productId, storeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductAliase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('alias_key')) {
      context.handle(
        _aliasKeyMeta,
        aliasKey.isAcceptableOrUnknown(data['alias_key']!, _aliasKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasKeyMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('store_id')) {
      context.handle(
        _storeIdMeta,
        storeId.isAcceptableOrUnknown(data['store_id']!, _storeIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductAliase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductAliase(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      aliasKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias_key'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      )!,
      storeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}store_id'],
      ),
    );
  }

  @override
  $ProductAliasesTable createAlias(String alias) {
    return $ProductAliasesTable(attachedDatabase, alias);
  }
}

class ProductAliase extends DataClass implements Insertable<ProductAliase> {
  final int id;
  final String aliasKey;
  final int productId;

  /// Null means the alias applies at every store.
  final int? storeId;
  const ProductAliase({
    required this.id,
    required this.aliasKey,
    required this.productId,
    this.storeId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['alias_key'] = Variable<String>(aliasKey);
    map['product_id'] = Variable<int>(productId);
    if (!nullToAbsent || storeId != null) {
      map['store_id'] = Variable<int>(storeId);
    }
    return map;
  }

  ProductAliasesCompanion toCompanion(bool nullToAbsent) {
    return ProductAliasesCompanion(
      id: Value(id),
      aliasKey: Value(aliasKey),
      productId: Value(productId),
      storeId: storeId == null && nullToAbsent
          ? const Value.absent()
          : Value(storeId),
    );
  }

  factory ProductAliase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductAliase(
      id: serializer.fromJson<int>(json['id']),
      aliasKey: serializer.fromJson<String>(json['aliasKey']),
      productId: serializer.fromJson<int>(json['productId']),
      storeId: serializer.fromJson<int?>(json['storeId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'aliasKey': serializer.toJson<String>(aliasKey),
      'productId': serializer.toJson<int>(productId),
      'storeId': serializer.toJson<int?>(storeId),
    };
  }

  ProductAliase copyWith({
    int? id,
    String? aliasKey,
    int? productId,
    Value<int?> storeId = const Value.absent(),
  }) => ProductAliase(
    id: id ?? this.id,
    aliasKey: aliasKey ?? this.aliasKey,
    productId: productId ?? this.productId,
    storeId: storeId.present ? storeId.value : this.storeId,
  );
  ProductAliase copyWithCompanion(ProductAliasesCompanion data) {
    return ProductAliase(
      id: data.id.present ? data.id.value : this.id,
      aliasKey: data.aliasKey.present ? data.aliasKey.value : this.aliasKey,
      productId: data.productId.present ? data.productId.value : this.productId,
      storeId: data.storeId.present ? data.storeId.value : this.storeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductAliase(')
          ..write('id: $id, ')
          ..write('aliasKey: $aliasKey, ')
          ..write('productId: $productId, ')
          ..write('storeId: $storeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, aliasKey, productId, storeId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductAliase &&
          other.id == this.id &&
          other.aliasKey == this.aliasKey &&
          other.productId == this.productId &&
          other.storeId == this.storeId);
}

class ProductAliasesCompanion extends UpdateCompanion<ProductAliase> {
  final Value<int> id;
  final Value<String> aliasKey;
  final Value<int> productId;
  final Value<int?> storeId;
  const ProductAliasesCompanion({
    this.id = const Value.absent(),
    this.aliasKey = const Value.absent(),
    this.productId = const Value.absent(),
    this.storeId = const Value.absent(),
  });
  ProductAliasesCompanion.insert({
    this.id = const Value.absent(),
    required String aliasKey,
    required int productId,
    this.storeId = const Value.absent(),
  }) : aliasKey = Value(aliasKey),
       productId = Value(productId);
  static Insertable<ProductAliase> custom({
    Expression<int>? id,
    Expression<String>? aliasKey,
    Expression<int>? productId,
    Expression<int>? storeId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (aliasKey != null) 'alias_key': aliasKey,
      if (productId != null) 'product_id': productId,
      if (storeId != null) 'store_id': storeId,
    });
  }

  ProductAliasesCompanion copyWith({
    Value<int>? id,
    Value<String>? aliasKey,
    Value<int>? productId,
    Value<int?>? storeId,
  }) {
    return ProductAliasesCompanion(
      id: id ?? this.id,
      aliasKey: aliasKey ?? this.aliasKey,
      productId: productId ?? this.productId,
      storeId: storeId ?? this.storeId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (aliasKey.present) {
      map['alias_key'] = Variable<String>(aliasKey.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (storeId.present) {
      map['store_id'] = Variable<int>(storeId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductAliasesCompanion(')
          ..write('id: $id, ')
          ..write('aliasKey: $aliasKey, ')
          ..write('productId: $productId, ')
          ..write('storeId: $storeId')
          ..write(')'))
        .toString();
  }
}

class $LineItemsTable extends LineItems
    with TableInfo<$LineItemsTable, LineItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LineItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _receiptIdMeta = const VerificationMeta(
    'receiptId',
  );
  @override
  late final GeneratedColumn<int> receiptId = GeneratedColumn<int>(
    'receipt_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES receipts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawTextMeta = const VerificationMeta(
    'rawText',
  );
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
    'raw_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<int> productId = GeneratedColumn<int>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES products (id)',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('each'),
  );
  static const VerificationMeta _unitPriceCentsMeta = const VerificationMeta(
    'unitPriceCents',
  );
  @override
  late final GeneratedColumn<int> unitPriceCents = GeneratedColumn<int>(
    'unit_price_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lineTotalCentsMeta = const VerificationMeta(
    'lineTotalCents',
  );
  @override
  late final GeneratedColumn<int> lineTotalCents = GeneratedColumn<int>(
    'line_total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountCentsMeta = const VerificationMeta(
    'discountCents',
  );
  @override
  late final GeneratedColumn<int> discountCents = GeneratedColumn<int>(
    'discount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sectionMeta = const VerificationMeta(
    'section',
  );
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
    'section',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    receiptId,
    position,
    rawText,
    productId,
    quantity,
    unit,
    unitPriceCents,
    lineTotalCents,
    discountCents,
    code,
    section,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'line_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LineItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('receipt_id')) {
      context.handle(
        _receiptIdMeta,
        receiptId.isAcceptableOrUnknown(data['receipt_id']!, _receiptIdMeta),
      );
    } else if (isInserting) {
      context.missing(_receiptIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(
        _rawTextMeta,
        rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta),
      );
    } else if (isInserting) {
      context.missing(_rawTextMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('unit_price_cents')) {
      context.handle(
        _unitPriceCentsMeta,
        unitPriceCents.isAcceptableOrUnknown(
          data['unit_price_cents']!,
          _unitPriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('line_total_cents')) {
      context.handle(
        _lineTotalCentsMeta,
        lineTotalCents.isAcceptableOrUnknown(
          data['line_total_cents']!,
          _lineTotalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lineTotalCentsMeta);
    }
    if (data.containsKey('discount_cents')) {
      context.handle(
        _discountCentsMeta,
        discountCents.isAcceptableOrUnknown(
          data['discount_cents']!,
          _discountCentsMeta,
        ),
      );
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    }
    if (data.containsKey('section')) {
      context.handle(
        _sectionMeta,
        section.isAcceptableOrUnknown(data['section']!, _sectionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LineItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LineItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      receiptId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}receipt_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      rawText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_text'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}product_id'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      unitPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unit_price_cents'],
      ),
      lineTotalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_total_cents'],
      )!,
      discountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_cents'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      ),
      section: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section'],
      ),
    );
  }

  @override
  $LineItemsTable createAlias(String alias) {
    return $LineItemsTable(attachedDatabase, alias);
  }
}

class LineItem extends DataClass implements Insertable<LineItem> {
  final int id;
  final int receiptId;
  final int position;

  /// The line as printed (or as first read by OCR).
  final String rawText;
  final int? productId;
  final double quantity;

  /// 'each', 'kg' or 'lb'.
  final String unit;
  final int? unitPriceCents;
  final int lineTotalCents;
  final int discountCents;

  /// Barcode (UPC/EAN) or produce PLU printed on the line, when readable.
  final String? code;

  /// Department heading the line was printed under ("PRODUCE DEPT").
  final String? section;
  const LineItem({
    required this.id,
    required this.receiptId,
    required this.position,
    required this.rawText,
    this.productId,
    required this.quantity,
    required this.unit,
    this.unitPriceCents,
    required this.lineTotalCents,
    required this.discountCents,
    this.code,
    this.section,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['receipt_id'] = Variable<int>(receiptId);
    map['position'] = Variable<int>(position);
    map['raw_text'] = Variable<String>(rawText);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<int>(productId);
    }
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || unitPriceCents != null) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents);
    }
    map['line_total_cents'] = Variable<int>(lineTotalCents);
    map['discount_cents'] = Variable<int>(discountCents);
    if (!nullToAbsent || code != null) {
      map['code'] = Variable<String>(code);
    }
    if (!nullToAbsent || section != null) {
      map['section'] = Variable<String>(section);
    }
    return map;
  }

  LineItemsCompanion toCompanion(bool nullToAbsent) {
    return LineItemsCompanion(
      id: Value(id),
      receiptId: Value(receiptId),
      position: Value(position),
      rawText: Value(rawText),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      quantity: Value(quantity),
      unit: Value(unit),
      unitPriceCents: unitPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(unitPriceCents),
      lineTotalCents: Value(lineTotalCents),
      discountCents: Value(discountCents),
      code: code == null && nullToAbsent ? const Value.absent() : Value(code),
      section: section == null && nullToAbsent
          ? const Value.absent()
          : Value(section),
    );
  }

  factory LineItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LineItem(
      id: serializer.fromJson<int>(json['id']),
      receiptId: serializer.fromJson<int>(json['receiptId']),
      position: serializer.fromJson<int>(json['position']),
      rawText: serializer.fromJson<String>(json['rawText']),
      productId: serializer.fromJson<int?>(json['productId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      unitPriceCents: serializer.fromJson<int?>(json['unitPriceCents']),
      lineTotalCents: serializer.fromJson<int>(json['lineTotalCents']),
      discountCents: serializer.fromJson<int>(json['discountCents']),
      code: serializer.fromJson<String?>(json['code']),
      section: serializer.fromJson<String?>(json['section']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'receiptId': serializer.toJson<int>(receiptId),
      'position': serializer.toJson<int>(position),
      'rawText': serializer.toJson<String>(rawText),
      'productId': serializer.toJson<int?>(productId),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'unitPriceCents': serializer.toJson<int?>(unitPriceCents),
      'lineTotalCents': serializer.toJson<int>(lineTotalCents),
      'discountCents': serializer.toJson<int>(discountCents),
      'code': serializer.toJson<String?>(code),
      'section': serializer.toJson<String?>(section),
    };
  }

  LineItem copyWith({
    int? id,
    int? receiptId,
    int? position,
    String? rawText,
    Value<int?> productId = const Value.absent(),
    double? quantity,
    String? unit,
    Value<int?> unitPriceCents = const Value.absent(),
    int? lineTotalCents,
    int? discountCents,
    Value<String?> code = const Value.absent(),
    Value<String?> section = const Value.absent(),
  }) => LineItem(
    id: id ?? this.id,
    receiptId: receiptId ?? this.receiptId,
    position: position ?? this.position,
    rawText: rawText ?? this.rawText,
    productId: productId.present ? productId.value : this.productId,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    unitPriceCents: unitPriceCents.present
        ? unitPriceCents.value
        : this.unitPriceCents,
    lineTotalCents: lineTotalCents ?? this.lineTotalCents,
    discountCents: discountCents ?? this.discountCents,
    code: code.present ? code.value : this.code,
    section: section.present ? section.value : this.section,
  );
  LineItem copyWithCompanion(LineItemsCompanion data) {
    return LineItem(
      id: data.id.present ? data.id.value : this.id,
      receiptId: data.receiptId.present ? data.receiptId.value : this.receiptId,
      position: data.position.present ? data.position.value : this.position,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      productId: data.productId.present ? data.productId.value : this.productId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      unitPriceCents: data.unitPriceCents.present
          ? data.unitPriceCents.value
          : this.unitPriceCents,
      lineTotalCents: data.lineTotalCents.present
          ? data.lineTotalCents.value
          : this.lineTotalCents,
      discountCents: data.discountCents.present
          ? data.discountCents.value
          : this.discountCents,
      code: data.code.present ? data.code.value : this.code,
      section: data.section.present ? data.section.value : this.section,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LineItem(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('position: $position, ')
          ..write('rawText: $rawText, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('lineTotalCents: $lineTotalCents, ')
          ..write('discountCents: $discountCents, ')
          ..write('code: $code, ')
          ..write('section: $section')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    receiptId,
    position,
    rawText,
    productId,
    quantity,
    unit,
    unitPriceCents,
    lineTotalCents,
    discountCents,
    code,
    section,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LineItem &&
          other.id == this.id &&
          other.receiptId == this.receiptId &&
          other.position == this.position &&
          other.rawText == this.rawText &&
          other.productId == this.productId &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.unitPriceCents == this.unitPriceCents &&
          other.lineTotalCents == this.lineTotalCents &&
          other.discountCents == this.discountCents &&
          other.code == this.code &&
          other.section == this.section);
}

class LineItemsCompanion extends UpdateCompanion<LineItem> {
  final Value<int> id;
  final Value<int> receiptId;
  final Value<int> position;
  final Value<String> rawText;
  final Value<int?> productId;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<int?> unitPriceCents;
  final Value<int> lineTotalCents;
  final Value<int> discountCents;
  final Value<String?> code;
  final Value<String?> section;
  const LineItemsCompanion({
    this.id = const Value.absent(),
    this.receiptId = const Value.absent(),
    this.position = const Value.absent(),
    this.rawText = const Value.absent(),
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    this.lineTotalCents = const Value.absent(),
    this.discountCents = const Value.absent(),
    this.code = const Value.absent(),
    this.section = const Value.absent(),
  });
  LineItemsCompanion.insert({
    this.id = const Value.absent(),
    required int receiptId,
    required int position,
    required String rawText,
    this.productId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.unitPriceCents = const Value.absent(),
    required int lineTotalCents,
    this.discountCents = const Value.absent(),
    this.code = const Value.absent(),
    this.section = const Value.absent(),
  }) : receiptId = Value(receiptId),
       position = Value(position),
       rawText = Value(rawText),
       lineTotalCents = Value(lineTotalCents);
  static Insertable<LineItem> custom({
    Expression<int>? id,
    Expression<int>? receiptId,
    Expression<int>? position,
    Expression<String>? rawText,
    Expression<int>? productId,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<int>? unitPriceCents,
    Expression<int>? lineTotalCents,
    Expression<int>? discountCents,
    Expression<String>? code,
    Expression<String>? section,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (receiptId != null) 'receipt_id': receiptId,
      if (position != null) 'position': position,
      if (rawText != null) 'raw_text': rawText,
      if (productId != null) 'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (unitPriceCents != null) 'unit_price_cents': unitPriceCents,
      if (lineTotalCents != null) 'line_total_cents': lineTotalCents,
      if (discountCents != null) 'discount_cents': discountCents,
      if (code != null) 'code': code,
      if (section != null) 'section': section,
    });
  }

  LineItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? receiptId,
    Value<int>? position,
    Value<String>? rawText,
    Value<int?>? productId,
    Value<double>? quantity,
    Value<String>? unit,
    Value<int?>? unitPriceCents,
    Value<int>? lineTotalCents,
    Value<int>? discountCents,
    Value<String?>? code,
    Value<String?>? section,
  }) {
    return LineItemsCompanion(
      id: id ?? this.id,
      receiptId: receiptId ?? this.receiptId,
      position: position ?? this.position,
      rawText: rawText ?? this.rawText,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      lineTotalCents: lineTotalCents ?? this.lineTotalCents,
      discountCents: discountCents ?? this.discountCents,
      code: code ?? this.code,
      section: section ?? this.section,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (receiptId.present) {
      map['receipt_id'] = Variable<int>(receiptId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<int>(productId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (unitPriceCents.present) {
      map['unit_price_cents'] = Variable<int>(unitPriceCents.value);
    }
    if (lineTotalCents.present) {
      map['line_total_cents'] = Variable<int>(lineTotalCents.value);
    }
    if (discountCents.present) {
      map['discount_cents'] = Variable<int>(discountCents.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LineItemsCompanion(')
          ..write('id: $id, ')
          ..write('receiptId: $receiptId, ')
          ..write('position: $position, ')
          ..write('rawText: $rawText, ')
          ..write('productId: $productId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('unitPriceCents: $unitPriceCents, ')
          ..write('lineTotalCents: $lineTotalCents, ')
          ..write('discountCents: $discountCents, ')
          ..write('code: $code, ')
          ..write('section: $section')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $StoresTable stores = $StoresTable(this);
  late final $ReceiptsTable receipts = $ReceiptsTable(this);
  late final $ReceiptImagesTable receiptImages = $ReceiptImagesTable(this);
  late final $ProductsTable products = $ProductsTable(this);
  late final $ProductAliasesTable productAliases = $ProductAliasesTable(this);
  late final $LineItemsTable lineItems = $LineItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    stores,
    receipts,
    receiptImages,
    products,
    productAliases,
    lineItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'receipts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('receipt_images', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'receipts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('line_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$StoresTableCreateCompanionBuilder =
    StoresCompanion Function({
      Value<int> id,
      required String name,
      required String normalizedName,
    });
typedef $$StoresTableUpdateCompanionBuilder =
    StoresCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> normalizedName,
    });

final class $$StoresTableReferences
    extends BaseReferences<_$AppDatabase, $StoresTable, Store> {
  $$StoresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ReceiptsTable, List<Receipt>> _receiptsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.receipts,
    aliasName: 'stores__id__receipts__store_id',
  );

  $$ReceiptsTableProcessedTableManager get receiptsRefs {
    final manager = $$ReceiptsTableTableManager(
      $_db,
      $_db.receipts,
    ).filter((f) => f.storeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProductAliasesTable, List<ProductAliase>>
  _productAliasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productAliases,
    aliasName: 'stores__id__product_aliases__store_id',
  );

  $$ProductAliasesTableProcessedTableManager get productAliasesRefs {
    final manager = $$ProductAliasesTableTableManager(
      $_db,
      $_db.productAliases,
    ).filter((f) => f.storeId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_productAliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StoresTableFilterComposer
    extends Composer<_$AppDatabase, $StoresTable> {
  $$StoresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> receiptsRefs(
    Expression<bool> Function($$ReceiptsTableFilterComposer f) f,
  ) {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.storeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> productAliasesRefs(
    Expression<bool> Function($$ProductAliasesTableFilterComposer f) f,
  ) {
    final $$ProductAliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productAliases,
      getReferencedColumn: (t) => t.storeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductAliasesTableFilterComposer(
            $db: $db,
            $table: $db.productAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StoresTableOrderingComposer
    extends Composer<_$AppDatabase, $StoresTable> {
  $$StoresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoresTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoresTable> {
  $$StoresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  Expression<T> receiptsRefs<T extends Object>(
    Expression<T> Function($$ReceiptsTableAnnotationComposer a) f,
  ) {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.storeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> productAliasesRefs<T extends Object>(
    Expression<T> Function($$ProductAliasesTableAnnotationComposer a) f,
  ) {
    final $$ProductAliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productAliases,
      getReferencedColumn: (t) => t.storeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductAliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.productAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StoresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoresTable,
          Store,
          $$StoresTableFilterComposer,
          $$StoresTableOrderingComposer,
          $$StoresTableAnnotationComposer,
          $$StoresTableCreateCompanionBuilder,
          $$StoresTableUpdateCompanionBuilder,
          (Store, $$StoresTableReferences),
          Store,
          PrefetchHooks Function({bool receiptsRefs, bool productAliasesRefs})
        > {
  $$StoresTableTableManager(_$AppDatabase db, $StoresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StoresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StoresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
              }) => StoresCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String normalizedName,
              }) => StoresCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StoresTable, Store>(table),
                  $$StoresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({receiptsRefs = false, productAliasesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (receiptsRefs) db.receipts,
                    if (productAliasesRefs) db.productAliases,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (receiptsRefs)
                        await $_getPrefetchedData<Store, $StoresTable, Receipt>(
                          currentTable: table,
                          referencedTable: $$StoresTableReferences
                              ._receiptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoresTableReferences(
                                db,
                                table,
                                p0,
                              ).receiptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.storeId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (productAliasesRefs)
                        await $_getPrefetchedData<
                          Store,
                          $StoresTable,
                          ProductAliase
                        >(
                          currentTable: table,
                          referencedTable: $$StoresTableReferences
                              ._productAliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StoresTableReferences(
                                db,
                                table,
                                p0,
                              ).productAliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.storeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StoresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoresTable,
      Store,
      $$StoresTableFilterComposer,
      $$StoresTableOrderingComposer,
      $$StoresTableAnnotationComposer,
      $$StoresTableCreateCompanionBuilder,
      $$StoresTableUpdateCompanionBuilder,
      (Store, $$StoresTableReferences),
      Store,
      PrefetchHooks Function({bool receiptsRefs, bool productAliasesRefs})
    >;
typedef $$ReceiptsTableCreateCompanionBuilder =
    ReceiptsCompanion Function({
      Value<int> id,
      Value<int?> storeId,
      required DateTime purchasedAt,
      Value<int?> subtotalCents,
      Value<int?> taxCents,
      Value<int?> totalCents,
      Value<String> currency,
      Value<String?> imagePath,
      Value<String?> ocrText,
      required String source,
      Value<DateTime> createdAt,
    });
typedef $$ReceiptsTableUpdateCompanionBuilder =
    ReceiptsCompanion Function({
      Value<int> id,
      Value<int?> storeId,
      Value<DateTime> purchasedAt,
      Value<int?> subtotalCents,
      Value<int?> taxCents,
      Value<int?> totalCents,
      Value<String> currency,
      Value<String?> imagePath,
      Value<String?> ocrText,
      Value<String> source,
      Value<DateTime> createdAt,
    });

final class $$ReceiptsTableReferences
    extends BaseReferences<_$AppDatabase, $ReceiptsTable, Receipt> {
  $$ReceiptsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StoresTable _storeIdTable(_$AppDatabase db) =>
      db.stores.createAlias('receipts__store_id__stores__id');

  $$StoresTableProcessedTableManager? get storeId {
    final $_column = $_itemColumn<int>('store_id');
    if ($_column == null) return null;
    final manager = $$StoresTableTableManager(
      $_db,
      $_db.stores,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_storeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ReceiptImagesTable, List<ReceiptImage>>
  _receiptImagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.receiptImages,
    aliasName: 'receipts__id__receipt_images__receipt_id',
  );

  $$ReceiptImagesTableProcessedTableManager get receiptImagesRefs {
    final manager = $$ReceiptImagesTableTableManager(
      $_db,
      $_db.receiptImages,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_receiptImagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LineItemsTable, List<LineItem>>
  _lineItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lineItems,
    aliasName: 'receipts__id__line_items__receipt_id',
  );

  $$LineItemsTableProcessedTableManager get lineItemsRefs {
    final manager = $$LineItemsTableTableManager(
      $_db,
      $_db.lineItems,
    ).filter((f) => f.receiptId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lineItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReceiptsTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get purchasedAt => $composableBuilder(
    column: $table.purchasedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subtotalCents => $composableBuilder(
    column: $table.subtotalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get taxCents => $composableBuilder(
    column: $table.taxCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StoresTableFilterComposer get storeId {
    final $$StoresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storeId,
      referencedTable: $db.stores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoresTableFilterComposer(
            $db: $db,
            $table: $db.stores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> receiptImagesRefs(
    Expression<bool> Function($$ReceiptImagesTableFilterComposer f) f,
  ) {
    final $$ReceiptImagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptImages,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptImagesTableFilterComposer(
            $db: $db,
            $table: $db.receiptImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lineItemsRefs(
    Expression<bool> Function($$LineItemsTableFilterComposer f) f,
  ) {
    final $$LineItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineItems,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineItemsTableFilterComposer(
            $db: $db,
            $table: $db.lineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get purchasedAt => $composableBuilder(
    column: $table.purchasedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subtotalCents => $composableBuilder(
    column: $table.subtotalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get taxCents => $composableBuilder(
    column: $table.taxCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrText => $composableBuilder(
    column: $table.ocrText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StoresTableOrderingComposer get storeId {
    final $$StoresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storeId,
      referencedTable: $db.stores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoresTableOrderingComposer(
            $db: $db,
            $table: $db.stores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptsTable> {
  $$ReceiptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get purchasedAt => $composableBuilder(
    column: $table.purchasedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subtotalCents => $composableBuilder(
    column: $table.subtotalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get taxCents =>
      $composableBuilder(column: $table.taxCents, builder: (column) => column);

  GeneratedColumn<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get ocrText =>
      $composableBuilder(column: $table.ocrText, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$StoresTableAnnotationComposer get storeId {
    final $$StoresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storeId,
      referencedTable: $db.stores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoresTableAnnotationComposer(
            $db: $db,
            $table: $db.stores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> receiptImagesRefs<T extends Object>(
    Expression<T> Function($$ReceiptImagesTableAnnotationComposer a) f,
  ) {
    final $$ReceiptImagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.receiptImages,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptImagesTableAnnotationComposer(
            $db: $db,
            $table: $db.receiptImages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lineItemsRefs<T extends Object>(
    Expression<T> Function($$LineItemsTableAnnotationComposer a) f,
  ) {
    final $$LineItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineItems,
      getReferencedColumn: (t) => t.receiptId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.lineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReceiptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptsTable,
          Receipt,
          $$ReceiptsTableFilterComposer,
          $$ReceiptsTableOrderingComposer,
          $$ReceiptsTableAnnotationComposer,
          $$ReceiptsTableCreateCompanionBuilder,
          $$ReceiptsTableUpdateCompanionBuilder,
          (Receipt, $$ReceiptsTableReferences),
          Receipt,
          PrefetchHooks Function({
            bool storeId,
            bool receiptImagesRefs,
            bool lineItemsRefs,
          })
        > {
  $$ReceiptsTableTableManager(_$AppDatabase db, $ReceiptsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> storeId = const Value.absent(),
                Value<DateTime> purchasedAt = const Value.absent(),
                Value<int?> subtotalCents = const Value.absent(),
                Value<int?> taxCents = const Value.absent(),
                Value<int?> totalCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReceiptsCompanion(
                id: id,
                storeId: storeId,
                purchasedAt: purchasedAt,
                subtotalCents: subtotalCents,
                taxCents: taxCents,
                totalCents: totalCents,
                currency: currency,
                imagePath: imagePath,
                ocrText: ocrText,
                source: source,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> storeId = const Value.absent(),
                required DateTime purchasedAt,
                Value<int?> subtotalCents = const Value.absent(),
                Value<int?> taxCents = const Value.absent(),
                Value<int?> totalCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<String?> ocrText = const Value.absent(),
                required String source,
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReceiptsCompanion.insert(
                id: id,
                storeId: storeId,
                purchasedAt: purchasedAt,
                subtotalCents: subtotalCents,
                taxCents: taxCents,
                totalCents: totalCents,
                currency: currency,
                imagePath: imagePath,
                ocrText: ocrText,
                source: source,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReceiptsTable, Receipt>(table),
                  $$ReceiptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                storeId = false,
                receiptImagesRefs = false,
                lineItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (receiptImagesRefs) db.receiptImages,
                    if (lineItemsRefs) db.lineItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (storeId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.storeId,
                                    referencedTable: $$ReceiptsTableReferences
                                        ._storeIdTable(db),
                                    referencedColumn: $$ReceiptsTableReferences
                                        ._storeIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (receiptImagesRefs)
                        await $_getPrefetchedData<
                          Receipt,
                          $ReceiptsTable,
                          ReceiptImage
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptsTableReferences
                              ._receiptImagesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptsTableReferences(
                                db,
                                table,
                                p0,
                              ).receiptImagesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.receiptId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lineItemsRefs)
                        await $_getPrefetchedData<
                          Receipt,
                          $ReceiptsTable,
                          LineItem
                        >(
                          currentTable: table,
                          referencedTable: $$ReceiptsTableReferences
                              ._lineItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ReceiptsTableReferences(
                                db,
                                table,
                                p0,
                              ).lineItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.receiptId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ReceiptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptsTable,
      Receipt,
      $$ReceiptsTableFilterComposer,
      $$ReceiptsTableOrderingComposer,
      $$ReceiptsTableAnnotationComposer,
      $$ReceiptsTableCreateCompanionBuilder,
      $$ReceiptsTableUpdateCompanionBuilder,
      (Receipt, $$ReceiptsTableReferences),
      Receipt,
      PrefetchHooks Function({
        bool storeId,
        bool receiptImagesRefs,
        bool lineItemsRefs,
      })
    >;
typedef $$ReceiptImagesTableCreateCompanionBuilder =
    ReceiptImagesCompanion Function({
      Value<int> id,
      required int receiptId,
      required int position,
      required String path,
    });
typedef $$ReceiptImagesTableUpdateCompanionBuilder =
    ReceiptImagesCompanion Function({
      Value<int> id,
      Value<int> receiptId,
      Value<int> position,
      Value<String> path,
    });

final class $$ReceiptImagesTableReferences
    extends BaseReferences<_$AppDatabase, $ReceiptImagesTable, ReceiptImage> {
  $$ReceiptImagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ReceiptsTable _receiptIdTable(_$AppDatabase db) =>
      db.receipts.createAlias('receipt_images__receipt_id__receipts__id');

  $$ReceiptsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<int>('receipt_id')!;

    final manager = $$ReceiptsTableTableManager(
      $_db,
      $_db.receipts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReceiptImagesTableFilterComposer
    extends Composer<_$AppDatabase, $ReceiptImagesTable> {
  $$ReceiptImagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  $$ReceiptsTableFilterComposer get receiptId {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptImagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ReceiptImagesTable> {
  $$ReceiptImagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReceiptsTableOrderingComposer get receiptId {
    final $$ReceiptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableOrderingComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptImagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReceiptImagesTable> {
  $$ReceiptImagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  $$ReceiptsTableAnnotationComposer get receiptId {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReceiptImagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReceiptImagesTable,
          ReceiptImage,
          $$ReceiptImagesTableFilterComposer,
          $$ReceiptImagesTableOrderingComposer,
          $$ReceiptImagesTableAnnotationComposer,
          $$ReceiptImagesTableCreateCompanionBuilder,
          $$ReceiptImagesTableUpdateCompanionBuilder,
          (ReceiptImage, $$ReceiptImagesTableReferences),
          ReceiptImage,
          PrefetchHooks Function({bool receiptId})
        > {
  $$ReceiptImagesTableTableManager(_$AppDatabase db, $ReceiptImagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReceiptImagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReceiptImagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReceiptImagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> receiptId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> path = const Value.absent(),
              }) => ReceiptImagesCompanion(
                id: id,
                receiptId: receiptId,
                position: position,
                path: path,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int receiptId,
                required int position,
                required String path,
              }) => ReceiptImagesCompanion.insert(
                id: id,
                receiptId: receiptId,
                position: position,
                path: path,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReceiptImagesTable, ReceiptImage>(table),
                  $$ReceiptImagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (receiptId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.receiptId,
                                referencedTable: $$ReceiptImagesTableReferences
                                    ._receiptIdTable(db),
                                referencedColumn: $$ReceiptImagesTableReferences
                                    ._receiptIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReceiptImagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReceiptImagesTable,
      ReceiptImage,
      $$ReceiptImagesTableFilterComposer,
      $$ReceiptImagesTableOrderingComposer,
      $$ReceiptImagesTableAnnotationComposer,
      $$ReceiptImagesTableCreateCompanionBuilder,
      $$ReceiptImagesTableUpdateCompanionBuilder,
      (ReceiptImage, $$ReceiptImagesTableReferences),
      ReceiptImage,
      PrefetchHooks Function({bool receiptId})
    >;
typedef $$ProductsTableCreateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      required String canonicalKey,
      required String displayName,
      Value<double?> sizeValue,
      Value<String?> sizeUnit,
      Value<int?> packCount,
      Value<String?> category,
    });
typedef $$ProductsTableUpdateCompanionBuilder =
    ProductsCompanion Function({
      Value<int> id,
      Value<String> canonicalKey,
      Value<String> displayName,
      Value<double?> sizeValue,
      Value<String?> sizeUnit,
      Value<int?> packCount,
      Value<String?> category,
    });

final class $$ProductsTableReferences
    extends BaseReferences<_$AppDatabase, $ProductsTable, Product> {
  $$ProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProductAliasesTable, List<ProductAliase>>
  _productAliasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productAliases,
    aliasName: 'products__id__product_aliases__product_id',
  );

  $$ProductAliasesTableProcessedTableManager get productAliasesRefs {
    final manager = $$ProductAliasesTableTableManager(
      $_db,
      $_db.productAliases,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_productAliasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$LineItemsTable, List<LineItem>>
  _lineItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.lineItems,
    aliasName: 'products__id__line_items__product_id',
  );

  $$LineItemsTableProcessedTableManager get lineItemsRefs {
    final manager = $$LineItemsTableTableManager(
      $_db,
      $_db.lineItems,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_lineItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProductsTableFilterComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalKey => $composableBuilder(
    column: $table.canonicalKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sizeValue => $composableBuilder(
    column: $table.sizeValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sizeUnit => $composableBuilder(
    column: $table.sizeUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get packCount => $composableBuilder(
    column: $table.packCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> productAliasesRefs(
    Expression<bool> Function($$ProductAliasesTableFilterComposer f) f,
  ) {
    final $$ProductAliasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productAliases,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductAliasesTableFilterComposer(
            $db: $db,
            $table: $db.productAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> lineItemsRefs(
    Expression<bool> Function($$LineItemsTableFilterComposer f) f,
  ) {
    final $$LineItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineItemsTableFilterComposer(
            $db: $db,
            $table: $db.lineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalKey => $composableBuilder(
    column: $table.canonicalKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sizeValue => $composableBuilder(
    column: $table.sizeValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sizeUnit => $composableBuilder(
    column: $table.sizeUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get packCount => $composableBuilder(
    column: $table.packCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductsTable> {
  $$ProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get canonicalKey => $composableBuilder(
    column: $table.canonicalKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sizeValue =>
      $composableBuilder(column: $table.sizeValue, builder: (column) => column);

  GeneratedColumn<String> get sizeUnit =>
      $composableBuilder(column: $table.sizeUnit, builder: (column) => column);

  GeneratedColumn<int> get packCount =>
      $composableBuilder(column: $table.packCount, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  Expression<T> productAliasesRefs<T extends Object>(
    Expression<T> Function($$ProductAliasesTableAnnotationComposer a) f,
  ) {
    final $$ProductAliasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productAliases,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductAliasesTableAnnotationComposer(
            $db: $db,
            $table: $db.productAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> lineItemsRefs<T extends Object>(
    Expression<T> Function($$LineItemsTableAnnotationComposer a) f,
  ) {
    final $$LineItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.lineItems,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LineItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.lineItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductsTable,
          Product,
          $$ProductsTableFilterComposer,
          $$ProductsTableOrderingComposer,
          $$ProductsTableAnnotationComposer,
          $$ProductsTableCreateCompanionBuilder,
          $$ProductsTableUpdateCompanionBuilder,
          (Product, $$ProductsTableReferences),
          Product,
          PrefetchHooks Function({bool productAliasesRefs, bool lineItemsRefs})
        > {
  $$ProductsTableTableManager(_$AppDatabase db, $ProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> canonicalKey = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<double?> sizeValue = const Value.absent(),
                Value<String?> sizeUnit = const Value.absent(),
                Value<int?> packCount = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => ProductsCompanion(
                id: id,
                canonicalKey: canonicalKey,
                displayName: displayName,
                sizeValue: sizeValue,
                sizeUnit: sizeUnit,
                packCount: packCount,
                category: category,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String canonicalKey,
                required String displayName,
                Value<double?> sizeValue = const Value.absent(),
                Value<String?> sizeUnit = const Value.absent(),
                Value<int?> packCount = const Value.absent(),
                Value<String?> category = const Value.absent(),
              }) => ProductsCompanion.insert(
                id: id,
                canonicalKey: canonicalKey,
                displayName: displayName,
                sizeValue: sizeValue,
                sizeUnit: sizeUnit,
                packCount: packCount,
                category: category,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductsTable, Product>(table),
                  $$ProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({productAliasesRefs = false, lineItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (productAliasesRefs) db.productAliases,
                    if (lineItemsRefs) db.lineItems,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (productAliasesRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          ProductAliase
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._productAliasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).productAliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (lineItemsRefs)
                        await $_getPrefetchedData<
                          Product,
                          $ProductsTable,
                          LineItem
                        >(
                          currentTable: table,
                          referencedTable: $$ProductsTableReferences
                              ._lineItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).lineItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductsTable,
      Product,
      $$ProductsTableFilterComposer,
      $$ProductsTableOrderingComposer,
      $$ProductsTableAnnotationComposer,
      $$ProductsTableCreateCompanionBuilder,
      $$ProductsTableUpdateCompanionBuilder,
      (Product, $$ProductsTableReferences),
      Product,
      PrefetchHooks Function({bool productAliasesRefs, bool lineItemsRefs})
    >;
typedef $$ProductAliasesTableCreateCompanionBuilder =
    ProductAliasesCompanion Function({
      Value<int> id,
      required String aliasKey,
      required int productId,
      Value<int?> storeId,
    });
typedef $$ProductAliasesTableUpdateCompanionBuilder =
    ProductAliasesCompanion Function({
      Value<int> id,
      Value<String> aliasKey,
      Value<int> productId,
      Value<int?> storeId,
    });

final class $$ProductAliasesTableReferences
    extends BaseReferences<_$AppDatabase, $ProductAliasesTable, ProductAliase> {
  $$ProductAliasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('product_aliases__product_id__products__id');

  $$ProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<int>('product_id')!;

    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StoresTable _storeIdTable(_$AppDatabase db) =>
      db.stores.createAlias('product_aliases__store_id__stores__id');

  $$StoresTableProcessedTableManager? get storeId {
    final $_column = $_itemColumn<int>('store_id');
    if ($_column == null) return null;
    final manager = $$StoresTableTableManager(
      $_db,
      $_db.stores,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_storeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $ProductAliasesTable> {
  $$ProductAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aliasKey => $composableBuilder(
    column: $table.aliasKey,
    builder: (column) => ColumnFilters(column),
  );

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StoresTableFilterComposer get storeId {
    final $$StoresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storeId,
      referencedTable: $db.stores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoresTableFilterComposer(
            $db: $db,
            $table: $db.stores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductAliasesTable> {
  $$ProductAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aliasKey => $composableBuilder(
    column: $table.aliasKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StoresTableOrderingComposer get storeId {
    final $$StoresTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storeId,
      referencedTable: $db.stores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoresTableOrderingComposer(
            $db: $db,
            $table: $db.stores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductAliasesTable> {
  $$ProductAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get aliasKey =>
      $composableBuilder(column: $table.aliasKey, builder: (column) => column);

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StoresTableAnnotationComposer get storeId {
    final $$StoresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.storeId,
      referencedTable: $db.stores,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StoresTableAnnotationComposer(
            $db: $db,
            $table: $db.stores,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductAliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductAliasesTable,
          ProductAliase,
          $$ProductAliasesTableFilterComposer,
          $$ProductAliasesTableOrderingComposer,
          $$ProductAliasesTableAnnotationComposer,
          $$ProductAliasesTableCreateCompanionBuilder,
          $$ProductAliasesTableUpdateCompanionBuilder,
          (ProductAliase, $$ProductAliasesTableReferences),
          ProductAliase,
          PrefetchHooks Function({bool productId, bool storeId})
        > {
  $$ProductAliasesTableTableManager(
    _$AppDatabase db,
    $ProductAliasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> aliasKey = const Value.absent(),
                Value<int> productId = const Value.absent(),
                Value<int?> storeId = const Value.absent(),
              }) => ProductAliasesCompanion(
                id: id,
                aliasKey: aliasKey,
                productId: productId,
                storeId: storeId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String aliasKey,
                required int productId,
                Value<int?> storeId = const Value.absent(),
              }) => ProductAliasesCompanion.insert(
                id: id,
                aliasKey: aliasKey,
                productId: productId,
                storeId: storeId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ProductAliasesTable, ProductAliase>(table),
                  $$ProductAliasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false, storeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$ProductAliasesTableReferences
                                    ._productIdTable(db),
                                referencedColumn:
                                    $$ProductAliasesTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (storeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.storeId,
                                referencedTable: $$ProductAliasesTableReferences
                                    ._storeIdTable(db),
                                referencedColumn:
                                    $$ProductAliasesTableReferences
                                        ._storeIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProductAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductAliasesTable,
      ProductAliase,
      $$ProductAliasesTableFilterComposer,
      $$ProductAliasesTableOrderingComposer,
      $$ProductAliasesTableAnnotationComposer,
      $$ProductAliasesTableCreateCompanionBuilder,
      $$ProductAliasesTableUpdateCompanionBuilder,
      (ProductAliase, $$ProductAliasesTableReferences),
      ProductAliase,
      PrefetchHooks Function({bool productId, bool storeId})
    >;
typedef $$LineItemsTableCreateCompanionBuilder =
    LineItemsCompanion Function({
      Value<int> id,
      required int receiptId,
      required int position,
      required String rawText,
      Value<int?> productId,
      Value<double> quantity,
      Value<String> unit,
      Value<int?> unitPriceCents,
      required int lineTotalCents,
      Value<int> discountCents,
      Value<String?> code,
      Value<String?> section,
    });
typedef $$LineItemsTableUpdateCompanionBuilder =
    LineItemsCompanion Function({
      Value<int> id,
      Value<int> receiptId,
      Value<int> position,
      Value<String> rawText,
      Value<int?> productId,
      Value<double> quantity,
      Value<String> unit,
      Value<int?> unitPriceCents,
      Value<int> lineTotalCents,
      Value<int> discountCents,
      Value<String?> code,
      Value<String?> section,
    });

final class $$LineItemsTableReferences
    extends BaseReferences<_$AppDatabase, $LineItemsTable, LineItem> {
  $$LineItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ReceiptsTable _receiptIdTable(_$AppDatabase db) =>
      db.receipts.createAlias('line_items__receipt_id__receipts__id');

  $$ReceiptsTableProcessedTableManager get receiptId {
    final $_column = $_itemColumn<int>('receipt_id')!;

    final manager = $$ReceiptsTableTableManager(
      $_db,
      $_db.receipts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_receiptIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProductsTable _productIdTable(_$AppDatabase db) =>
      db.products.createAlias('line_items__product_id__products__id');

  $$ProductsTableProcessedTableManager? get productId {
    final $_column = $_itemColumn<int>('product_id');
    if ($_column == null) return null;
    final manager = $$ProductsTableTableManager(
      $_db,
      $_db.products,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LineItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LineItemsTable> {
  $$LineItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineTotalCents => $composableBuilder(
    column: $table.lineTotalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountCents => $composableBuilder(
    column: $table.discountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnFilters(column),
  );

  $$ReceiptsTableFilterComposer get receiptId {
    final $$ReceiptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableFilterComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableFilterComposer get productId {
    final $$ProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableFilterComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LineItemsTable> {
  $$LineItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawText => $composableBuilder(
    column: $table.rawText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineTotalCents => $composableBuilder(
    column: $table.lineTotalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountCents => $composableBuilder(
    column: $table.discountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get section => $composableBuilder(
    column: $table.section,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReceiptsTableOrderingComposer get receiptId {
    final $$ReceiptsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableOrderingComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableOrderingComposer get productId {
    final $$ProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableOrderingComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LineItemsTable> {
  $$LineItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<int> get unitPriceCents => $composableBuilder(
    column: $table.unitPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lineTotalCents => $composableBuilder(
    column: $table.lineTotalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discountCents => $composableBuilder(
    column: $table.discountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get section =>
      $composableBuilder(column: $table.section, builder: (column) => column);

  $$ReceiptsTableAnnotationComposer get receiptId {
    final $$ReceiptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.receiptId,
      referencedTable: $db.receipts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReceiptsTableAnnotationComposer(
            $db: $db,
            $table: $db.receipts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProductsTableAnnotationComposer get productId {
    final $$ProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.products,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.products,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LineItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LineItemsTable,
          LineItem,
          $$LineItemsTableFilterComposer,
          $$LineItemsTableOrderingComposer,
          $$LineItemsTableAnnotationComposer,
          $$LineItemsTableCreateCompanionBuilder,
          $$LineItemsTableUpdateCompanionBuilder,
          (LineItem, $$LineItemsTableReferences),
          LineItem,
          PrefetchHooks Function({bool receiptId, bool productId})
        > {
  $$LineItemsTableTableManager(_$AppDatabase db, $LineItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LineItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LineItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LineItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> receiptId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> rawText = const Value.absent(),
                Value<int?> productId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int?> unitPriceCents = const Value.absent(),
                Value<int> lineTotalCents = const Value.absent(),
                Value<int> discountCents = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> section = const Value.absent(),
              }) => LineItemsCompanion(
                id: id,
                receiptId: receiptId,
                position: position,
                rawText: rawText,
                productId: productId,
                quantity: quantity,
                unit: unit,
                unitPriceCents: unitPriceCents,
                lineTotalCents: lineTotalCents,
                discountCents: discountCents,
                code: code,
                section: section,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int receiptId,
                required int position,
                required String rawText,
                Value<int?> productId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int?> unitPriceCents = const Value.absent(),
                required int lineTotalCents,
                Value<int> discountCents = const Value.absent(),
                Value<String?> code = const Value.absent(),
                Value<String?> section = const Value.absent(),
              }) => LineItemsCompanion.insert(
                id: id,
                receiptId: receiptId,
                position: position,
                rawText: rawText,
                productId: productId,
                quantity: quantity,
                unit: unit,
                unitPriceCents: unitPriceCents,
                lineTotalCents: lineTotalCents,
                discountCents: discountCents,
                code: code,
                section: section,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LineItemsTable, LineItem>(table),
                  $$LineItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({receiptId = false, productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (receiptId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.receiptId,
                                referencedTable: $$LineItemsTableReferences
                                    ._receiptIdTable(db),
                                referencedColumn: $$LineItemsTableReferences
                                    ._receiptIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable: $$LineItemsTableReferences
                                    ._productIdTable(db),
                                referencedColumn: $$LineItemsTableReferences
                                    ._productIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LineItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LineItemsTable,
      LineItem,
      $$LineItemsTableFilterComposer,
      $$LineItemsTableOrderingComposer,
      $$LineItemsTableAnnotationComposer,
      $$LineItemsTableCreateCompanionBuilder,
      $$LineItemsTableUpdateCompanionBuilder,
      (LineItem, $$LineItemsTableReferences),
      LineItem,
      PrefetchHooks Function({bool receiptId, bool productId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$StoresTableTableManager get stores =>
      $$StoresTableTableManager(_db, _db.stores);
  $$ReceiptsTableTableManager get receipts =>
      $$ReceiptsTableTableManager(_db, _db.receipts);
  $$ReceiptImagesTableTableManager get receiptImages =>
      $$ReceiptImagesTableTableManager(_db, _db.receiptImages);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db, _db.products);
  $$ProductAliasesTableTableManager get productAliases =>
      $$ProductAliasesTableTableManager(_db, _db.productAliases);
  $$LineItemsTableTableManager get lineItems =>
      $$LineItemsTableTableManager(_db, _db.lineItems);
}
