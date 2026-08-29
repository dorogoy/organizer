/// Locators shared by the catalogue `tool/` scripts — one line-number
/// helper, so every `file:line:` finding in the catalogue checks and the
/// lookup generator counts lines the same way. No coupling into `lib/`:
/// the generated table keeps its own asset-path constant by necessity.
library;

final RegExp _entryErrorId = RegExp(r'entry "([^"]+)"');

/// The 1-based line number of [index] in [text].
int lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// The reporting line for a core parse failure: the offending entry's own
/// line when the message names one, otherwise the top of the file. This
/// regexes the parser's entry-error wording — entry errors start with
/// `entry "<id>":`, a documented contract of `parseCatalogue` — so a
/// wording change there is a cross-tool change.
int lineForEntryError(String text, String message) {
  final named = _entryErrorId.firstMatch(message);
  if (named == null) {
    return 1;
  }
  final probe = text.indexOf('"${named.group(1)}"');
  return probe == -1 ? 1 : lineOf(text, probe);
}
