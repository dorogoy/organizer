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

/// Schema v3's additive upgrade of `log_entries` (Story 2.2, AD-23): the
/// one nullable `session_started` payload column — the declared pocket —
/// added by ALTER TABLE only, on the v1→v2 pattern: no table rebuild, no
/// data migration, refusal triggers untouched. A named infrastructure
/// identifier on the store module's terms (AD-15's ban is on literals
/// reaching a widget).
const String logEntriesPocketMinutesUpgrade =
    'ALTER TABLE log_entries ADD COLUMN pocket_minutes INTEGER NULL';

/// Schema v4's additive upgrade of `log_entries` (Story 2.5, AD-23): the
/// one nullable `energy_set` payload column — the tapped level's stable
/// wire int — added by ALTER TABLE only, on the v2→v3 pattern: no table
/// rebuild, no data migration, refusal triggers untouched. A named
/// infrastructure identifier on the store module's terms (AD-15's ban
/// is on literals reaching a widget).
const String logEntriesEnergyLevelUpgrade =
    'ALTER TABLE log_entries ADD COLUMN energy_level INTEGER NULL';

/// The substrate database: two insert-only tables whose refusal of UPDATE
/// and DELETE is declared in `substrate.drift` and installed by the initial
/// migration (AD-2). schemaVersion 4 (Story 2.5): the only change from 3
/// is the nullable energy level column above, and every later change is
/// additive-only (AD-23).
@DriftDatabase(include: {substrateSchemaFile})
class SubstrateDatabase extends _$SubstrateDatabase {
  SubstrateDatabase(super.connection);

  @override
  int get schemaVersion => 4;

  /// The initial migration creates everything: both tables and the four
  /// `.drift`-declared triggers. The v1→v2 step adds the setting columns
  /// in place, by ALTER TABLE alone, so a v1 install upgrades without a
  /// rebuild and its rows read back unchanged — old rows with null setting
  /// fields. The v2→v3 step adds the pocket column the same way, so a v2
  /// install upgrades with its rows unchanged too — old rows with a null
  /// pocket, deriving as unbounded sessions. The v3→v4 step adds the
  /// energy level column the same way, so a v3 install upgrades with its
  /// rows unchanged too — old rows with a null level, deriving as
  /// unanswered days. The mechanism is drift's; the
  /// outcomes — triggers present after first open on a fresh install, old
  /// rows intact after upgrade — are pinned by `test/store/substrate_test.dart`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(logEntriesSettingKeyUpgrade);
        await customStatement(logEntriesSettingValueUpgrade);
      }
      if (from < 3) {
        await customStatement(logEntriesPocketMinutesUpgrade);
      }
      if (from < 4) {
        await customStatement(logEntriesEnergyLevelUpgrade);
      }
    },
    beforeOpen: (_) => customStatement(recursiveTriggersPragma),
  );
}
