/// The manual-capture command (AD-3, FR-27, AD-14): the one pure
/// function that computes *what* to append when the user saves a line
/// they typed by hand — never ids, instants or offsets, which the shell
/// mints at the commit of the tap. A `capture_created` row and its pool
/// fact exist only because this file returned them: it is the kind's
/// single sanctioned minter (and the pool's first manual writer), so no
/// second capture writer can appear silently. Nothing here reads the
/// log — a capture is a fresh act, not a derivation — and nothing here
/// decides candidacy or precedence: that is 3.3's derivation over the
/// very rows this minter writes, so this story ships the substrate and
/// no behavior.
///
/// The capture's whole payload is the line itself: the fact carries it
/// as its Origin Context — its own single trimmed line and nothing more
/// (AD-14) — while the log row stays payload-minimal, riding the
/// existing item-pair shape with the fact's id and `Origin.manual` and
/// nothing else (AD-23's discipline: no new payload column, no flag on
/// an old kind).
///
/// [factId] arrives from the shell so it stays a verbatim copier (the
/// `cardDone` precedent: commands receive item ids, they never mint
/// them). Minting a v7 id for a refused capture names nothing and
/// appends nothing.
///
/// Refusal is silence, on the `setting_changed` shape: a line that is
/// blank after trimming returns no content and appends nothing — no
/// error surface exists anywhere to show (the surface disables `Guardar`
/// on a blank line, so the refusal is unreachable from the UI and
/// guards only the command boundary). A non-spatial line is accepted
/// without comment: nothing here judges the text, and nothing ever
/// will.
///
/// Story 3.4 widens the fact payload with [dictated] (FR-32): the
/// boolean rides the same single minter — written once at creation,
/// never updated, and a keyboard correction after dictation keeps it
/// `true`, because it records who authored the line, not its final
/// wording.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';

/// The pool-fact payload of one capture: the origin (always `manual` —
/// a dictated capture is `manual` too, dictation being an input method
/// and not a genesis path), the chosen 1-3-5 size, the Origin
/// Context — the trimmed single line — and, since Story 3.4, the
/// dictation boolean: whether dictation authored the line. The shell
/// completes the fact, minting the UUIDv7 id, the instant and the
/// offset in force, before the port sees it.
typedef CaptureFactContent = ({
  Origin origin,
  Size size,
  String originContext,
  bool dictated,
});

/// One capture's whole write: the pool-fact payload plus the
/// `capture_created` content row referencing the fact the same batch
/// appends. The shell appends the fact first, then the entry.
typedef CaptureContent = ({CaptureFactContent fact, LogEntryContent entry});

/// `capture_created` for the saved line — exactly one content row, its
/// whole payload the item pair naming the pool fact (the fact's id,
/// `Origin.manual`), and the fact payload the line itself carries.
/// [dictated] records who authored the line (FR-32): `true` when the
/// transcript landed from the microphone, `false` when the keyboard
/// typed it — written once here, never updated, and outside origin
/// arithmetic either way.
CaptureContent? captureCreate({
  required String factId,
  required String line,
  required Size size,
  required bool dictated,
}) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return (
    fact: (
      origin: Origin.manual,
      size: size,
      originContext: trimmed,
      dictated: dictated,
    ),
    entry: (
      kind: LogKind.captureCreated,
      itemId: factId,
      itemOrigin: Origin.manual,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
    ),
  );
}
