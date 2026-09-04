/// The Warm Return derivation (Story 2.7, FR-6, AD-24): whether the
/// current opening arrives 48 h or more after the latest contact that
/// preceded it — `app_opened` rows and user acts — so the shell can
/// receive the user with the fixed greeting and nothing else.
///
/// This is `core/derive`'s sibling to the strip and the checkpoint, on
/// their precedent (AD-6's stated crossing for derived state): a fact
/// the shell renders as a non-work surface, never a signal-as-work,
/// and a read that writes nothing (AD-3). It is deliberately NOT a
/// strip resident — Warm Return holds no slot in UX-DR22's precedence
/// — and it owns no state anywhere: the predicate recomputes from the
/// log alone at every read, so the greeting stands for the whole
/// opening by derivation and is gone at the next opening inside 48 h,
/// with no dismissal kind, no timer and no stored marker (AD-21).
///
/// The 48 h is a wall-clock duration between absolute instants, never
/// a day count: no domestic day is computed here, no `offsetSeconds`
/// parameter exists, and no days-away number is representable (FR-6's
/// own clause — the greeting's string carries none either).
///
/// The current opening is the last `app_opened` row at or before the
/// read instant, in store order — the read is queue-consistent after
/// the opening batch (one minted instant serves `app_opened`,
/// `session_started` and the first `card_dealt` together), so no later
/// open can exist, and list order needs no same-instant tie-break.
/// The anchor is the max instant among rows strictly before that row
/// in list order that are contact; due iff the read instant minus the
/// anchor is at least the threshold. No `app_opened` row at all means
/// no current opening is defined — false; no contact before the last
/// one (the first-ever open) — false. Rows after the read instant are
/// skipped, the readers' convention (strip.dart).
///
/// Contact is the opening delimiters and the user's acts (AD-21's
/// enumeration): every typed entry except the system events — today
/// `app_opened` (the delimiter itself, which a later opening makes
/// prior contact), `crash_recorded` (a crash is not the user) and,
/// since Story 3.4, `permission_refused` (the user turning the app
/// away, not using it — the `crash_recorded` precedent). An
/// `UnknownEntry` contributes nothing: a future kind joins exactly one
/// set — contact or system — in the same pass that adds it to
/// [LogKind], never before.

library;

import 'package:core/log/log_entry.dart';

/// The Warm Return threshold (AD-24): forty-eight hours, in UTC
/// microseconds — a wall-clock duration between absolute instants,
/// never a day count, so no calendar and no offset read it. One
/// source of truth: the derivation and the core tests read it from
/// here.
const int warmReturnThresholdMicros = 48 * 60 * 60 * 1000 * 1000;

/// Whether one entry is a user act (AD-21): every typed entry except
/// the system events. Today the system events are `app_opened` (the
/// opening delimiter, counted as contact by the derivation itself),
/// `crash_recorded` and `permission_refused` (Story 3.4 — a refusal is
/// the user turning the app away, not the user using it), and
/// `slice_failed` (Story 4.6 — the no-Slicer family's own register: a
/// rescue that found no Slicer states a system's absence, and a
/// system event must not reset the absence clock);
/// `session_ended` is the user's own stop, the payload-carrying kinds
/// are all acts — `slice_requested` and `slice_returned` included
/// (Story 4.6: the user's ask and its delivery ride the user's own
/// dealt card, the `capture_created` precedent). An `UnknownEntry` is
/// not an act — a tolerated row asserts nothing — and a future kind
/// joins exactly one set in the pass that adds it.
bool _isUserAct(LogEntry entry) {
  switch (entry) {
    case ItemActEntry():
    case SessionStartEntry():
    case SessionExtendEntry():
    case SettingEntry():
    case EnergySetEntry():
    case ReportAnsweredEntry():
      return true;
    case SliceEntry():
      // The rescue channel splits (Story 4.6, AD-21's own
      // enumeration): `slice_requested` and `slice_returned` are the
      // user's ask and its delivery — contact, the `capture_created`
      // precedent — while `slice_failed` is a system event (the
      // no-Slicer family's own register): an auto-heuristic failure
      // with no user act beside it must not reset the 48 h absence
      // clock and suppress a deserved Warm Return.
      return entry.kind != LogKind.sliceFailed;
    case MomentEntry(:final kind):
      // `session_ended` is the user's stop — the one moment that is an
      // act. A future moment kind defaults to NOT contact (mirroring
      // `UnknownEntry`'s conservative default) until its pass assigns
      // it a set.
      return kind == LogKind.sessionEnded;
    case CrashEntry():
      return false;
    case PermissionRefusedEntry():
      return false;
    case UnknownEntry():
      return false;
  }
}

/// Derives whether this opening is a warm return (Story 2.7, FR-6,
/// AD-24): pure over the log, writing nothing (AD-3). Due iff the
/// read instant stands at least [warmReturnThresholdMicros] after the
/// latest contact before the current opening — the last `app_opened`
/// row at or before [instantUtcMicros] in store order, with the anchor
/// the max instant among `app_opened` rows and user acts strictly
/// before that row. Mid-opening acts sit after the last `app_opened`
/// and never move the anchor, so the fact holds through the session by
/// derivation alone; a later `app_opened` makes everything before it
/// prior contact, so the anchor moves with each peek. Rows after the
/// read instant contribute nothing, whatever their list position.
bool warmReturnDue({
  required List<LogEntry> entries,
  required int instantUtcMicros,
}) {
  // The max contact instant seen so far at-or-before the read instant
  // — opens and acts both — and the current opening: the last
  // `app_opened` seen so far. When a new opening arrives, everything
  // contacted before it becomes the anchor; the opening itself then
  // joins the contact a still-later opening would anchor on.
  var contact = -1;
  var anchor = -1;
  var sawOpening = false;
  for (final entry in entries) {
    if (entry.instantUtcMicros > instantUtcMicros) {
      continue;
    }
    if (entry is MomentEntry && entry.kind == LogKind.appOpened) {
      anchor = contact;
      sawOpening = true;
      if (entry.instantUtcMicros > contact) {
        contact = entry.instantUtcMicros;
      }
      continue;
    }
    if (_isUserAct(entry) && entry.instantUtcMicros > contact) {
      contact = entry.instantUtcMicros;
    }
  }
  if (!sawOpening || anchor < 0) {
    return false;
  }
  return instantUtcMicros - anchor >= warmReturnThresholdMicros;
}
