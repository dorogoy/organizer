// The BYOK per-provider wire (Story 4-4): the port of the story 4-1
// harness's candidate adapters (`eval/lib/candidates.dart`) into the
// app's egress chokepoint. Mechanism per provider, code not
// configuration — gemini's generateContent with `x-goog-api-key` and
// a `responseSchema`, OpenAI's chat completions with a Bearer key
// and a strict `json_schema`, Anthropic's messages with `x-api-key`
// and the schema riding a forced tool's `input_schema`, and
// OpenRouter's OpenAI-compatible route with the per-request
// `provider.zdr: true` routing preference (the app's own enforcement
// of the no-training gate OpenRouter was admitted under).
//
// One send per slice, always: this module sends once and classifies
// — no retry, no queue, no metering, no report. Everything is a
// named wire constant on the egress module's terms (AD-15's ban is
// on literals reaching a widget; these never leave the wire).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'egress_payload.dart';
import 'provider_allowlist.dart';
import 'rescue_contract.dart';

/// A non-2xx HTTP status from a provider — the classification
/// evidence `ByokSlicer` maps onto the cause taxonomy (401/403, 429,
/// 5xx). Carries the status and nothing else: the body is not for
/// anyone here to read.
/// The status exception's diagnostic prefix — a named wire
/// identifier (AD-15's ban is on literals reaching a widget).
const String wireStatusMessagePrefix = 'wire status ';

final class WireStatusException implements Exception {
  const WireStatusException(this.statusCode);

  /// The HTTP status the provider answered with.
  final int statusCode;

  @override
  String toString() => wireStatusMessagePrefix + statusCode.toString();
}

// --- Endpoint constants, one per wire kind. --------------------------

/// Gemini's generateContent endpoint prefix; the model id and method
/// suffix compose onto it.
const String geminiModelsUrlPrefix =
    'https://generativelanguage.googleapis.com/v1beta/models/';

/// Gemini's method suffix on the model path.
const String geminiGenerateContentSuffix = ':generateContent';

/// OpenAI's chat completions endpoint.
const String openAiChatCompletionsUrl =
    'https://api.openai.com/v1/chat/completions';

/// Anthropic's messages endpoint.
const String anthropicMessagesUrl = 'https://api.anthropic.com/v1/messages';

/// OpenRouter's OpenAI-compatible chat completions endpoint.
const String openRouterChatCompletionsUrl =
    'https://openrouter.ai/api/v1/chat/completions';

// --- Header vocabulary. ----------------------------------------------

/// The content-type header's name.
const String contentTypeHeader = 'Content-Type';

/// The one content type every wire sends.
const String jsonContentType = 'application/json';

/// The one HTTP method every wire send uses.
const String wirePostMethod = 'POST';

/// Gemini's key header.
const String xGoogApiKeyHeader = 'x-goog-api-key';

/// The bearer-token header's name (OpenAI, OpenRouter).
const String authorizationHeader = 'Authorization';

/// The bearer scheme's prefix, joined to the key by a single space.
const String bearerSchemePrefix = 'Bearer ';

/// Anthropic's key header.
const String xApiKeyHeader = 'x-api-key';

/// Anthropic's version header's name.
const String anthropicVersionHeader = 'anthropic-version';

/// The Anthropic API version this wire speaks.
const String anthropicVersionValue = '2023-06-01';

// --- Request-body vocabulary. -----------------------------------------

/// The model key (OpenAI-, Anthropic- and OpenRouter-shaped bodies).
const String modelKey = 'model';

/// Gemini's contents field.
const String contentsKey = 'contents';

/// The role field of a chat message, every wire.
const String roleKey = 'role';

/// The messages key (all chat-shaped bodies).
const String messagesKey = 'messages';

/// The user role's value.
const String userRoleValue = 'user';

/// The content key, both as a message field and as a response field.
const String contentKey = 'content';

/// The discriminating type key of part objects and tool choices.
const String typeKey = 'type';

/// A text part's type value.
const String textTypeValue = 'text';

/// A text part's (and gemini part's) text field.
const String textKey = 'text';

/// Gemini generateContent's inline image part field — mime type and
/// bytes nest under this key; the part has no `type` discriminator.
const String inlineDataTypeValue = 'inline_data';

/// Gemini's inline image part's mime-type field.
const String inlineMimeTypeKey = 'mime_type';

/// Gemini's inline image part's data field.
const String inlineDataKey = 'data';

/// OpenAI's image part's type value.
const String imageUrlTypeValue = 'image_url';

