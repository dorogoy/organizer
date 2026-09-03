/// The log vocabulary (AD-21): the event log holds user acts and system
/// events, and no entry may assert an absence or an obligation.
///
/// This file holds Story 1.3's slice of the vocabulary: the seven kinds the
/// epic names, plus the unknown-kind carrier every forward-only reader must
/// tolerate (AD-23) — and, additively since Story 2.1, the eighth kind
/// `setting_changed`, since Story 2.4 the ninth kind `session_extended`
/// (FR-10, AD-19), since Story 2.5 the tenth kind `energy_set`
/// (FR-4, AD-4), since Story 2.6 the eleventh kind `report_answered`
/// (SM-2, AD-21), since Story 3.2 the twelfth kind `capture_created`
/// (FR-27, AD-14), and since Story 3.4 the thirteenth kind
/// `permission_refused` (FR-32, AD-17, AD-21 — one of the system events'
/// three stated derivation exceptions). A new kind is a new kind, never a
/// flag on an old one.
///
/// It also holds the validated record→entry conversion every read passes
/// through (Story 1.6, the item 1.3 deferred here): the inert records the
/// store port returns become domain entries only after their shape checks
/// out — itemId/itemOrigin travel as a pair, `stack` rides only on
/// `crash_recorded`, `setting_changed` carries its key and exactly one of
/// its int or text value (the text half additively since Story 4.3,
/// schema v8),
/// `session_started` and `session_extended` carry their minutes,
/// `energy_set` carries its level, `report_answered` carries its answer
/// and the week it answers, and a known kind's payload must match
/// the kind.

library;

import 'package:core/energy/energy.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';

/// The permission identity a `permission_refused` row names (AD-17:
/// exactly three runtime permissions, each requested at the moment its
/// feature is first used). A core enum, stored as wire text — no
/// free-form strings: a row naming a permission this build does not
/// know is excluded at the read boundary, never coerced (AD-23).
enum Permission {
  /// `RECORD_AUDIO` — dictation into the capture line (FR-32).
  microphone,

  /// `CAMERA` — the scan path (a later story twins this pattern).
  camera,

  /// `POST_NOTIFICATIONS` — the ambient invitation (a later story).
  notifications,
}

/// Every [Permission] this build knows, keyed by wire name.
const Map<String, Permission> permissionByName = {
  'microphone': Permission.microphone,
  'camera': Permission.camera,
  'notifications': Permission.notifications,
};

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
  static const sessionExtended = LogKind._('session_extended', known: true);
  static const appOpened = LogKind._('app_opened', known: true);
  static const crashRecorded = LogKind._('crash_recorded', known: true);
  static const settingChanged = LogKind._('setting_changed', known: true);
  static const energySet = LogKind._('energy_set', known: true);
  static const reportAnswered = LogKind._('report_answered', known: true);
  static const captureCreated = LogKind._('capture_created', known: true);
  static const permissionRefused = LogKind._('permission_refused', known: true);

  /// Every kind this build knows, keyed by wire name.
  static const knownByName = <String, LogKind>{
    'card_dealt': cardDealt,
    'card_done': cardDone,
    'card_skipped': cardSkipped,
    'session_started': sessionStarted,
    'session_ended': sessionEnded,
    'session_extended': sessionExtended,
    'app_opened': appOpened,
    'crash_recorded': crashRecorded,
    'setting_changed': settingChanged,
    'energy_set': energySet,
    'report_answered': reportAnswered,
    'capture_created': captureCreated,
    'permission_refused': permissionRefused,
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

/// A user act on a pool item (`card_dealt`, `card_done`, `card_skipped`,
/// and — since Story 3.2, FR-27, AD-14 — `capture_created`, the manual
/// capture's genesis row): the kind, the instant, and the referenced
/// item's id and origin (AD-14).
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

/// A moment in the product's life with no pool-item referent and no
/// payload (`session_ended`, `app_opened`). `session_started` left
/// this family in Story 2.2: it carries the declared pocket, so it has
/// its own subtype below.
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

/// A `session_started` row (Story 2.2, AD-19): the moment plus the
/// pocket the user declared for this sitting, or absent when the
/// session opened on its own (the auto-open) — an unbounded sitting.
/// The type offers no other field: the pocket is the row's whole
/// payload, the extensions a sitting accepted live on their own
/// `session_extended` rows below (Story 2.4 — the walk sums them into
/// the declared pocket, so this row stays the FR-23 original), and no
/// close cause may ever ride a `session_ended` by passing through
/// here. A value outside the minted range stays in the log and derives
/// as absent — tolerance, never repair (AD-23).
final class SessionStartEntry extends LogEntry {
  const SessionStartEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.kind,
    this.pocketMinutes,
  });

  @override
  final LogKind kind;

  /// The declared pocket, in minutes — `pocketLeastMinutes`–
  /// `pocketMostMinutes` as minted, absent for an unbounded sitting.
  final int? pocketMinutes;
}

