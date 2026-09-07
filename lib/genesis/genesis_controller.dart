// The typed genesis channel (Story 5.8, FR-11's second entrance,
// FR-25, FR-26 b): the `Analizar` act's shell half — the scan
// channel's discipline (Story 5.2–5.7) minus every photo mechanic:
// no camera, no face gate, no cache subdirectory, no consent token
// (the typed dispatch structurally rides `GenesisSliceRequest` →
// `ProjectGenesisText`, token-free — the token binds to scan cache
// identities only scans have). One surface, one description, one
// dispatch, one resolution; nothing queues, retries or persists
// beyond the rows and facts the resolution mints.
//
// The instrumentation is the scan channel's own vocabulary verbatim
// (FR-26 b's "on the same terms" is literal): `consent_granted` at
// the `Analizar` tap — the send IS the consent, no separate dialog,
// no provider name — `slice_failed{cause}` on both failure arms, and
// `scan_abandoned` as the unbounded wait's one honest resolution the
// user's own departure caused, all through the same single
// sanctioned minters (`scan_commands.dart`); the kind census stays
// twenty. The landing is 5.7's verbatim: `parseScanSlice` over the
// delivered body (one parser, one landing, one Origin Context rule
// for both entrances), `scanSliceLanded` seeds, per-fact appends.
// Nothing is dealt: the facts are not candidates until 5.9 wires
// Epic material into the weave — the caller closes quietly to the
// Dispenser.
//
// The wait rides 5.6's semantics unchanged: uncapped, and a
// [close] landing anywhere inside it — the surface's lifecycle
// departure or its disposal — is the user abandoning the wait: the
// close mints exactly one `scan_abandoned` row, discards the
// standing dispatch, and the bumped epoch folds every late
// resolution to a stale answer (no landing, no rows). Writes ride
// the shared `LogWriteQueue`, one substrate under the whole shell,
// quiet about their own failure exactly as the scan channel's are.
import 'package:core/commands/scan_commands.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/slicer/scan_steps.dart';
import 'package:uuid/uuid.dart';

import '../egress/local_slicer.dart';
import '../session/log_write_queue.dart';

/// One typed genesis attempt's terminal outcome (Story 5.8): sealed
/// so no third state — no pending, no queued, no retrying — exists
/// as a type, on `ScanConsentOutcome`'s own shape.
sealed class GenesisOutcome {
  const GenesisOutcome();
}

/// The slice was delivered and its steps landed as pool facts —
/// 5.7's landing verbatim: one parser, one landing, one Origin
/// Context rule for both entrances. Nothing is dealt (the one-card
/// landing is 5.9's); the caller closes quietly to the Dispenser.
final class GenesisDelivered extends GenesisOutcome {
  const GenesisDelivered();
}

/// The genesis failed terminally with one of the closed eight
/// causes: the caller routes the standing `noSlicerCauseFromFailure`
/// map, the 4-5 mapping unchanged. A body that parses but violates
/// the step contract arrives here as `malformedResponse` — the one
/// declared fold, never an eighth cause.
final class GenesisFailed extends GenesisOutcome {
  const GenesisFailed(this.cause);

  /// The port's failure cause.
  final SlicerFailureCause cause;
}

/// A stale answer (the epoch discipline): the act folded closed
/// before or during the wait — a blank description, a second act
/// while one stands, an absent slicer seam, or the wait closed
/// while the dispatch stood. No routing, nothing landed; when the
/// close minted a `scan_abandoned` row that row is already the one
/// honest record, and when nothing stood nothing was ever true —
/// the outcome never says which, the scan channel's own fold
/// (`ScanConsentStale`'s precedent: one outcome, one meaning —
/// "this act is over; route nothing").
final class GenesisStale extends GenesisOutcome {
  const GenesisStale();
}

