import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift_flutter/drift_flutter.dart';

/// The substrate's database file name — drift appends `.sqlite` and stores
/// it in the app's documents directory. An infrastructure identifier, never
/// a user-facing string: the one named string constant this module owns, on
/// the same terms as the four font/format names in `lib/ui/tokens.dart`
/// (AD-15's ban is on literals reaching a widget).
const String substrateFileName = 'organizer_substrate';

/// The production connection for the substrate database.
DatabaseConnection connectSubstrate() => driftDatabase(name: substrateFileName);
