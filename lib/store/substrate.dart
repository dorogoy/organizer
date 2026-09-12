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

/// Schema v5's additive upgrade of `log_entries` (Story 2.6, AD-23): the
/// two nullable `report_answered` payload columns — the weekly
/// self-report's tapped 1–5 answer and the answered week's
/// `Week.weekOrdinal` — added by ALTER TABLE only, on the v3→v4
/// pattern: no table rebuild, no data migration, refusal triggers
/// untouched. Named infrastructure identifiers on the store module's
/// terms (AD-15's ban is on literals reaching a widget).
const String logEntriesReportValueUpgrade =
    'ALTER TABLE log_entries ADD COLUMN report_value INTEGER NULL';

const String logEntriesReportWeekUpgrade =
    'ALTER TABLE log_entries ADD COLUMN report_week INTEGER NULL';

/// Schema v6's additive upgrade of `pool_facts` (Story 3.2, AD-23): the
/// one nullable Origin Context column — a manual capture's own single
/// line (AD-14) — added by ALTER TABLE only, on the v2→v5 pattern: no
/// table rebuild, no data migration, refusal triggers untouched. A
/// named infrastructure identifier on the store module's terms (AD-15's
/// ban is on literals reaching a widget).
const String poolFactsOriginContextUpgrade =
    'ALTER TABLE pool_facts ADD COLUMN origin_context TEXT NULL';

/// Schema v7's additive upgrade of `log_entries` (Story 3.4, AD-23):
/// the one nullable `permission_refused` payload column — the refused
/// permission's wire name (AD-17, AD-21) — added by ALTER TABLE only,
/// on the v2→v6 pattern: no table rebuild, no data migration, refusal
/// triggers untouched. A named infrastructure identifier on the store
/// module's terms (AD-15's ban is on literals reaching a widget).
const String logEntriesPermissionUpgrade =
    'ALTER TABLE log_entries ADD COLUMN permission TEXT NULL';

/// Schema v7's additive upgrade of `pool_facts` (Story 3.4, AD-23): the
/// one nullable dictation boolean — whether dictation authored the line
/// (FR-32, AD-26) — added by ALTER TABLE only, on the same pattern: no
/// table rebuild, no data migration, refusal triggers untouched. A
/// named infrastructure identifier on the store module's terms (AD-15).
const String poolFactsDictatedUpgrade =
    'ALTER TABLE pool_facts ADD COLUMN dictated BOOL NULL';

/// Schema v8's additive upgrade of `log_entries` (Story 4.3, AD-23):
/// the one nullable `setting_changed` text column — the selected AI
/// provider's id (AD-22: never a credential, never an availability
/// claim) — added by ALTER TABLE only, on the v2→v7 pattern: no
/// table rebuild, no data migration, refusal triggers untouched. A
/// named infrastructure identifier on the store module's terms
/// (AD-15).
const String logEntriesTextValueUpgrade =
    'ALTER TABLE log_entries ADD COLUMN text_value TEXT NULL';

/// Schema v9's additive upgrade of `log_entries` (Story 4.6, AD-23):
/// the one nullable `slice_failed` payload column — the slice
/// failure's cause wire name — added by ALTER TABLE only, on the same
/// pattern: no table rebuild, no data migration, refusal triggers
/// untouched. A named infrastructure identifier on the store module's
/// terms (AD-15).
const String logEntriesSliceCauseUpgrade =
    'ALTER TABLE log_entries ADD COLUMN slice_cause TEXT NULL';

/// Schema v9's additive upgrade of `pool_facts` (Story 4.6, AD-23):
/// the one nullable rescue-parent column — the item id a rescue step
/// rescues — added by ALTER TABLE only, on the same pattern. A named
/// infrastructure identifier on the store module's terms (AD-15).
const String poolFactsRescueOfUpgrade =
    'ALTER TABLE pool_facts ADD COLUMN rescue_of TEXT NULL';