/// The typed genesis channel (FR-11, FR-25). [store] is the one
/// substrate the whole shell holds; [slicer] and
/// [readSelectedProvider] copy the scan controller's composition
/// convention: main threads the one production port and the
/// selected-provider read, and the surface runs the fail-closed
/// pre-dispatch read itself (`_continueToConsent`'s mirror) before
/// any row or dispatch. Absent (the test seam), an analyze folds
/// closed — nothing half-wired dispatches.
class GenesisController {
  GenesisController({
    required this.store,
    this.slicer,
    this.readSelectedProvider,
    LogWriteQueue? writeQueue,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
  }) : writeQueue = writeQueue ?? LogWriteQueue();

  final StorePort store;

  /// The Slicer seam (AD-9): the SAME instance the Dispenser's
  /// rescue path and the scan channel's consent phase hold. Absent
  /// (the test seam), the analyze folds closed — nothing
  /// half-wired dispatches.
  final SlicerPort? slicer;

  /// The selected-provider read (AD-22): the pre-dispatch
  /// availability read, resolved from the log — null when none
  /// stands. The surface owns the read itself, fail-closed before
  /// any row or dispatch; the controller never calls it.
  final Future<String?> Function()? readSelectedProvider;

  final LogWriteQueue writeQueue;
  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// Whether a dispatch stands (the wait has begun): set once the
  /// guards pass, cleared on every [analyze] exit and by the [close]
  /// that mints it, so [close] mints exactly one `scan_abandoned`
  /// row for a departure mid-wait and nothing for a post-resolution
  /// dispose — and a fresh surface's analyze (the controller is a
  /// root singleton, reused surface to surface) owns the seam again.
  bool _sliceInFlight = false;

  /// The close epoch: bumped by every [close], so a dispatch
  /// resolving after a terminal close can see its own staleness — a
  /// late landing records nothing and lands nothing.
  int _epoch = 0;

  /// The `Analizar` act (FR-25): the send IS the consent — one
  /// `consent_granted` row (instrumentation only, carrying no
  /// capability; no token exists on this path), then exactly one
  /// `GenesisSliceRequest` carrying the composed genesis prompt and
  /// nothing else. Delivered, the body parses through the scan
  /// contract's one parser and the steps land as pool facts (5.7
  /// verbatim: origin `cloud` on BYOK, `local` on the debug stub —
  /// set at genesis, immutable); violated, the one declared
  /// `malformedResponse` fold; failed, the raw cause beside its one
  /// `slice_failed` row; thrown, the `providerUnreachable` fold
  /// (a malfunction is never a taxonomy value). A close landing
  /// anywhere inside the wait resolves everything to
  /// [GenesisStale] — the close already minted the departure's one
  /// `scan_abandoned` row.
  ///
  /// Guards: a blank-after-trim description saves nothing (the
  /// surface's disabled pill already says so — this is the same
  /// guard any caller the pill cannot speak for), a dispatch
  /// already standing is nothing at all (one act, one send), and an
  /// absent [slicer] seam folds closed — nothing half-wired
  /// dispatches.
  Future<GenesisOutcome> analyze(String description) async {
    final trimmed = description.trim();
    final slicer = this.slicer;
    if (trimmed.isEmpty || _sliceInFlight || slicer == null) {
      return const GenesisStale();
    }
    _sliceInFlight = true;
    final epoch = _epoch;
    try {
      await _appendConsentGranted();
      if (_epoch != epoch) {
        // A close won the race before the dispatch began: cancelled
        // and discarded — the slicer is never called, and the close
        // already minted the wait's scan_abandoned row.
        return const GenesisStale();
      }
      final SlicerOutcome outcome;
      try {
        outcome = await slicer.slice(
          GenesisSliceRequest(text: _genesisPrompt(trimmed)),
        );
      } on Object {
        // A throw is a malfunction, never a taxonomy value (the scan
        // path's own containment): resolve as the provider-unreachable
        // arm — unless the close won the race, which is the stale
        // answer below. The fold is a failed dispatch on record all
        // the same (FR-26 b), so its row mints here exactly as the
        // typed failure arm's does.
        if (_epoch != epoch) {
          return const GenesisStale();
        }
        _sliceInFlight = false;
        await _appendGenesisSliceFailed(SlicerFailureCause.providerUnreachable);
        return const GenesisFailed(SlicerFailureCause.providerUnreachable);
      }
      if (_epoch != epoch) {
        // The wait closed while the dispatch stood: a stale answer —
        // no routing, nothing recreated, the close's own
        // scan_abandoned row already stands.
        return const GenesisStale();
      }
      // The resolution owns the rest, so a close during the tail
      // appends below mints nothing.
      _sliceInFlight = false;
      switch (outcome) {
        case SlicerDelivered(:final responseBody):
          // The landing (5.7 verbatim): the delivered body parses in
          // pure core AFTER the port returned, and each parsed step
          // lands as a pool fact through the core's single
          // sanctioned minter.
          final slice = parseScanSlice(responseBody);
          if (slice == null) {
            // A body that parses but violates the step contract folds
            // into the declared mapping — one `slice_failed` row
            // under the existing `malformedResponse` cause, surfaced
            // by the existing provider-unresponsive string, never an
            // eighth cause, and nothing is dealt as-is.
            await _appendGenesisSliceFailed(
              SlicerFailureCause.malformedResponse,
            );
            return const GenesisFailed(SlicerFailureCause.malformedResponse);
          }
          await _appendGenesisLanded(
            slice,
            origin: slicer is LocalSlicer ? Origin.local : Origin.cloud,
          );
          return const GenesisDelivered();
        case SlicerFailed(:final cause):
          // A failed dispatch resolves on record (FR-26 b): one
          // `slice_failed` row carrying the raw cause, then the
          // standing 4-5 mapping the caller routes.
          await _appendGenesisSliceFailed(cause);
          return GenesisFailed(cause);
      }
    } finally {
      // A stale resolution may finish after close has opened a new
      // wait. Do not clear that newer wait's flag from the old
      // dispatch.
      if (_epoch == epoch) {
        _sliceInFlight = false;
      }
    }
  }