/// OpenAI's image part's field.
const String imageUrlKey = 'image_url';

/// OpenAI's image part's URL field — a data URI at runtime.
const String imageUrlUrlKey = 'url';

/// The data-URI scheme prefix.
const String dataUriSchemePrefix = 'data:';

/// The data-URI base64 middle, between mime type and payload.
const String dataUriBase64Middle = ';base64,';

/// Anthropic's image part's type value.
const String imageTypeValue = 'image';

/// Anthropic's image part's source field.
const String sourceKey = 'source';

/// Anthropic's base64 source's type value.
const String base64TypeValue = 'base64';

/// Anthropic's base64 source's data field.
const String dataKey = 'data';

/// Anthropic's base64 source's media-type field.
const String mediaTypeKey = 'media_type';

/// Gemini's generation-config field.
const String generationConfigKey = 'generationConfig';

/// Gemini's JSON response mime type field.
const String responseMimeTypeKey = 'responseMimeType';

/// Gemini's structured-output schema field.
const String responseSchemaKey = 'responseSchema';

/// The JSON mime type as a value.
const String applicationJsonValue = 'application/json';

/// The response-format field (OpenAI- and OpenRouter-shaped bodies).
const String responseFormatKey = 'response_format';

/// The strict json_schema's type value.
const String jsonSchemaTypeValue = 'json_schema';

/// The nested json_schema field.
const String jsonSchemaKey = 'json_schema';

/// The schema's name field.
const String schemaNameKey = 'name';

/// The strictness flag's field.
const String strictKey = 'strict';

/// The embedded schema's field.
const String schemaKey = 'schema';

/// The strict wires' completion-token ceiling, the harness's own.
const int wireMaxCompletionTokens = 2048;

/// Anthropic's token ceiling field.
const String maxTokensKey = 'max_tokens';

/// The strict wires' completion-token ceiling field.
const String maxCompletionTokensKey = 'max_completion_tokens';

/// Anthropic's tools field.
const String toolsKey = 'tools';

/// Anthropic's tool description field.
const String descriptionKey = 'description';

/// Anthropic's tool input-schema field.
const String inputSchemaKey = 'input_schema';

/// Anthropic's forced-tool choice field.
const String toolChoiceKey = 'tool_choice';

/// A forced tool choice's type value.
const String toolTypeValue = 'tool';

/// The name a forced tool choice carries.
const String nameKey = 'name';

/// The slice-plan schema's name, shared by the strict wires.
const String slicePlanSchemaName = 'slice_plan';

/// Anthropic's emit-tool's name, verbatim from the harness.
const String emitSlicePlanToolName = 'emit_slice_plan';

/// Anthropic's emit-tool's description, verbatim from the harness.
const String emitSlicePlanToolDescription =
    'Emite el plan de pasos como JSON estructurado.';

/// OpenRouter's routing-preference field.
const String providerRoutingKey = 'provider';

/// OpenRouter's zero-data-retention routing flag.
const String zdrRoutingKey = 'zdr';

// --- Response-body vocabulary. -----------------------------------------

/// OpenAI's choices field.
const String choicesKey = 'choices';

/// OpenAI's message field inside a choice.
const String messageKey = 'message';

/// Gemini's candidates field.
const String candidatesKey = 'candidates';

/// Gemini's parts field inside a candidate's content.
const String partsKey = 'parts';

/// Anthropic's tool_use block's type value.
const String toolUseTypeValue = 'tool_use';

/// Anthropic's tool_use block's input field — already decoded JSON.
const String inputKey = 'input';

// --- The mime sniffing for scan payloads. ------------------------------

/// The JPEG mime type.
const String imageJpegMimeType = 'image/jpeg';

/// The PNG mime type.
const String imagePngMimeType = 'image/png';

/// The two image mime types the egress cap can emit, sniffed from
/// the bytes' magic numbers — the cap re-encodes to JPEG and keeps
/// PNG as PNG, so every scan payload that reaches the wire carries
/// one of the two.
String imageMimeTypeOf(Uint8List bytes) {
  if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return imageJpegMimeType;
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return imagePngMimeType;
  }
  return imageJpegMimeType;
}

/// The per-send stall bound: one value for every wire, a bound on
/// the pathological (a provider that accepts the connection and
/// never answers), never a latency target — the measured sends run
/// far under it. Elapsing classifies as `providerUnreachable`: the
/// provider never delivered an answer, and no retry follows (one
/// attempt per slice, always).
const Duration wireSendTimeout = Duration(minutes: 2);

