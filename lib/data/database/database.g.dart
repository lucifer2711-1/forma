// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ScanTableTable extends ScanTable
    with TableInfo<$ScanTableTable, ScanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusIndexMeta = const VerificationMeta(
    'statusIndex',
  );
  @override
  late final GeneratedColumn<int> statusIndex = GeneratedColumn<int>(
    'status_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelPathMeta = const VerificationMeta(
    'modelPath',
  );
  @override
  late final GeneratedColumn<String> modelPath = GeneratedColumn<String>(
    'model_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    updatedAt,
    statusIndex,
    thumbnailPath,
    modelPath,
    bytes,
    isFavorite,
    tags,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('status_index')) {
      context.handle(
        _statusIndexMeta,
        statusIndex.isAcceptableOrUnknown(
          data['status_index']!,
          _statusIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_statusIndexMeta);
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('model_path')) {
      context.handle(
        _modelPathMeta,
        modelPath.isAcceptableOrUnknown(data['model_path']!, _modelPathMeta),
      );
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    } else if (isInserting) {
      context.missing(_isFavoriteMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    } else if (isInserting) {
      context.missing(_tagsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      statusIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status_index'],
      )!,
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      modelPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_path'],
      ),
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
    );
  }

  @override
  $ScanTableTable createAlias(String alias) {
    return $ScanTableTable(attachedDatabase, alias);
  }
}

class ScanRow extends DataClass implements Insertable<ScanRow> {
  /// Stable uuid, also used as the on-disk folder name.
  final String id;

  /// User-visible name.
  final String name;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime updatedAt;

  /// Draft, processing, ready, or failed.
  final int statusIndex;

  /// Optional absolute path to the thumbnail image.
  final String? thumbnailPath;

  /// Optional absolute path to the exported model file.
  final String? modelPath;

  /// On-disk size of the scan folder.
  final int bytes;

  /// Whether the user favorited this scan.
  final bool isFavorite;

