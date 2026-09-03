import 'package:core/commands/capture_commands.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/store_port.dart';
import 'package:uuid/uuid.dart';

import '../session/log_write_queue.dart';

/// The Manual Capture write seam (Story 3.2, FR-27): the shell side of
/// the core's single sanctioned capture minter. It follows the
/// Dispenser controller's division of labour exactly — the core decides
/// content (`captureCreate`: the pool-fact payload with its Origin
/// Context, plus the `capture_created` row whose item pair names the
/// fact), and this shell mints the fact's UUIDv7 id and the batch's one
/// instant (with the offset in force) at entry, before any await, while
/// the entry's own v7 id is minted per row at its commit — the
/// dispenser pattern. The same
/// store instance the Dispenser holds is handed in, and writes are
/// serialized over the shared `LogWriteQueue`, so a capture racing a
/// `Hecho` at the surface can never interleave appends with it.
///
/// The instant is minted at entry, before any await, so the recorded
/// rows describe the tap, not the reads that follow; the fact's id is
/// minted there too, handed straight to the command so the shell stays
/// a verbatim copier — a refused blank line names nothing and appends
/// nothing (unreachable from the surface, which disables `Guardar` on
/// a blank line). A failing append rethrows to the caller while the
/// queue recovers: the surface stays with its line intact, nothing is
/// surfaced, and the retry is the same tap.
class CaptureController {
  CaptureController({
    required this.store,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
    LogWriteQueue? writeQueue,
  }) : writeQueue = writeQueue ?? LogWriteQueue();

  final StorePort store;
  final Uuid idMinter;
  final DateTime Function() nowOf;
  final LogWriteQueue writeQueue;

  /// Saves one capture (FR-27): one manual pool fact — origin `manual`,
  /// the chosen 1-3-5 size, Origin Context the trimmed single line —
  /// then the `capture_created` entry referencing it, both at the one
  /// minted instant, a v7 id per row, the fact before the entry that
  /// names it. [dictated] (FR-32, Story 3.4) records who authored the
  /// line: `true` when the transcript landed from the microphone,
  /// `false` when the keyboard typed it — written once at creation,
  /// and a keyboard correction after dictation keeps it `true`. A
  /// line that is blank after trimming appends nothing at
  /// all (the core command's own refusal). Nothing here deals a card
  /// or touches candidacy: a capture is not a candidate until 3.3's
  /// derivation says so.
  Future<void> save(String line, Size size, {bool dictated = false}) {
    final now = nowOf();
    final factId = idMinter.v7();
    return writeQueue.enqueue(() async {
      final captured = captureCreate(
        factId: factId,
        line: line,
        size: size,
        dictated: dictated,
      );
      if (captured == null) {
        return;
      }
      await store.appendPoolFact((
        id: factId,
        origin: captured.fact.origin,
        size: captured.fact.size,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        originContext: captured.fact.originContext,
        dictated: captured.fact.dictated,
      ));
      final content = captured.entry;
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
        settingTextValue: null,
        pocketMinutes: content.pocketMinutes,
        energyLevel: content.energyLevel,
        reportValue: content.reportValue,
        reportWeek: content.reportWeek,
        permission: content.permission?.name,
      ));
    });
  }
}
