// The rescue contract (Story 4-4, FR-5): the one live runtime
// contract this story ships — the Spanish prompt a rescue re-slice
// rides, and the structured-output schema the answer is pinned to.
// Distinct from the eval harness's photo schema by design: a rescue
// asks for 2–4 steps of at most 60 seconds each (the runtime
// contract 4-6 weaves), never the 3–5-minute photo plan 4-1 scored.
//
// The canonical schema constant is the single source of the wire's
// field names: everything downstream that needs them — the prompt's
// JSON-shape example, the Local stub's canned body, the tests'
// assertions — derives them from [rescueSchemaFieldNames], a parse
// of the canonical JSON, so no copy can drift from the contract.
//
// Infrastructure constants on the egress module's terms (AD-15's
// ban is on literals reaching a widget): provider-facing protocol
// copy, never user copy. Genesis and scan prompts ride their
// payloads verbatim (Epic 5 authors that copy at minting); only
// rescue composes its prompt in the access layer.
import 'dart:convert';

/// The rescue prompt's fixed head: the whole instruction set — step
/// count, per-step ceiling, real actions, JSON-only — up to the
/// JSON-shape example, which is derived from the canonical schema
/// so the named fields cannot drift from the contract.
const String rescuePromptHead =
    'Una tarea de casa se ha atascado. Divídela en 2 a 4 pasos: acciones reales y concretas que se hagan en esa casa, cada una de 60 segundos o menos, en un orden que funcione. Responde solo con un objeto JSON con la forma ';

/// What follows the derived JSON-shape example: the no-prose-around
/// instruction and the origin context's lead-in.
const String rescuePromptAfterShape =
    ' y nada más alrededor. El contexto del origen es: ';

/// The lead-in to the task slot, after the origin context.
const String rescuePromptTaskLead = '. La tarea atascada es: ';

/// The prompt's tail, after the task.
const String rescuePromptTail = '.';

// The derived example's punctuation pieces — the skeleton around the
// schema-derived field names, spelled once each.
const String rescueExampleShapeOpen = '{"';
const String rescueExampleStepsToText = '":[{"';
const String rescueExampleTextToDuration = '":"...","';
const String rescueExampleDurationClose = '":...}]}';

/// Composes the rescue prompt from the request's two facts. The
/// fixed pieces are constants, the JSON-shape example is derived
/// from the canonical schema, and the composition is plain
/// concatenation — no template engine, no formatting vocabulary,
/// nothing the caller can reshape.
String rescuePromptFor(String originContext, String task) =>
    rescuePromptHead +
    _rescueShapeExample() +
    rescuePromptAfterShape +
    originContext +
    rescuePromptTaskLead +
    task +
    rescuePromptTail;

/// The canonical schema's own field names, parsed — the single
/// source every restatement downstream derives from.
String _rescueShapeExample() {
  final names = rescueSchemaFieldNames();
  return rescueExampleShapeOpen +
      names.steps +
      rescueExampleStepsToText +
      names.text +
      rescueExampleTextToDuration +
      names.durationSeconds +
      rescueExampleDurationClose;
}

/// The rescue schema as canonical JSON: `steps` of 2 to 4 objects,
/// each a `text` string and a `duration_seconds` integer of 1 to
/// 60, nothing else. The per-provider wires map this canonical form
/// onto their own structured-output dialects (Gemini's uppercase
/// responseSchema, OpenAI's strict json_schema, Anthropic's tool
/// input_schema); OpenRouter takes OpenAI's dialect as-is.
const String rescueSliceSchemaJson =
    '{"type":"object","properties":{"steps":{"type":"array","minItems":2,"maxItems":4,"items":{"type":"object","properties":{"text":{"type":"string"},"duration_seconds":{"type":"integer","minimum":1,"maximum":60}},"required":["text","duration_seconds"],"additionalProperties":false}}},"required":["steps"],"additionalProperties":false}';

// --- The canonical schema's own walk vocabulary, stated at the
// --- schema's home so the wires and this file share one copy.

/// The canonical schema's properties field.
const String propertiesKey = 'properties';

/// The canonical schema's required field.
const String requiredKey = 'required';

/// The canonical schema's items field.
const String itemsKey = 'items';

/// The canonical schema's type field.
const String schemaTypeKey = 'type';

/// The canonical schema's string type value — the step text's type.
const String schemaStringTypeValue = 'string';

/// The canonical-schema walk's shape-failure diagnostics — named
/// identifiers on the egress module's terms (AD-15's ban is on
/// literals reaching a widget), shared by every walk of the schema
/// (this file's field-name parse, the Gemini dialect converter).
const String canonicalSchemaObjectFailure =
    'canonical schema is not a JSON object — wire bug';
const String canonicalSchemaPropertyWithoutTypeFailure =
    'canonical schema property without a type — wire bug';
const String canonicalSchemaPropertyNotObjectFailure =
    'canonical schema property is not an object — wire bug';

/// The rescue schema's field names, parsed from the canonical JSON:
/// the steps array's name (the single required top-level property),
/// and the step object's text and duration field names (the
/// string-typed property and the other one). A canonical schema
/// that will not yield all three is a wire bug and throws
/// [StateError] — the contract is a constant, so a throw here is a
/// build-time authoring error, never a runtime surprise.
({String steps, String text, String durationSeconds}) rescueSchemaFieldNames() {
  final decoded = jsonDecode(rescueSliceSchemaJson);
  if (decoded is! Map) {
    throw StateError(canonicalSchemaObjectFailure);
  }
  final required = decoded[requiredKey];
  if (required is! List || required.length != 1) {
    throw StateError(canonicalSchemaPropertyWithoutTypeFailure);
  }
  final steps = required.single;
  if (steps is! String) {
    throw StateError(canonicalSchemaPropertyWithoutTypeFailure);
  }
  final properties = decoded[propertiesKey];
  if (properties is! Map) {
    throw StateError(canonicalSchemaPropertyNotObjectFailure);
  }
  final stepsShape = properties[steps];
  if (stepsShape is! Map) {
    throw StateError(canonicalSchemaPropertyNotObjectFailure);
  }
  final items = stepsShape[itemsKey];
  if (items is! Map) {
    throw StateError(canonicalSchemaPropertyNotObjectFailure);
  }
  final itemProperties = items[propertiesKey];
  if (itemProperties is! Map || itemProperties.length != 2) {
    throw StateError(canonicalSchemaPropertyNotObjectFailure);
  }
  String? text;
  String? durationSeconds;
  itemProperties.forEach((name, shape) {
    if (shape is! Map) {
      throw StateError(canonicalSchemaPropertyNotObjectFailure);
    }
    if (shape[schemaTypeKey] == schemaStringTypeValue) {
      text = name as String;
    } else {
      durationSeconds = name as String;
    }
  });
  final textName = text;
  final durationName = durationSeconds;
  if (textName == null || durationName == null) {
    throw StateError(canonicalSchemaPropertyWithoutTypeFailure);
  }
  return (steps: steps, text: textName, durationSeconds: durationName);
}
