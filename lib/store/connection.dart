import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift_flutter/drift_flutter.dart';

import 'substrate.dart' show recursiveTriggersPragma;

/// The substrate's database file name — drift appends `.sqlite` and stores
/// it in the app's documents directory. An infrastructure identifier, never
/// a user-facing string: the one named string constant this module owns, on
/// the same terms as the four font/format names in `lib/ui/tokens.dart`
/// (AD-15's ban is on literals reaching a widget).
const String substrateFileName = 'organizer_substrate';

/// Runs once on every underlying native connection the drift host opens —
/// pooled, background-isolate, or single — so `recursive_triggers` can never
/// be left off a connection that later serves an `INSERT OR REPLACE`
/// (idempotent, and layered with `SubstrateDatabase`'s `beforeOpen`).
///
/// The parameter is `dynamic` because the option's declared type
/// (`void Function(CommonDatabase)`) names a class from `package:sqlite3`,
/// a transitive dependency this package does not declare directly; a
/// `dynamic` parameter is assignable to it — but only the `setup:`
/// assignment is checked against that declared type, while the
/// `db.execute(...)` inside dispatches dynamically at runtime.
///
/// Top-level on purpose: drift sends the setup callback across isolates to
/// the database host, and a closure cannot cross an isolate boundary at
/// all — one here would crash at startup, not at analysis time; a
/// top-level function reference always arrives.
void _configureConnection(dynamic db) {
  db.execute(recursiveTriggersPragma);
}

/// The production connection for the substrate database. Bootstrap owns its
/// construction so callers outside this module cannot reach Drift directly.
DatabaseConnection connectSubstrate() => driftDatabase(
  name: substrateFileName,
  native: const DriftNativeOptions(setup: _configureConnection),
);
