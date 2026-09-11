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
/// (FR-27, AD-14), since Story 3.4 the thirteenth kind
/// `permission_refused` (FR-32, AD-17, AD-21 — one of the system events'
/// three stated derivation exceptions), since Story 4.6 the
/// fourteenth–sixteenth kinds `slice_requested` / `slice_returned` /
/// `slice_failed` (FR-5, AD-21 — the Rescue Mode channel's three rows,
/// appending on the same terms as a photo scan), since Story 5.2 the
/// seventeenth kind `face_refused` (FR-25, AD-21 — the on-device face
/// gate's refusal, a payload-less system event on the `app_opened`
/// precedent: no drift schema change, no item pair, no cause),
/// since Story 5.4 the eighteenth kind `consent_granted` (AD-8,
/// FR-26 b — the consent act's payload-less user-act row:
/// instrumentation only, carrying no capability and no scan identity;
/// the consent token itself is never persisted, never exported, never
/// reconstructible from the log), and since Story 5.5 the nineteenth
/// kind `consent_declined` (FR-25, FR-26, AD-21 — the declined
/// consent's payload-less system event: a decline record that asserts
/// nothing, logged for the audit trail but never contact — no
/// capability, no scan identity, no re-ask), and since Story 5.6 the
/// twentieth kind `scan_abandoned` (FR-16, AD-8, AD-21 — the
/// unbounded wait's honest departure: a payload-less **user act** on
/// the naming table's own register, the user leaving the scan surface
/// or backgrounding the app mid-wait — AD-8's resolution cause —
/// logged for the audit trail but never contact), and since Story 5.9
/// the twenty-first kind `epic_activated` (AD-21 — an Epic Project's
/// activation: a user act on the existing item-act shape, `itemId`
/// the Epic's derived stable id, `itemOrigin` the Epic's own origin.
/// Minted once at a successful landing, its ABSENCE is what makes an
/// Epic dormant — AD-21 forbids logging an absence, so dormancy is
/// never a row, only the state where no `epic_activated` names the
/// id), and since Story 5.11 the twenty-second kind
/// `cluster_curation_changed` (FR-31, AD-16, AD-21 — the curation
/// act's user row: one cluster's new enabled bit on its own schema
/// columns (v11), never a `setting_changed` key, because the cluster
/// payload is not a setting but a user act on the house's own
/// content), and since Story 5.13 the twenty-third kind
/// `suggestion_dismissed` (FR-15, AD-14, AD-21 — the seasonal
/// suggestion's ✕: a user act on the existing item-act shape, the
/// pair naming the dismissed Epic Project (its derived stable id and
/// own origin, `epic_activated`'s precedent). The row is a decline,
/// never contact — the `consent_declined` register made load-bearing
/// for FR-15's zero-side-effects consequence — and its only reader is
/// the strip's own eligibility: a same-season dismissal suppresses the
/// project's suggestion until the season turns, with no stored flag,
/// no setting key and no column — the row's own instant and offset
/// derive the season the TAP happened in, which is the season the
/// suppression scopes to. At the 04:00 season boundary a suggestion
/// shown in season S can be ✕-tapped after the turn: the row scopes
/// to S+1, suppressing the season the tap landed in — benign and
/// correct, because S is already historical and its suppression is
/// moot the moment S ends), and since Story 6.3 the twenty-fourth
/// kind `item_triaged` (FR-22, AD-21 — the triage act's user row:
/// one destination from the closed `TriageDestination` vocabulary and
/// an optional `CoarseVolumeTag`, riding their own schema columns (v12)
/// and referencing no pool item — the object triaged is physical, so
/// AD-14 does not apply; the substrate the Quarantine Box (6.5) and
/// the declutter metric (6.7, Epic 7) derive from, minted by this
/// story through the core command alone), and since Story 6.5 the
/// twenty-fifth kind `box_created` (FR-21, AD-4, AD-21 — the
/// Quarantine Box's own row: a payload-less user act whose **id** is
/// the box's identity and whose instant is the box's date, so the row
/// needs no payload column of its own; the box's contents live only as
/// the link on the `item_triaged` rows that name it, and the box
/// itself reconstructs from this row alone — no quarantine table, no
/// stored follow-up date, AD-1), and since Story 7.1 the
/// twenty-sixth and twenty-seventh kinds `before_saved` and
/// `album_entry_added` (FR-17, AD-13, AD-21 — the transformation
/// reward's two album-mutation rows: the deliberate Before shot a
/// delivered scan's offer took, naming the scan group's stable id
/// and the content-addressed album blob; and the saved Before/After
/// pair, naming the same group and BOTH blob names. Album mutation
/// is log acts, never flags on old kinds — the `capture_created`
/// register, each on its own two nullable schema columns (v14)). A
/// new kind is a new kind, never a flag
/// on an old one.
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
/// and the week it answers, `cluster_curation_changed` carries its
/// cluster's wire name and enabled bit (Story 5.11, on its own v11
/// columns), `item_triaged` carries its destination, optional coarse
/// volume tag and optional box link (Stories 6.3/6.5, on their own
/// v12/v13 columns), `box_created` carries nothing at all (Story 6.5
/// — its id and instant are the whole row), a `before_saved` row
/// (Story 7.1) carries its full item pair — the scan group's stable
/// id and origin — plus its Before blob name, an `album_entry_added`
/// row (Story 7.1) carries the same pair plus BOTH blob names, and a
/// known
/// kind's payload must match
/// the kind.