/// A `session_extended` row (Story 2.4, FR-10, AD-19): the minutes the
/// user added to the open sitting's declared pocket by answering the
/// checkpoint's silent secondary. The payload reuses the `pocketMinutes`
/// fact `session_started` already carries — one fact, one column, no
/// schema change (AD-23's additive-only payloads) — and the type offers
/// no other field: no close cause, no question, no count rides an
/// extension. The walk sums a sitting's extensions into its declared
/// pocket; this row keeps its own added minutes so the original start
/// row stays readable beside them.
final class SessionExtendEntry extends LogEntry {
  const SessionExtendEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.pocketMinutes,
  });

  @override
  final LogKind kind = LogKind.sessionExtended;

  /// The minutes added to the sitting's declared pocket, as minted —
  /// `checkpointIntervalMinutes` per accepted offer. A non-positive
  /// value stays in the log and sums nothing: tolerance, never repair
  /// (AD-23). The walk and the checkpoint fold both require a positive
  /// count; they do not re-check the minted interval.
  final int pocketMinutes;
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
/// its new value — an int since 2.1, and additively since Story 4.3 a
/// text (AD-22: the selected AI provider rides this row as
/// `selected_provider`, never a credential or an availability claim).
/// The settings record is a derived cache over these entries — never a
/// source of truth — and the type offers no other field, so no
/// availability claim or capability grant can ride along (AD-22's
/// discipline, arrived at ahead of its story). Exactly one of
/// [value]/[textValue] is non-null on every entry the read boundary
/// returns; a value outside the setting's confirmed range stays in the
/// log and derives nothing: tolerance, never repair (AD-23).
final class SettingEntry extends LogEntry {
  const SettingEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.key,
    this.value,
    this.textValue,
  });

  @override
  final LogKind kind = LogKind.settingChanged;

  /// The setting's key — the keys this build knows are the Time Bag's
  /// and the selected provider's; any other key is carried verbatim
  /// and derives nothing.
  final String key;

  /// The setting's new int value, as written — null exactly when
  /// [textValue] carries the row's value instead.
  final int? value;

  /// The setting's new text value, as written (Story 4.3, AD-22) —
  /// null exactly when [value] carries the row's value instead. The
  /// one sanctioned text is a provider id, charset-validated by the
  /// derivation; the field can hold no credential, because the vault
  /// never mints one here.
  final String? textValue;
}

/// An `energy_set` user act (Story 2.5, FR-4, AD-4): the level the
/// daily check-in tapped, and nothing else. One row per tap through
/// the single sanctioned minter (`core/commands/energy_commands.dart`)
/// — the check-in never deals a card, and no second energy writer can
/// appear silently. Energy stays day-scoped in the derivation
/// (`core/energy`): the last row of the current domestic day wins and
/// every boundary defaults 🟢, so no synthetic row ever exists at one.
/// The type offers no other field, so no nag count, no source tag and
/// no session attribution can ride along.
final class EnergySetEntry extends LogEntry {
  const EnergySetEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.level,
  });

  @override
  final LogKind kind = LogKind.energySet;

  /// The tapped level — one of the three semantic levels, never an
  /// out-of-range value (the minter's enum input makes one
  /// unrepresentable; a stored out-of-range int excludes the row at
  /// the read boundary, AD-23's quiet tolerance).
  final EnergyLevel level;
}