/// Sends one slice request over [entry]'s wire: builds the URL,
/// headers and body per the entry's kind, POSTs exactly once under
/// [wireSendTimeout], and returns the 2xx response body as text. The
/// POST does not follow redirects (a 3xx is status evidence, never a
/// second host) and a stall completes the abort trigger so the
/// in-flight send does not outlive the bound. A non-2xx status
/// throws [WireStatusException] (the classification evidence); a
/// stall throws `TimeoutException`; socket-level failures propagate
/// as themselves — all three for the same reason: the classifier
/// reads the evidence. A 2xx body that is not valid UTF-8 throws
/// `FormatException` — the delivered-but-unusable evidence,
/// `malformedResponse` by the taxonomy's own definition. The schema
/// is the request's structured-output contract — the rescue contract
/// for rescue payloads; scan and genesis ride their prompts
/// verbatim with no schema until Epic 5 authors their contracts.
Future<String> sendSlicerWire({
  required http.Client client,
  required ProviderAllowlistEntry entry,
  required String apiKey,
  required EgressPayload payload,
}) async {
  final prompt = _promptOf(payload);
  final schema = payload is RescueResliceText ? rescueSliceSchemaJson : null;
  final abort = Completer<void>();
  final request =
      http.AbortableRequest(
          wirePostMethod,
          _urlFor(entry),
          abortTrigger: abort.future,
        )
        ..followRedirects = false
        ..headers.addAll(_headersFor(entry, apiKey))
        ..body = jsonEncode(
          _bodyFor(
            entry: entry,
            payload: payload,
            prompt: prompt,
            schema: schema,
          ),
        );
  try {
    final response = await _postOnce(client, request).timeout(wireSendTimeout);
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw WireStatusException(status);
    }
    return utf8.decode(response.bodyBytes);
  } on TimeoutException {
    if (!abort.isCompleted) {
      abort.complete();
    }
    rethrow;
  }
}

/// One POST through [client.send], then the full body — the timeout
/// wraps this whole round trip so a stall on either half is one bound.
Future<http.Response> _postOnce(
  http.Client client,
  http.BaseRequest request,
) async {
  final streamed = await client.send(request);
  return http.Response.fromStream(streamed);
}

/// Extracts the provider's slice text from a delivered response
/// body, or null when the body will not yield one — the
/// `malformedResponse` evidence. Per wire: OpenAI-shaped bodies
/// carry it as a choices[0].message.content string, Gemini as the
/// joined text parts of candidates[0].content, Anthropic as the
/// forced tool's decoded input (re-encoded here so every wire's
/// slice text is a JSON string).
String? extractSliceText({
  required SlicerWireKind wireKind,
  required String responseBody,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseBody);
  } on FormatException {
    return null;
  }
  return switch (wireKind) {
    SlicerWireKind.openAiChat => _extractChatContent(decoded),
    SlicerWireKind.openRouterChat => _extractChatContent(decoded),
    SlicerWireKind.geminiNative => _extractGeminiText(decoded),
    SlicerWireKind.anthropicMessages => _extractAnthropicToolInput(decoded),
  };
}

Uri _urlFor(ProviderAllowlistEntry entry) => switch (entry.wireKind) {
  SlicerWireKind.geminiNative => Uri.parse(
    geminiModelsUrlPrefix + entry.modelId + geminiGenerateContentSuffix,
  ),
  SlicerWireKind.openAiChat => Uri.parse(openAiChatCompletionsUrl),
  SlicerWireKind.anthropicMessages => Uri.parse(anthropicMessagesUrl),
  SlicerWireKind.openRouterChat => Uri.parse(openRouterChatCompletionsUrl),
};

Map<String, String> _headersFor(ProviderAllowlistEntry entry, String apiKey) {
  final headers = <String, String>{contentTypeHeader: jsonContentType};
  switch (entry.wireKind) {
    case SlicerWireKind.geminiNative:
      headers[xGoogApiKeyHeader] = apiKey;
    case SlicerWireKind.openAiChat:
    case SlicerWireKind.openRouterChat:
      headers[authorizationHeader] = bearerSchemePrefix + apiKey;
    case SlicerWireKind.anthropicMessages:
      headers[xApiKeyHeader] = apiKey;
      headers[anthropicVersionHeader] = anthropicVersionValue;
  }
  return headers;
}