library;

// The triage value vocabularies' multi-word members (`donate_sell`,
// `trash_recycle`, `caja_grande`) are their wire names, fixed in
// snake_case by Story 6.3's spec — the log's own kind-wire register
// (`card_done`), unlike this file's single-word permission wires and
// the camelCase cause column. Keeping `.name` as the wire keeps one
// mint site; the members carry scoped lint ignores, not a file-wide
// one.

import 'package:core/curation/curation.dart';
import 'package:core/energy/energy.dart';
import 'package:core/ports/slicer_port.dart';
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

/// The triage act's destination vocabulary (Story 6.3, FR-22, AD-21):
/// where a let-go object went — the three equal members of the
/// destination flow plus, additively since Story 6.5, `quarantine`
/// (FR-21): the hesitation outcome, recorded as its own dated box
/// through the act that mints a `box_created` row beside it. A core
/// enum, stored as wire text on the `item_triaged` row's own column
/// — no free-form strings, no numeric code — and a row naming a
/// destination this build does not know is excluded at the read
/// boundary, never coerced (AD-23).
enum TriageDestination {
  /// `keep` — the object stayed (Quedármelo's wire name; the
  /// destination flow itself is Story 6.4's, this build only records).
  keep,

  /// `donate_sell` — the object left through donation or sale.
  // ignore: constant_identifier_names
  donate_sell,

  /// `trash_recycle` — the object left as waste or recycling.
  // ignore: constant_identifier_names
  trash_recycle,

  /// `quarantine` — the object went into a dated Quarantine Box
  /// (Story 6.5, FR-21): the hesitation outcome, not a fourth equal
  /// destination of the flow — the row links the `box_created` row
  /// the same act mints through [TriageEntry.boxId]. A quarantined
  /// object liberates nothing, so no volume tag ever rides the row
  /// (FR-22/AD-26 honesty).
  quarantine,
}

/// Every [TriageDestination] this build knows, keyed by wire name —
/// the `permissionByName` closed-map precedent: the census holds
/// exactly keep, donate_sell, trash_recycle and — additively since
/// Story 6.5 — quarantine as data, and a stored name outside it is a
/// read-boundary flaw, never a coercion (AD-23).
const Map<String, TriageDestination> triageDestinationByName = {
  'keep': TriageDestination.keep,
  'donate_sell': TriageDestination.donate_sell,
  'trash_recycle': TriageDestination.trash_recycle,
  'quarantine': TriageDestination.quarantine,
};

/// The triage act's coarse volume tag (Story 6.3, FR-22): the
/// optional, approximate size of the let-go batch — a bag, a box, a
/// big box, a piece of furniture. Four members and no numeric member
/// can ever exist: the vocabulary IS the value space, so a numeric
/// volume is unrepresentable by construction (no int field, no int
/// column, no wire name that parses as one). A row naming a tag this
/// build does not know is excluded at the read boundary when the
/// column is non-empty, never coerced (AD-23); an absent or empty
/// column is the declined tag and converts cleanly — declining to tag
/// writes nothing (FR-22).
enum CoarseVolumeTag {
  /// `bolsa` — a bag's worth.
  bolsa,

  /// `caja` — a box's worth.
  caja,

  /// `caja_grande` — a big box's worth.
  // ignore: constant_identifier_names
  caja_grande,

  /// `mueble` — a piece of furniture's worth.
  mueble,
}

/// Every [CoarseVolumeTag] this build knows, keyed by wire name —
/// the same closed-map precedent, additively extendable forward.
const Map<String, CoarseVolumeTag> coarseVolumeTagByName = {
  'bolsa': CoarseVolumeTag.bolsa,
  'caja': CoarseVolumeTag.caja,
  'caja_grande': CoarseVolumeTag.caja_grande,
  'mueble': CoarseVolumeTag.mueble,
};

