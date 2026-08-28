/// The log vocabulary (AD-21): the event log holds user acts and system
/// events, and no entry may assert an absence or an obligation.
///
/// This file holds Story 1.3's slice of the vocabulary: the seven kinds the
/// epic names, plus the unknown-kind carrier every forward-only reader must
/// tolerate (AD-23). A new kind is a new kind, never a flag on an old one.

library;

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

  /// Every kind this build knows, keyed by wire name.
  static const knownByName = <String, LogKind>{
    'card_dealt': cardDealt,
    'card_done': cardDone,
    'card_skipped': cardSkipped,
    'session_started': sessionStarted,
    'session_ended': sessionEnded,
    'app_opened': appOpened,
    'crash_recorded': crashRecorded,
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