Map<String, Object?> _bodyFor({
  required ProviderAllowlistEntry entry,
  required EgressPayload payload,
  required String prompt,
  required String? schema,
}) => switch (entry.wireKind) {
  SlicerWireKind.geminiNative => _geminiBody(payload, prompt, schema),
  SlicerWireKind.openAiChat => _chatBody(
    modelId: entry.modelId,
    payload: payload,
    prompt: prompt,
    schema: schema,
    zdr: false,
    tokenCeilingKey: maxCompletionTokensKey,
  ),
  SlicerWireKind.anthropicMessages => _anthropicBody(
    entry,
    payload,
    prompt,
    schema,
  ),
  SlicerWireKind.openRouterChat => _chatBody(
    modelId: entry.modelId,
    payload: payload,
    prompt: prompt,
    schema: schema,
    zdr: true,
    // OpenRouter's OpenAI-compatible endpoint documents `max_tokens`
    // as its ceiling parameter — OpenAI-direct's newer
    // `max_completion_tokens` stays on the OpenAI wire alone.
    tokenCeilingKey: maxTokensKey,
  ),
};

/// The prompt a payload rides on the wire: scan and genesis
/// verbatim (Epic 5 authors that copy), rescue composed from the
/// access layer's own contract.
String _promptOf(EgressPayload payload) => switch (payload) {
  ScanImagePrompt(:final prompt) => prompt,
  ProjectGenesisText(:final text) => text,
  RescueResliceText(:final originContext, :final task) => rescuePromptFor(
    originContext,
    task,
  ),
};

Map<String, Object?> _geminiBody(
  EgressPayload payload,
  String prompt,
  String? schema,
) => <String, Object?>{
  contentsKey: [
    {
      roleKey: userRoleValue,
      partsKey: [
        {textKey: prompt},
        if (payload is ScanImagePrompt)
          {
            inlineDataTypeValue: {
              inlineMimeTypeKey: imageMimeTypeOf(payload.imageBytes),
              inlineDataKey: base64Encode(payload.imageBytes),
            },
          },
      ],
    },
  ],
  // The JSON response mode and the schema ride together, or neither
  // does: forcing `responseMimeType: application/json` on a
  // schema-less payload (scan/genesis before Epic 5 authors their
  // contracts) would coerce a prose answer into JSON mode while the
  // OpenAI-shaped wires send no response format at all — a
  // schema-less gemini call stays a plain generateContent request,
  // its prompt verbatim.
  if (schema != null)
    generationConfigKey: {
      responseMimeTypeKey: applicationJsonValue,
      responseSchemaKey: geminiSchemaFrom(schema),
    },
};

/// Maps the canonical schema onto Gemini's `responseSchema` dialect
/// (OpenAPI-style uppercase types, no `additionalProperties`) — the
/// harness's own converter, ported.
Map<String, Object?> geminiSchemaFrom(String schemaJson) {
  final decoded = jsonDecode(schemaJson);
  if (decoded is! Map) {
    throw StateError(canonicalSchemaObjectFailure);
  }
  return _toGeminiSchema(decoded);
}

Map<String, Object?> _toGeminiSchema(Map source) {
  // Reads walk the canonical schema (schemaTypeKey, the schema's own
  // vocabulary); writes speak Gemini's dialect (typeKey), where the
  // field happens to share the name.
  final type = source[schemaTypeKey];
  if (type is! String) {
    throw StateError(canonicalSchemaPropertyWithoutTypeFailure);
  }
  final out = <String, Object?>{typeKey: type.toUpperCase()};
  final properties = source[propertiesKey];
  if (properties is Map) {
    final translated = <String, Object?>{};
    for (final entry in properties.entries) {
      if (entry.value is! Map) {
        // A property that is not a schema object is a wire bug, not
        // a field to drop silently — the translation must stay
        // total or the dialect quietly under-constrains the answer.
        throw StateError(canonicalSchemaPropertyNotObjectFailure);
      }
      translated[entry.key as String] = _toGeminiSchema(entry.value as Map);
    }
    out[propertiesKey] = translated;
  }
  final required = source[requiredKey];
  if (required is List && required.isNotEmpty) {
    out[requiredKey] = required;
  }
  final items = source[itemsKey];
  if (items is Map) {
    out[itemsKey] = _toGeminiSchema(items);
  }
  return out;
}

// The canonical-schema walk's shared vocabulary and failure
// diagnostics live at the schema's own home, rescue_contract.dart —
// this converter imports them from there. The dialect's deliberate
// omissions, stated once here: everything the Gemini
// structured-output subset does not carry is dropped —
// `additionalProperties`, `minItems`/`maxItems`,
// `minimum`/`maximum` — because a bound Gemini cannot enforce would
// be a lie in the request. The canonical bounds stay in the strict
// wires (OpenAI's, OpenRouter's, Anthropic's tool input_schema) and
// are re-enforced downstream by 4-6's parse of the delivered text.