/// Every [SlicerFailureCause] this build knows, keyed by wire name
/// (Story 4.6) — the `slice_failed` row's cause identity, derived from
/// the enum so a new member cannot write a name this map does not
/// know. A row naming a cause this build does not know is excluded,
/// never coerced (AD-23).
final Map<String, SlicerFailureCause> slicerFailureCauseByName = {
  for (final cause in SlicerFailureCause.values) cause.name: cause,
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
  static const sliceRequested = LogKind._('slice_requested', known: true);
  static const sliceReturned = LogKind._('slice_returned', known: true);
  static const sliceFailed = LogKind._('slice_failed', known: true);
  static const faceRefused = LogKind._('face_refused', known: true);
  static const consentGranted = LogKind._('consent_granted', known: true);
  static const consentDeclined = LogKind._('consent_declined', known: true);
  static const scanAbandoned = LogKind._('scan_abandoned', known: true);
  static const epicActivated = LogKind._('epic_activated', known: true);
  static const clusterCurationChanged = LogKind._(
    'cluster_curation_changed',
    known: true,
  );
  static const suggestionDismissed = LogKind._(
    'suggestion_dismissed',
    known: true,
  );
  static const itemTriaged = LogKind._('item_triaged', known: true);
  static const boxCreated = LogKind._('box_created', known: true);
  static const beforeSaved = LogKind._('before_saved', known: true);
  static const albumEntryAdded = LogKind._('album_entry_added', known: true);

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
    'slice_requested': sliceRequested,
    'slice_returned': sliceReturned,
    'slice_failed': sliceFailed,
    'face_refused': faceRefused,
    'consent_granted': consentGranted,
    'consent_declined': consentDeclined,
    'scan_abandoned': scanAbandoned,
    'epic_activated': epicActivated,
    'cluster_curation_changed': clusterCurationChanged,
    'suggestion_dismissed': suggestionDismissed,
    'item_triaged': itemTriaged,
    'box_created': boxCreated,
    'before_saved': beforeSaved,
    'album_entry_added': albumEntryAdded,
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
/// payload (`session_ended`, `app_opened`, and — since Story 5.2 —
/// `face_refused`, the face gate's refusal on the `app_opened`
/// precedent — since Story 5.4 — `consent_granted`, the consent
/// act's user-act row, and — since Story 5.5 — `consent_declined`,
/// the declined consent's system-event record, and — since Story 5.6 —
/// `scan_abandoned`, the mid-wait departure's user-act record (the
/// naming table's own register, never contact), all equally
/// payload-less). `session_started` left
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

/// A `slice_*` row (Story 4.6, FR-5, AD-21; the pair renegotiated
/// Story 5.7): the Rescue Mode channel's own shape — a user act
/// naming the rescued pool item, its kind one of the three
/// (`slice_requested` the activation, `slice_returned` the
/// delivered re-slice, `slice_failed` the terminal failure) — and,
/// on `slice_failed` alone, the port's closed failure cause. Since
/// Story 5.7 the item pair is optional ON `slice_failed` alone: a
/// rescue failure names the parent it failed, while a scan failure
/// carries no pair at all — no item exists, the scan died before
/// any fact — so its row holds the cause only; the two content
/// kinds still require the pair. The rows append on the same terms
/// as a photo scan (the Slicer-call series closes over both
/// channels), and nothing here queues, retries or persists a
/// pending state: a fresh rescue is a fresh `slice_requested` by
/// construction. The type offers no other field, so no prompt, no
/// delivered body, no provider and no key may ride along — the
/// history records THAT a slice happened and, on failure, which of
/// the seven causes it met, never the conversation itself.
final class SliceEntry extends LogEntry {
  const SliceEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.kind,
    this.itemId,
    this.itemOrigin,
    this.cause,
  });

  /// One of the three `slice_*` kinds — never any other.
  @override
  final LogKind kind;

  /// The rescued pool item's id — the parent, never a step: the
  /// depth cap lives in the command boundary, so a step's row
  /// cannot exist. Non-null exactly on rescue rows; null only on a
  /// scan `slice_failed` row, where no item exists — the scan died
  /// before any fact (Story 5.7). Every walk and derivation reads
  /// the pair by comparison only, so a null pair names nothing and
  /// matches nothing.
  final String? itemId;

  /// The rescued item's origin, which every item-referencing entry
  /// carries too (AD-14) — null exactly when [itemId] is.
  final Origin? itemOrigin;

  /// The port's failure cause — non-null exactly on `slice_failed`
  /// rows, the whole payload the failure history keeps. A stored name
  /// this build does not know excludes the row at the read boundary
  /// (AD-23's quiet tolerance).
  final SlicerFailureCause? cause;
}