/// The weekly self-report's answer scale (Story 2.6, SM-2): the five
/// numerals 1–5 are their own wire encoding — no enum, because five
/// numerals name nothing semantic an enum's members would name better
/// (energy needed one; this does not). The range check these bounds
/// express is the whole ceremony, and it runs at exactly two sites by
/// design: the read boundary below, and the minter
/// (`core/commands/report_commands.dart`) — the `settingValue` guard's
/// terms, one source of truth beside the entry it guards.
const int reportScaleLeast = 1;
const int reportScaleMost = 5;

/// A `report_answered` user act (Story 2.6, SM-2, AD-21): the weekly
/// self-report's tapped 1–5 answer and the week it answers — and
/// nothing else. One row per answer through the single sanctioned
/// minter (`core/commands/report_commands.dart`), so no second report
/// writer can appear silently. The week is the answered week's
/// `Week.weekOrdinal` — the Calendar's one week identity (AD-4 forbids
/// a second week counter beside it) — carried explicitly because the
/// report persists until answered (SM-2's override of the Sunday-only
/// reading), so an answer may fall outside the week it reports on and
/// the instant alone cannot attribute it: without the target week,
/// SM-2's week-4-versus-week-1 trend cannot be built at all. The type
/// offers no other field, so no question text, no dismissal state and
/// no notification fact can ride along (FR-24's path never exists). A
/// value outside [reportScaleLeast]–[reportScaleMost] excludes the row
/// at the read boundary — quiet tolerance, never a repair write
/// (AD-23) — and nothing consumes the kind yet: parts 2–3 derive
/// eligibility and the slot handoff over exactly these rows.
final class ReportAnsweredEntry extends LogEntry {
  const ReportAnsweredEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.value,
    required this.week,
  });

  @override
  final LogKind kind = LogKind.reportAnswered;

  /// The tapped answer — the wire int [reportScaleLeast]–
  /// [reportScaleMost], as minted. Five numerals are their own
  /// encoding; a stored value outside the scale excludes the row at
  /// the read boundary (AD-23's quiet tolerance).
  final int value;

  /// The answered week's `Week.weekOrdinal` (calendar.dart: whole days
  /// from the epoch Monday 2000-01-03 over 7, consecutive weeks
  /// differing by exactly 1) — the week the answer reports on, never
  /// the answer's own instant re-derived: persistence lets the two
  /// diverge, and the divergence is this field's whole reason.
  final int week;
}

