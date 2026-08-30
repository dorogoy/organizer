/// The log vocabulary (AD-21): the event log holds user acts and system
/// events, and no entry may assert an absence or an obligation.
///
/// This file holds Story 1.3's slice of the vocabulary: the seven kinds the
/// epic names, plus the unknown-kind carrier every forward-only reader must
/// tolerate (AD-23) — and, additively since Story 2.1, the eighth kind
/// `setting_changed`. A new kind is a new kind, never a flag on an old one.
///
/// It also holds the validated record→entry conversion every read passes
/// through (Story 1.6, the item 1.3 deferred here): the inert records the
/// store port returns become domain entries only after their shape checks
/// out — itemId/itemOrigin travel as a pair, `stack` rides only on
/// `crash_recorded`, `setting_changed` carries its key and value, and a
/// known kind's payload must match the kind.

library;

import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';

/// One entry kind, as a past-tense `snake_case` verb phrase. Instances are
/// values: known kinds are the static constants, and [parse] carries any
/// other name as an unknown kind — never coerced, never fatal (AD-23).
final class LogKind {
  const LogKind._(this.name, {required this.known});

  /// The wire name, exactly as it is stored and exported.
  final String name;

  /// Whether this build knows the kind. Unknown kinds are carried and
  /// skipped by every derivation.
  final bool known;

  static const cardDealt = LogKind._('card_dealt', known: true);
  static const cardDone = LogKind._('card_done', known: true);
  static const cardSkipped = LogKind._('card_skipped', known: true);
  static const sessionStarted = LogKind._('session_started', known: true);
  static const sessionEnded = LogKind._('session_ended', known: true);
  static const appOpened = LogKind._('app_opened', known: true);
  static const crashRecorded = LogKind._('crash_recorded', known: true);
  static const settingChanged = LogKind._('setting_changed', known: true);

  /// Every kind this build knows, keyed by wire name.
  static const knownByName = <String, LogKind>{
    'card_dealt': cardDealt,
    'card_done': cardDone,
    'card_skipped': cardSkipped,
    'session_started': sessionStarted,
    'session_ended': sessionEnded,
    'app_opened': appOpened,
    'crash_recorded': crashRecorded,
    'setting_changed': settingChanged,
  };

  /// Resolves a stored name. A name this build does not know parses to an
  /// unknown kind — carried verbatim, never coerced (AD-23).
  static LogKind parse(String name) =>
      knownByName[name] ?? LogKind._(name, known: false);

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      other is LogKind && other.name == name && other.known == known;

  @override
  int get hashCode => Object.hash(name, known);
}

/// One append-only log entry. Every entry carries its shell-minted UUIDv7
/// id and its instant plus the local offset in force when it was written
/// (AD-4); the subtypes carry their payload and nothing else. Only the core
/// constructs domain objects (AD-5) — the shell hands the port an inert
/// record.
sealed class LogEntry {
  const LogEntry({
    required this.id,
    required this.instantUtcMicros,
    required this.offsetSeconds,
  });

  /// This entry's kind.
  LogKind get kind;

  /// The shell-minted UUIDv7 id.
  final String id;

  /// The entry's instant, in UTC microseconds since the epoch.
  final int instantUtcMicros;

  /// The local UTC offset in force when the entry was written, in seconds
  /// east of UTC (AD-4: the offset travels with the event).
  final int offsetSeconds;
}

/// A user act on a pool item (`card_dealt`, `card_done`, `card_skipped`):
/// the kind, the instant, and the referenced item's id and origin (AD-14).
final class ItemActEntry extends LogEntry {
  const ItemActEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.kind,
    required this.itemId,
    required this.itemOrigin,
  });

  @override
  final LogKind kind;

  /// The referenced pool item's id.
  final String itemId;

  /// The referenced item's origin, which every item-referencing entry
  /// carries too (AD-14).
  final Origin itemOrigin;
}

/// A moment in the product's life with no pool-item referent
/// (`session_started`, `session_ended`, `app_opened`).
final class MomentEntry extends LogEntry {
  const MomentEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.kind,
  });

  @override
  final LogKind kind;
}

/// A `crash_recorded` system event (AD-12): the stack and the timestamp —
/// and nothing else. The type offers no other field, so no task text, image
/// path, prompt or URL can ride along.
final class CrashEntry extends LogEntry {
  const CrashEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.stack,
  });

  @override
  final LogKind kind = LogKind.crashRecorded;

  /// The stack trace, as text.
  final String stack;
}

/// A `setting_changed` user act (Story 2.1, AD-1): the setting's key and
/// its new value. The settings record is a derived cache over these
/// entries — never a source of truth — and the type offers no other
/// field, so no availability claim or capability grant can ride along
/// (AD-22's discipline, arrived at ahead of its story). A value outside
/// the setting's confirmed range stays in the log and derives nothing:
/// tolerance, never repair (AD-23).
final class SettingEntry extends LogEntry {
  const SettingEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.key,
    required this.value,
  });

  @override
  final LogKind kind = LogKind.settingChanged;

  /// The setting's key — the only key this build knows is the Time
  /// Bag's; any other key is carried verbatim and derives nothing.
  final String key;

  /// The setting's new value, as written.
  final int value;
}