/// A `cluster_curation_changed` user act (Story 5.11, FR-31, AD-16,
/// AD-21): one curation cluster's new enabled bit — and nothing
/// else. One row per flip through the single sanctioned minter
/// (`core/commands/curation_commands.dart`), so no second curation
/// writer can appear silently. The payload rides its own schema
/// columns (v11) — the cluster's wire name and the enabled bit,
/// never a `setting_changed` key (AD-21's vocabulary split: the
/// cluster payload is a user act on the house's own content, not a
/// settings-cache event). The type offers no other field, so no task
/// name, no count and no catalogue fact can ride along (FR-31,
/// NL-1 — curation is cluster-level only, never a browsable
/// catalogue). A wire name this build does not know excludes the row
/// at the read boundary — quiet tolerance, never a repair write
/// (AD-23) — and the derivation reads the cluster as the core
/// enum, never a free-form string.
final class ClusterCurationChangedEntry extends LogEntry {
  const ClusterCurationChangedEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.cluster,
    required this.enabled,
  });

  @override
  final LogKind kind = LogKind.clusterCurationChanged;

  /// The curated cluster, as the core enum — the identity the
  /// derivation (`core/curation`) reads, never a free-form string.
  final CurationCluster cluster;

  /// Whether the cluster was turned on or off — the row's whole
  /// payload beside the cluster it names, and the flip's own whole
  /// feedback (FR-31: no count, no summary, no copy beyond the
  /// switch).
  final bool enabled;
}

/// An `item_triaged` user act (Story 6.3, FR-22, AD-21): one triage
/// decision — the destination the let-go object left through, plus an
/// optional coarse volume tag and, additively since Story 6.5, an
/// optional box link (FR-21) — and nothing else. One row per act
/// through the single sanctioned minter
/// (`core/commands/triage_commands.dart`), so no second triage writer
/// can appear silently. The payload rides its own schema columns (v12,
/// v13) — the destination's wire name, the tag's and the linked box
/// id — never a `setting_changed` key and never a numeric volume: the
/// tag enum IS the value space, so no field of this entry can hold a
/// number. The type references no pool item: the object triaged is
/// physical, so AD-14 does not apply, and no item pair rides the row.
/// The type offers no other field, so no photograph reference (FR-22's
/// figures come only from taps) and no completion fact can ride along
/// — a purge card's `card_done` is 6.4's act, never this row's. The
/// box link rides only a quarantine row (the minter's own shape — a
/// hesitated object enters the dated box the same act's
/// `box_created` row names, and no other destination opens a box),
/// and the handed-off volume tag never rides one: a quarantined
/// object liberates nothing (FR-22/AD-26 honesty). An unknown
/// destination or tag wire name excludes the row at the read boundary
/// — quiet tolerance, never a repair write (AD-23); a box link that
/// matches no `box_created` row stands and is skipped by the
/// derivation — an orphan, never invented into a box.
final class TriageEntry extends LogEntry {
  const TriageEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.destination,
    this.volumeTag,
    this.boxId,
  });

  @override
  final LogKind kind = LogKind.itemTriaged;

  /// The destination the triaged object left through — one of the
  /// four the [TriageDestination] enum names, as the core enum the
  /// derivations (6.5's quarantine, 6.7's metric) read, never a
  /// free-form string. Unknown future values are read-boundary flaws
  /// (AD-23).
  final TriageDestination destination;

  /// The coarse volume tag, when one was offered — one of exactly the
  /// four the [CoarseVolumeTag] enum names, or null when the user
  /// declined to tag (FR-22: declining writes nothing, so an absent
  /// tag simply does not contribute). Never set beside [boxId]: a
  /// quarantined object liberates nothing.
  final CoarseVolumeTag? volumeTag;

  /// The linked Quarantine Box's id — the `box_created` row's own id
  /// (the pre-minted v7 the act threaded through both rows, Story
  /// 6.5, FR-21), non-null exactly on quarantine rows the act minted.
  /// The box's date is that row's own instant (AD-4); membership
  /// exists only as this link, and a link matching no `box_created`
  /// row is an orphan the derivation skips, never a box it invents
  /// (AD-1).
  final String? boxId;
}

