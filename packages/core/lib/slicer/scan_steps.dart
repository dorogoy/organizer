/// The scan-steps parse (Story 5.7, FR-16, AD-5): the delivered
/// scan body becomes steps IN CORE — the shell never judges a
/// provider's answer, exactly as it never judges a log record's
/// shape. One function, pure over its input, answers either the
/// parsed slice — the space's description plus its steps — or
/// nothing; the caller folds nothing into `malformedResponse`, the
/// port's own cause for a body that will not yield its slice, the
/// same one-failure fold `rescue_steps.dart` keeps.
///
/// The wire field names below are this library's own statement of
/// the four names the scan prompt pins (`lib/scan/scan_controller.dart`
/// composes the prompt; core cannot import it), and the parity is
/// pinned from the shell side: a test there feeds the prompt's own
/// field names and the Local stub's canned body through this parse,
/// so a drift in either direction fails the gate. The count, minute
/// and text bounds are the prompt's contract — 1–6 steps, each
/// tagged 3–5 minutes — and they are re-enforced here whatever a
/// wire dropped on the way out, restated as the single reader
/// exactly as the rescue parse restates its own. The description
/// bound (`scanDescriptionTextMost`) is this parse's own, on the
/// `rescueStepTextMost` precedent: a wall is refused whole, never
/// trimmed into shape — the Origin Context serves verbatim or the
/// body is not a slice this build would land as work.

library;

import 'dart:convert';

/// The scan contract's least step count (FR-16): a slice below one
/// step is not a slice.
const int scanStepsLeast = 1;

/// The scan contract's most step count (FR-16): the parse's own wall
/// bound — a plan above six steps is a wall, not a first step.
const int scanStepsMost = 6;

/// The scan contract's per-step least duration, in minutes (FR-16).
const int scanStepMinutesLeast = 3;

/// The scan contract's per-step most duration, in minutes (FR-16).
const int scanStepMinutesMost = 5;

/// The per-step least duration in seconds — the least estimate a
/// scan step can mint (`scanStepMinutesLeast × 60`), stated beside
/// the minute bound it derives from so the store's read clamp and
/// the tests read one pair of numbers.
const int scanStepSecondsLeast = scanStepMinutesLeast * 60;

/// The per-step most duration in seconds (`scanStepMinutesMost × 60`)
/// — the most estimate a scan step can mint.
const int scanStepSecondsMost = scanStepMinutesMost * 60;

/// The per-step most text length, in UTF-16 code units, measured on
/// the text AFTER the parse's own trim — never the raw wire string,
/// the `rescueStepTextMost` precedent. The bound is the parse's own
/// (the wire schema carries none) and a step past it refuses the
/// whole body, never trims the words into shape (AD-23's no-repair
/// rule).
const int scanStepTextMost = 160;

/// The description's most text length, in UTF-16 code units,
/// measured after trim — the Origin Context the whole slice shares,
/// bounded once here rather than per step.
const int scanDescriptionTextMost = 400;

/// The description's wire name — the prompt's own field name,
/// parity pinned shell-side.
const String scanWireDescriptionField = 'description';

/// The steps array's wire name.
const String scanWireStepsField = 'steps';

/// The step object's text wire name.
const String scanWireTextField = 'text';

/// The step object's duration wire name.
const String scanWireDurationField = 'duration_minutes';

/// The response-contract sentence every Slicer prompt ends with —
/// the one shared, single-source copy (Story 5.8's review: two
/// hand-maintained copies could drift phrasing — and therefore
/// provider behaviour — on one entrance while every parity pin
/// stayed green). Both the scan prompt and the genesis prompt
/// interpolate this const; the shell-side parity tests pin that
/// they do. Provider-facing instruction prose, never UI copy —
/// the prompt precedent (not ARB, AD-15 never reaches a widget).
const String scanResponseContract =
    'Responde únicamente con un objeto JSON con la forma '
    '"$scanWireDescriptionField": "…", "$scanWireStepsField": '
    '[{"$scanWireTextField": "…", "$scanWireDurationField": 4}]}, '
    'y nada más.';

/// One parsed scan step: its trimmed non-empty text and its verbatim
/// duration in minutes — the text becomes the fact's `stepText`, the
/// minutes its estimate (`minutes × 60`).
typedef ScanStep = ({String text, int durationMinutes});

/// One parsed scan slice: the space's trimmed description — the
/// Origin Context every step fact of the slice carries (FR-16) —
/// plus the steps themselves.
typedef ScanSlice = ({String description, List<ScanStep> steps});

/// Parses [body] against the scan contract: a JSON object holding a
/// non-empty `description` string of at most `scanDescriptionTextMost`
/// code units (measured after trim) and a `steps` array of 1–6
/// objects, each a non-empty `text` string of at most
/// `scanStepTextMost` code units (measured after trim) and an
/// integer `duration_minutes` of 3–5 — the bounds the wires cannot
/// be trusted to have enforced, restated here as the single reader.
/// A body that fails any clause answers null: one failure cause
/// (`malformedResponse`) covers them all, and nothing here repairs,
/// retries or coaxes a near-miss into shape (AD-23's tolerance is
/// for unknown log kinds, never for a slice this build would land
/// as work). Unknown extra keys are carried, not rejected — a
/// provider's dialect may add what it likes around the four names
/// the contract owns, exactly as the log carries an unknown kind.
ScanSlice? parseScanSlice(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on Object {
    // The one-fold contract (Story 5.7): any body that will not yield
    // its slice answers null — non-JSON (FormatException) and a body
    // so deeply nested the decoder overflows its stack
    // (StackOverflowError, an Error) alike; the scan caller's wait
    // has only a finally, so this catch is what keeps the crash off
    // `grantConsent`.
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final Object? descriptionWire = decoded[scanWireDescriptionField];
  if (descriptionWire is! String) {
    return null;
  }
  final description = descriptionWire.trim();
  if (description.isEmpty) {
    return null;
  }
  if (description.length > scanDescriptionTextMost) {
    return null;
  }
  final Object? stepsWire = decoded[scanWireStepsField];
  if (stepsWire is! List ||
      stepsWire.length < scanStepsLeast ||
      stepsWire.length > scanStepsMost) {
    return null;
  }
  final steps = <ScanStep>[];
  for (final Object? stepWire in stepsWire) {
    if (stepWire is! Map) {
      return null;
    }
    final Object? textWire = stepWire[scanWireTextField];
    if (textWire is! String) {
      return null;
    }
    final text = textWire.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.length > scanStepTextMost) {
      return null;
    }
    final Object? durationWire = stepWire[scanWireDurationField];
    // An integer, never a double or a numeral-shaped string: a JSON
    // whole number decodes as int in Dart, and anything else is not
    // the contract's integer.
    if (durationWire is! int) {
      return null;
    }
    if (durationWire < scanStepMinutesLeast ||
        durationWire > scanStepMinutesMost) {
      return null;
    }
    steps.add((text: text, durationMinutes: durationWire));
  }
  return (description: description, steps: steps);
}
