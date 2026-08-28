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

/// The substrate database: two insert-only tables whose refusal of UPDATE
/// and DELETE is declared in `substrate.drift` and installed by the initial
/// migration (AD-2). schemaVersion 1 — every later change is additive-only
/// (AD-23).
@DriftDatabase(include: {substrateSchemaFile})
class SubstrateDatabase extends _$SubstrateDatabase {
  SubstrateDatabase(super.connection);

  @override
  int get schemaVersion => 1;

  /// The initial migration creates everything: both tables and the four
  /// `.drift`-declared triggers. The mechanism is drift's; the outcome —
  /// triggers present after first open on a fresh install — is pinned by
  /// `test/store/substrate_test.dart`.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) => customStatement(recursiveTriggersPragma),
  );
}