/// A `box_created` user act (Story 6.5, FR-21, AD-4, AD-21): one
/// dated Quarantine Box exists because this row exists — the box's
/// identity IS the row's shell-minted UUIDv7 [LogEntry.id] and its
/// date IS the row's own instant plus offset, so the type offers no
/// payload field at all: no name, no capacity, no follow-up date
/// (AD-1 — the six-month derivation is 6.6's, computed from this
/// row's instant, never stored). One row per quarantine act through
/// the single sanctioned minter (`core/commands/triage_commands.dart`),
/// so no second box writer can appear silently. The box's contents
/// are nothing of this row's: they live only as the link on the
/// `item_triaged` rows that name it, so a box whose act's triage
/// append failed reconstructs as an honest, coarse empty box — and
/// any date-collapse of same-date boxes is 6.6's derivation concern,
/// never this row's.
final class BoxCreatedEntry extends LogEntry {
  const BoxCreatedEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
  });

  @override
  final LogKind kind = LogKind.boxCreated;
}

/// A `before_saved` user act (Story 7.1, FR-17, FR-25, AD-13, AD-21):
/// the deliberate Before shot a delivered scan's offer took — one
/// quiet offer at scan delivery, the user still in front of the
/// space with the camera in hand, answered through one shoot action
/// or declined by leaving (`Cerrar`, zero side effects). The row
/// names the scan group's STABLE id — the same id the group's
/// `epic_activated` row names — and the group's own origin, on the
/// existing item-pair shape (AD-14), plus the album blob's
/// content-addressed name on the row's own schema column (v14): the
/// bytes live in the Files `album` scope, never in the log, and the
/// shot is a separate deliberate frame — never the uploaded scan
/// frame, which FR-25/AD-8 unlink on every terminal path. One row
/// per accepted offer through the single sanctioned minter
/// (`core/commands/reward_commands.dart`), so no second Before
/// writer can appear silently; a declined offer writes nothing, so
/// the space derives as a no-Before space by absence (AD-21). The
/// type offers no other field, so no caption, no share fact and no
/// milestone state can ride along — the milestone derivations
/// (`core/derive/reward.dart`) read the group folds, never this row's
/// instants.
final class BeforeSavedEntry extends LogEntry {
  const BeforeSavedEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.itemId,
    required this.itemOrigin,
    required this.blobName,
  });

  @override
  final LogKind kind = LogKind.beforeSaved;

  /// The scan group's stable id — the group's first landed fact's id,
  /// the same id `epic_activated` and `album_entry_added` name.
  final String itemId;

  /// The group's own origin (`cloud` on the BYOK path, `local` on the
  /// debug stub), which every item-referencing entry carries (AD-14).
  final Origin itemOrigin;

  /// The Before blob's content-addressed name (sha256 hex + `.jpg`),
  /// AD-13's blob naming — the Files `album` scope's flat key.
  final String blobName;
}

/// An `album_entry_added` user act (Story 7.1, FR-17, AD-13, AD-21):
/// the saved Before/After pair — the transformation reward's own
/// write, appended automatically the moment the After shot lands in
/// the reward's pair flow (never a share button, never a manual
/// save). The row names the same group id and origin the
/// `before_saved` row named, plus BOTH blob names on the row's own
/// schema columns (v14): the album's membership reconstructs from
/// these rows alone — no album table, no ordering column, AD-1 —
/// and Epic 9's export derives from them. One row per saved pair
/// through the single sanctioned minter
/// (`core/commands/reward_commands.dart`), so no second album writer
/// can appear silently; a reward closed before the After shot writes
/// nothing (zero side effects). The type offers no other field, so
/// no caption, no adjective about the result and no share fact can
/// ride along — UX-DR40's copy law stated at the type.
final class AlbumEntryAddedEntry extends LogEntry {
  const AlbumEntryAddedEntry({
    required super.id,
    required super.instantUtcMicros,
    required super.offsetSeconds,
    required this.itemId,
    required this.itemOrigin,
    required this.beforeName,
    required this.afterName,
  });

  @override
  final LogKind kind = LogKind.albumEntryAdded;

  /// The group's stable id — the same id the group's
  /// `epic_activated` and `before_saved` rows name.
  final String itemId;

  /// The group's own origin (AD-14).
  final Origin itemOrigin;

  /// The Before blob's content-addressed name (AD-13) — the name the
  /// group's `before_saved` row carried.
  final String beforeName;

  /// The After blob's content-addressed name (AD-13) — the shot the
  /// reward's pair flow just took.
  final String afterName;
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

  /// A `slice_failed` row without a cause this build can read (Story
  /// 4.6): the column is absent, empty, or names a cause this build
  /// does not know — either way the row asserts nothing about why the
  /// slice failed and the derivation reads it as absent from the
  /// rescue history. Quiet tolerance, never a repair write (AD-23).
  sliceCauseAbsent,

  /// A cause payload on a kind that is not `slice_failed` (Story
  /// 4.6) — mirroring the setting, pocket, energy, report and
  /// permission rules: the failure's cause rides its own kind and no
  /// other, and the two content kinds (`slice_requested`,
  /// `slice_returned`) carry none.
  causeOnNonFailedKind,

