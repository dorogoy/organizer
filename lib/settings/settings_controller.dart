import 'package:core/commands/settings_commands.dart';
import 'package:core/log/log_entry.dart';
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
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
  });

  final StorePort store;
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
