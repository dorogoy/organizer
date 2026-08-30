import 'package:drift/drift.dart';

part 'substrate.g.dart';

/// The drift schema file this database includes — an infrastructure file
/// reference, never a user-facing string: the one named string constant
/// this file owns, on the same terms as the font/format names in
/// `lib/ui/tokens.dart` (AD-15's ban is on literals reaching a widget).
const String substrateSchemaFile = 'substrate.drift';

/// Makes conflict replacement run the DELETE refusal triggers instead of
/// silently replacing an existing row. Applied on two idempotent layers so
/// no connection can miss it: `beforeOpen` below (covers any executor,
/// including the tests' `NativeDatabase.memory()`) and the per-connection
/// `setup` callback in `connection.dart` (covers every underlying native
/// connection the production host opens, pooled or parallel).
const String recursiveTriggersPragma = 'PRAGMA recursive_triggers = ON';

/// Schema v2's additive upgrade of `log_entries` (Story 2.1, AD-23): the
/// two nullable `setting_changed` payload columns, added by ALTER TABLE
/// only — no table rebuild, no data migration, refusal triggers untouched.
/// Named infrastructure identifiers on the store module's terms (AD-15's
/// ban is on literals reaching a widget), one per statement.
const String logEntriesSettingKeyUpgrade =
    'ALTER TABLE log_entries ADD COLUMN setting_key TEXT NULL';

const String logEntriesSettingValueUpgrade =
    'ALTER TABLE log_entries ADD COLUMN setting_value INTEGER NULL';

/// The substrate database: two insert-only tables whose refusal of UPDATE
/// and DELETE is declared in `substrate.drift` and installed by the initial
/// migration (AD-2). schemaVersion 2 (Story 2.1): the only change from 1
/// is the pair of nullable setting columns above, and every later change
/// is additive-only (AD-23).
@DriftDatabase(include: {substrateSchemaFile})
class SubstrateDatabase extends _$SubstrateDatabase {
  SubstrateDatabase(super.connection);

  @override
  int get schemaVersion => 2;

  /// The initial migration creates everything: both tables and the four
  /// `.drift`-declared triggers. The v1→v2 step adds the setting columns
  /// in place, by ALTER TABLE alone, so a v1 install upgrades without a
  /// rebuild and its rows read back unchanged — old rows with null setting
  /// fields. The mechanism is drift's; the outcomes — triggers present
  /// after first open on a fresh install, old rows intact after upgrade —
  /// are pinned by `test/store/substrate_test.dart`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(logEntriesSettingKeyUpgrade);
        await customStatement(logEntriesSettingValueUpgrade);
      }
    },
    beforeOpen: (_) => customStatement(recursiveTriggersPragma),
  );
}