  /// Comma-separated tags (library filtering, Phase 3).
  final String tags;
  const ScanRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.statusIndex,
    this.thumbnailPath,
    this.modelPath,
    required this.bytes,
    required this.isFavorite,
    required this.tags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['status_index'] = Variable<int>(statusIndex);
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || modelPath != null) {
      map['model_path'] = Variable<String>(modelPath);
    }
    map['bytes'] = Variable<int>(bytes);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['tags'] = Variable<String>(tags);
    return map;
  }

  ScanTableCompanion toCompanion(bool nullToAbsent) {
    return ScanTableCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      statusIndex: Value(statusIndex),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      modelPath: modelPath == null && nullToAbsent
          ? const Value.absent()
          : Value(modelPath),
      bytes: Value(bytes),
      isFavorite: Value(isFavorite),
      tags: Value(tags),
    );
  }

  factory ScanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      statusIndex: serializer.fromJson<int>(json['statusIndex']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      modelPath: serializer.fromJson<String?>(json['modelPath']),
      bytes: serializer.fromJson<int>(json['bytes']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      tags: serializer.fromJson<String>(json['tags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'statusIndex': serializer.toJson<int>(statusIndex),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'modelPath': serializer.toJson<String?>(modelPath),
      'bytes': serializer.toJson<int>(bytes),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'tags': serializer.toJson<String>(tags),
    };
  }

  ScanRow copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? statusIndex,
    Value<String?> thumbnailPath = const Value.absent(),
    Value<String?> modelPath = const Value.absent(),
    int? bytes,
    bool? isFavorite,
    String? tags,
  }) => ScanRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    statusIndex: statusIndex ?? this.statusIndex,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    modelPath: modelPath.present ? modelPath.value : this.modelPath,
    bytes: bytes ?? this.bytes,
    isFavorite: isFavorite ?? this.isFavorite,
    tags: tags ?? this.tags,
  );
  ScanRow copyWithCompanion(ScanTableCompanion data) {
    return ScanRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      statusIndex: data.statusIndex.present
          ? data.statusIndex.value
          : this.statusIndex,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      modelPath: data.modelPath.present ? data.modelPath.value : this.modelPath,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      tags: data.tags.present ? data.tags.value : this.tags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('statusIndex: $statusIndex, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('modelPath: $modelPath, ')
          ..write('bytes: $bytes, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    updatedAt,
    statusIndex,
    thumbnailPath,
    modelPath,
    bytes,
    isFavorite,
    tags,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.statusIndex == this.statusIndex &&
          other.thumbnailPath == this.thumbnailPath &&
          other.modelPath == this.modelPath &&
          other.bytes == this.bytes &&
          other.isFavorite == this.isFavorite &&
          other.tags == this.tags);
}

class ScanTableCompanion extends UpdateCompanion<ScanRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> statusIndex;
  final Value<String?> thumbnailPath;
  final Value<String?> modelPath;
  final Value<int> bytes;
  final Value<bool> isFavorite;
  final Value<String> tags;
  final Value<int> rowid;
  const ScanTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.statusIndex = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.modelPath = const Value.absent(),
    this.bytes = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.tags = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanTableCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int statusIndex,
    this.thumbnailPath = const Value.absent(),
    this.modelPath = const Value.absent(),
    required int bytes,
    required bool isFavorite,
    required String tags,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       statusIndex = Value(statusIndex),
       bytes = Value(bytes),
       isFavorite = Value(isFavorite),
       tags = Value(tags);
  static Insertable<ScanRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? statusIndex,
    Expression<String>? thumbnailPath,
    Expression<String>? modelPath,
    Expression<int>? bytes,
    Expression<bool>? isFavorite,
    Expression<String>? tags,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (statusIndex != null) 'status_index': statusIndex,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (modelPath != null) 'model_path': modelPath,
      if (bytes != null) 'bytes': bytes,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (tags != null) 'tags': tags,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? statusIndex,
    Value<String?>? thumbnailPath,
    Value<String?>? modelPath,
    Value<int>? bytes,
    Value<bool>? isFavorite,
    Value<String>? tags,
    Value<int>? rowid,
  }) {
    return ScanTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      statusIndex: statusIndex ?? this.statusIndex,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      modelPath: modelPath ?? this.modelPath,
      bytes: bytes ?? this.bytes,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (statusIndex.present) {
      map['status_index'] = Variable<int>(statusIndex.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (modelPath.present) {
      map['model_path'] = Variable<String>(modelPath.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('statusIndex: $statusIndex, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('modelPath: $modelPath, ')
          ..write('bytes: $bytes, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('tags: $tags, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$FormaDatabase extends GeneratedDatabase {
  _$FormaDatabase(QueryExecutor e) : super(e);
  $FormaDatabaseManager get managers => $FormaDatabaseManager(this);
  late final $ScanTableTable scanTable = $ScanTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [scanTable];
}

typedef $$ScanTableTableCreateCompanionBuilder = ScanTableCompanion Function({
  required String id,
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
  required int statusIndex,
  Value<String?> thumbnailPath,
  Value<String?> modelPath,
  required int bytes,
  required bool isFavorite,
  required String tags,
  Value<int> rowid,
});
typedef $$ScanTableTableUpdateCompanionBuilder = ScanTableCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> statusIndex,
  Value<String?> thumbnailPath,
  Value<String?> modelPath,
  Value<int> bytes,
  Value<bool> isFavorite,
  Value<String> tags,
  Value<int> rowid,
});

class $$ScanTableTableFilterComposer
    extends Composer<_$FormaDatabase, $ScanTableTable> {
  $$ScanTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statusIndex => $composableBuilder(
    column: $table.statusIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelPath => $composableBuilder(
    column: $table.modelPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanTableTableOrderingComposer
    extends Composer<_$FormaDatabase, $ScanTableTable> {
  $$ScanTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statusIndex => $composableBuilder(
    column: $table.statusIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelPath => $composableBuilder(
    column: $table.modelPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanTableTableAnnotationComposer
    extends Composer<_$FormaDatabase, $ScanTableTable> {
  $$ScanTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get statusIndex => $composableBuilder(
    column: $table.statusIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelPath =>
      $composableBuilder(column: $table.modelPath, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);
}

class $$ScanTableTableTableManager
    extends
        RootTableManager<
          _$FormaDatabase,
          $ScanTableTable,
          ScanRow,
          $$ScanTableTableFilterComposer,
          $$ScanTableTableOrderingComposer,
          $$ScanTableTableAnnotationComposer,
          $$ScanTableTableCreateCompanionBuilder,
          $$ScanTableTableUpdateCompanionBuilder,
          (ScanRow, BaseReferences<_$FormaDatabase, $ScanTableTable, ScanRow>),
          ScanRow,
          PrefetchHooks Function()
        > {
  $$ScanTableTableTableManager(_$FormaDatabase db, $ScanTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> statusIndex = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> modelPath = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanTableCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                statusIndex: statusIndex,
                thumbnailPath: thumbnailPath,
                modelPath: modelPath,
                bytes: bytes,
                isFavorite: isFavorite,
                tags: tags,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required DateTime createdAt,
                required DateTime updatedAt,
                required int statusIndex,
                Value<String?> thumbnailPath = const Value.absent(),
                Value<String?> modelPath = const Value.absent(),
                required int bytes,
                required bool isFavorite,
                required String tags,
                Value<int> rowid = const Value.absent(),
              }) => ScanTableCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                updatedAt: updatedAt,
                statusIndex: statusIndex,
                thumbnailPath: thumbnailPath,
                modelPath: modelPath,
                bytes: bytes,
                isFavorite: isFavorite,
                tags: tags,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanTableTable, ScanRow>(table),
                  BaseReferences<_$FormaDatabase, $ScanTableTable, ScanRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanTableTableProcessedTableManager =
    ProcessedTableManager<
      _$FormaDatabase,
      $ScanTableTable,
      ScanRow,
      $$ScanTableTableFilterComposer,
      $$ScanTableTableOrderingComposer,
      $$ScanTableTableAnnotationComposer,
      $$ScanTableTableCreateCompanionBuilder,
      $$ScanTableTableUpdateCompanionBuilder,
      (ScanRow, BaseReferences<_$FormaDatabase, $ScanTableTable, ScanRow>),
      ScanRow,
      PrefetchHooks Function()
    >;

class $FormaDatabaseManager {
  final _$FormaDatabase _db;
  $FormaDatabaseManager(this._db);
  $$ScanTableTableTableManager get scanTable =>
      $$ScanTableTableTableManager(_db, _db.scanTable);
}