  /// The terminal close. Since Story 5.6's discipline: a dispatch
  /// standing at the close means the user left the wait — back or
  /// background, the departure is the resolution cause — and exactly
  /// one payload-less `scan_abandoned` row is minted for it through
  /// the core's single sanctioned minter. The in-flight flag clears
  /// here, so the dispose that follows a lifecycle release — and
  /// every later close — mints nothing more; leaving with no
  /// dispatch standing mints nothing either. The bumped epoch
  /// retires every in-flight landing. Idempotent by construction.
  Future<void> close() async {
    final Future<void>? abandonment;
    if (_sliceInFlight) {
      _sliceInFlight = false;
      abandonment = _appendScanAbandoned();
    } else {
      abandonment = null;
    }
    _epoch++;
    await abandonment;
  }

  /// Appends one minted content row — the write paths' shared
  /// copier, the scan controller's own idiom: one minted instant
  /// per act (the caller's [now]), a v7 id per row, the offset in
  /// force at the mint, every content field copied verbatim.
  Future<void> _appendContent(LogEntryContent content, DateTime now) async {
    await store.appendLogEntry((
      id: idMinter.v7(),
      kind: content.kind.name,
      instantUtcMicros: now.microsecondsSinceEpoch,
      offsetSeconds: now.timeZoneOffset.inSeconds,
      itemId: content.itemId,
      itemOrigin: content.itemOrigin,
      stack: content.stack,
      settingKey: content.settingKey,
      settingValue: content.settingValue,
      settingTextValue: content.settingTextValue,
      pocketMinutes: content.pocketMinutes,
      energyLevel: content.energyLevel,
      reportValue: content.reportValue,
      reportWeek: content.reportWeek,
      permission: content.permission?.name,
      sliceCause: content.sliceCause,
    ));
  }

