/// The scan command (Story 5.2, FR-25, AD-21): the one pure function
/// that computes *what* to append when the on-device face gate refuses a
/// frame — never ids, instants or offsets, which the shell mints at the
/// commit of the refusal. A `face_refused` row exists only because this
/// file returned it: it is the kind's single sanctioned minter, so no
/// second refusal writer can appear silently.
///
/// The row is a system event, not a user act (AD-21): it asserts a fact
/// that happened — the gate refused a frame with a person in it — and
/// carries no payload at all, on the `app_opened` precedent: no item
/// pair, no cause, no frame reference, nothing the log could later read
/// as an obligation or an absence. The refusal is about the frame,
/// never about the user (AD-21's discipline), and the row is not
/// contact for the warm return — a refusal is not the user using the
/// app, the `crash_recorded` and `permission_refused` precedent.
///
/// A detector *failure* mints nothing here, by design: a failure is not
/// a refusal, and the log must never claim a privacy decision that was
/// not made (the scan controller folds a failed gate into a quiet
/// close). Nothing retries, nothing queues: a fresh scan is a fresh
/// frame by construction.

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
