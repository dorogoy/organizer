import 'package:core/commands/settings_commands.dart';
import 'package:core/derive/permission.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:uuid/uuid.dart';

/// The Settings read and write seam (Story 2.1): the controller derives
/// the Time Bag over the log on every read — the settings record is a
/// derived cache rebuilt at start and never a source of truth (AD-1) —
/// and writes through the core's single sanctioned `setting_changed`
/// minter, following the dispenser controller's division of labour
/// exactly: the core decides content, this shell mints each record's
/// UUIDv7 id, instant and offset before the port appends. The same
/// store instance the dispenser holds is handed in (one substrate under
/// the whole shell — `app_test.dart`'s single-openStore pin).
///
/// Story 3.4 adds the validator surface's dictation facts (FR-32,
/// AD-26): the microphone reactivation row's premise — refused (the
/// `permissionMayBeAsked` derivation over the log) ∧ not granted (the
/// recognizer probe's own platform read) — plus the dictated-capture
/// count over the pool facts. Both are reads, writing nothing; the
/// row's single action opens the system's app-details screen through
/// the recognizer port, the permission surface's only recovery path
/// (the app itself never re-asks).
///
/// Writes are serialized with the `_enqueueWrite` pattern
/// (`dispenser_controller.dart`): one setting change's read→compute→append
/// runs to completion before the next begins, so a rapid second tap on
/// another option cannot interleave appends. A change appends exactly one
/// row and carries no confirmation of any kind — silence is the surface's
/// register, and the selected option reading as the current value is the
/// whole feedback there is.
class SettingsController {
  SettingsController({
    required this.store,
    this.recognizer,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
  });

  final StorePort store;

  /// The recognizer seam (Story 3.4): the probe's granted bit and the
  /// app-details action. Absent (the test seam), the reactivation row
  /// reads as absent and the dictated count still renders.
  final RecognizerPort? recognizer;

  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// The serialized write path: one change's append runs to completion
  /// before the next begins. Failures clear from the chain itself so one
  /// throwing change never wedges the next.
  Future<void> _writes = Future<void>.value();

  /// Reads the Time Bag (AD-1: a derivation, never a write): the last
  /// valid `time_bag` entry in store read order, defaulting to 15. The
  /// settled write chain drains first, so a read racing a change sees
  /// the changed log, not a half-written one.
  Future<int> readTimeBag() async {
    await _writes;
    final log = logEntriesOf(await store.readLogEntries());
    return deriveTimeBagMinutes(log);
  }

  /// Reads the microphone reactivation row's premise (Story 3.4,
  /// FR-32): the row renders only while it has something to reactivate
  /// — the permission is refused (the derivation over the log, one
  /// definition) ∧ not granted (the probe's platform read, so a system
  /// re-grant retires the row by itself). The probe speaks "not
  /// granted" only as `askable` — available ∧ not granted — so an
  /// `unavailable` read hides the row: while recognition cannot run
  /// there is nothing to reactivate into, and the row returns with
  /// availability (a refused-but-re-granted read already retired it).
  /// With no recognizer seam the row reads as absent; a failed read is
  /// quiet and reads the same.
  Future<bool> readMicReactivationAvailable() async {
    await _writes;
    final recognizer = this.recognizer;
    if (recognizer == null) {
      return false;
    }
    final entries = logEntriesOf(await store.readLogEntries());
    if (permissionMayBeAsked(entries, Permission.microphone)) {
      return false;
    }
    try {
      return await recognizer.probe() == RecognizerAvailability.askable;
    } catch (_) {
      return false;
    }
  }

  /// Reads the dictated-capture count (Story 3.4, FR-32, AD-26): pool
  /// facts whose dictation boolean is `true` — the validator surface's
  /// own figure, rendered nowhere else (no card marks a capture as
  /// spoken). Old rows read `null`, deriving as not dictated.
  Future<int> readDictatedCount() async {
    await _writes;
    final facts = await store.readPoolFacts();
    return facts.where((fact) => fact.dictated == true).length;
  }

  /// The reactivation row's single action (Story 3.4): the system's
  /// app-details screen, opened through the recognizer port — the
  /// permission surface's only recovery path. The app never re-asks on
  /// its own; a re-grant restores the affordance through the probe.
  Future<void> openMicAppSettings() async {
    final recognizer = this.recognizer;
    if (recognizer == null) {
      return;
    }
    await recognizer.openAppSettings();
  }

  /// Appends one `setting_changed` {time_bag, [minutes]} row — or
  /// nothing at all when the core command refuses the value (out of
  /// range; unreachable from a surface offering only stepped options).
  /// The instant is minted at entry, before any await, so the recorded
  /// row describes the tap, not the reads that follow. No confirmation,
  /// no state, no error surface: the next read's selection mark is the
  /// only consequence.
  Future<void> writeTimeBag(int minutes) {
    final now = nowOf();
    return _enqueueWrite(() async {
      final contents = settingChanged(key: timeBagSettingKey, value: minutes);
      for (final content in contents) {
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
        ));
      }
    });
  }

  Future<void> _enqueueWrite(Future<void> Function() step) {
    final chained = _writes.then((_) => step());
    // The caller observes the attempt's failure, while the chain itself
    // recovers so a later change can retry.
    _writes = chained.catchError((Object error) {});
    return chained;
  }
}
