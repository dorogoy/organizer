/// The five candidate adapters (story 4.1).
///
/// Each adapter maps the canonical prompt + schema + photo onto its provider's
/// native request/response shape and makes exactly ONE request per photo —
/// the harness has no retry anywhere, so a network error or a non-200 status
/// is a failed photo, same as a parse failure. The mechanism mapping is code
/// per candidate, not configuration: OpenAI-compatible chat completions with
/// base64 image parts for the local pair (Lemonade), OpenAI structured
/// outputs (`json_schema`, strict), Gemini `generateContent` with a
/// `responseSchema`, and an Anthropic messages call whose schema rides a
/// tool. Keys reach cloud candidates through environment variables only.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// One HTTP round trip. Injectable so the unit tests can count calls and
/// fake payloads; the default is a plain `http.post` with no retry.
typedef Transport = Future<http.Response> Function(
  Uri url,
  Map<String, String> headers,
  String bodyJson,
);

Future<http.Response> defaultTransport(
  Uri url,
  Map<String, String> headers,
  String bodyJson,
) => http.post(url, headers: headers, body: bodyJson);

/// A transport failure — network error, HTTP non-200, non-JSON body. Fails
/// the photo; never retried.
final class HarnessTransportException implements Exception {
  HarnessTransportException(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// What an adapter extracted from a 200 response, before any limb judgement.
sealed class ModelOutput {
  const ModelOutput();
}

/// The provider answered JSON-as-text: the first-attempt `jsonDecode` of this
/// string is the parse limb — no fence-stripping, no repair.
final class TextOutput extends ModelOutput {
  const TextOutput(this.text);
  final String text;
}

/// The provider answered structured JSON natively (Anthropic `tool_use.input`
/// arrives already decoded in the response body).
final class DecodedOutput extends ModelOutput {
  const DecodedOutput(this.value);
  final Object? value;
}

/// The provider answered 200 but with nothing extractable — a parse-limb
/// failure carrying the recorded reason.
final class OutputAbsent extends ModelOutput {
  const OutputAbsent(this.reason);
  final String reason;
}

/// A reply: the extracted output plus the raw evidence the results directory
/// records (endpoint and verbatim body; both live under gitignored
/// `eval/results/raw/`).
final class CandidateReply {
  const CandidateReply({
    required this.output,
    required this.endpoint,
    required this.rawBody,
  });
  final ModelOutput output;
  final Uri endpoint;
  final String rawBody;
}

/// Static registry entry for one candidate.
final class CandidateSpec {
  const CandidateSpec({
    required this.id,
    required this.local,
    this.envKey,
    required this.defaultModel,
    this.defaultBaseUrl,
  });

  final String id;
  final bool local;
  final String? envKey;
  final String defaultModel;
  final String? defaultBaseUrl;
}

/// Lemonade's default OpenAI-compatible endpoint (overridable by flag).
const lemonadeDefaultBaseUrl = 'http://localhost:13305/api/v1';

const candidateSpecs = <CandidateSpec>[
  CandidateSpec(
    id: 'e2b_local',
    local: true,
    defaultModel: 'gemma4-it-e2b-FLM',
    defaultBaseUrl: lemonadeDefaultBaseUrl,
  ),
  CandidateSpec(
    id: 'e4b_local',
    local: true,
    defaultModel: 'gemma4-it-e4b-FLM',
    defaultBaseUrl: lemonadeDefaultBaseUrl,
  ),
  CandidateSpec(
    id: 'gemini',
    local: false,
    envKey: 'EVAL_GEMINI_API_KEY',
    defaultModel: 'gemini-2.5-flash',
  ),
  CandidateSpec(
    id: 'openai',
    local: false,
    envKey: 'EVAL_OPENAI_API_KEY',
    defaultModel: 'gpt-5-mini',
  ),
  CandidateSpec(
    id: 'anthropic',
    local: false,
    envKey: 'EVAL_ANTHROPIC_API_KEY',
    defaultModel: 'claude-sonnet-4-5',
  ),
];

/// The canonical order of the cloud trio — also the tie-break order when two
/// cloud candidates share the best score.
const cloudCascadeOrder = ['gemini', 'openai', 'anthropic'];

CandidateSpec specFor(String id) {
  for (final spec in candidateSpecs) {
    if (spec.id == id) return spec;
  }
  throw ArgumentError(
    'unknown candidate "$id" — allowed: ${candidateSpecs.map((s) => s.id).join(', ')}',
  );
}

abstract interface class Candidate {
  String get id;
  String get model;

  /// Sends exactly one request for one photo.
  Future<CandidateReply> requestSlicePlan({
    required String prompt,
    required String schemaJson,
    required Uint8List imageBytes,
    required String imageMimeType,
  });
}

/// Builds a candidate from a spec plus optional flag overrides. Cloud
/// candidates require their environment key here — the caller resolves it
/// and refuses (exit 2) when missing.
Candidate buildCandidate({
  required String id,
  String? baseUrl,
  String? model,
  String? apiKey,
  Transport? transport,
}) {
  final spec = specFor(id);
  final theModel = model ?? spec.defaultModel;
  final theTransport = transport ?? defaultTransport;
  if (spec.local) {
    return ChatCompletionsCandidate.openAiCompatible(
      id: id,
      baseUrl: baseUrl ?? spec.defaultBaseUrl ?? lemonadeDefaultBaseUrl,
      model: theModel,
      transport: theTransport,
    );
  }
  if (apiKey == null || apiKey.isEmpty) {
    throw StateError(
      '${spec.envKey} is not set — cloud candidates take their key from the environment only',
    );
  }
  return switch (id) {
    'gemini' => GeminiCandidate(
      model: theModel,
      apiKey: apiKey,
      transport: theTransport,
    ),
    'openai' => ChatCompletionsCandidate.openAiCloud(
      apiKey: apiKey,
      model: theModel,
      transport: theTransport,
    ),
    'anthropic' => AnthropicCandidate(
      model: theModel,
      apiKey: apiKey,
      transport: theTransport,
    ),
    _ => throw ArgumentError('unknown cloud candidate "$id"'),
  };
}

/// One POST round trip through the injectable transport; wraps every failure
/// mode into [HarnessTransportException] so a photo fails once, with a
/// reason, and nothing retries.
Future<http.Response> postJson(
  Transport transport,
  Uri url,
  Map<String, String> headers,
  Map<String, Object?> body,
) async {
  final bodyJson = jsonEncode(body);
  http.Response response;
  try {
    response = await transport(url, headers, bodyJson);
  } on HarnessTransportException {
    rethrow;
  } on Exception catch (e) {
    throw HarnessTransportException('network error: $e');
  }
  if (response.statusCode != 200) {
    throw HarnessTransportException(
      'HTTP ${response.statusCode}: ${_snippet(response.body)}',
    );
  }
  return response;
}

String _snippet(String body) {
  const max = 300;
  final compact = body.replaceAll('\n', ' ').replaceAll('\r', '');
  return compact.length <= max ? compact : '${compact.substring(0, max)}…';
}

Object? decodeJsonBody(http.Response response) {
  try {
    return jsonDecode(utf8.decode(response.bodyBytes));
  } on FormatException catch (e) {
    throw HarnessTransportException('response body is not JSON: $e');
  }
}

/// Chat completions shape shared by the local pair (Lemonade,
/// OpenAI-compatible, `json_object` response format) and the OpenAI cloud
/// candidate (structured outputs: `json_schema`, strict).
class ChatCompletionsCandidate implements Candidate {
  ChatCompletionsCandidate.openAiCompatible({
    required this.id,
    required this.baseUrl,
    required this.model,
    required this.transport,
  }) : apiKey = null,
       strict = false;

  ChatCompletionsCandidate.openAiCloud({
    required this.apiKey,
    required this.model,
    required this.transport,
  }) : id = 'openai',
       baseUrl = 'https://api.openai.com/v1',
       strict = true;

  final String baseUrl;
  final String? apiKey;
  final bool strict;
  final Transport transport;

  @override
  final String id;

  @override
  final String model;

  @override
  Future<CandidateReply> requestSlicePlan({
    required String prompt,
    required String schemaJson,
    required Uint8List imageBytes,
    required String imageMimeType,
  }) async {
    final responseFormat = strict
        ? {
            'type': 'json_schema',
            'json_schema': {
              'name': 'slice_plan',
              'strict': true,
              'schema': jsonDecode(schemaJson),
            },
          }
        : {'type': 'json_object'};
    final body = <String, Object?>{
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:$imageMimeType;base64,${base64Encode(imageBytes)}',
              },
            },
          ],
        },
      ],
      'response_format': responseFormat,
      if (strict) 'max_completion_tokens': 2048 else 'max_tokens': 2048,
    };
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiKey != null) 'Authorization': 'Bearer $apiKey',
    };
    final url = Uri.parse('$baseUrl/chat/completions');
    final response = await postJson(transport, url, headers, body);
    return CandidateReply(
      output: extractOpenAiContent(decodeJsonBody(response)),
      endpoint: url,
      rawBody: utf8.decode(response.bodyBytes),
    );
  }
}