/// Schema v9's additive upgrade of `pool_facts` (Story 4.6, AD-23):
/// the one nullable estimate column — the Slicer's verbatim duration
/// tag, in seconds — added by ALTER TABLE only, on the same pattern.
/// A named infrastructure identifier on the store module's terms
/// (AD-15).
const String poolFactsEstimateSecondsUpgrade =
    'ALTER TABLE pool_facts ADD COLUMN estimate_seconds INTEGER NULL';

/// Schema v10's additive upgrade of `pool_facts` (Story 5.7, AD-23):
/// the one nullable step-text column — a scan step's own words, the
/// task itself where a rescue step keeps its text in the Origin
/// Context — added by ALTER TABLE only, on the same pattern. A named
/// infrastructure identifier on the store module's terms (AD-15).
const String poolFactsStepTextUpgrade =
    'ALTER TABLE pool_facts ADD COLUMN step_text TEXT NULL';

/// Schema v11's additive upgrade of `log_entries` (Story 5.11,
/// AD-23): the one nullable `cluster_curation_changed` payload
/// column — the curated cluster's wire name — added by ALTER TABLE
/// only, on the v2→v10 pattern: no table rebuild, no data migration,
/// refusal triggers untouched. A named infrastructure identifier on
/// the store module's terms (AD-15's ban is on literals reaching a
/// widget).
const String logEntriesClusterUpgrade =
    'ALTER TABLE log_entries ADD COLUMN cluster TEXT NULL';

/// Schema v11's additive upgrade of `log_entries` (Story 5.11,
/// AD-23): the one nullable `cluster_curation_changed` payload
/// column — the cluster's new enabled bit — added by ALTER TABLE
/// only, on the same pattern: no table rebuild, no data migration,
/// refusal triggers untouched. A named infrastructure identifier on
/// the store module's terms (AD-15).
const String logEntriesEnabledUpgrade =
    'ALTER TABLE log_entries ADD COLUMN enabled BOOL NULL';

/// Schema v12's additive upgrade of `log_entries` (Story 6.3,
/// AD-23): the one nullable `item_triaged` payload column — the
/// triage act's destination wire name — added by ALTER TABLE only,
/// on the v2→v11 pattern: no table rebuild, no data migration,
/// refusal triggers untouched. A named infrastructure identifier on
/// the store module's terms (AD-15's ban is on literals reaching a
/// widget).
const String logEntriesTriageDestinationUpgrade =
    'ALTER TABLE log_entries ADD COLUMN triage_destination TEXT NULL';

/// Schema v12's additive upgrade of `log_entries` (Story 6.3,
/// AD-23): the one nullable `item_triaged` payload column — the
/// triage act's optional coarse volume tag wire name, absent when
/// the tag was declined — added by ALTER TABLE only, on the same
/// pattern: no table rebuild, no data migration, refusal triggers
/// untouched. A named infrastructure identifier on the store
/// module's terms (AD-15).
const String logEntriesTriageVolumeTagUpgrade =
    'ALTER TABLE log_entries ADD COLUMN triage_volume_tag TEXT NULL';

/// Schema v13's additive upgrade of `log_entries` (Story 6.5,
/// AD-23): the one nullable quarantine `item_triaged` payload column
/// — the linked box's id, the `box_created` row's own id (FR-21) —
/// added by ALTER TABLE only, on the v2→v12 pattern: no table
/// rebuild, no data migration, refusal triggers untouched. A named
/// infrastructure identifier on the store module's terms (AD-15's
/// ban is on literals reaching a widget).
const String logEntriesTriageBoxIdUpgrade =
    'ALTER TABLE log_entries ADD COLUMN triage_box_id TEXT NULL';

/// The additive ALTER's own shape (Story 3.4's idempotent upgrades): the
/// table and column a re-check reads are derived from each named upgrade
/// statement itself, so no second copy of either name exists to drift.
/// Named infrastructure identifiers on the store module's terms (AD-15).
const String additiveAlterShape =
    r'^ALTER TABLE ([a-z_]+) ADD COLUMN ([a-z_]+)';

/// The idempotent upgrade's column-presence read, with the table name
/// substituted for [tableInfoPragmaSlot] — the one shape the pragma
/// accepts, as a named identifier on the terms above.
const String tableInfoPragmaTemplate = 'PRAGMA table_info(@)';

