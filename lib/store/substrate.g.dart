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
  static const VerificationMeta _dictatedMeta = const VerificationMeta(
    'dictated',
  );
  late final GeneratedColumn<bool> dictated = GeneratedColumn<bool>(
    'dictated',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _rescueOfMeta = const VerificationMeta(
    'rescueOf',
  );
  late final GeneratedColumn<String> rescueOf = GeneratedColumn<String>(
    'rescue_of',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _estimateSecondsMeta = const VerificationMeta(
    'estimateSeconds',
  );
  late final GeneratedColumn<int> estimateSeconds = GeneratedColumn<int>(
    'estimate_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _stepTextMeta = const VerificationMeta(
    'stepText',
  );
  late final GeneratedColumn<String> stepText = GeneratedColumn<String>(
    'step_text',
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
    dictated,
    rescueOf,
    estimateSeconds,
    stepText,
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
    if (data.containsKey('dictated')) {
      context.handle(
        _dictatedMeta,
        dictated.isAcceptableOrUnknown(data['dictated']!, _dictatedMeta),
      );
    }
    if (data.containsKey('rescue_of')) {
      context.handle(
        _rescueOfMeta,
        rescueOf.isAcceptableOrUnknown(data['rescue_of']!, _rescueOfMeta),
      );
    }
    if (data.containsKey('estimate_seconds')) {
      context.handle(
        _estimateSecondsMeta,
        estimateSeconds.isAcceptableOrUnknown(
          data['estimate_seconds']!,
          _estimateSecondsMeta,
        ),
      );
    }
    if (data.containsKey('step_text')) {
      context.handle(
        _stepTextMeta,
        stepText.isAcceptableOrUnknown(data['step_text']!, _stepTextMeta),
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
      dictated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dictated'],
      ),
      rescueOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rescue_of'],
      ),
      estimateSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimate_seconds'],
      ),
      stepText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step_text'],
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
  final bool? dictated;
  final String? rescueOf;
  final int? estimateSeconds;
  final String? stepText;
  const PoolFact({
    required this.id,
    required this.origin,
    required this.size,
    required this.instantUtcMicros,
    required this.offsetSeconds,
    this.originContext,
    this.dictated,
    this.rescueOf,
    this.estimateSeconds,
    this.stepText,
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
    if (!nullToAbsent || dictated != null) {
      map['dictated'] = Variable<bool>(dictated);
    }
    if (!nullToAbsent || rescueOf != null) {
      map['rescue_of'] = Variable<String>(rescueOf);
    }
    if (!nullToAbsent || estimateSeconds != null) {
      map['estimate_seconds'] = Variable<int>(estimateSeconds);
    }
    if (!nullToAbsent || stepText != null) {
      map['step_text'] = Variable<String>(stepText);
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
      dictated: dictated == null && nullToAbsent
          ? const Value.absent()
          : Value(dictated),
      rescueOf: rescueOf == null && nullToAbsent
          ? const Value.absent()
          : Value(rescueOf),
      estimateSeconds: estimateSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(estimateSeconds),
      stepText: stepText == null && nullToAbsent
          ? const Value.absent()
          : Value(stepText),
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
      dictated: serializer.fromJson<bool?>(json['dictated']),
      rescueOf: serializer.fromJson<String?>(json['rescue_of']),
      estimateSeconds: serializer.fromJson<int?>(json['estimate_seconds']),
      stepText: serializer.fromJson<String?>(json['step_text']),
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
      'dictated': serializer.toJson<bool?>(dictated),
      'rescue_of': serializer.toJson<String?>(rescueOf),
      'estimate_seconds': serializer.toJson<int?>(estimateSeconds),
      'step_text': serializer.toJson<String?>(stepText),
    };
  }

  PoolFact copyWith({
    String? id,
    String? origin,
    String? size,
    int? instantUtcMicros,
    int? offsetSeconds,
    Value<String?> originContext = const Value.absent(),
    Value<bool?> dictated = const Value.absent(),
    Value<String?> rescueOf = const Value.absent(),
    Value<int?> estimateSeconds = const Value.absent(),
    Value<String?> stepText = const Value.absent(),
  }) => PoolFact(
    id: id ?? this.id,
    origin: origin ?? this.origin,
    size: size ?? this.size,
    instantUtcMicros: instantUtcMicros ?? this.instantUtcMicros,
    offsetSeconds: offsetSeconds ?? this.offsetSeconds,
    originContext: originContext.present
        ? originContext.value
        : this.originContext,
    dictated: dictated.present ? dictated.value : this.dictated,
    rescueOf: rescueOf.present ? rescueOf.value : this.rescueOf,
    estimateSeconds: estimateSeconds.present
        ? estimateSeconds.value
        : this.estimateSeconds,
    stepText: stepText.present ? stepText.value : this.stepText,
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
      dictated: data.dictated.present ? data.dictated.value : this.dictated,
      rescueOf: data.rescueOf.present ? data.rescueOf.value : this.rescueOf,
      estimateSeconds: data.estimateSeconds.present
          ? data.estimateSeconds.value
          : this.estimateSeconds,
      stepText: data.stepText.present ? data.stepText.value : this.stepText,
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
          ..write('originContext: $originContext, ')
          ..write('dictated: $dictated, ')
          ..write('rescueOf: $rescueOf, ')
          ..write('estimateSeconds: $estimateSeconds, ')
          ..write('stepText: $stepText')
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
    dictated,
    rescueOf,
    estimateSeconds,
    stepText,
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
          other.originContext == this.originContext &&
          other.dictated == this.dictated &&
          other.rescueOf == this.rescueOf &&
          other.estimateSeconds == this.estimateSeconds &&
          other.stepText == this.stepText);
}

class PoolFactsCompanion extends UpdateCompanion<PoolFact> {
  final Value<String> id;
  final Value<String> origin;
  final Value<String> size;
  final Value<int> instantUtcMicros;
  final Value<int> offsetSeconds;
  final Value<String?> originContext;
  final Value<bool?> dictated;
  final Value<String?> rescueOf;
  final Value<int?> estimateSeconds;
  final Value<String?> stepText;
  final Value<int> rowid;
  const PoolFactsCompanion({
    this.id = const Value.absent(),
    this.origin = const Value.absent(),
    this.size = const Value.absent(),
    this.instantUtcMicros = const Value.absent(),
    this.offsetSeconds = const Value.absent(),
    this.originContext = const Value.absent(),
    this.dictated = const Value.absent(),
    this.rescueOf = const Value.absent(),
    this.estimateSeconds = const Value.absent(),
    this.stepText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PoolFactsCompanion.insert({
    required String id,
    required String origin,
    required String size,
    required int instantUtcMicros,
    required int offsetSeconds,
    this.originContext = const Value.absent(),
    this.dictated = const Value.absent(),
    this.rescueOf = const Value.absent(),
    this.estimateSeconds = const Value.absent(),
    this.stepText = const Value.absent(),
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
    Expression<bool>? dictated,
    Expression<String>? rescueOf,
    Expression<int>? estimateSeconds,
    Expression<String>? stepText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (origin != null) 'origin': origin,
      if (size != null) 'size': size,
      if (instantUtcMicros != null) 'instant_utc_micros': instantUtcMicros,
      if (offsetSeconds != null) 'offset_seconds': offsetSeconds,
      if (originContext != null) 'origin_context': originContext,
      if (dictated != null) 'dictated': dictated,
      if (rescueOf != null) 'rescue_of': rescueOf,
      if (estimateSeconds != null) 'estimate_seconds': estimateSeconds,
      if (stepText != null) 'step_text': stepText,
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
    Value<bool?>? dictated,
    Value<String?>? rescueOf,
    Value<int?>? estimateSeconds,
    Value<String?>? stepText,
    Value<int>? rowid,
  }) {
    return PoolFactsCompanion(
      id: id ?? this.id,
      origin: origin ?? this.origin,
      size: size ?? this.size,
      instantUtcMicros: instantUtcMicros ?? this.instantUtcMicros,
      offsetSeconds: offsetSeconds ?? this.offsetSeconds,
      originContext: originContext ?? this.originContext,
      dictated: dictated ?? this.dictated,
      rescueOf: rescueOf ?? this.rescueOf,
      estimateSeconds: estimateSeconds ?? this.estimateSeconds,
      stepText: stepText ?? this.stepText,
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
    if (dictated.present) {
      map['dictated'] = Variable<bool>(dictated.value);
    }
    if (rescueOf.present) {
      map['rescue_of'] = Variable<String>(rescueOf.value);
    }
    if (estimateSeconds.present) {
      map['estimate_seconds'] = Variable<int>(estimateSeconds.value);
    }
    if (stepText.present) {
      map['step_text'] = Variable<String>(stepText.value);
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
          ..write('dictated: $dictated, ')
          ..write('rescueOf: $rescueOf, ')
          ..write('estimateSeconds: $estimateSeconds, ')
          ..write('stepText: $stepText, ')
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
  static const VerificationMeta _textValueMeta = const VerificationMeta(
    'textValue',
  );
  late final GeneratedColumn<String> textValue = GeneratedColumn<String>(
    'text_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _permissionMeta = const VerificationMeta(
    'permission',
  );
  late final GeneratedColumn<String> permission = GeneratedColumn<String>(
    'permission',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _sliceCauseMeta = const VerificationMeta(
    'sliceCause',
  );
  late final GeneratedColumn<String> sliceCause = GeneratedColumn<String>(
    'slice_cause',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _clusterMeta = const VerificationMeta(
    'cluster',
  );
  late final GeneratedColumn<String> cluster = GeneratedColumn<String>(
    'cluster',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _triageDestinationMeta = const VerificationMeta(
    'triageDestination',
  );
  late final GeneratedColumn<String> triageDestination =
      GeneratedColumn<String>(
        'triage_destination',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: 'NULL',
      );
  static const VerificationMeta _triageVolumeTagMeta = const VerificationMeta(
    'triageVolumeTag',
  );
  late final GeneratedColumn<String> triageVolumeTag = GeneratedColumn<String>(
    'triage_volume_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _triageBoxIdMeta = const VerificationMeta(
    'triageBoxId',
  );
  late final GeneratedColumn<String> triageBoxId = GeneratedColumn<String>(
    'triage_box_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _beforeBlobMeta = const VerificationMeta(
    'beforeBlob',
  );
  late final GeneratedColumn<String> beforeBlob = GeneratedColumn<String>(
    'before_blob',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL',
  );
  static const VerificationMeta _afterBlobMeta = const VerificationMeta(
    'afterBlob',
  );
  late final GeneratedColumn<String> afterBlob = GeneratedColumn<String>(
    'after_blob',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    textValue,
    pocketMinutes,
    energyLevel,
    reportValue,
    reportWeek,
    permission,
    sliceCause,
    cluster,
    enabled,
    triageDestination,
    triageVolumeTag,
    triageBoxId,
    beforeBlob,
    afterBlob,
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
    if (data.containsKey('text_value')) {
      context.handle(
        _textValueMeta,
        textValue.isAcceptableOrUnknown(data['text_value']!, _textValueMeta),
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
    if (data.containsKey('permission')) {
      context.handle(
        _permissionMeta,
        permission.isAcceptableOrUnknown(data['permission']!, _permissionMeta),
      );
    }
    if (data.containsKey('slice_cause')) {
      context.handle(
        _sliceCauseMeta,
        sliceCause.isAcceptableOrUnknown(data['slice_cause']!, _sliceCauseMeta),
      );
    }
    if (data.containsKey('cluster')) {
      context.handle(
        _clusterMeta,
        cluster.isAcceptableOrUnknown(data['cluster']!, _clusterMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('triage_destination')) {
      context.handle(
        _triageDestinationMeta,
        triageDestination.isAcceptableOrUnknown(
          data['triage_destination']!,
          _triageDestinationMeta,
        ),
      );
    }
    if (data.containsKey('triage_volume_tag')) {
      context.handle(
        _triageVolumeTagMeta,
        triageVolumeTag.isAcceptableOrUnknown(
          data['triage_volume_tag']!,
          _triageVolumeTagMeta,
        ),
      );
    }
    if (data.containsKey('triage_box_id')) {
      context.handle(
        _triageBoxIdMeta,
        triageBoxId.isAcceptableOrUnknown(
          data['triage_box_id']!,
          _triageBoxIdMeta,
        ),
      );
    }
    if (data.containsKey('before_blob')) {
      context.handle(
        _beforeBlobMeta,
        beforeBlob.isAcceptableOrUnknown(data['before_blob']!, _beforeBlobMeta),
      );
    }
    if (data.containsKey('after_blob')) {
      context.handle(
        _afterBlobMeta,
        afterBlob.isAcceptableOrUnknown(data['after_blob']!, _afterBlobMeta),
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
      textValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_value'],
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
      permission: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission'],
      ),
      sliceCause: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slice_cause'],
      ),
      cluster: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cluster'],
      ),
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      ),
      triageDestination: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triage_destination'],
      ),
      triageVolumeTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triage_volume_tag'],
      ),
      triageBoxId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}triage_box_id'],
      ),
      beforeBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}before_blob'],
      ),
      afterBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}after_blob'],
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
  final String? textValue;
  final int? pocketMinutes;
  final int? energyLevel;
  final int? reportValue;
  final int? reportWeek;
  final String? permission;
  final String? sliceCause;
  final String? cluster;
  final bool? enabled;
  final String? triageDestination;
  final String? triageVolumeTag;
  final String? triageBoxId;
  final String? beforeBlob;
  final String? afterBlob;
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
    this.textValue,
    this.pocketMinutes,
    this.energyLevel,
    this.reportValue,
    this.reportWeek,
    this.permission,
    this.sliceCause,
    this.cluster,
    this.enabled,
    this.triageDestination,
    this.triageVolumeTag,
    this.triageBoxId,
    this.beforeBlob,
    this.afterBlob,
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
    if (!nullToAbsent || textValue != null) {
      map['text_value'] = Variable<String>(textValue);
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
    if (!nullToAbsent || permission != null) {
      map['permission'] = Variable<String>(permission);
    }
    if (!nullToAbsent || sliceCause != null) {
      map['slice_cause'] = Variable<String>(sliceCause);
    }
    if (!nullToAbsent || cluster != null) {
      map['cluster'] = Variable<String>(cluster);
    }
    if (!nullToAbsent || enabled != null) {
      map['enabled'] = Variable<bool>(enabled);
    }
    if (!nullToAbsent || triageDestination != null) {
      map['triage_destination'] = Variable<String>(triageDestination);
    }
    if (!nullToAbsent || triageVolumeTag != null) {
      map['triage_volume_tag'] = Variable<String>(triageVolumeTag);
    }
    if (!nullToAbsent || triageBoxId != null) {
      map['triage_box_id'] = Variable<String>(triageBoxId);
    }
    if (!nullToAbsent || beforeBlob != null) {
      map['before_blob'] = Variable<String>(beforeBlob);
    }
    if (!nullToAbsent || afterBlob != null) {
      map['after_blob'] = Variable<String>(afterBlob);
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
      textValue: textValue == null && nullToAbsent
          ? const Value.absent()
          : Value(textValue),
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
      permission: permission == null && nullToAbsent
          ? const Value.absent()
          : Value(permission),
      sliceCause: sliceCause == null && nullToAbsent
          ? const Value.absent()
          : Value(sliceCause),
      cluster: cluster == null && nullToAbsent
          ? const Value.absent()
          : Value(cluster),
      enabled: enabled == null && nullToAbsent
          ? const Value.absent()
          : Value(enabled),
      triageDestination: triageDestination == null && nullToAbsent
          ? const Value.absent()
          : Value(triageDestination),
      triageVolumeTag: triageVolumeTag == null && nullToAbsent
          ? const Value.absent()
          : Value(triageVolumeTag),
      triageBoxId: triageBoxId == null && nullToAbsent
          ? const Value.absent()
          : Value(triageBoxId),
      beforeBlob: beforeBlob == null && nullToAbsent
          ? const Value.absent()
          : Value(beforeBlob),
      afterBlob: afterBlob == null && nullToAbsent
          ? const Value.absent()
          : Value(afterBlob),
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
      textValue: serializer.fromJson<String?>(json['text_value']),
      pocketMinutes: serializer.fromJson<int?>(json['pocket_minutes']),
      energyLevel: serializer.fromJson<int?>(json['energy_level']),
      reportValue: serializer.fromJson<int?>(json['report_value']),
      reportWeek: serializer.fromJson<int?>(json['report_week']),
      permission: serializer.fromJson<String?>(json['permission']),
      sliceCause: serializer.fromJson<String?>(json['slice_cause']),
      cluster: serializer.fromJson<String?>(json['cluster']),
      enabled: serializer.fromJson<bool?>(json['enabled']),
      triageDestination: serializer.fromJson<String?>(
        json['triage_destination'],
      ),
      triageVolumeTag: serializer.fromJson<String?>(json['triage_volume_tag']),
      triageBoxId: serializer.fromJson<String?>(json['triage_box_id']),
      beforeBlob: serializer.fromJson<String?>(json['before_blob']),
      afterBlob: serializer.fromJson<String?>(json['after_blob']),
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
      'text_value': serializer.toJson<String?>(textValue),
      'pocket_minutes': serializer.toJson<int?>(pocketMinutes),
      'energy_level': serializer.toJson<int?>(energyLevel),
      'report_value': serializer.toJson<int?>(reportValue),
      'report_week': serializer.toJson<int?>(reportWeek),
      'permission': serializer.toJson<String?>(permission),
      'slice_cause': serializer.toJson<String?>(sliceCause),
      'cluster': serializer.toJson<String?>(cluster),
      'enabled': serializer.toJson<bool?>(enabled),
      'triage_destination': serializer.toJson<String?>(triageDestination),
      'triage_volume_tag': serializer.toJson<String?>(triageVolumeTag),
      'triage_box_id': serializer.toJson<String?>(triageBoxId),
      'before_blob': serializer.toJson<String?>(beforeBlob),
      'after_blob': serializer.toJson<String?>(afterBlob),
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
    Value<String?> textValue = const Value.absent(),
    Value<int?> pocketMinutes = const Value.absent(),
    Value<int?> energyLevel = const Value.absent(),
    Value<int?> reportValue = const Value.absent(),
    Value<int?> reportWeek = const Value.absent(),
    Value<String?> permission = const Value.absent(),
    Value<String?> sliceCause = const Value.absent(),
    Value<String?> cluster = const Value.absent(),
    Value<bool?> enabled = const Value.absent(),
    Value<String?> triageDestination = const Value.absent(),
    Value<String?> triageVolumeTag = const Value.absent(),
    Value<String?> triageBoxId = const Value.absent(),
    Value<String?> beforeBlob = const Value.absent(),
    Value<String?> afterBlob = const Value.absent(),
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
    textValue: textValue.present ? textValue.value : this.textValue,
    pocketMinutes: pocketMinutes.present
        ? pocketMinutes.value
        : this.pocketMinutes,
    energyLevel: energyLevel.present ? energyLevel.value : this.energyLevel,
    reportValue: reportValue.present ? reportValue.value : this.reportValue,
    reportWeek: reportWeek.present ? reportWeek.value : this.reportWeek,
    permission: permission.present ? permission.value : this.permission,
    sliceCause: sliceCause.present ? sliceCause.value : this.sliceCause,
    cluster: cluster.present ? cluster.value : this.cluster,
    enabled: enabled.present ? enabled.value : this.enabled,
    triageDestination: triageDestination.present
        ? triageDestination.value
        : this.triageDestination,
    triageVolumeTag: triageVolumeTag.present
        ? triageVolumeTag.value
        : this.triageVolumeTag,
    triageBoxId: triageBoxId.present ? triageBoxId.value : this.triageBoxId,
    beforeBlob: beforeBlob.present ? beforeBlob.value : this.beforeBlob,
    afterBlob: afterBlob.present ? afterBlob.value : this.afterBlob,
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
      textValue: data.textValue.present ? data.textValue.value : this.textValue,
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
      permission: data.permission.present
          ? data.permission.value
          : this.permission,
      sliceCause: data.sliceCause.present
          ? data.sliceCause.value
          : this.sliceCause,
      cluster: data.cluster.present ? data.cluster.value : this.cluster,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      triageDestination: data.triageDestination.present
          ? data.triageDestination.value
          : this.triageDestination,
      triageVolumeTag: data.triageVolumeTag.present
          ? data.triageVolumeTag.value
          : this.triageVolumeTag,
      triageBoxId: data.triageBoxId.present
          ? data.triageBoxId.value
          : this.triageBoxId,
      beforeBlob: data.beforeBlob.present
          ? data.beforeBlob.value
          : this.beforeBlob,
      afterBlob: data.afterBlob.present ? data.afterBlob.value : this.afterBlob,
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
          ..write('textValue: $textValue, ')
          ..write('pocketMinutes: $pocketMinutes, ')
          ..write('energyLevel: $energyLevel, ')
          ..write('reportValue: $reportValue, ')
          ..write('reportWeek: $reportWeek, ')
          ..write('permission: $permission, ')
          ..write('sliceCause: $sliceCause, ')
          ..write('cluster: $cluster, ')
          ..write('enabled: $enabled, ')
          ..write('triageDestination: $triageDestination, ')
          ..write('triageVolumeTag: $triageVolumeTag, ')
          ..write('triageBoxId: $triageBoxId, ')
          ..write('beforeBlob: $beforeBlob, ')
          ..write('afterBlob: $afterBlob')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    kind,
    instantUtcMicros,
    offsetSeconds,
    itemId,
    itemOrigin,
    stack,
    settingKey,
    settingValue,
    textValue,
    pocketMinutes,
    energyLevel,
    reportValue,
    reportWeek,
    permission,
    sliceCause,
    cluster,
    enabled,
    triageDestination,
    triageVolumeTag,
    triageBoxId,
    beforeBlob,
    afterBlob,
  ]);
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
          other.textValue == this.textValue &&
          other.pocketMinutes == this.pocketMinutes &&
          other.energyLevel == this.energyLevel &&
          other.reportValue == this.reportValue &&
          other.reportWeek == this.reportWeek &&
          other.permission == this.permission &&
          other.sliceCause == this.sliceCause &&
          other.cluster == this.cluster &&
          other.enabled == this.enabled &&
          other.triageDestination == this.triageDestination &&
          other.triageVolumeTag == this.triageVolumeTag &&
          other.triageBoxId == this.triageBoxId &&
          other.beforeBlob == this.beforeBlob &&
          other.afterBlob == this.afterBlob);
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
  final Value<String?> textValue;
  final Value<int?> pocketMinutes;
  final Value<int?> energyLevel;
  final Value<int?> reportValue;
  final Value<int?> reportWeek;
  final Value<String?> permission;
  final Value<String?> sliceCause;
  final Value<String?> cluster;
  final Value<bool?> enabled;
  final Value<String?> triageDestination;
  final Value<String?> triageVolumeTag;
  final Value<String?> triageBoxId;
  final Value<String?> beforeBlob;
  final Value<String?> afterBlob;
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
    this.textValue = const Value.absent(),
    this.pocketMinutes = const Value.absent(),
    this.energyLevel = const Value.absent(),
    this.reportValue = const Value.absent(),
    this.reportWeek = const Value.absent(),
    this.permission = const Value.absent(),
    this.sliceCause = const Value.absent(),
    this.cluster = const Value.absent(),
    this.enabled = const Value.absent(),
    this.triageDestination = const Value.absent(),
    this.triageVolumeTag = const Value.absent(),
    this.triageBoxId = const Value.absent(),
    this.beforeBlob = const Value.absent(),
    this.afterBlob = const Value.absent(),
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
    this.textValue = const Value.absent(),
    this.pocketMinutes = const Value.absent(),
    this.energyLevel = const Value.absent(),
    this.reportValue = const Value.absent(),
    this.reportWeek = const Value.absent(),
    this.permission = const Value.absent(),
    this.sliceCause = const Value.absent(),
    this.cluster = const Value.absent(),
    this.enabled = const Value.absent(),
    this.triageDestination = const Value.absent(),
    this.triageVolumeTag = const Value.absent(),
    this.triageBoxId = const Value.absent(),
    this.beforeBlob = const Value.absent(),
    this.afterBlob = const Value.absent(),
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
    Expression<String>? textValue,
    Expression<int>? pocketMinutes,
    Expression<int>? energyLevel,
    Expression<int>? reportValue,
    Expression<int>? reportWeek,
    Expression<String>? permission,
    Expression<String>? sliceCause,
    Expression<String>? cluster,
    Expression<bool>? enabled,
    Expression<String>? triageDestination,
    Expression<String>? triageVolumeTag,
    Expression<String>? triageBoxId,
    Expression<String>? beforeBlob,
    Expression<String>? afterBlob,
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
      if (textValue != null) 'text_value': textValue,
      if (pocketMinutes != null) 'pocket_minutes': pocketMinutes,
      if (energyLevel != null) 'energy_level': energyLevel,
      if (reportValue != null) 'report_value': reportValue,
      if (reportWeek != null) 'report_week': reportWeek,
      if (permission != null) 'permission': permission,
      if (sliceCause != null) 'slice_cause': sliceCause,
      if (cluster != null) 'cluster': cluster,
      if (enabled != null) 'enabled': enabled,
      if (triageDestination != null) 'triage_destination': triageDestination,
      if (triageVolumeTag != null) 'triage_volume_tag': triageVolumeTag,
      if (triageBoxId != null) 'triage_box_id': triageBoxId,
      if (beforeBlob != null) 'before_blob': beforeBlob,
      if (afterBlob != null) 'after_blob': afterBlob,
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
    Value<String?>? textValue,
    Value<int?>? pocketMinutes,
    Value<int?>? energyLevel,
    Value<int?>? reportValue,
    Value<int?>? reportWeek,
    Value<String?>? permission,
    Value<String?>? sliceCause,
    Value<String?>? cluster,
    Value<bool?>? enabled,
    Value<String?>? triageDestination,
    Value<String?>? triageVolumeTag,
    Value<String?>? triageBoxId,
    Value<String?>? beforeBlob,
    Value<String?>? afterBlob,
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
      textValue: textValue ?? this.textValue,
      pocketMinutes: pocketMinutes ?? this.pocketMinutes,
      energyLevel: energyLevel ?? this.energyLevel,
      reportValue: reportValue ?? this.reportValue,
      reportWeek: reportWeek ?? this.reportWeek,
      permission: permission ?? this.permission,
      sliceCause: sliceCause ?? this.sliceCause,
      cluster: cluster ?? this.cluster,
      enabled: enabled ?? this.enabled,
      triageDestination: triageDestination ?? this.triageDestination,
      triageVolumeTag: triageVolumeTag ?? this.triageVolumeTag,
      triageBoxId: triageBoxId ?? this.triageBoxId,
      beforeBlob: beforeBlob ?? this.beforeBlob,
      afterBlob: afterBlob ?? this.afterBlob,
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
    if (textValue.present) {
      map['text_value'] = Variable<String>(textValue.value);
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
    if (permission.present) {
      map['permission'] = Variable<String>(permission.value);
    }
    if (sliceCause.present) {
      map['slice_cause'] = Variable<String>(sliceCause.value);
    }
    if (cluster.present) {
      map['cluster'] = Variable<String>(cluster.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (triageDestination.present) {
      map['triage_destination'] = Variable<String>(triageDestination.value);
    }
    if (triageVolumeTag.present) {
      map['triage_volume_tag'] = Variable<String>(triageVolumeTag.value);
    }
    if (triageBoxId.present) {
      map['triage_box_id'] = Variable<String>(triageBoxId.value);
    }
    if (beforeBlob.present) {
      map['before_blob'] = Variable<String>(beforeBlob.value);
    }
    if (afterBlob.present) {
      map['after_blob'] = Variable<String>(afterBlob.value);
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
          ..write('textValue: $textValue, ')
          ..write('pocketMinutes: $pocketMinutes, ')
          ..write('energyLevel: $energyLevel, ')
          ..write('reportValue: $reportValue, ')
          ..write('reportWeek: $reportWeek, ')
          ..write('permission: $permission, ')
          ..write('sliceCause: $sliceCause, ')
          ..write('cluster: $cluster, ')
          ..write('enabled: $enabled, ')
          ..write('triageDestination: $triageDestination, ')
          ..write('triageVolumeTag: $triageVolumeTag, ')
          ..write('triageBoxId: $triageBoxId, ')
          ..write('beforeBlob: $beforeBlob, ')
          ..write('afterBlob: $afterBlob, ')
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
  Value<bool?> dictated,
  Value<String?> rescueOf,
  Value<int?> estimateSeconds,
  Value<String?> stepText,
  Value<int> rowid,
});
typedef $PoolFactsUpdateCompanionBuilder = PoolFactsCompanion Function({
  Value<String> id,
  Value<String> origin,
  Value<String> size,
  Value<int> instantUtcMicros,
  Value<int> offsetSeconds,
  Value<String?> originContext,
  Value<bool?> dictated,
  Value<String?> rescueOf,
  Value<int?> estimateSeconds,
  Value<String?> stepText,
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

  ColumnFilters<bool> get dictated => $composableBuilder(
    column: $table.dictated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rescueOf => $composableBuilder(
    column: $table.rescueOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimateSeconds => $composableBuilder(
    column: $table.estimateSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stepText => $composableBuilder(
    column: $table.stepText,
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

  ColumnOrderings<bool> get dictated => $composableBuilder(
    column: $table.dictated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rescueOf => $composableBuilder(
    column: $table.rescueOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimateSeconds => $composableBuilder(
    column: $table.estimateSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stepText => $composableBuilder(
    column: $table.stepText,
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

  GeneratedColumn<bool> get dictated =>
      $composableBuilder(column: $table.dictated, builder: (column) => column);

  GeneratedColumn<String> get rescueOf =>
      $composableBuilder(column: $table.rescueOf, builder: (column) => column);

  GeneratedColumn<int> get estimateSeconds => $composableBuilder(
    column: $table.estimateSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stepText =>
      $composableBuilder(column: $table.stepText, builder: (column) => column);
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
                Value<bool?> dictated = const Value.absent(),
                Value<String?> rescueOf = const Value.absent(),
                Value<int?> estimateSeconds = const Value.absent(),
                Value<String?> stepText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoolFactsCompanion(
                id: id,
                origin: origin,
                size: size,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
                originContext: originContext,
                dictated: dictated,
                rescueOf: rescueOf,
                estimateSeconds: estimateSeconds,
                stepText: stepText,
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
                Value<bool?> dictated = const Value.absent(),
                Value<String?> rescueOf = const Value.absent(),
                Value<int?> estimateSeconds = const Value.absent(),
                Value<String?> stepText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PoolFactsCompanion.insert(
                id: id,
                origin: origin,
                size: size,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
                originContext: originContext,
                dictated: dictated,
                rescueOf: rescueOf,
                estimateSeconds: estimateSeconds,
                stepText: stepText,
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
  Value<String?> textValue,
  Value<int?> pocketMinutes,
  Value<int?> energyLevel,
  Value<int?> reportValue,
  Value<int?> reportWeek,
  Value<String?> permission,
  Value<String?> sliceCause,
  Value<String?> cluster,
  Value<bool?> enabled,
  Value<String?> triageDestination,
  Value<String?> triageVolumeTag,
  Value<String?> triageBoxId,
  Value<String?> beforeBlob,
  Value<String?> afterBlob,
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
  Value<String?> textValue,
  Value<int?> pocketMinutes,
  Value<int?> energyLevel,
  Value<int?> reportValue,
  Value<int?> reportWeek,
  Value<String?> permission,
  Value<String?> sliceCause,
  Value<String?> cluster,
  Value<bool?> enabled,
  Value<String?> triageDestination,
  Value<String?> triageVolumeTag,
  Value<String?> triageBoxId,
  Value<String?> beforeBlob,
  Value<String?> afterBlob,
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

  ColumnFilters<String> get textValue => $composableBuilder(
    column: $table.textValue,
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

  ColumnFilters<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sliceCause => $composableBuilder(
    column: $table.sliceCause,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cluster => $composableBuilder(
    column: $table.cluster,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triageDestination => $composableBuilder(
    column: $table.triageDestination,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triageVolumeTag => $composableBuilder(
    column: $table.triageVolumeTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triageBoxId => $composableBuilder(
    column: $table.triageBoxId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beforeBlob => $composableBuilder(
    column: $table.beforeBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get afterBlob => $composableBuilder(
    column: $table.afterBlob,
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

  ColumnOrderings<String> get textValue => $composableBuilder(
    column: $table.textValue,
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

  ColumnOrderings<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sliceCause => $composableBuilder(
    column: $table.sliceCause,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cluster => $composableBuilder(
    column: $table.cluster,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triageDestination => $composableBuilder(
    column: $table.triageDestination,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triageVolumeTag => $composableBuilder(
    column: $table.triageVolumeTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triageBoxId => $composableBuilder(
    column: $table.triageBoxId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beforeBlob => $composableBuilder(
    column: $table.beforeBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get afterBlob => $composableBuilder(
    column: $table.afterBlob,
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

  GeneratedColumn<String> get textValue =>
      $composableBuilder(column: $table.textValue, builder: (column) => column);

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

  GeneratedColumn<String> get permission => $composableBuilder(
    column: $table.permission,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sliceCause => $composableBuilder(
    column: $table.sliceCause,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cluster =>
      $composableBuilder(column: $table.cluster, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get triageDestination => $composableBuilder(
    column: $table.triageDestination,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triageVolumeTag => $composableBuilder(
    column: $table.triageVolumeTag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triageBoxId => $composableBuilder(
    column: $table.triageBoxId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get beforeBlob => $composableBuilder(
    column: $table.beforeBlob,
    builder: (column) => column,
  );

  GeneratedColumn<String> get afterBlob =>
      $composableBuilder(column: $table.afterBlob, builder: (column) => column);
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
                Value<String?> textValue = const Value.absent(),
                Value<int?> pocketMinutes = const Value.absent(),
                Value<int?> energyLevel = const Value.absent(),
                Value<int?> reportValue = const Value.absent(),
                Value<int?> reportWeek = const Value.absent(),
                Value<String?> permission = const Value.absent(),
                Value<String?> sliceCause = const Value.absent(),
                Value<String?> cluster = const Value.absent(),
                Value<bool?> enabled = const Value.absent(),
                Value<String?> triageDestination = const Value.absent(),
                Value<String?> triageVolumeTag = const Value.absent(),
                Value<String?> triageBoxId = const Value.absent(),
                Value<String?> beforeBlob = const Value.absent(),
                Value<String?> afterBlob = const Value.absent(),
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
                textValue: textValue,
                pocketMinutes: pocketMinutes,
                energyLevel: energyLevel,
                reportValue: reportValue,
                reportWeek: reportWeek,
                permission: permission,
                sliceCause: sliceCause,
                cluster: cluster,
                enabled: enabled,
                triageDestination: triageDestination,
                triageVolumeTag: triageVolumeTag,
                triageBoxId: triageBoxId,
                beforeBlob: beforeBlob,
                afterBlob: afterBlob,
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
                Value<String?> textValue = const Value.absent(),
                Value<int?> pocketMinutes = const Value.absent(),
                Value<int?> energyLevel = const Value.absent(),
                Value<int?> reportValue = const Value.absent(),
                Value<int?> reportWeek = const Value.absent(),
                Value<String?> permission = const Value.absent(),
                Value<String?> sliceCause = const Value.absent(),
                Value<String?> cluster = const Value.absent(),
                Value<bool?> enabled = const Value.absent(),
                Value<String?> triageDestination = const Value.absent(),
                Value<String?> triageVolumeTag = const Value.absent(),
                Value<String?> triageBoxId = const Value.absent(),
                Value<String?> beforeBlob = const Value.absent(),
                Value<String?> afterBlob = const Value.absent(),
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
                textValue: textValue,
                pocketMinutes: pocketMinutes,
                energyLevel: energyLevel,
                reportValue: reportValue,
                reportWeek: reportWeek,
                permission: permission,
                sliceCause: sliceCause,
                cluster: cluster,
                enabled: enabled,
                triageDestination: triageDestination,
                triageVolumeTag: triageVolumeTag,
                triageBoxId: triageBoxId,
                beforeBlob: beforeBlob,
                afterBlob: afterBlob,
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
