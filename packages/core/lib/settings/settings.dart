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
/// accumulator exists anywhere. FR-9's rollback clause — unspent pocket
/// minutes returning to the bag on pause — is therefore satisfied
/// vacuously: nothing was ever subtracted, so nothing returns (Story
/// 2.3). A depleting wallet is the rejected alternative, recorded here
/// so no later reader implements one, for subtraction would make debt
/// expressible (NFR9) — the very ledger the ceiling exists to keep out
/// of the schema. This file holds no write path at all — the single
/// sanctioned `setting_changed` minter lives in
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

/// The `setting_changed` key naming the Time Bag — one of the two
/// settings this build knows. A key this build does not know stays in
/// the log untouched and derives nothing (AD-23).
const String timeBagSettingKey = 'time_bag';

/// The `setting_changed` key naming the selected AI provider (Story
/// 4.3, AD-22): the BYOK path's one chosen id, riding the row as
/// charset-validated text (schema v8). The row never carries the
/// credential itself — the vault's envelopes live in Files storage —
/// and never an availability claim: `deriveProviderConfigured` asks
/// about the credential at read time, so nothing persists its answer.
const String selectedProviderSettingKey = 'selected_provider';

/// A provider id's charset (Story 4.3): lowercase letters, digits and
/// the underscore, one to sixty-four characters — one flat path
/// segment, the same rule the credential vault's Files scoping
/// refuses on. The compile-time provider allowlist (4-4) mints ids
/// inside it; the settings minter and the vault both validate against
/// it, so no id that could traverse or namespace a Files scope is
/// ever written or stored.
final RegExp _providerIdPattern = RegExp(r'^[a-z0-9_]{1,64}$');

/// Whether [id] is a well-formed provider id — the one shared rule
/// the minter, the derivation and the shell's vault all read.
bool isValidProviderId(String id) => _providerIdPattern.hasMatch(id);

/// The stepped options the Time Bag surface offers (FR-7 fixes the
/// range, not the granularity): six quiet pills, tappable at 200%.
const List<int> timeBagOptions = [5, 10, 15, 20, 25, 30];

/// The declared pocket's range floor (FR-8, Story 2.2): one minute —
/// sub-five pockets are command-legal, never surfaced by the ladder.
const int pocketLeastMinutes = 1;

/// The declared pocket's range ceiling (FR-8, Story 2.2): sixty
/// minutes.
const int pocketMostMinutes = 60;

/// The pocket the trigger chip carries when no pocketed session stands
/// (FR-8, Story 2.2) — read by the chip beside the bag's own default,
/// never a second copy of either number.
const int defaultPocketMinutes = 15;

/// One minute, in microseconds — the pocket's wall-clock arithmetic
/// (span deadlines, elapsed checks) reads this one named constant
/// wherever it computes, never a hand-copied literal (Story 2.2).
const int microsPerMinute = 60 * 1000 * 1000;

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
/// (AD-3). The pass reads `setting_changed` rows alone: every other
/// kind — `card_*` acts, session rows, pockets — is invisible to it, so
/// acts append and the ceiling stands unchanged, which is the whole of
/// FR-9's vacuous rollback (the bag-invariance proof's object, Story
/// 2.3).
int deriveTimeBagMinutes(List<LogEntry> entries) {
  var bag = defaultTimeBagMinutes;
  for (final entry in entries) {
    if (entry is SettingEntry &&
        entry.key == timeBagSettingKey &&
        entry.value != null &&
        _isValidTimeBagMinutes(entry.value!)) {
      bag = entry.value!;
    }
  }
  return bag;
}

/// The derived selected AI provider (Story 4.3, AD-22): the last
/// `selected_provider` `setting_changed` entry in store read order
/// whose text satisfies [isValidProviderId], or null when the log
/// holds no valid choice. Entries carrying any other shape — an int
/// value, a foreign key, a text outside the charset — are treated as
/// absent: the entry stays in the log, never repaired, never fatal
/// (AD-23), and an earlier valid choice (or none) stands. The
/// derivation reads the SettingEntry type alone and knows nothing
/// about credentials: whether a decryptable envelope stands behind
/// the chosen provider is `deriveProviderConfigured`'s question,
/// answered at read time from the vault, never persisted here.
String? deriveSelectedProvider(List<LogEntry> entries) {
  String? selected;
  for (final entry in entries) {
    if (entry is SettingEntry &&
        entry.key == selectedProviderSettingKey &&
        entry.textValue != null &&
        isValidProviderId(entry.textValue!)) {
      selected = entry.textValue;
    }
  }
  return selected;
}

/// The derived "a Slicer is configured" bit (Story 4.3, AD-22): the
/// provider choice survived ([selectedProvider] names one) AND the
/// credential decrypts right now ([credentialAvailable] — the shell
/// reads the vault's live answer at derivation time; nothing
/// persists it). After a restore where the choice survived but no
/// envelope did, this reads false until a credential is saved again;
/// after a save with no choice made, it reads false too — both
/// halves are required, and neither is remembered for the other.
bool deriveProviderConfigured(
  String? selectedProvider,
  bool credentialAvailable,
) => selectedProvider != null && credentialAvailable;