  /// A `cluster_curation_changed` row without a cluster this build
  /// can read (Story 5.11): the column is absent, empty, or names a
  /// cluster this build does not know — either way the row asserts
  /// nothing about any cluster's state and the derivation reads the
  /// log as if it were not there (AD-23's quiet tolerance, the
  /// `permission` column's own discipline).
  curationClusterAbsent,

  /// A `cluster_curation_changed` row without its enabled bit
  /// (Story 5.11): the bit is the row's whole payload beside the
  /// cluster it names — without it the row asserts nothing. Quiet
  /// tolerance, never a repair write (AD-23).
  curationEnabledAbsent,

  /// A cluster or enabled payload on a kind that is not
  /// `cluster_curation_changed` (Story 5.11) — mirroring the setting,
  /// pocket, energy, report, permission and cause rules: every
  /// payload column rides its own kind and no other.
  curationOnNonCurationKind,

  /// An `item_triaged` row without a destination this build can read
  /// (Story 6.3): the column is absent, empty, or names a destination
  /// this build does not know — either way the row asserts nothing
  /// about where anything went and the derivations (6.5, 6.7) read
  /// the log as if it were not there. Quiet tolerance, never a repair
  /// write (AD-23), the `permission` column's own discipline.
  triageDestinationAbsent,

  /// An `item_triaged` row whose tag column holds a value this build
  /// cannot read (Story 6.3): a non-empty name naming no coarse tag
  /// this build knows. The tag is optional — an absent or empty
  /// column is the declined tag and converts cleanly (FR-22: declining
  /// writes nothing) — but a value that stands and cannot be read is
  /// load-bearing (the coarse volume the metric sums), so the row is
  /// excluded, never coerced and never silently dropped (AD-23).
  triageVolumeTagAbsent,

  /// A destination, tag or box-link payload on a kind that is not
  /// `item_triaged` (Stories 6.3/6.5) — mirroring the setting, pocket,
  /// energy, report, permission, cause and curation rules: every
  /// payload column rides its own kind and no other.
  triageOnNonTriageKind,

  /// A `before_saved` row without its Before blob name, or an
  /// `album_entry_added` row without either of its two blob names
  /// (Story 7.1, AD-13): the name is the row's whole link to the
  /// bytes — without it the row asserts a photo that cannot be read,
  /// so it asserts nothing. Quiet tolerance, never a repair write
  /// (AD-23).
  rewardNameAbsent,

  /// A Before or After blob name on a kind that is not
  /// `before_saved`/`album_entry_added` — or an After name on a
  /// `before_saved` row (Story 7.1) — mirroring the setting, pocket,
  /// energy, report, permission, cause, curation and triage rules:
  /// every payload column rides its own kind and no other, and the
  /// After name rides the pair row alone.
  photoNameOnNonPhotoKind,
}

/// One record's conversion at the read boundary: the domain entry when the
/// shape checks out, otherwise the flaw that excludes the row — exactly one
/// of the two is non-null.
typedef LogEntryConversion = ({LogEntry? entry, LogRecordFlaw? flaw});

bool _isItemAct(LogKind kind) =>
    kind == LogKind.cardDealt ||
    kind == LogKind.cardDone ||
    kind == LogKind.cardSkipped ||
    kind == LogKind.captureCreated ||
    kind == LogKind.epicActivated ||
    kind == LogKind.suggestionDismissed;

bool _isMoment(LogKind kind) =>
    kind == LogKind.sessionEnded ||
    kind == LogKind.appOpened ||
    kind == LogKind.faceRefused ||
    kind == LogKind.consentGranted ||
    kind == LogKind.consentDeclined ||
    kind == LogKind.scanAbandoned;