/// An entry whose kind this build does not know. Carried verbatim and
/// skipped by every derivation — never coerced, never fatal (AD-23).
final class UnknownEntry extends LogEntry {
  const UnknownEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.kind,
  });

  @override
  final LogKind kind;
}

/// Why one record was excluded at the read boundary. Surfaced distinctly,
/// never coerced: AD-23's tolerance is for kinds this build does not know,
/// not for a known kind whose payload disagrees with it.
enum LogRecordFlaw {
  /// Exactly one of itemId/itemOrigin — the pair travels together (AD-14).
  halfItemPair,

  /// An item act (`card_*`) with no item pair at all.
  itemPairAbsent,

  /// A `stack` payload on a kind that is not `crash_recorded` (AD-12).
  stackOffCrashKind,

  /// An item pair on a kind that references no pool item.
  itemOnNonItemKind,

  /// `crash_recorded` without its stack (AD-12).
  stackAbsent,

  /// A kind this build knows but this boundary does not classify:
  /// excluded rather than coerced into a moment. A new kind extends
  /// `_isItemAct`/`_isMoment` in the same pass that adds it to
  /// [LogKind], and until then it lands here — never a `MomentEntry`
  /// carrying a foreign kind.
  unclassifiedKind,

  /// `setting_changed` without its key (AD-1 — an entry must name the
  /// setting it changed; an empty string is not a value here either).
  settingKeyAbsent,

  /// `setting_changed` without its int value.
  settingValueAbsent,

  /// A setting key or value on a kind that is not `setting_changed`.
  settingOnNonSettingKind,
}

/// One record's conversion at the read boundary: the domain entry when the
/// shape checks out, otherwise the flaw that excludes the row — exactly one
/// of the two is non-null.
typedef LogEntryConversion = ({LogEntry? entry, LogRecordFlaw? flaw});

bool _isItemAct(LogKind kind) =>
    kind == LogKind.cardDealt ||
    kind == LogKind.cardDone ||
    kind == LogKind.cardSkipped;

bool _isMoment(LogKind kind) =>
    kind == LogKind.sessionStarted ||
    kind == LogKind.sessionEnded ||
    kind == LogKind.appOpened;

/// Converts one inert store record into a domain entry with shape
/// validation — the boundary Story 1.3 deferred to this story. Unknown
/// kinds are carried as [UnknownEntry] whatever their payload (AD-23);
/// a known kind must carry exactly its own payload: an item act its full
/// item pair and no stack, a moment neither, `crash_recorded` its stack
/// and nothing else (AD-12, AD-14), `setting_changed` its key and int
/// value and nothing else (AD-1). An empty string is not a value
/// here: an itemId that is empty counts as an absent pair, an empty
/// stack as no stack, an empty setting key as no key. A known kind this
/// boundary does not classify is excluded with
/// [LogRecordFlaw.unclassifiedKind] — never coerced.
LogEntryConversion convertLogEntryRecord(LogEntryRecord record) {
  final kind = LogKind.parse(record.kind);

  if (!kind.known) {
    return (
      entry: UnknownEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        kind: kind,
      ),
      flaw: null,
    );
  }

  final itemIdIsAbsent = record.itemId?.isEmpty ?? true;
  // The house rule, applied to the setting fields as to every other:
  // an empty string is not a value — an empty setting key counts as
  // absent, so it cannot make a non-setting kind "carry" a setting
  // payload.
  final settingKeyIsAbsent = record.settingKey?.isEmpty ?? true;
  final carriesSetting = !settingKeyIsAbsent || record.settingValue != null;

  if (_isItemAct(kind)) {
    if (itemIdIsAbsent && record.itemOrigin == null) {
      return (entry: null, flaw: LogRecordFlaw.itemPairAbsent);
    }
    if (itemIdIsAbsent || record.itemOrigin == null) {
      return (entry: null, flaw: LogRecordFlaw.halfItemPair);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    return (
      entry: ItemActEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        kind: kind,
        itemId: record.itemId!,
        itemOrigin: record.itemOrigin!,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.crashRecorded) {
    if (record.stack?.isEmpty ?? true) {
      return (entry: null, flaw: LogRecordFlaw.stackAbsent);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    return (
      entry: CrashEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        stack: record.stack!,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.settingChanged) {
    if (record.settingKey?.isEmpty ?? true) {
      return (entry: null, flaw: LogRecordFlaw.settingKeyAbsent);
    }
    if (record.settingValue == null) {
      return (entry: null, flaw: LogRecordFlaw.settingValueAbsent);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    return (
      entry: SettingEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        key: record.settingKey!,
        value: record.settingValue!,
      ),
      flaw: null,
    );
  }

  if (_isMoment(kind)) {
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    return (
      entry: MomentEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        kind: kind,
      ),
      flaw: null,
    );
  }

  return (entry: null, flaw: LogRecordFlaw.unclassifiedKind);
}

/// The accepted entries of a record snapshot, in snapshot order. A
/// malformed row is excluded — its flaw is [convertLogEntryRecord]'s to
/// surface, never a coercion — and an unknown kind is carried (AD-23).
/// Every derivation consumes this list, never raw records.
List<LogEntry> logEntriesOf(List<LogEntryRecord> records) {
  final entries = <LogEntry>[];
  for (final record in records) {
    final conversion = convertLogEntryRecord(record);
    if (conversion.entry != null) {
      entries.add(conversion.entry!);
    }
  }
  return entries;
}