/// The template's substitution slot (see [tableInfoPragmaTemplate]).
const String tableInfoPragmaSlot = '@';

/// The column of `PRAGMA table_info`'s answer that carries a column's
/// name — the field the presence comparison reads.
const String tableInfoNameField = 'name';

/// Schema v14's additive upgrades of `log_entries` (Story 7.1,
/// AD-23): the two nullable reward payload columns — the album
/// blob's content-addressed name the Before shot saved (the
/// `before_saved` row) and the After the pair saved (the
/// `album_entry_added` row) — added by ALTER TABLE only, on the
/// v2→v13 pattern: no table rebuild, no data migration, refusal
/// triggers untouched. Named infrastructure identifiers on the
/// store module's terms (AD-15's ban is on literals reaching a
/// widget).
const String logEntriesBeforeBlobUpgrade =
    'ALTER TABLE log_entries ADD COLUMN before_blob TEXT NULL';

const String logEntriesAfterBlobUpgrade =
    'ALTER TABLE log_entries ADD COLUMN after_blob TEXT NULL';

/// The substrate database: two insert-only tables whose refusal of UPDATE
/// and DELETE is declared in `substrate.drift` and installed by the initial
/// migration (AD-2). schemaVersion 14 (Story 7.1): the only change
/// from 13 is the two nullable reward blob-name columns above, and
/// every later change is additive-only (AD-23).
///
/// Upgrades run inside one transaction and add each column only when the
/// table does not already hold it: a v6 install that died between the two
/// v7 ALTERs (or after their commit but before the version bump) re-opens
/// on a retry that neither re-runs a landed ALTER nor lands half a step —
/// failure-atomic and idempotent, so no upgrade window can wedge a device
/// on its next open.
@DriftDatabase(include: {substrateSchemaFile})
class SubstrateDatabase extends _$SubstrateDatabase {
  SubstrateDatabase(super.connection);

  @override
  int get schemaVersion => 14;

  /// Adds [upgrade]'s column to its table only when the table does not
  /// already hold it — the idempotence half of the upgrade guarantee:
  /// a relaunch over a half-upgraded file (columns landed, version not
  /// yet bumped) must not re-run an ALTER that would now fail. The
  /// table and column are read from the statement itself
  /// ([additiveAlterShape]), never re-named here; an upgrade off the
  /// house shape runs as-is, and the migration tests catch it.
  Future<void> _addColumnIfAbsent(String upgrade) async {
    final shape = RegExp(additiveAlterShape).firstMatch(upgrade);
    if (shape == null) {
      await customStatement(upgrade);
      return;
    }
    final pragma = tableInfoPragmaTemplate.replaceAll(
      tableInfoPragmaSlot,
      shape.group(1)!,
    );
    final columns = await customSelect(pragma).get();
    final present = columns.any(
      (row) => row.read<String>(tableInfoNameField) == shape.group(2),
    );
    if (!present) {
      await customStatement(upgrade);
    }
  }