/// A `permission_refused` system event (Story 3.4, FR-32, AD-17,
/// AD-21): the user refused one of the three runtime permissions at
/// the moment its feature was first used — or the system revoked it
/// after grant, which the next press reads identically — and nothing
/// else. The crash shape (AD-12's): one payload field and no item
/// pair, the row asserting a fact that happened, never an absence or
/// an obligation. The type offers no other field, so no grant, no
/// capability claim and no re-ask state can ride along (AD-22's
/// discipline): the entry stands forever, `permissionMayBeAsked`
/// derives false over it, and reversal lives outside the log — the
/// system's own settings screen, reached through the Settings row
/// that renders only while a re-grant has something to reactivate.
/// The row is never an act: it is not contact for the warm return
/// (the `crash_recorded` precedent — a refusal is not the user
/// using the app).
final class PermissionRefusedEntry extends LogEntry {
  const PermissionRefusedEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.permission,
  });

  @override
  final LogKind kind = LogKind.permissionRefused;

  /// The refused permission, as the core enum — the identity
  /// `permissionMayBeAsked` derives over, never a free-form string.
  final Permission permission;
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

  /// `setting_changed` without either payload value (Story 4.3): the
  /// int column and the text column are both null (or empty — an empty
  /// string is not a value), so the row names a setting but asserts
  /// nothing about it. The row stays in the log and derives nothing.
  settingValueAbsent,

  /// `setting_changed` carrying both its int and its text value
  /// (Story 4.3): the exactly-one-of rule broken from the other side —
  /// the row asserts two values and therefore none. The row stays in
  /// the log and derives nothing.
  settingValueConflict,

  /// A setting key or value on a kind that is not `setting_changed`.
  settingOnNonSettingKind,

  /// A pocket payload on a kind that carries none — every kind except
  /// the two minutes-carrying session kinds `session_started` (Story
  /// 2.2) and `session_extended` (Story 2.4): `session_ended` and
  /// `app_opened` are moments and must carry none, mirroring the
  /// setting rule.
  pocketOnNonPocketKind,

  /// A `session_extended` row without its added minutes (Story 2.4) —
  /// the minutes are the row's whole payload; without them it asserts
  /// nothing.
  extendMinutesAbsent,

  /// An `energy_set` row without a level this build can read (Story
  /// 2.5): the column is absent, or its int is outside the stable
  /// 0–2 mapping — either way the row asserts nothing about the day's
  /// energy and the day derives as unanswered, defaulting 🟢. Quiet
  /// tolerance, never a repair write (AD-23).
  energyLevelAbsent,

  /// An energy level on a kind that is not `energy_set` — mirroring
  /// the setting and pocket rules: every payload column rides its own
  /// kind and no other.
  energyOnNonEnergyKind,

  /// A `report_answered` row without an answer this build can read
  /// (Story 2.6): the column is absent, or its int is outside the
  /// 1–5 scale — either way the row asserts nothing about any week's
  /// overwhelm and the week simply has no data point (SM-2's own
  /// reading of an unanswered week). Quiet tolerance, never a repair
  /// write (AD-23).
  reportValueAbsent,

  /// A `report_answered` row without its week (Story 2.6): the week is
  /// the answer's whole attribution — persistence lets an answer fall
  /// outside the week it reports on (SM-2, AD-4), so the instant alone
  /// cannot attribute it — and a row that names no week asserts
  /// nothing. Quiet tolerance, never a repair write (AD-23).
  reportWeekAbsent,

  /// Report fields on a kind that is not `report_answered` — mirroring
  /// the setting, pocket and energy rules: every payload column rides
  /// its own kind and no other.
  reportOnNonReportKind,

  /// A `permission_refused` row without a permission this build can
  /// read (Story 3.4): the column is absent, empty, or names a
  /// permission this build does not know — either way the row asserts
  /// nothing about any permission's askability and the derivation
  /// reads the log as if it were not there. Quiet tolerance, never a
  /// repair write (AD-23).
  permissionAbsent,

  /// A permission payload on a kind that is not `permission_refused`
  /// — mirroring the setting, pocket, energy and report rules: every
  /// payload column rides its own kind and no other.
  permissionOnNonPermissionKind,
}

/// One record's conversion at the read boundary: the domain entry when the
/// shape checks out, otherwise the flaw that excludes the row — exactly one
/// of the two is non-null.
typedef LogEntryConversion = ({LogEntry? entry, LogRecordFlaw? flaw});

bool _isItemAct(LogKind kind) =>
    kind == LogKind.cardDealt ||
    kind == LogKind.cardDone ||
    kind == LogKind.cardSkipped ||
    kind == LogKind.captureCreated;

bool _isMoment(LogKind kind) =>
    kind == LogKind.sessionEnded || kind == LogKind.appOpened;