Map<String, Object?> _chatBody({
  required String modelId,
  required EgressPayload payload,
  required String prompt,
  required String? schema,
  required bool zdr,
  required String tokenCeilingKey,
}) => <String, Object?>{
  modelKey: modelId,
  messagesKey: [
    {
      roleKey: userRoleValue,
      contentKey: [
        {typeKey: textTypeValue, textKey: prompt},
        if (payload is ScanImagePrompt)
          {
            typeKey: imageUrlTypeValue,
            imageUrlKey: {
              imageUrlUrlKey:
                  dataUriSchemePrefix +
                  imageMimeTypeOf(payload.imageBytes) +
                  dataUriBase64Middle +
                  base64Encode(payload.imageBytes),
            },
          },
      ],
    },
  ],
  if (schema != null)
    responseFormatKey: {
      typeKey: jsonSchemaTypeValue,
      jsonSchemaKey: {
        schemaNameKey: slicePlanSchemaName,
        strictKey: true,
        schemaKey: jsonDecode(schema),
      },
    },
  tokenCeilingKey: wireMaxCompletionTokens,
  if (zdr) providerRoutingKey: {zdrRoutingKey: true},
};

Map<String, Object?> _anthropicBody(
  ProviderAllowlistEntry entry,
  EgressPayload payload,
  String prompt,
  String? schema,
) => <String, Object?>{
  modelKey: entry.modelId,
  maxTokensKey: wireMaxCompletionTokens,
  messagesKey: [
    {
      roleKey: userRoleValue,
      contentKey: [
        if (payload is ScanImagePrompt)
          {
            typeKey: imageTypeValue,
            sourceKey: {
              typeKey: base64TypeValue,
              mediaTypeKey: imageMimeTypeOf(payload.imageBytes),
              dataKey: base64Encode(payload.imageBytes),
            },
          },
        {typeKey: textTypeValue, textKey: prompt},
      ],
    },
  ],
  // The schema rides a forced tool; with no authored contract yet
  // (scan/genesis before Epic 5) the call stays a plain messages
  // request — no tool to force, nothing invented here.
  if (schema != null) ...{
    toolsKey: [
      {
        nameKey: emitSlicePlanToolName,
        descriptionKey: emitSlicePlanToolDescription,
        inputSchemaKey: jsonDecode(schema),
      },
    ],
    toolChoiceKey: {typeKey: toolTypeValue, nameKey: emitSlicePlanToolName},
  },
};

String? _extractChatContent(Object? decoded) {
  if (decoded is! Map) {
    return null;
  }
  final choices = decoded[choicesKey];
  if (choices is List && choices.isNotEmpty) {
    final first = choices.first;
    if (first is Map) {
      final message = first[messageKey];
      if (message is Map) {
        final content = message[contentKey];
        if (content is String && content.isNotEmpty) {
          return content;
        }
      }
    }
  }
  return null;
}

String? _extractGeminiText(Object? decoded) {
  if (decoded is! Map) {
    return null;
  }
  final candidates = decoded[candidatesKey];
  if (candidates is List && candidates.isNotEmpty) {
    final first = candidates.first;
    if (first is Map) {
      final content = first[contentKey];
      if (content is Map) {
        final parts = content[partsKey];
        if (parts is List) {
          final text = parts
              .whereType<Map>()
              .map((part) => part[textKey])
              .whereType<String>()
              .join();
          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }
  }
  return null;
}

String? _extractAnthropicToolInput(Object? decoded) {
  if (decoded is! Map) {
    return null;
  }
  final content = decoded[contentKey];
  if (content is List) {
    for (final block in content) {
      if (block is Map &&
          block[typeKey] == toolUseTypeValue &&
          block[nameKey] == emitSlicePlanToolName) {
        final input = block[inputKey];
        if (input != null) {
          return jsonEncode(input);
        }
      }
    }
    // No forced-tool answer — the schema-less shapes (scan/genesis
    // before Epic 5 authors their contracts) answer as plain text
    // blocks, and those carry the slice text verbatim. The tool_use
    // half above stays preferred: a forced tool's decoded input is
    // the structured contract's own answer.
    for (final block in content) {
      if (block is Map && block[typeKey] == textTypeValue) {
        final text = block[textKey];
        if (text is String && text.isNotEmpty) {
          return text;
        }
      }
    }
  }
  return null;
}
