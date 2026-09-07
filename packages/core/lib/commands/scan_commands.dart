/// The scan commands (Story 5.2, Story 5.4 and Story 5.5; FR-25, FR-26 b,
/// AD-21, AD-8): pure functions that compute *what* to append — never ids,
/// instants or offsets, which the shell mints at the commit of each
/// act. `faceRefused` is the on-device face gate's refusal's single
/// sanctioned minter, so no second refusal writer can appear silently;
/// `consentGranted` (Story 5.4) is the consent act's single sanctioned
/// minter — instrumentation only, carrying no capability; and
/// `consentDeclined` (Story 5.5) is the declined consent's single
/// sanctioned minter — a logged decline that is never contact and
/// carries no capability, so no second decline writer can appear
/// silently; and `scanAbandoned` (Story 5.6) is `scan_abandoned`'s
/// single sanctioned minter — the row the scan controller's close
/// mints when the user leaves or backgrounds the wait, so no second
/// abandonment writer can appear silently.
///
/// All four rows are payload-less on the `app_opened` precedent: no item
/// pair, no cause, no frame reference, no scan identity — nothing the
/// log could later read as an obligation, an absence or a capability
/// (AD-21's discipline). A detector *failure* mints nothing here, by
/// design: a failure is not a refusal, and the log must never claim a
/// privacy decision that was not made (the scan controller folds a
/// failed gate into a quiet close). Nothing retries, nothing queues: a
/// fresh scan is a fresh frame by construction.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';

/// `face_refused` — exactly one payload-less content row. There is no
/// refusal shape here to reach: the shell completes the row — minting
/// the UUIDv7 id, the instant and the offset in force — before the port
/// sees it, and the append rides the shared `LogWriteQueue` like every
/// other write.
List<LogEntryContent> faceRefused() {
  return [
    (
      kind: LogKind.faceRefused,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
    ),
  ];
}

/// `consent_granted` — exactly one payload-less content row, the
/// kind's single sanctioned minter (Story 5.4, AD-8, FR-26 b). The
/// row is instrumentation only and carries no capability: the consent
/// token itself is minted separately (`mintScanConsent`), never
/// persisted, never exported, never reconstructible from the log, and
/// this row names no scanId — a row grants nothing, it only records
/// that the consent act happened. There is no consent shape here to
/// reach: the shell completes the row — minting the UUIDv7 id, the
/// instant and the offset in force — before the port sees it, and the
/// append rides the shared `LogWriteQueue` like every other write.
/// The row is a user act (AD-21): contact for the warm return — the
/// user was actively using the app, the opposite register of the
/// refusal rows above.
List<LogEntryContent> consentGranted() {
  return [
    (
      kind: LogKind.consentGranted,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
    ),
  ];
}

/// `consent_declined` — exactly one payload-less content row, the
/// kind's single sanctioned minter (Story 5.5, FR-25, FR-26, AD-21).
/// The row is a decline record that asserts nothing: it logs that the
/// per-scan consent was declined — FR-26's audit trail — and carries
/// no capability, no scan identity and no re-ask state; a decline is
/// never contact (the permission-refusal register, not the user-act
/// one — the log must never read a refusal as engagement). There is
/// no decline shape here to reach: the shell completes the row —
/// minting the UUIDv7 id, the instant and the offset in force —
/// before the port sees it, and the append rides the shared
/// `LogWriteQueue` like every other write.
List<LogEntryContent> consentDeclined() {
  return [
    (
      kind: LogKind.consentDeclined,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
    ),
  ];
}

/// `scan_abandoned` — exactly one payload-less content row, the
/// kind's single sanctioned minter (Story 5.6, FR-16, AD-8, AD-21).
/// The row records the unbounded wait's one honest resolution the
/// user's own departure caused: leaving the scan surface or
/// backgrounding the app mid-wait cancels and discards the scan —
/// the row is AD-8's resolution cause, FR-26's audit trail — and it
/// asserts nothing else: no capability, no scan identity, no
/// re-ask, never contact (the naming table's user-act register, the
/// `warm_return` default's non-contact side). There is no abandonment
/// shape here to reach: the shell completes the row — minting the
/// UUIDv7 id, the instant and the offset in force — before the port
/// sees it, and the append rides the shared `LogWriteQueue` like
/// every other write.
List<LogEntryContent> scanAbandoned() {
  return [
    (
      kind: LogKind.scanAbandoned,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
    ),
  ];
}