/// Converts one inert store record into a domain entry with shape
/// validation — the boundary Story 1.3 deferred to this story. Unknown
/// kinds are carried as [UnknownEntry] whatever their payload (AD-23);
/// a known kind must carry exactly its own payload: an item act its full
/// item pair and no stack, a moment neither, `crash_recorded` its stack
/// and nothing else (AD-12, AD-14), `setting_changed` its key and int
/// value and nothing else (AD-1), `session_started` its optional pocket
/// and nothing else (Story 2.2 — the row's whole payload, read
/// structurally as null-or-int; an out-of-range value converts and
/// derives as absent, never a repair write), `session_extended` its
/// added minutes and nothing else (Story 2.4 — absent minutes exclude
/// the row; an out-of-range value converts and derives as absent),
/// `energy_set` its level and nothing else (Story 2.5 — an absent or
/// out-of-range level excludes the row), `report_answered` its 1–5
/// answer and its week and nothing else (Story 2.6 — an absent or
/// out-of-range value, or an absent week, excludes the row), and
/// `capture_created` its full item pair and nothing else (Story 3.2 —
/// the item-act family's own shape, the pair naming the pool fact the
/// same tap appended), and `permission_refused` its permission — one
/// of the three the [Permission] enum names — and nothing else
/// (Story 3.4, the crash shape: no item pair). An
/// empty string is not a
/// value here: an itemId that is empty counts as an absent pair, an
/// empty stack as no stack, an empty setting key as no key. A known
/// kind this boundary does not classify is excluded with
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
  // payload. The text value (Story 4.3) reads by the same rule: an
  // empty text counts as absent everywhere below.
  final settingKeyIsAbsent = record.settingKey?.isEmpty ?? true;
  final settingTextIsAbsent = record.settingTextValue?.isEmpty ?? true;
  final carriesSetting =
      !settingKeyIsAbsent ||
      record.settingValue != null ||
      !settingTextIsAbsent;
  final carriesPocket = record.pocketMinutes != null;
  final carriesEnergy = record.energyLevel != null;
  final carriesReport = record.reportValue != null || record.reportWeek != null;
  final permissionIsAbsent =
      record.permission == null || permissionByName[record.permission!] == null;
  final carriesPermission = record.permission != null;

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
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
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
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
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
    if (record.settingValue == null && settingTextIsAbsent) {
      // Neither payload value: the row names a setting and asserts
      // nothing (the empty-string-is-not-a-value rule makes an empty
      // text count as absent here too).
      return (entry: null, flaw: LogRecordFlaw.settingValueAbsent);
    }
    if (record.settingValue != null && !settingTextIsAbsent) {
      // Both payload values: exactly-one-of broken from the other
      // side — the row asserts two values and therefore none.
      return (entry: null, flaw: LogRecordFlaw.settingValueConflict);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
    }
    return (
      entry: SettingEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        key: record.settingKey!,
        value: record.settingValue,
        // An empty text is not a value (the house rule): an empty
        // string normalizes to absent here, so an int-valued row
        // with an empty text converts as int-only, exactly as the
        // foreign-kind rule reads it.
        textValue: settingTextIsAbsent ? null : record.settingTextValue,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.sessionStarted) {
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
    }
    return (
      entry: SessionStartEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        kind: kind,
        pocketMinutes: record.pocketMinutes,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.sessionExtended) {
    if (record.pocketMinutes == null) {
      return (entry: null, flaw: LogRecordFlaw.extendMinutesAbsent);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
    }
    return (
      entry: SessionExtendEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        pocketMinutes: record.pocketMinutes!,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.energySet) {
    final level = energyLevelOfWire(record.energyLevel);
    if (level == null) {
      return (entry: null, flaw: LogRecordFlaw.energyLevelAbsent);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
    }
    return (
      entry: EnergySetEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        level: level,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.reportAnswered) {
    final value = record.reportValue;
    if (value == null || value < reportScaleLeast || value > reportScaleMost) {
      return (entry: null, flaw: LogRecordFlaw.reportValueAbsent);
    }
    final week = record.reportWeek;
    if (week == null) {
      return (entry: null, flaw: LogRecordFlaw.reportWeekAbsent);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
    }
    return (
      entry: ReportAnsweredEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        value: value,
        week: week,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.permissionRefused) {
    if (permissionIsAbsent) {
      return (entry: null, flaw: LogRecordFlaw.permissionAbsent);
    }
    if (record.itemId != null || record.itemOrigin != null) {
      return (entry: null, flaw: LogRecordFlaw.itemOnNonItemKind);
    }
    if (record.stack != null) {
      return (entry: null, flaw: LogRecordFlaw.stackOffCrashKind);
    }
    if (carriesSetting) {
      return (entry: null, flaw: LogRecordFlaw.settingOnNonSettingKind);
    }
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    return (
      entry: PermissionRefusedEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        permission: permissionByName[record.permission!]!,
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
    if (carriesPocket) {
      return (entry: null, flaw: LogRecordFlaw.pocketOnNonPocketKind);
    }
    if (carriesEnergy) {
      return (entry: null, flaw: LogRecordFlaw.energyOnNonEnergyKind);
    }
    if (carriesReport) {
      return (entry: null, flaw: LogRecordFlaw.reportOnNonReportKind);
    }
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
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