/// Whether [kind] is one of the three `slice_*` kinds (Story 4.6).
bool _isSliceKind(LogKind kind) =>
    kind == LogKind.sliceRequested ||
    kind == LogKind.sliceReturned ||
    kind == LogKind.sliceFailed;

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
/// (Story 3.4, the crash shape: no item pair), and a `slice_*` row
/// (Story 4.6) its full item pair plus — on `slice_failed` alone — a
/// cause the [slicerFailureCauseByName] map knows, and nothing
/// else — renegotiated Story 5.7: a scan `slice_failed` converts
/// with its cause and NO item pair (the scan died before any
/// fact), while the two content kinds and a rescue failure still
/// require the full pair, and a half pair excludes the row
/// whichever family it came from. A `cluster_curation_changed` row
/// (Story 5.11) carries its cluster wire name — one of the eight the
/// [CurationCluster] enum names — and its enabled bit, and nothing
/// else.
/// An
/// empty string is not a
/// value here: an itemId that is empty counts as an absent pair, an
/// empty stack as no stack, an empty setting key as no key. An
/// `item_triaged` row (Stories 6.3/6.5) carries its destination wire
/// name — one of the four the [TriageDestination] map knows — its
/// optional coarse volume tag — one of the four the
/// [CoarseVolumeTag] map knows, absent when the tag was declined —
/// and its optional box link (6.5), absent or empty when the row
/// names no box — and nothing else. A `box_created` row (Story 6.5)
/// carries nothing at all: its id and instant are the whole row. A
/// known kind this boundary does not classify is
/// excluded with
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
  // The curation columns read by the raw presence rule the
  // permission column sets: presence is what a foreign kind
  // violates, and the kind's own branch below judges the value
  // (Story 5.11).
  final carriesCuration = record.cluster != null || record.enabled != null;
  // The triage columns read by the same raw presence rule (Story
  // 6.3): presence is what a foreign kind violates, and the kind's
  // own branch below judges the values — an empty string is not a
  // value there, exactly as everywhere below. The box link (6.5)
  // joins the same rule on its own v13 column.
  final carriesTriage =
      record.triageDestination != null ||
      record.triageVolumeTag != null ||
      record.triageBoxId != null;
  // The reward-photo columns read by the same raw presence rule (Story
  // 7.1): presence is what a foreign kind violates, and the photo
  // kinds' own branches below judge the values — an empty string is
  // not a value there, exactly as everywhere below.
  final carriesPhoto = record.beforeName != null || record.afterName != null;
  // The cause column reads by the same house rule: an empty string is
  // not a value, so it counts as absent everywhere below (Story 4.6).
  final sliceCauseIsAbsent =
      record.sliceCause == null ||
      slicerFailureCauseByName[record.sliceCause!] == null;
  final carriesCause = record.sliceCause != null;

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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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

  if (_isSliceKind(kind)) {
    // The pair rule splits by family (Story 5.7): the two content
    // kinds and a rescue failure carry the full pair; a scan failure
    // carries none. A half pair excludes the row whichever family it
    // came from — the pair travels whole or not at all — and an
    // EMPTY itemId counts as absent on both halves (the house rule
    // above), so a pairless scan row stored with itemId = "" converts
    // as the shape it is instead of reading halfItemPair.
    final carriesItem =
        (record.itemId?.isNotEmpty ?? false) || record.itemOrigin != null;
    if (kind != LogKind.sliceFailed) {
      if (itemIdIsAbsent && record.itemOrigin == null) {
        return (entry: null, flaw: LogRecordFlaw.itemPairAbsent);
      }
      if (itemIdIsAbsent || record.itemOrigin == null) {
        return (entry: null, flaw: LogRecordFlaw.halfItemPair);
      }
    } else {
      if (sliceCauseIsAbsent) {
        return (entry: null, flaw: LogRecordFlaw.sliceCauseAbsent);
      }
      if (carriesItem && (itemIdIsAbsent || record.itemOrigin == null)) {
        return (entry: null, flaw: LogRecordFlaw.halfItemPair);
      }
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    var cause = record.sliceCause == null
        ? null
        : slicerFailureCauseByName[record.sliceCause!];
    if (kind != LogKind.sliceFailed) {
      cause = null;
      if (carriesCause) {
        return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
      }
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
    }
    return (
      entry: SliceEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        kind: kind,
        itemId: itemIdIsAbsent ? null : record.itemId,
        itemOrigin: record.itemOrigin,
        cause: cause,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.clusterCurationChanged) {
    // The curation payload's own discipline (Story 5.11): the cluster
    // wire name must name a cluster this build knows — absent, empty
    // or unknown excludes the row, the `permission` column's own
    // rule — and the enabled bit must stand, the row's whole other
    // half. A cluster or enabled payload on any other kind is the
    // foreign-column flaw every branch above returns.
    final cluster = curationClusterOfWireName(record.cluster);
    if (cluster == null) {
      return (entry: null, flaw: LogRecordFlaw.curationClusterAbsent);
    }
    if (record.enabled == null) {
      return (entry: null, flaw: LogRecordFlaw.curationEnabledAbsent);
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
    if (carriesPermission) {
      return (entry: null, flaw: LogRecordFlaw.permissionOnNonPermissionKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
    }
    return (
      entry: ClusterCurationChangedEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        cluster: cluster,
        enabled: record.enabled!,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.itemTriaged) {
    // The triage payload's own discipline (Story 6.3): the destination
    // wire name must name a destination this build knows — absent,
    // empty or unknown excludes the row, the `permission` column's
    // own rule — while the tag is optional: an absent or empty column
    // is the declined tag (FR-22: declining writes nothing), and only
    // a value that stands and cannot be read is a flaw. The box link
    // (Story 6.5) reads by the same empty-is-not-a-value rule: absent
    // or empty is simply an unlinked row, and the derivation skips
    // it as an orphan — the link's own target judges it, never this
    // boundary. A destination, tag or box payload on any other kind
    // is the foreign-column flaw every branch above returns.
    final destinationWire = record.triageDestination;
    final destination = destinationWire == null || destinationWire.isEmpty
        ? null
        : triageDestinationByName[destinationWire];
    if (destination == null) {
      return (entry: null, flaw: LogRecordFlaw.triageDestinationAbsent);
    }
    final tagWire = record.triageVolumeTag;
    final volumeTag = tagWire == null || tagWire.isEmpty
        ? null
        : coarseVolumeTagByName[tagWire];
    if (volumeTag == null && tagWire != null && tagWire.isNotEmpty) {
      return (entry: null, flaw: LogRecordFlaw.triageVolumeTagAbsent);
    }
    final boxWire = record.triageBoxId;
    final boxId = (boxWire == null || boxWire.isEmpty) ? null : boxWire;
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
    }
    return (
      entry: TriageEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        destination: destination,
        volumeTag: volumeTag,
        boxId: boxId,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.boxCreated) {
    // The box row's own discipline (Story 6.5): payload-less by
    // construction — the row's id is the box's identity and its
    // instant is the box's date, so every payload family is foreign
    // here, the whole foreign-column set every branch above guards.
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
    }
    return (
      entry: BoxCreatedEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.beforeSaved) {
    // The Before row's own discipline (Story 7.1): the full item pair
    // — the scan group's stable id and origin, AD-14 — plus exactly
    // its Before blob name, the row's whole link to the bytes. The
    // house rule reads an empty name as absent, so an empty string
    // cannot make a foreign kind "carry" a photo or a photo row
    // "carry" its link. An After name here is the foreign-column
    // flaw — it rides the pair row alone.
    if (itemIdIsAbsent && record.itemOrigin == null) {
      return (entry: null, flaw: LogRecordFlaw.itemPairAbsent);
    }
    if (itemIdIsAbsent || record.itemOrigin == null) {
      return (entry: null, flaw: LogRecordFlaw.halfItemPair);
    }
    if (record.beforeName?.isEmpty ?? true) {
      return (entry: null, flaw: LogRecordFlaw.rewardNameAbsent);
    }
    if (record.afterName != null) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    return (
      entry: BeforeSavedEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        itemId: record.itemId!,
        itemOrigin: record.itemOrigin!,
        blobName: record.beforeName!,
      ),
      flaw: null,
    );
  }

  if (kind == LogKind.albumEntryAdded) {
    // The pair row's own discipline (Story 7.1): the full item pair
    // plus BOTH blob names — the Before the group's `before_saved`
    // row carried and the After the reward's flow just shot; without
    // either the row asserts a pair that cannot be read, so it
    // asserts nothing. The house rule reads an empty name as absent
    // here exactly as everywhere above.
    if (itemIdIsAbsent && record.itemOrigin == null) {
      return (entry: null, flaw: LogRecordFlaw.itemPairAbsent);
    }
    if (itemIdIsAbsent || record.itemOrigin == null) {
      return (entry: null, flaw: LogRecordFlaw.halfItemPair);
    }
    if (record.beforeName?.isEmpty ?? true) {
      return (entry: null, flaw: LogRecordFlaw.rewardNameAbsent);
    }
    if (record.afterName?.isEmpty ?? true) {
      return (entry: null, flaw: LogRecordFlaw.rewardNameAbsent);
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    return (
      entry: AlbumEntryAddedEntry(
        id: record.id,
        instantUtcMicros: record.instantUtcMicros,
        offsetSeconds: record.offsetSeconds,
        itemId: record.itemId!,
        itemOrigin: record.itemOrigin!,
        beforeName: record.beforeName!,
        afterName: record.afterName!,
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
    if (carriesCuration) {
      return (entry: null, flaw: LogRecordFlaw.curationOnNonCurationKind);
    }
    if (carriesCause) {
      return (entry: null, flaw: LogRecordFlaw.causeOnNonFailedKind);
    }
    if (carriesTriage) {
      return (entry: null, flaw: LogRecordFlaw.triageOnNonTriageKind);
    }
    if (carriesPhoto) {
      return (entry: null, flaw: LogRecordFlaw.photoNameOnNonPhotoKind);
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