  /// Enqueues one core minter's rows — every row writer's common
  /// body, the scan controller's own idiom: the instant minted at
  /// entry, before any await, a v7 id per row, the shared
  /// `LogWriteQueue` serializing the append against every other
  /// write the shell owns, and a quiet absorption of a failing
  /// store.
  Future<void> _appendMinted(Iterable<LogEntryContent> Function() mint) {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final content in mint()) {
            await _appendContent(content, now);
          }
        })
        .catchError((Object _) {});
  }

  /// Appends exactly one `consent_granted` row through the core's
  /// single sanctioned minter — instrumentation only, carrying no
  /// capability; no token exists on the typed path to keep out of
  /// the log.
  Future<void> _appendConsentGranted() => _appendMinted(() => consentGranted());

  /// Appends exactly one `scan_abandoned` row through the core's
  /// single sanctioned minter — on [_appendScanAbandoned]'s own
  /// shape in the scan channel: no in-closure epoch re-check,
  /// because the close is what makes the row true (the departure is
  /// the resolution cause, so the row stands whatever else races
  /// it).
  Future<void> _appendScanAbandoned() => _appendMinted(() => scanAbandoned());

  /// Appends exactly one `slice_failed` row through the scan
  /// channel's single sanctioned failure minter (FR-26 b) — the
  /// resolution's own truth, minted only after it survived the
  /// caller's epoch checks.
  Future<void> _appendGenesisSliceFailed(SlicerFailureCause cause) =>
      _appendMinted(() => scanSliceFailed(cause: cause));

  /// Lands a delivered slice's steps as pool facts — 5.7's landing
  /// verbatim, the scan channel's own body: the seeds from the
  /// core's single sanctioned minter, the shell minting only the
  /// id, the instant and the offset; one resolution instant for the
  /// whole slice; per-fact appends, no cross-fact transaction (the
  /// substrate is insert-only and a partial plan derives honestly);
  /// the whole landing riding the shared `LogWriteQueue` and a
  /// failing store absorbed quietly.
  Future<void> _appendGenesisLanded(ScanSlice slice, {required Origin origin}) {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final seed in scanSliceLanded(
            origin: origin,
            description: slice.description,
            steps: slice.steps,
          )) {
            await store.appendPoolFact((
              id: idMinter.v7(),
              origin: seed.origin,
              size: seed.size,
              instantUtcMicros: now.microsecondsSinceEpoch,
              offsetSeconds: now.timeZoneOffset.inSeconds,
              originContext: seed.originContext,
              dictated: null,
              rescueOf: null,
              estimateSeconds: seed.estimateSeconds,
              stepText: seed.stepText,
            ));
          }
        })
        .catchError((Object _) {});
  }
}

/// The genesis prompt's head (Story 5.8): the instruction — the
/// scan prompt's own contract for a described project instead of a
/// photographed space — ending at the description's lead-in.
/// Provider-facing instruction, never UI copy: the scan prompt's
/// precedent (`_scanPrompt`, `scan_controller.dart`) — AD-15's
/// literal ban is on copy reaching a widget, and this never reaches
/// one. The JSON shape's four field names are interpolated from
/// `scan_steps.dart`'s own wire-name consts (`rescue_contract.dart`'s
/// single-source precedent — no copy can drift); parity is pinned
/// from the test side (prompt ↔ parse ↔ Local stub).
const String _genesisPromptHead =
    'Eres el asistente de una app móvil de organización del hogar. Recibirás la descripción de un proyecto doméstico escrita por la persona que lo quiere poner en marcha. Tu tarea es convertirla en un plan corto que esa persona pueda ejecutar hoy mismo, paso a paso. Escribe cada paso como una acción concreta y directa sobre lo que la descripción menciona — no inventes objetos ni espacios, y da un orden ejecutable de principio a fin. La respuesta incluye también una descripción: una frase que describa el proyecto tal como queda. Cada paso lleva su duración como un número entero de minutos entre 3 y 5. El proyecto descrito es: ';

/// The genesis prompt's tail: the description's close and the JSON
/// contract itself — the ONE shared contract const
/// (`scanResponseContract`, core's single source), so no copy of
/// the provider-facing contract can drift between the two
/// entrances.
const String _genesisPromptTail = '. $scanResponseContract';

/// Composes the genesis prompt: the instruction, the user's
/// description verbatim, then the scan JSON contract — the answer
/// parses through `parseScanSlice` unchanged, one parser for both
/// entrances.
String _genesisPrompt(String description) =>
    _genesisPromptHead + description + _genesisPromptTail;