ModelOutput extractOpenAiContent(Object? decoded) {
  if (decoded is! Map) {
    return OutputAbsent('response is not a JSON object');
  }
  final choices = decoded['choices'];
  if (choices is List && choices.isNotEmpty) {
    final first = choices.first;
    if (first is Map) {
      final message = first['message'];
      if (message is Map) {
        final content = message['content'];
        if (content is String && content.isNotEmpty) {
          return TextOutput(content);
        }
        return OutputAbsent(
          'choices[0].message.content is not a non-empty string',
        );
      }
      return OutputAbsent('choices[0].message is not an object');
    }
    return OutputAbsent('choices[0] is not an object');
  }
  return OutputAbsent('no choices[0] in response');
}

class GeminiCandidate implements Candidate {
  GeminiCandidate({
    required this.model,
    required this.apiKey,
    required this.transport,
  });

  @override
  String get id => 'gemini';

  @override
  final String model;

  final String apiKey;
  final Transport transport;

  @override
  Future<CandidateReply> requestSlicePlan({
    required String prompt,
    required String schemaJson,
    required Uint8List imageBytes,
    required String imageMimeType,
  }) async {
    final body = <String, Object?>{
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': imageMimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': geminiSchemaFrom(schemaJson),
      },
    };
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );
    final response = await postJson(transport, url, {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    }, body);
    return CandidateReply(
      output: extractGeminiText(decodeJsonBody(response)),
      endpoint: url,
      rawBody: utf8.decode(response.bodyBytes),
    );
  }
}

