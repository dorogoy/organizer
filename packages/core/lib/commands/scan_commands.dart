/// The scan commands (Story 5.2, Stories 5.4–5.7; FR-16, FR-25,
/// FR-26 b, AD-21, AD-8): pure functions that compute *what* to
/// append — never ids, instants or offsets, which the shell mints
/// at the commit of each act. `faceRefused`, `consentGranted`,
/// `consentDeclined` and `scanAbandoned` are their kinds' single
/// sanctioned minters (Stories 5.2–5.6), so no second writer for
/// any of those rows can appear silently; `scanSliceLanded` and
/// `scanSliceFailed` (Story 5.7) are the delivered scan's two
/// single sanctioned writers — the step-fact seeds a delivered
/// slice lands, and the `slice_failed` row a failed or violating
/// one mints — so no second scan landing writer can appear silently
/// either.
///
/// The four earlier rows are payload-less on the `app_opened`
/// precedent: no item
/// pair, no cause, no frame reference, no scan identity — nothing the
/// log could later read as an obligation, an absence or a capability
/// (AD-21's discipline); `scanSliceFailed`'s row carries exactly its
/// one cause and no item pair (no item exists — the scan died before
/// any fact). A detector *failure* mints nothing here, by
/// design: a failure is not a refusal, and the log must never claim a
/// privacy decision that was not made (the scan controller folds a
/// failed gate into a quiet close). Nothing retries, nothing queues: a
/// fresh scan is a fresh frame by construction.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/slicer/scan_steps.dart';

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

/// The step-fact payload of one landed scan step (Story 5.7,
/// FR-16): everything the fact carries except the shell's own id,
/// instant and offset — the origin (`cloud` on the BYOK path,
/// `local` on the debug stub), the size from the ONE fixed banding
/// (`sizeOfEstimateSeconds` — maintenance across the scan band's
/// 180–300 s, by construction and never re-banded), the estimate
/// verbatim (`duration_minutes × 60`), the slice's description as
/// the Origin Context every step of the slice shares, and the
/// step's own words as `stepText`. No `rescueOf` exists on this
/// path: a scan step is a genesis, never a re-slice.
typedef ScanSliceFactSeed = ({
  Origin origin,
  Size size,
  String originContext,
  String stepText,
  int estimateSeconds,
});

/// The delivered scan's step-fact seeds (Story 5.7, FR-16, FR-27):
/// one seed per parsed step — `parseScanSlice`'s own contract
/// already bounded them 1–6 × 3–5 minutes, each text at most
/// `scanStepTextMost` code units — the facts the shell appends
/// per-step through the store port. The seeds carry no ids, no
/// instants and no offsets: the shell mints those at the commit of
/// the landing, one id per fact, the resolution's one instant for
/// the whole slice. Nothing here writes: this is the content of
/// the landing, never the landing itself.
List<ScanSliceFactSeed> scanSliceLanded({
  required Origin origin,
  required String description,
  required List<ScanStep> steps,
}) {
  final seeds = <ScanSliceFactSeed>[];
  for (final step in steps) {
    // The verbatim estimate, computed once — the banding's one-rule
    // discipline: the size and the estimate read the same number and
    // can never diverge under edit.
    final seconds = step.durationMinutes * 60;
    seeds.add((
      origin: origin,
      size: sizeOfEstimateSeconds(seconds),
      originContext: description,
      stepText: step.text,
      estimateSeconds: seconds,
    ));
  }
  return seeds;
}

/// `slice_failed` for the scan channel (Story 5.7, FR-16, FR-26 b,
/// AD-21) — the scan's single sanctioned failure writer: exactly
/// one row carrying the port's cause verbatim and NO item pair (no
/// item exists — the scan died before any fact; a body that parses
/// but violates the step contract arrives here as
/// `malformedResponse`, the parse's own declared fold, never an
/// eighth cause). The row closes FR-26 series (b)'s outcome
/// vocabulary beside the consent and abandonment rows: a failed
/// dispatch is recorded, never inferred from absent facts. There
/// is no shape here to reach: the shell completes the row —
/// minting the UUIDv7 id, the instant and the offset in force —
/// before the port sees it, and the append rides the shared
/// `LogWriteQueue` like every other write.
List<LogEntryContent> scanSliceFailed({required SlicerFailureCause cause}) {
  return [
    (
      kind: LogKind.sliceFailed,
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
      sliceCause: cause.name,
    ),
  ];
}
