/// The settings command (AD-3, AD-1): the one pure function that computes
/// *what* to append when a setting changes — never ids, instants or
/// offsets, which the shell mints at the commit of the act. A
/// `setting_changed` row exists only because this file returned it: it is
/// the kind's single sanctioned minter, so no second writer of settings
/// rows can appear silently. Nothing here reads the log — a setting change
/// is a fresh act, not a derivation — and nothing subtracts from any bag:
/// the Time Bag is a ceiling composed against, never a wallet spent.
///
/// Story 4.3 grows the sanctioned keys additively (AD-22, schema v8):
/// beside the Time Bag's int, the selected AI provider rides the same
/// kind as charset-validated text — a provider id, never a credential
/// (the vault's envelopes live in Files storage, never in the log) and
/// never an availability claim (the read-side derivation asks the vault
/// at read time; nothing persists its answer).
///
/// Refusal is silence, on purpose: a key this build does not know, a
/// Time Bag value outside its confirmed range, or a provider id outside
/// the charset returns no content and appends nothing — no error surface
/// exists anywhere to show (the option surface offers only valid values,
/// so the refusal is unreachable from the UI and guards only the command
/// boundary).

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';

/// `setting_changed` for the named key — the keys this build knows are
/// [timeBagSettingKey] (int-valued) and [selectedProviderSettingKey]
/// (text-valued, Story 4.3), and any other key returns no content
/// (AD-23: this build does not write what it cannot read). A Time Bag
/// value inside [timeBagLeastMinutes]–[timeBagMostMinutes] — passed as
/// [value], with no [textValue] — returns exactly one content row; a
/// provider id satisfying [isValidProviderId] — passed as [textValue],
/// with no [value] — returns exactly one content row carrying the text;
/// anything else returns none. The shell completes the row — minting
/// the UUIDv7 id, the instant and the offset in force — before the
/// port sees it.
List<LogEntryContent> settingChanged({
  required String key,
  int? value,
  String? textValue,
}) {
  final int? intValue;
  final String? text;
  if (key == timeBagSettingKey) {
    if (value == null ||
        textValue != null ||
        value < timeBagLeastMinutes ||
        value > timeBagMostMinutes) {
      return const [];
    }
    intValue = value;
    text = null;
  } else if (key == selectedProviderSettingKey) {
    if (textValue == null || value != null || !isValidProviderId(textValue)) {
      return const [];
    }
    intValue = null;
    text = textValue;
  } else {
    return const [];
  }
  return [
    (
      kind: LogKind.settingChanged,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: key,
      settingValue: intValue,
      settingTextValue: text,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
    ),
  ];
}