/// Maps the canonical schema onto Gemini's `responseSchema` dialect
/// (OpenAPI-style uppercase types, no `additionalProperties`).
Map<String, Object?> geminiSchemaFrom(String schemaJson) {
  final decoded = jsonDecode(schemaJson);
  if (decoded is! Map) {
    throw StateError('canonical schema is not a JSON object — harness bug');
  }
  return _toGeminiSchema(decoded);
}

Map<String, Object?> _toGeminiSchema(Map source) {
  final type = source['type'];
  if (type is! String) {
    throw StateError('canonical schema property without a type — harness bug');
  }
  final out = <String, Object?>{'type': type.toUpperCase()};
  final properties = source['properties'];
  if (properties is Map) {
    out['properties'] = {
      for (final entry in properties.entries)
        if (entry.value is Map)
          entry.key as String: _toGeminiSchema(entry.value as Map),
    };
  }
  final required = source['required'];
  if (required is List && required.isNotEmpty) {
    out['required'] = required;
  }
  final items = source['items'];
  if (items is Map) {
    out['items'] = _toGeminiSchema(items);
  }
  return out;
}

ModelOutput extractGeminiText(Object? decoded) {
  if (decoded is! Map) {
    return OutputAbsent('response is not a JSON object');
  }
  final candidates = decoded['candidates'];
  if (candidates is List && candidates.isNotEmpty) {
    final first = candidates.first;
    if (first is Map) {
      final content = first['content'];
      if (content is Map) {
        final parts = content['parts'];
        if (parts is List) {
          final text = parts
              .whereType<Map>()
              .map((part) => part['text'])
              .whereType<String>()
              .join();
          if (text.isNotEmpty) {
            return TextOutput(text);
          }
        }
        return OutputAbsent('no text parts in candidates[0].content');
      }
      return OutputAbsent('candidates[0].content is not an object');
    }
    return OutputAbsent('candidates[0] is not an object');
  }
  return OutputAbsent('no candidates[0] in response');
}

class AnthropicCandidate implements Candidate {
  AnthropicCandidate({
    required this.model,
    required this.apiKey,
    required this.transport,
  });

  @override
  String get id => 'anthropic';

  @override
  final String model;

  final String apiKey;
  final Transport transport;

  @override
  Future<CandidateReply> requestSlicePlan({
    required String prompt,
    required String schemaJson,
    required Uint8List imageBytes,
    required String imageMimeType,
  }) async {
    final body = <String, Object?>{
      'model': model,
      'max_tokens': 2048,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': imageMimeType,
                'data': base64Encode(imageBytes),
              },
            },
            {'type': 'text', 'text': prompt},
          ],
        },
      ],
      'tools': [
        {
          'name': 'emit_slice_plan',
          'description': 'Emite el plan de pasos como JSON estructurado.',
          'input_schema': jsonDecode(schemaJson),
        },
      ],
      'tool_choice': {'type': 'tool', 'name': 'emit_slice_plan'},
    };
    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    final response = await postJson(transport, url, {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    }, body);
    return CandidateReply(
      output: extractAnthropicToolInput(decodeJsonBody(response)),
      endpoint: url,
      rawBody: utf8.decode(response.bodyBytes),
    );
  }
}

ModelOutput extractAnthropicToolInput(Object? decoded) {
  if (decoded is! Map) {
    return OutputAbsent('response is not a JSON object');
  }
  final content = decoded['content'];
  if (content is List) {
    for (final block in content) {
      if (block is Map &&
          block['type'] == 'tool_use' &&
          block['name'] == 'emit_slice_plan') {
        return DecodedOutput(block['input']);
      }
    }
    final hasText = content.any(
      (block) => block is Map && block['type'] == 'text',
    );
    if (hasText) {
      return const OutputAbsent(
        'no tool_use block — the model answered text instead of calling emit_slice_plan',
      );
    }
    return const OutputAbsent('no tool_use block in response content');
  }
  return OutputAbsent('content is not an array');
}
