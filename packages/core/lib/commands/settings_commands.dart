/// The settings command (AD-3, AD-1): the one pure function that computes
/// *what* to append when a setting changes — never ids, instants or
/// offsets, which the shell mints at the commit of the act. A
/// `setting_changed` row exists only because this file returned it: it is
/// the kind's single sanctioned minter, so no second writer of settings
/// rows can appear silently. Nothing here reads the log — a setting change
/// is a fresh act, not a derivation — and nothing subtracts from any bag:
/// the Time Bag is a ceiling composed against, never a wallet spent.
///
/// Refusal is silence, on purpose: a key this build does not know, or a
/// Time Bag value outside its confirmed range, returns no content and
/// appends nothing — no error surface exists anywhere to show (the option
/// surface offers only valid values, so the refusal is unreachable from
/// the UI and guards only the command boundary).

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';

/// `setting_changed` for the named key — [timeBagSettingKey] is the only
/// key this build knows, and any other key returns no content (AD-23:
/// this build does not write what it cannot read). A Time Bag value
/// inside [timeBagLeastMinutes]–[timeBagMostMinutes] returns exactly one
/// content row; anything outside returns none. The shell completes the
/// row — minting the UUIDv7 id, the instant and the offset in force —
/// before the port sees it.
List<LogEntryContent> settingChanged({
  required String key,
  required int value,
}) {
  if (key != timeBagSettingKey ||
      value < timeBagLeastMinutes ||
      value > timeBagMostMinutes) {
    return const [];
  }
  return [
    (
      kind: LogKind.settingChanged,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: key,
      settingValue: value,
    ),
  ];
}
