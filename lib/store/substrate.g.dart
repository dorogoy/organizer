// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'substrate.dart';

// ignore_for_file: type=lint
class PoolFacts extends Table with TableInfo<PoolFacts, PoolFact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PoolFacts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  late final GeneratedColumn<String> origin = GeneratedColumn<String>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _instantUtcMicrosMeta = const VerificationMeta(
    'instantUtcMicros',
  );
  late final GeneratedColumn<int> instantUtcMicros = GeneratedColumn<int>(
    'instant_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _offsetSecondsMeta = const VerificationMeta(
    'offsetSeconds',
  );
  late final GeneratedColumn<int> offsetSeconds = GeneratedColumn<int>(
    'offset_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _originContextMeta = const VerificationMeta(
    'originContext',
  );
  late final GeneratedColumn<String> originContext = GeneratedColumn<String>(
    'origin_context',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    origin,
    size,
    instantUtcMicros,
    offsetSeconds,
    originContext,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pool_facts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PoolFact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    } else if (isInserting) {
      context.missing(_originMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('instant_utc_micros')) {
      context.handle(
        _instantUtcMicrosMeta,
        instantUtcMicros.isAcceptableOrUnknown(
          data['instant_utc_micros']!,
          _instantUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instantUtcMicrosMeta);
    }
    if (data.containsKey('offset_seconds')) {
      context.handle(
        _offsetSecondsMeta,
        offsetSeconds.isAcceptableOrUnknown(
          data['offset_seconds']!,
          _offsetSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_offsetSecondsMeta);
    }
    if (data.containsKey('origin_context')) {
      context.handle(
        _originContextMeta,
        originContext.isAcceptableOrUnknown(
          data['origin_context']!,
          _originContextMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PoolFact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PoolFact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}size'],
      )!,
      instantUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}instant_utc_micros'],
      )!,
      offsetSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_seconds'],
      )!,
      originContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_context'],
      ),
    );
  }

  @override
  PoolFacts createAlias(String alias) {
    return PoolFacts(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class PoolFact extends DataClass implements Insertable<PoolFact> {
  final String id;
  final String origin;
  final String size;
  final int instantUtcMicros;
  final int offsetSeconds;
  final String? originContext;
  const PoolFact({
    required this.id,
    required this.origin,
    required this.size,
    required this.instantUtcMicros,
    required this.offsetSeconds,
    this.originContext,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['origin'] = Variable<String>(origin);
    map['size'] = Variable<String>(size);
    map['instant_utc_micros'] = Variable<int>(instantUtcMicros);
    map['offset_seconds'] = Variable<int>(offsetSeconds);
    if (!nullToAbsent || originContext != null) {
      map['origin_context'] = Variable<String>(originContext);
    }
    return map;
  }

  PoolFactsCompanion toCompanion(bool nullToAbsent) {
    return PoolFactsCompanion(
      id: Value(id),
      origin: Value(origin),
      size: Value(size),
      instantUtcMicros: Value(instantUtcMicros),
      offsetSeconds: Value(offsetSeconds),
      originContext: originContext == null && nullToAbsent
          ? const Value.absent()
          : Value(originContext),
    );
  }

  factory PoolFact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PoolFact(
      id: serializer.fromJson<String>(json['id']),
      origin: serializer.fromJson<String>(json['origin']),
      size: serializer.fromJson<String>(json['size']),
      instantUtcMicros: serializer.fromJson<int>(json['instant_utc_micros']),
      offsetSeconds: serializer.fromJson<int>(json['offset_seconds']),
      originContext: serializer.fromJson<String?>(json['origin_context']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'origin': serializer.toJson<String>(origin),
      'size': serializer.toJson<String>(size),
      'instant_utc_micros': serializer.toJson<int>(instantUtcMicros),
      'offset_seconds': serializer.toJson<int>(offsetSeconds),
      'origin_context': serializer.toJson<String?>(originContext),
    };
  }

  PoolFact copyWith({
    String? id,
    String? origin,
    String? size,
    int? instantUtcMicros,
    int? offsetSeconds,
    Value<String?> originContext = const Value.absent(),
  }) => PoolFact(
    id: id ?? this.id,
    origin: origin ?? this.origin,
    size: size ?? this.size,
    instantUtcMicros: instantUtcMicros ?? this.instantUtcMicros,
    offsetSeconds: offsetSeconds ?? this.offsetSeconds,
    originContext: originContext.present
        ? originContext.value
        : this.originContext,
  );
  PoolFact copyWithCompanion(PoolFactsCompanion data) {
    return PoolFact(
      id: data.id.present ? data.id.value : this.id,
      origin: data.origin.present ? data.origin.value : this.origin,
      size: data.size.present ? data.size.value : this.size,
      instantUtcMicros: data.instantUtcMicros.present
          ? data.instantUtcMicros.value
          : this.instantUtcMicros,
      offsetSeconds: data.offsetSeconds.present
          ? data.offsetSeconds.value
          : this.offsetSeconds,
      originContext: data.originContext.present
          ? data.originContext.value
          : this.originContext,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PoolFact(')
          ..write('id: $id, ')
          ..write('origin: $origin, ')
          ..write('size: $size, ')
          ..write('instantUtcMicros: $instantUtcMicros, ')
          ..write('offsetSeconds: $offsetSeconds, ')
          ..write('originContext: $originContext')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    origin,
    size,
    instantUtcMicros,
    offsetSeconds,
    originContext,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PoolFact &&
          other.id == this.id &&
          other.origin == this.origin &&
          other.size == this.size &&
          other.instantUtcMicros == this.instantUtcMicros &&
          other.offsetSeconds == this.offsetSeconds &&
          other.originContext == this.originContext);
}

class PoolFactsCompanion extends UpdateCompanion<PoolFact> {
  final Value<String> id;
  final Value<String> origin;
  final Value<String> size;
  final Value<int> instantUtcMicros;
  final Value<int> offsetSeconds;
  final Value<String?> originContext;
  final Value<int> rowid;
  const PoolFactsCompanion({
    this.id = const Value.absent(),
    this.origin = const Value.absent(),
    this.size = const Value.absent(),
    this.instantUtcMicros = const Value.absent(),
    this.offsetSeconds = const Value.absent(),
    this.originContext = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoolFactsCompanion.insert({
    required String id,
    required String origin,
    required String size,
    required int instantUtcMicros,
    required int offsetSeconds,
    this.originContext = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       origin = Value(origin),
       size = Value(size),
       instantUtcMicros = Value(instantUtcMicros),
       offsetSeconds = Value(offsetSeconds);
  static Insertable<PoolFact> custom({
    Expression<String>? id,
    Expression<String>? origin,
    Expression<String>? size,
    Expression<int>? instantUtcMicros,
    Expression<int>? offsetSeconds,
    Expression<String>? originContext,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (origin != null) 'origin': origin,
      if (size != null) 'size': size,
      if (instantUtcMicros != null) 'instant_utc_micros': instantUtcMicros,
      if (offsetSeconds != null) 'offset_seconds': offsetSeconds,
      if (originContext != null) 'origin_context': originContext,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PoolFactsCompanion copyWith({
    Value<String>? id,
    Value<String>? origin,
    Value<String>? size,
    Value<int>? instantUtcMicros,
    Value<int>? offsetSeconds,
    Value<String?>? originContext,
    Value<int>? rowid,
  }) {
    return PoolFactsCompanion(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      size: size ?? this.size,
      instantUtcMicros: instantUtcMicros ?? this.instantUtcMicros,
      offsetSeconds: offsetSeconds ?? this.offsetSeconds,
      originContext: originContext ?? this.originContext,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (origin.present) {
      map['origin'] = Variable<String>(origin.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (instantUtcMicros.present) {
      map['instant_utc_micros'] = Variable<int>(instantUtcMicros.value);
    }
    if (offsetSeconds.present) {
      map['offset_seconds'] = Variable<int>(offsetSeconds.value);
    }
    if (originContext.present) {
      map['origin_context'] = Variable<String>(originContext.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PoolFactsCompanion(')
          ..write('id: $id, ')
          ..write('origin: $origin, ')
          ..write('size: $size, ')
          ..write('instantUtcMicros: $instantUtcMicros, ')
          ..write('offsetSeconds: $offsetSeconds, ')
          ..write('originContext: $originContext, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LogEntries extends Table with TableInfo<LogEntries, LogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LogEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _instantUtcMicrosMeta = const VerificationMeta(
    'instantUtcMicros',
  );
  late final GeneratedColumn<int> instantUtcMicros = GeneratedColumn<int>(
    'instant_utc_micros',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _offsetSecondsMeta = const VerificationMeta(
    'offsetSeconds',
  );
  late final GeneratedColumn<int> offsetSeconds = GeneratedColumn<int>(
    'offset_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _itemOriginMeta = const VerificationMeta(
    'itemOrigin',
  );
  late final GeneratedColumn<String> itemOrigin = GeneratedColumn<String>(
    'item_origin',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _stackMeta = const VerificationMeta('stack');
  late final GeneratedColumn<String> stack = GeneratedColumn<String>(
    'stack',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _settingKeyMeta = const VerificationMeta(
    'settingKey',
  );
  late final GeneratedColumn<String> settingKey = GeneratedColumn<String>(
    'setting_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _settingValueMeta = const VerificationMeta(
    'settingValue',
  );
  late final GeneratedColumn<int> settingValue = GeneratedColumn<int>(
    'setting_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _pocketMinutesMeta = const VerificationMeta(
    'pocketMinutes',
  );
  late final GeneratedColumn<int> pocketMinutes = GeneratedColumn<int>(
    'pocket_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _energyLevelMeta = const VerificationMeta(
    'energyLevel',
  );
  late final GeneratedColumn<int> energyLevel = GeneratedColumn<int>(
    'energy_level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _reportValueMeta = const VerificationMeta(
    'reportValue',
  );
  late final GeneratedColumn<int> reportValue = GeneratedColumn<int>(
    'report_value',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _reportWeekMeta = const VerificationMeta(
    'reportWeek',
  );
  late final GeneratedColumn<int> reportWeek = GeneratedColumn<int>(
    'report_week',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    instantUtcMicros,
    offsetSeconds,
    itemId,
    itemOrigin,
    stack,
    settingKey,
    settingValue,
    pocketMinutes,
    energyLevel,
    reportValue,
    reportWeek,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('instant_utc_micros')) {
      context.handle(
        _instantUtcMicrosMeta,
        instantUtcMicros.isAcceptableOrUnknown(
          data['instant_utc_micros']!,
          _instantUtcMicrosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instantUtcMicrosMeta);
    }
    if (data.containsKey('offset_seconds')) {
      context.handle(
        _offsetSecondsMeta,
        offsetSeconds.isAcceptableOrUnknown(
          data['offset_seconds']!,
          _offsetSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_offsetSecondsMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('item_origin')) {
      context.handle(
        _itemOriginMeta,
        itemOrigin.isAcceptableOrUnknown(data['item_origin']!, _itemOriginMeta),
      );
    }
    if (data.containsKey('stack')) {
      context.handle(
        _stackMeta,
        stack.isAcceptableOrUnknown(data['stack']!, _stackMeta),
      );
    }
    if (data.containsKey('setting_key')) {
      context.handle(
        _settingKeyMeta,
        settingKey.isAcceptableOrUnknown(data['setting_key']!, _settingKeyMeta),
      );
    }
    if (data.containsKey('setting_value')) {
      context.handle(
        _settingValueMeta,
        settingValue.isAcceptableOrUnknown(
          data['setting_value']!,
          _settingValueMeta,
        ),
      );
    }
    if (data.containsKey('pocket_minutes')) {
      context.handle(
        _pocketMinutesMeta,
        pocketMinutes.isAcceptableOrUnknown(
          data['pocket_minutes']!,
          _pocketMinutesMeta,
        ),
      );
    }
    if (data.containsKey('energy_level')) {
      context.handle(
        _energyLevelMeta,
        energyLevel.isAcceptableOrUnknown(
          data['energy_level']!,
          _energyLevelMeta,
        ),
      );
    }
    if (data.containsKey('report_value')) {
      context.handle(
        _reportValueMeta,
        reportValue.isAcceptableOrUnknown(
          data['report_value']!,
          _reportValueMeta,
        ),
      );
    }
    if (data.containsKey('report_week')) {
      context.handle(
        _reportWeekMeta,
        reportWeek.isAcceptableOrUnknown(data['report_week']!, _reportWeekMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      instantUtcMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}instant_utc_micros'],
      )!,
      offsetSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_seconds'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      itemOrigin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_origin'],
      ),
      stack: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stack'],
      ),
      settingKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setting_key'],
      ),
      settingValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}setting_value'],
      ),
      pocketMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pocket_minutes'],
      ),
      energyLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}energy_level'],
      ),
      reportValue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}report_value'],
      ),
      reportWeek: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}report_week'],
      ),
    );
  }

  @override
  LogEntries createAlias(String alias) {
    return LogEntries(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LogEntry extends DataClass implements Insertable<LogEntry> {
  final String id;
  final String kind;
  final int instantUtcMicros;
  final int offsetSeconds;
  final String? itemId;
  final String? itemOrigin;
  final String? stack;
  final String? settingKey;
  final int? settingValue;
  final int? pocketMinutes;
  final int? energyLevel;
  final int? reportValue;
  final int? reportWeek;
  const LogEntry({
    required this.id,
    required this.kind,
    required this.instantUtcMicros,
    required this.offsetSeconds,
    this.itemId,
    this.itemOrigin,
    this.stack,
    this.settingKey,
    this.settingValue,
    this.pocketMinutes,
    this.energyLevel,
    this.reportValue,
    this.reportWeek,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['instant_utc_micros'] = Variable<int>(instantUtcMicros);
    map['offset_seconds'] = Variable<int>(offsetSeconds);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || itemOrigin != null) {
      map['item_origin'] = Variable<String>(itemOrigin);
    }
    if (!nullToAbsent || stack != null) {
      map['stack'] = Variable<String>(stack);
    }
    if (!nullToAbsent || settingKey != null) {
      map['setting_key'] = Variable<String>(settingKey);
    }
    if (!nullToAbsent || settingValue != null) {
      map['setting_value'] = Variable<int>(settingValue);
    }
    if (!nullToAbsent || pocketMinutes != null) {
      map['pocket_minutes'] = Variable<int>(pocketMinutes);
    }
    if (!nullToAbsent || energyLevel != null) {
      map['energy_level'] = Variable<int>(energyLevel);
    }
    if (!nullToAbsent || reportValue != null) {
      map['report_value'] = Variable<int>(reportValue);
    }
    if (!nullToAbsent || reportWeek != null) {
      map['report_week'] = Variable<int>(reportWeek);
    }
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      kind: Value(kind),
      instantUtcMicros: Value(instantUtcMicros),
      offsetSeconds: Value(offsetSeconds),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      itemOrigin: itemOrigin == null && nullToAbsent
          ? const Value.absent()
          : Value(itemOrigin),
      stack: stack == null && nullToAbsent
          ? const Value.absent()
          : Value(stack),
      settingKey: settingKey == null && nullToAbsent
          ? const Value.absent()
          : Value(settingKey),
      settingValue: settingValue == null && nullToAbsent
          ? const Value.absent()
          : Value(settingValue),
      pocketMinutes: pocketMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(pocketMinutes),
      energyLevel: energyLevel == null && nullToAbsent
          ? const Value.absent()
          : Value(energyLevel),
      reportValue: reportValue == null && nullToAbsent
          ? const Value.absent()
          : Value(reportValue),
      reportWeek: reportWeek == null && nullToAbsent
          ? const Value.absent()
          : Value(reportWeek),
    );
  }

  factory LogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogEntry(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      instantUtcMicros: serializer.fromJson<int>(json['instant_utc_micros']),
      offsetSeconds: serializer.fromJson<int>(json['offset_seconds']),
      itemId: serializer.fromJson<String?>(json['item_id']),
      itemOrigin: serializer.fromJson<String?>(json['item_origin']),
      stack: serializer.fromJson<String?>(json['stack']),
      settingKey: serializer.fromJson<String?>(json['setting_key']),
      settingValue: serializer.fromJson<int?>(json['setting_value']),
      pocketMinutes: serializer.fromJson<int?>(json['pocket_minutes']),
      energyLevel: serializer.fromJson<int?>(json['energy_level']),
      reportValue: serializer.fromJson<int?>(json['report_value']),
      reportWeek: serializer.fromJson<int?>(json['report_week']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'instant_utc_micros': serializer.toJson<int>(instantUtcMicros),
      'offset_seconds': serializer.toJson<int>(offsetSeconds),
      'item_id': serializer.toJson<String?>(itemId),
      'item_origin': serializer.toJson<String?>(itemOrigin),
      'stack': serializer.toJson<String?>(stack),
      'setting_key': serializer.toJson<String?>(settingKey),
      'setting_value': serializer.toJson<int?>(settingValue),
      'pocket_minutes': serializer.toJson<int?>(pocketMinutes),
      'energy_level': serializer.toJson<int?>(energyLevel),
      'report_value': serializer.toJson<int?>(reportValue),
      'report_week': serializer.toJson<int?>(reportWeek),
    };
  }

  LogEntry copyWith({
    String? id,
    String? kind,
    int? instantUtcMicros,
    int? offsetSeconds,
    Value<String?> itemId = const Value.absent(),
    Value<String?> itemOrigin = const Value.absent(),
    Value<String?> stack = const Value.absent(),
    Value<String?> settingKey = const Value.absent(),
    Value<int?> settingValue = const Value.absent(),
    Value<int?> pocketMinutes = const Value.absent(),
    Value<int?> energyLevel = const Value.absent(),
    Value<int?> reportValue = const Value.absent(),
    Value<int?> reportWeek = const Value.absent(),
  }) => LogEntry(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    instantUtcMicros: instantUtcMicros ?? this.instantUtcMicros,
    offsetSeconds: offsetSeconds ?? this.offsetSeconds,
    itemId: itemId.present ? itemId.value : this.itemId,
    itemOrigin: itemOrigin.present ? itemOrigin.value : this.itemOrigin,
    stack: stack.present ? stack.value : this.stack,
    settingKey: settingKey.present ? settingKey.value : this.settingKey,
    settingValue: settingValue.present ? settingValue.value : this.settingValue,
    pocketMinutes: pocketMinutes.present
        ? pocketMinutes.value
        : this.pocketMinutes,
    energyLevel: energyLevel.present ? energyLevel.value : this.energyLevel,
    reportValue: reportValue.present ? reportValue.value : this.reportValue,
    reportWeek: reportWeek.present ? reportWeek.value : this.reportWeek,
  );
  LogEntry copyWithCompanion(LogEntriesCompanion data) {
    return LogEntry(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      instantUtcMicros: data.instantUtcMicros.present
          ? data.instantUtcMicros.value
          : this.instantUtcMicros,
      offsetSeconds: data.offsetSeconds.present
          ? data.offsetSeconds.value
          : this.offsetSeconds,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      itemOrigin: data.itemOrigin.present
          ? data.itemOrigin.value
          : this.itemOrigin,
      stack: data.stack.present ? data.stack.value : this.stack,
      settingKey: data.settingKey.present
          ? data.settingKey.value
          : this.settingKey,
      settingValue: data.settingValue.present
          ? data.settingValue.value
          : this.settingValue,
      pocketMinutes: data.pocketMinutes.present
          ? data.pocketMinutes.value
          : this.pocketMinutes,
      energyLevel: data.energyLevel.present
          ? data.energyLevel.value
          : this.energyLevel,
      reportValue: data.reportValue.present
          ? data.reportValue.value
          : this.reportValue,
      reportWeek: data.reportWeek.present
          ? data.reportWeek.value
          : this.reportWeek,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogEntry(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('instantUtcMicros: $instantUtcMicros, ')
          ..write('offsetSeconds: $offsetSeconds, ')
          ..write('itemId: $itemId, ')
          ..write('itemOrigin: $itemOrigin, ')
          ..write('stack: $stack, ')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('pocketMinutes: $pocketMinutes, ')
          ..write('energyLevel: $energyLevel, ')
          ..write('reportValue: $reportValue, ')
          ..write('reportWeek: $reportWeek')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    instantUtcMicros,
    offsetSeconds,
    itemId,
    itemOrigin,
    stack,
    settingKey,
    settingValue,
    pocketMinutes,
    energyLevel,
    reportValue,
    reportWeek,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogEntry &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.instantUtcMicros == this.instantUtcMicros &&
          other.offsetSeconds == this.offsetSeconds &&
          other.itemId == this.itemId &&
          other.itemOrigin == this.itemOrigin &&
          other.stack == this.stack &&
          other.settingKey == this.settingKey &&
          other.settingValue == this.settingValue &&
          other.pocketMinutes == this.pocketMinutes &&
          other.energyLevel == this.energyLevel &&
          other.reportValue == this.reportValue &&
          other.reportWeek == this.reportWeek);
}

class LogEntriesCompanion extends UpdateCompanion<LogEntry> {
  final Value<String> id;
  final Value<String> kind;
  final Value<int> instantUtcMicros;
  final Value<int> offsetSeconds;
  final Value<String?> itemId;
  final Value<String?> itemOrigin;
  final Value<String?> stack;
  final Value<String?> settingKey;
  final Value<int?> settingValue;
  final Value<int?> pocketMinutes;
  final Value<int?> energyLevel;
  final Value<int?> reportValue;
  final Value<int?> reportWeek;
  final Value<int> rowid;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.instantUtcMicros = const Value.absent(),
    this.offsetSeconds = const Value.absent(),
    this.itemId = const Value.absent(),
    this.itemOrigin = const Value.absent(),
    this.stack = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.pocketMinutes = const Value.absent(),
    this.energyLevel = const Value.absent(),
    this.reportValue = const Value.absent(),
    this.reportWeek = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    required String id,
    required String kind,
    required int instantUtcMicros,
    required int offsetSeconds,
    this.itemId = const Value.absent(),
    this.itemOrigin = const Value.absent(),
    this.stack = const Value.absent(),
    this.settingKey = const Value.absent(),
    this.settingValue = const Value.absent(),
    this.pocketMinutes = const Value.absent(),
    this.energyLevel = const Value.absent(),
    this.reportValue = const Value.absent(),
    this.reportWeek = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       instantUtcMicros = Value(instantUtcMicros),
       offsetSeconds = Value(offsetSeconds);
  static Insertable<LogEntry> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<int>? instantUtcMicros,
    Expression<int>? offsetSeconds,
    Expression<String>? itemId,
    Expression<String>? itemOrigin,
    Expression<String>? stack,
    Expression<String>? settingKey,
    Expression<int>? settingValue,
    Expression<int>? pocketMinutes,
    Expression<int>? energyLevel,
    Expression<int>? reportValue,
    Expression<int>? reportWeek,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (instantUtcMicros != null) 'instant_utc_micros': instantUtcMicros,
      if (offsetSeconds != null) 'offset_seconds': offsetSeconds,
      if (itemId != null) 'item_id': itemId,
      if (itemOrigin != null) 'item_origin': itemOrigin,
      if (stack != null) 'stack': stack,
      if (settingKey != null) 'setting_key': settingKey,
      if (settingValue != null) 'setting_value': settingValue,
      if (pocketMinutes != null) 'pocket_minutes': pocketMinutes,
      if (energyLevel != null) 'energy_level': energyLevel,
      if (reportValue != null) 'report_value': reportValue,
      if (reportWeek != null) 'report_week': reportWeek,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LogEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<int>? instantUtcMicros,
    Value<int>? offsetSeconds,
    Value<String?>? itemId,
    Value<String?>? itemOrigin,
    Value<String?>? stack,
    Value<String?>? settingKey,
    Value<int?>? settingValue,
    Value<int?>? pocketMinutes,
    Value<int?>? energyLevel,
    Value<int?>? reportValue,
    Value<int?>? reportWeek,
    Value<int>? rowid,
  }) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      instantUtcMicros: instantUtcMicros ?? this.instantUtcMicros,
      offsetSeconds: offsetSeconds ?? this.offsetSeconds,
      itemId: itemId ?? this.itemId,
      itemOrigin: itemOrigin ?? this.itemOrigin,
      stack: stack ?? this.stack,
      settingKey: settingKey ?? this.settingKey,
      settingValue: settingValue ?? this.settingValue,
      pocketMinutes: pocketMinutes ?? this.pocketMinutes,
      energyLevel: energyLevel ?? this.energyLevel,
      reportValue: reportValue ?? this.reportValue,
      reportWeek: reportWeek ?? this.reportWeek,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (instantUtcMicros.present) {
      map['instant_utc_micros'] = Variable<int>(instantUtcMicros.value);
    }
    if (offsetSeconds.present) {
      map['offset_seconds'] = Variable<int>(offsetSeconds.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (itemOrigin.present) {
      map['item_origin'] = Variable<String>(itemOrigin.value);
    }
    if (stack.present) {
      map['stack'] = Variable<String>(stack.value);
    }
    if (settingKey.present) {
      map['setting_key'] = Variable<String>(settingKey.value);
    }
    if (settingValue.present) {
      map['setting_value'] = Variable<int>(settingValue.value);
    }
    if (pocketMinutes.present) {
      map['pocket_minutes'] = Variable<int>(pocketMinutes.value);
    }
    if (energyLevel.present) {
      map['energy_level'] = Variable<int>(energyLevel.value);
    }
    if (reportValue.present) {
      map['report_value'] = Variable<int>(reportValue.value);
    }
    if (reportWeek.present) {
      map['report_week'] = Variable<int>(reportWeek.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('instantUtcMicros: $instantUtcMicros, ')
          ..write('offsetSeconds: $offsetSeconds, ')
          ..write('itemId: $itemId, ')
          ..write('itemOrigin: $itemOrigin, ')
          ..write('stack: $stack, ')
          ..write('settingKey: $settingKey, ')
          ..write('settingValue: $settingValue, ')
          ..write('pocketMinutes: $pocketMinutes, ')
          ..write('energyLevel: $energyLevel, ')
          ..write('reportValue: $reportValue, ')
          ..write('reportWeek: $reportWeek, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SubstrateDatabase extends GeneratedDatabase {
  _$SubstrateDatabase(QueryExecutor e) : super(e);
  $SubstrateDatabaseManager get managers => $SubstrateDatabaseManager(this);
  late final PoolFacts poolFacts = PoolFacts(this);
  late final LogEntries logEntries = LogEntries(this);
  late final Trigger poolFactsRefuseUpdate = Trigger(
    'CREATE TRIGGER pool_facts_refuse_update BEFORE UPDATE ON pool_facts BEGIN SELECT RAISE (ABORT, \'pool_facts is insert-only (AD-2)\');END',
    'pool_facts_refuse_update',
  );
  late final Trigger poolFactsRefuseDelete = Trigger(
    'CREATE TRIGGER pool_facts_refuse_delete BEFORE DELETE ON pool_facts BEGIN SELECT RAISE (ABORT, \'pool_facts is insert-only (AD-2)\');END',
    'pool_facts_refuse_delete',
  );
  late final Trigger logEntriesRefuseUpdate = Trigger(
    'CREATE TRIGGER log_entries_refuse_update BEFORE UPDATE ON log_entries BEGIN SELECT RAISE (ABORT, \'log_entries is insert-only (AD-2)\');END',
    'log_entries_refuse_update',
  );
  late final Trigger logEntriesRefuseDelete = Trigger(
    'CREATE TRIGGER log_entries_refuse_delete BEFORE DELETE ON log_entries BEGIN SELECT RAISE (ABORT, \'log_entries is insert-only (AD-2)\');END',
    'log_entries_refuse_delete',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    poolFacts,
    logEntries,
    poolFactsRefuseUpdate,
    poolFactsRefuseDelete,
    logEntriesRefuseUpdate,
    logEntriesRefuseDelete,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'pool_facts',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'pool_facts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'log_entries',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'log_entries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [],
    ),
  ]);
}

typedef $PoolFactsCreateCompanionBuilder = PoolFactsCompanion Function({
  required String id,
  required String origin,
  required String size,
  required int instantUtcMicros,
  required int offsetSeconds,
  Value<String?> originContext,
  Value<int> rowid,
});
typedef $PoolFactsUpdateCompanionBuilder = PoolFactsCompanion Function({
  Value<String> id,
  Value<String> origin,
  Value<String> size,
  Value<int> instantUtcMicros,
  Value<int> offsetSeconds,
  Value<String?> originContext,
  Value<int> rowid,
});

class $PoolFactsFilterComposer
    extends Composer<_$SubstrateDatabase, PoolFacts> {
  $PoolFactsFilterComposer({
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

  ColumnFilters<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get instantUtcMicros => $composableBuilder(
    column: $table.instantUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetSeconds => $composableBuilder(
    column: $table.offsetSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originContext => $composableBuilder(
    column: $table.originContext,
    builder: (column) => ColumnFilters(column),
  );
}

class $PoolFactsOrderingComposer
    extends Composer<_$SubstrateDatabase, PoolFacts> {
  $PoolFactsOrderingComposer({
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

  ColumnOrderings<String> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get instantUtcMicros => $composableBuilder(
    column: $table.instantUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetSeconds => $composableBuilder(
    column: $table.offsetSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originContext => $composableBuilder(
    column: $table.originContext,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PoolFactsAnnotationComposer
    extends Composer<_$SubstrateDatabase, PoolFacts> {
  $PoolFactsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get instantUtcMicros => $composableBuilder(
    column: $table.instantUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetSeconds => $composableBuilder(
    column: $table.offsetSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originContext => $composableBuilder(
    column: $table.originContext,
    builder: (column) => column,
  );
}

class $PoolFactsTableManager
    extends
        RootTableManager<
          _$SubstrateDatabase,
          PoolFacts,
          PoolFact,
          $PoolFactsFilterComposer,
          $PoolFactsOrderingComposer,
          $PoolFactsAnnotationComposer,
          $PoolFactsCreateCompanionBuilder,
          $PoolFactsUpdateCompanionBuilder,
          (PoolFact, BaseReferences<_$SubstrateDatabase, PoolFacts, PoolFact>),
          PoolFact,
          PrefetchHooks Function()
        > {
  $PoolFactsTableManager(_$SubstrateDatabase db, PoolFacts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PoolFactsFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PoolFactsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PoolFactsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> origin = const Value.absent(),
                Value<String> size = const Value.absent(),
                Value<int> instantUtcMicros = const Value.absent(),
                Value<int> offsetSeconds = const Value.absent(),
                Value<String?> originContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoolFactsCompanion(
                id: id,
                origin: origin,
                size: size,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
                originContext: originContext,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String origin,
                required String size,
                required int instantUtcMicros,
                required int offsetSeconds,
                Value<String?> originContext = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoolFactsCompanion.insert(
                id: id,
                origin: origin,
                size: size,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
                originContext: originContext,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PoolFactsProcessedTableManager =
    ProcessedTableManager<
      _$SubstrateDatabase,
      PoolFacts,
      PoolFact,
      $PoolFactsFilterComposer,
      $PoolFactsOrderingComposer,
      $PoolFactsAnnotationComposer,
      $PoolFactsCreateCompanionBuilder,
      $PoolFactsUpdateCompanionBuilder,
      (PoolFact, BaseReferences<_$SubstrateDatabase, PoolFacts, PoolFact>),
      PoolFact,
      PrefetchHooks Function()
    >;
typedef $LogEntriesCreateCompanionBuilder = LogEntriesCompanion Function({
  required String id,
  required String kind,
  required int instantUtcMicros,
  required int offsetSeconds,
  Value<String?> itemId,
  Value<String?> itemOrigin,
  Value<String?> stack,
  Value<String?> settingKey,
  Value<int?> settingValue,
  Value<int?> pocketMinutes,
  Value<int?> energyLevel,
  Value<int?> reportValue,
  Value<int?> reportWeek,
  Value<int> rowid,
});
typedef $LogEntriesUpdateCompanionBuilder = LogEntriesCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<int> instantUtcMicros,
  Value<int> offsetSeconds,
  Value<String?> itemId,
  Value<String?> itemOrigin,
  Value<String?> stack,
  Value<String?> settingKey,
  Value<int?> settingValue,
  Value<int?> pocketMinutes,
  Value<int?> energyLevel,
  Value<int?> reportValue,
  Value<int?> reportWeek,
  Value<int> rowid,
});

class $LogEntriesFilterComposer
    extends Composer<_$SubstrateDatabase, LogEntries> {
  $LogEntriesFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get instantUtcMicros => $composableBuilder(
    column: $table.instantUtcMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetSeconds => $composableBuilder(
    column: $table.offsetSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemOrigin => $composableBuilder(
    column: $table.itemOrigin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stack => $composableBuilder(
    column: $table.stack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pocketMinutes => $composableBuilder(
    column: $table.pocketMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get energyLevel => $composableBuilder(
    column: $table.energyLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reportValue => $composableBuilder(
    column: $table.reportValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reportWeek => $composableBuilder(
    column: $table.reportWeek,
    builder: (column) => ColumnFilters(column),
  );
}

class $LogEntriesOrderingComposer
    extends Composer<_$SubstrateDatabase, LogEntries> {
  $LogEntriesOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get instantUtcMicros => $composableBuilder(
    column: $table.instantUtcMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetSeconds => $composableBuilder(
    column: $table.offsetSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemOrigin => $composableBuilder(
    column: $table.itemOrigin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stack => $composableBuilder(
    column: $table.stack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pocketMinutes => $composableBuilder(
    column: $table.pocketMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get energyLevel => $composableBuilder(
    column: $table.energyLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reportValue => $composableBuilder(
    column: $table.reportValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reportWeek => $composableBuilder(
    column: $table.reportWeek,
    builder: (column) => ColumnOrderings(column),
  );
}

class $LogEntriesAnnotationComposer
    extends Composer<_$SubstrateDatabase, LogEntries> {
  $LogEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get instantUtcMicros => $composableBuilder(
    column: $table.instantUtcMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetSeconds => $composableBuilder(
    column: $table.offsetSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get itemOrigin => $composableBuilder(
    column: $table.itemOrigin,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stack =>
      $composableBuilder(column: $table.stack, builder: (column) => column);

  GeneratedColumn<String> get settingKey => $composableBuilder(
    column: $table.settingKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get settingValue => $composableBuilder(
    column: $table.settingValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pocketMinutes => $composableBuilder(
    column: $table.pocketMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get energyLevel => $composableBuilder(
    column: $table.energyLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reportValue => $composableBuilder(
    column: $table.reportValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reportWeek => $composableBuilder(
    column: $table.reportWeek,
    builder: (column) => column,
  );
}

class $LogEntriesTableManager
    extends
        RootTableManager<
          _$SubstrateDatabase,
          LogEntries,
          LogEntry,
          $LogEntriesFilterComposer,
          $LogEntriesOrderingComposer,
          $LogEntriesAnnotationComposer,
          $LogEntriesCreateCompanionBuilder,
          $LogEntriesUpdateCompanionBuilder,
          (LogEntry, BaseReferences<_$SubstrateDatabase, LogEntries, LogEntry>),
          LogEntry,
          PrefetchHooks Function()
        > {
  $LogEntriesTableManager(_$SubstrateDatabase db, LogEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LogEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LogEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LogEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> instantUtcMicros = const Value.absent(),
                Value<int> offsetSeconds = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> itemOrigin = const Value.absent(),
                Value<String?> stack = const Value.absent(),
                Value<String?> settingKey = const Value.absent(),
                Value<int?> settingValue = const Value.absent(),
                Value<int?> pocketMinutes = const Value.absent(),
                Value<int?> energyLevel = const Value.absent(),
                Value<int?> reportValue = const Value.absent(),
                Value<int?> reportWeek = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LogEntriesCompanion(
                id: id,
                kind: kind,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
                itemId: itemId,
                itemOrigin: itemOrigin,
                stack: stack,
                settingKey: settingKey,
                settingValue: settingValue,
                pocketMinutes: pocketMinutes,
                energyLevel: energyLevel,
                reportValue: reportValue,
                reportWeek: reportWeek,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                required int instantUtcMicros,
                required int offsetSeconds,
                Value<String?> itemId = const Value.absent(),
                Value<String?> itemOrigin = const Value.absent(),
                Value<String?> stack = const Value.absent(),
                Value<String?> settingKey = const Value.absent(),
                Value<int?> settingValue = const Value.absent(),
                Value<int?> pocketMinutes = const Value.absent(),
                Value<int?> energyLevel = const Value.absent(),
                Value<int?> reportValue = const Value.absent(),
                Value<int?> reportWeek = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LogEntriesCompanion.insert(
                id: id,
                kind: kind,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
                itemId: itemId,
                itemOrigin: itemOrigin,
                stack: stack,
                settingKey: settingKey,
                settingValue: settingValue,
                pocketMinutes: pocketMinutes,
                energyLevel: energyLevel,
                reportValue: reportValue,
                reportWeek: reportWeek,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $LogEntriesProcessedTableManager =
    ProcessedTableManager<
      _$SubstrateDatabase,
      LogEntries,
      LogEntry,
      $LogEntriesFilterComposer,
      $LogEntriesOrderingComposer,
      $LogEntriesAnnotationComposer,
      $LogEntriesCreateCompanionBuilder,
      $LogEntriesUpdateCompanionBuilder,
      (LogEntry, BaseReferences<_$SubstrateDatabase, LogEntries, LogEntry>),
      LogEntry,
      PrefetchHooks Function()
    >;

class $SubstrateDatabaseManager {
  final _$SubstrateDatabase _db;
  $SubstrateDatabaseManager(this._db);
  $PoolFactsTableManager get poolFacts =>
      $PoolFactsTableManager(_db, _db.poolFacts);
  $LogEntriesTableManager get logEntries =>
      $LogEntriesTableManager(_db, _db.logEntries);
}
