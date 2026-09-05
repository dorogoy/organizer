/// The rescue-steps parse (Story 4.6, FR-5, AD-5): the delivered
/// re-slice text becomes steps IN CORE — the shell never judges a
/// provider's answer, exactly as it never judges a log record's shape.
/// One function, pure over its input, answers either the parsed steps
/// or nothing; the caller folds nothing into `malformedResponse`, the
/// port's own cause for a body that will not yield its slice.
///
/// The contract of record lives shell-side
/// (`lib/egress/rescue_contract.dart` — the prompt and the canonical
/// schema the BYOK wires pin their structured-output dialects to);
/// core cannot import it, so the wire field names below are this
/// library's own statement of the same three names, and the parity is
/// pinned from the shell side: a test there feeds the contract's own
/// derived field names and the Local stub's canned body through this
/// parse, so a drift in either direction fails the gate. The count
/// and duration bounds are the contract's — 2–4 steps, each 1–60
/// seconds — and they are re-enforced here whatever a wire dropped on
/// the way out (Gemini's dialect carries no minItems/maxItems by
/// design; the parse is where the bounds hold). The text bound
/// (`rescueStepTextMost`) is this parse's own — the wire schema says
/// only "string" — and it refuses a longer step whole rather than
/// truncate it: verbatim words serve the one-card surface, or the
/// body is not a slice this build would weave as work.

library;

import 'dart:convert';

/// The rescue contract's least step count (FR-5): a re-slice below two
/// steps is not a re-slice.
const int rescueStepsLeast = 2;

/// The rescue contract's most step count (FR-5): a re-slice above four
/// steps is a wall, not a ladder.
const int rescueStepsMost = 4;

/// The rescue contract's per-step least duration, in seconds (FR-5).
const int rescueStepSecondsLeast = 1;

/// The rescue contract's per-step most duration, in seconds (FR-5):
/// the ≤ 60 s band, the same ceiling a 🔴 day admits by.
const int rescueStepSecondsMost = 60;

/// The per-step most text length, in UTF-16 code units, measured on
/// the text AFTER the parse's own trim — never the raw wire string,
/// so padding neither saves nor condemns a step. The pair's least is
/// the parse's existing non-empty check (one unit), the same
/// Least/Most pairing the count and duration bounds keep. This bound
/// is the parse's own (the wire schema carries none), and it is per
/// step because the card shows one step at a time — a 2–4 step body
/// is a ladder, not one wall. A step past it refuses the whole body,
/// never trims the words into shape: the taxonomy's honesty rides
/// verbatim text, so a wall is refused rather than edited (AD-23's
/// no-repair rule, the one the parse below cites).
const int rescueStepTextMost = 120;

/// The steps array's wire name — `rescue_contract.dart`'s canonical
/// schema derives the same name; parity is pinned from the shell side.
const String rescueWireStepsField = 'steps';

/// The step object's text wire name.
const String rescueWireTextField = 'text';

/// The step object's duration wire name.
const String rescueWireDurationField = 'duration_seconds';

/// One parsed rescue step: its trimmed non-empty text and its verbatim
/// duration in seconds — the two facts the step's pool fact carries
/// (the text as its Origin Context, the duration as its estimate).
typedef RescueStep = ({String text, int durationSeconds});

/// Parses [body] against the rescue contract: a JSON object holding a
/// `steps` array of 2–4 objects, each a non-empty `text` string of at
/// most `rescueStepTextMost` code units (measured after trim) and an
/// integer `duration_seconds` of 1–60 — the bounds the wires cannot
/// be trusted to have enforced, restated here as the single reader. A
/// body that fails any clause answers null: one failure cause
/// (`malformedResponse`) covers them all, and nothing here repairs,
/// retries or coaxes a near-miss into shape (AD-23's tolerance is for
/// unknown log kinds, never for a slice this build would weave as
/// work). Unknown extra keys are carried, not rejected — a provider's
/// dialect may add what it likes around the three names the contract
/// owns, exactly as the log carries an unknown kind.
List<RescueStep>? parseRescueSteps(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final Object? stepsWire = decoded[rescueWireStepsField];
  if (stepsWire is! List || stepsWire.length < rescueStepsLeast) {
    return null;
  }
  if (stepsWire.length > rescueStepsMost) {
    return null;
  }
  final steps = <RescueStep>[];
  for (final Object? stepWire in stepsWire) {
    if (stepWire is! Map) {
      return null;
    }
    final Object? textWire = stepWire[rescueWireTextField];
    if (textWire is! String) {
      return null;
    }
    final text = textWire.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length > rescueStepTextMost) {
      return null;
    }
    final Object? durationWire = stepWire[rescueWireDurationField];
    // An integer, never a double or a numeral-shaped string: a JSON
    // whole number decodes as int in Dart, and anything else is not
    // the contract's integer.
    if (durationWire is! int) {
      return null;
    }
    if (durationWire < rescueStepSecondsLeast ||
        durationWire > rescueStepSecondsMost) {
      return null;
    }
    steps.add((text: text, durationSeconds: durationWire));
  }
  return steps;
}
