/// The settings derivation (AD-1): no settings record is ever stored —
/// the settings state is a derived cache over `setting_changed` entries,
/// rebuilt on every read, never a source of truth. "What the Time Bag
/// was on day 5" is answerable from the log alone, because the log is
/// all there is.
///
/// The shape mirrors `energy.dart`'s: one pure pass over the entries in
/// store read order, the last valid observation wins, a named constant
/// default. Settings are day-scoped to nothing — a setting persists
/// until changed (FR-7), so unlike energy there is no boundary reset
/// and no day filter: the pass simply reads the newest value.
///
/// The Time Bag is a ceiling, never a wallet (FR-7, FR-12): it covers
/// advance work only, nothing ever subtracts from it, and no
/// accumulator exists anywhere. This file holds no write path at all —
/// the single sanctioned `setting_changed` minter lives in
/// `commands/settings_commands.dart`.

library;

import 'package:core/log/log_entry.dart';

/// The Time Bag's confirmed range floor (FR-7, §10.1): 5 minutes.
const int timeBagLeastMinutes = 5;

/// The Time Bag's confirmed range ceiling (FR-7, §10.1): 30 minutes.
const int timeBagMostMinutes = 30;

/// The Time Bag's default (FR-7, §10.1): 15 minutes — the one source of
/// the number fifteen; the weave's composition default and every
/// derivation read it from here.
const int defaultTimeBagMinutes = 15;

/// The `setting_changed` key naming the Time Bag — the only setting
/// this build knows. A key this build does not know stays in the log
/// untouched and derives nothing (AD-23).
const String timeBagSettingKey = 'time_bag';

/// The stepped options the Time Bag surface offers (FR-7 fixes the
/// range, not the granularity): six quiet pills, tappable at 200%.
const List<int> timeBagOptions = [5, 10, 15, 20, 25, 30];

/// Whether [minutes] is a value the Time Bag may hold.
bool _isValidTimeBagMinutes(int minutes) =>
    minutes >= timeBagLeastMinutes && minutes <= timeBagMostMinutes;

/// The derived Time Bag (FR-7, AD-1): the last valid `time_bag`
/// `setting_changed` entry in store read order, defaulting to
/// [defaultTimeBagMinutes] when the log holds none. Entries whose value
/// falls outside the confirmed range are treated as absent — the entry
/// stays in the log, never repaired, never fatal (AD-23) — and an
/// earlier valid value (or the default) stands. Ties at one instant
/// need no rule of their own: store read order (instant, then append
/// sequence) is the input order, and the last valid entry in it wins
/// (AD-3).
int deriveTimeBagMinutes(List<LogEntry> entries) {
  var bag = defaultTimeBagMinutes;
  for (final entry in entries) {
    if (entry is SettingEntry &&
        entry.key == timeBagSettingKey &&
        _isValidTimeBagMinutes(entry.value)) {
      bag = entry.value;
    }
  }
  return bag;
}