  /// The initial migration creates everything: both tables and the four
  /// `.drift`-declared triggers. The v1→v2 step adds the setting columns
  /// in place, by ALTER TABLE alone, so a v1 install upgrades without a
  /// rebuild and its rows read back unchanged — old rows with null setting
  /// fields. The v2→v3 step adds the pocket column the same way, so a v2
  /// install upgrades with its rows unchanged too — old rows with a null
  /// pocket, deriving as unbounded sessions. The v3→v4 step adds the
  /// energy level column the same way, so a v3 install upgrades with its
  /// rows unchanged too — old rows with a null level, deriving as
  /// unanswered days. The v4→v5 step adds the two report columns the
  /// same way, so a v4 install upgrades with its rows unchanged too
  /// — old rows with null report fields, no week gaining or losing a
  /// data point. The v5→v6 step adds the pool's Origin Context column
  /// the same way, so a v5 install upgrades with its rows unchanged
  /// too — old facts with a null context, their origins deriving
  /// exactly as before. The v6→v7 step adds the log's permission
  /// column and the pool's dictation boolean the same way, so a v6
  /// install upgrades with its rows unchanged too — old rows with a
  /// null permission, deriving as no refusal on record, and old facts
  /// with a null boolean, deriving as not dictated. The v7→v8 step
  /// adds the log's setting text column the same way, so a v7 install
  /// upgrades with its rows unchanged too — old setting rows with a
  /// null text, deriving exactly as before. The v8→v9 step adds the
  /// log's slice-cause column and the pool's two rescue columns the
  /// same way, so a v8 install upgrades with its rows unchanged too
  /// — old rows with a null cause, deriving as no slice history, and
  /// old facts with null rescue fields, deriving as no chain. The
  /// v9→v10 step adds the pool's step-text column the same way, so
  /// a v9 install upgrades with its rows unchanged too — old facts
  /// with a null step text, deriving exactly as before. The v10→v11
  /// step adds the log's cluster and enabled columns the same way, so
  /// a v10 install upgrades with its rows unchanged too — old rows
  /// with a null cluster and a null enabled bit, deriving exactly as
  /// before (no curation row stands, the all-active default governs).
  /// The v11→v12 step adds the log's triage destination and tag
  /// columns the same way, so a v11 install upgrades with its rows
  /// unchanged too — old rows with null triage fields, deriving
  /// exactly as before (no triage row stands). The v12→v13 step
  /// adds the log's triage box-id column the same way, so a v12
  /// install upgrades with its rows unchanged too — old rows with
  /// a null box link, deriving exactly as before (no quarantine row
  /// stands). The v13→v14 step adds the log's two reward blob-name
  /// columns the same way, so a v13 install upgrades with its rows
  /// unchanged too — old rows with null blob names, deriving
  /// exactly as before (no photo row stands).
  /// Every
  /// step runs inside the one transaction and adds only an absent
  /// column, and the mechanism is
  /// drift's; the outcomes — triggers present after first open on a
  /// fresh install, old rows intact after upgrade — are pinned by
  /// `test/store/substrate_test.dart`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) => transaction(() async {
      if (from < 2) {
        await _addColumnIfAbsent(logEntriesSettingKeyUpgrade);
        await _addColumnIfAbsent(logEntriesSettingValueUpgrade);
      }
      if (from < 3) {
        await _addColumnIfAbsent(logEntriesPocketMinutesUpgrade);
      }
      if (from < 4) {
        await _addColumnIfAbsent(logEntriesEnergyLevelUpgrade);
      }
      if (from < 5) {
        await _addColumnIfAbsent(logEntriesReportValueUpgrade);
        await _addColumnIfAbsent(logEntriesReportWeekUpgrade);
      }
      if (from < 6) {
        await _addColumnIfAbsent(poolFactsOriginContextUpgrade);
      }
      if (from < 7) {
        await _addColumnIfAbsent(logEntriesPermissionUpgrade);
        await _addColumnIfAbsent(poolFactsDictatedUpgrade);
      }
      if (from < 8) {
        await _addColumnIfAbsent(logEntriesTextValueUpgrade);
      }
      if (from < 9) {
        await _addColumnIfAbsent(logEntriesSliceCauseUpgrade);
        await _addColumnIfAbsent(poolFactsRescueOfUpgrade);
        await _addColumnIfAbsent(poolFactsEstimateSecondsUpgrade);
      }
      if (from < 10) {
        await _addColumnIfAbsent(poolFactsStepTextUpgrade);
      }
      if (from < 11) {
        await _addColumnIfAbsent(logEntriesClusterUpgrade);
        await _addColumnIfAbsent(logEntriesEnabledUpgrade);
      }
      if (from < 12) {
        await _addColumnIfAbsent(logEntriesTriageDestinationUpgrade);
        await _addColumnIfAbsent(logEntriesTriageVolumeTagUpgrade);
      }
      if (from < 13) {
        await _addColumnIfAbsent(logEntriesTriageBoxIdUpgrade);
      }
      if (from < 14) {
        await _addColumnIfAbsent(logEntriesBeforeBlobUpgrade);
        await _addColumnIfAbsent(logEntriesAfterBlobUpgrade);
      }
    }),
    beforeOpen: (_) => customStatement(recursiveTriggersPragma),
  );
}
