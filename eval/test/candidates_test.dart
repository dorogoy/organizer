import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:eval/candidates.dart';

/// The real shared schema — the adapters must embed exactly what every
/// candidate receives (cwd for `dart test` is the eval package root).
final schemaJson = File('schema.json').readAsStringSync();

const imageBytes = [1, 2, 3, 4];

final class FakeServer {
  FakeServer(this.responder);

  final Object Function() responder;
  int calls = 0;
  Uri? lastUrl;
  Map<String, String>? lastHeaders;
  String? lastBody;

  Transport get transport {
    return (url, headers, bodyJson) async {
      calls++;
      lastUrl = url;
      lastHeaders = Map.of(headers);
      lastBody = bodyJson;
      final outcome = responder();
      if (outcome is http.Response) {
        return outcome;
      }
      throw outcome;
    };
  }
}

http.Response ok(String bodyJson) => http.Response(bodyJson, 200);

http.Response openAiBody(String content) => ok(
  jsonEncode({
    'choices': [
      {
        'message': {'role': 'assistant', 'content': content},
      },
    ],
  }),
);

Future<CandidateReply> request(Candidate candidate) =>
    candidate.requestSlicePlan(
      prompt: 'PROMPT',
      schemaJson: schemaJson,
      imageBytes: Uint8List.fromList(imageBytes),
      imageMimeType: 'image/jpeg',
    );

void main() {
  group('spec registry', () {
    test('the five candidates carry their env keys and defaults', () {
      expect(candidateSpecs.map((s) => s.id), [
        'e2b_local',
        'e4b_local',
        'gemini',
        'openai',
        'anthropic',
      ]);
      expect(specFor('gemini').envKey, 'EVAL_GEMINI_API_KEY');
      expect(specFor('openai').envKey, 'EVAL_OPENAI_API_KEY');
      expect(specFor('anthropic').envKey, 'EVAL_ANTHROPIC_API_KEY');
      expect(specFor('e2b_local').defaultBaseUrl, lemonadeDefaultBaseUrl);
    });

    test('an unknown candidate id is an error naming the allowed set', () {
      expect(() => specFor('nope'), throwsA(isA<ArgumentError>()));
    });

    test(
      'a cloud candidate without its environment key refuses construction',
      () {
        expect(
          () => buildCandidate(id: 'openai'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('EVAL_OPENAI_API_KEY'),
            ),
          ),
        );
      },
    );
  });

  group('local pair — OpenAI-compatible chat completions over Lemonade', () {
    test('sends exactly one request with the prompt, a base64 image part and json_object mode', () async {
      final server = FakeServer(() => openAiBody('{"steps": []}'));
      final candidate = buildCandidate(
        id: 'e2b_local',
        transport: server.transport,
      );
      await request(candidate);
      expect(server.calls, 1);
      expect(
        server.lastUrl,
        Uri.parse('http://localhost:13305/api/v1/chat/completions'),
      );
      final body = jsonDecode(server.lastBody!) as Map<String, Object?>;
      expect(body['model'], 'gemma4-it-e2b-FLM');
      expect(body['response_format'], {'type': 'json_object'});
      expect(body['max_tokens'], 2048);
      final parts =
          ((body['messages'] as List).first as Map)['content'] as List;
      expect(parts.first['type'], 'text');
      expect(parts.first['text'], 'PROMPT');
      expect(parts.last['type'], 'image_url');
      expect(
        (parts.last['image_url'] as Map)['url'],
        startsWith('data:image/jpeg;base64,'),
      );
      expect(
        server.lastHeaders,
        containsPair('Content-Type', 'application/json'),
      );
      expect(server.lastHeaders, isNot(contains('Authorization')));
    });

    test('e4b_local defaults to its own model id and honours --base-url/--model overrides', () async {
      final server = FakeServer(() => openAiBody('{"steps": []}'));
      final candidate = buildCandidate(
        id: 'e4b_local',
        baseUrl: 'http://localhost:9999/v1',
        model: 'other-model',
        transport: server.transport,
      );
      await request(candidate);
      expect(
        server.lastUrl,
        Uri.parse('http://localhost:9999/v1/chat/completions'),
      );
      expect((jsonDecode(server.lastBody!) as Map)['model'], 'other-model');
    });

    test('extracts the content string from a 200 response', () async {
      final server = FakeServer(
        () => openAiBody('{"steps": [{"text": "a", "duration_minutes": 4}]}'),
      );
      final reply = await request(
        buildCandidate(id: 'e2b_local', transport: server.transport),
      );
      expect(
        reply.output,
        isA<TextOutput>().having((o) => o.text, 'text', contains('steps')),
      );
      expect(reply.rawBody, contains('choices'));
    });
  });

  group('one request per photo — no retry anywhere', () {
    test('an HTTP non-200 fails once, with the status and a body snippet in the reason', () async {
      final server = FakeServer(() => http.Response('upstream boom', 500));
      final candidate = buildCandidate(
        id: 'e2b_local',
        transport: server.transport,
      );
      await expectLater(
        request(candidate),
        throwsA(
          isA<HarnessTransportException>().having(
            (e) => e.reason,
            'reason',
            allOf(contains('HTTP 500'), contains('upstream boom')),
          ),
        ),
      );
      expect(server.calls, 1);
    });

    test(
      'a network error fails once, wrapped as a transport failure',
      () async {
        final server = FakeServer(() => SocketException('connection refused'));
        final candidate = buildCandidate(
          id: 'e2b_local',
          transport: server.transport,
        );
        await expectLater(
          request(candidate),
          throwsA(
            isA<HarnessTransportException>().having(
              (e) => e.reason,
              'reason',
              contains('network error'),
            ),
          ),
        );
        expect(server.calls, 1);
      },
    );

    test('a 200 with a non-JSON body is a transport failure', () async {
      final server = FakeServer(() => ok('<html>not json</html>'));
      final candidate = buildCandidate(
        id: 'e2b_local',
        transport: server.transport,
      );
      await expectLater(
        request(candidate),
        throwsA(
          isA<HarnessTransportException>().having(
            (e) => e.reason,
            'reason',
            contains('not JSON'),
          ),
        ),
      );
    });
  });

  group('OpenAI cloud — structured outputs', () {
    test('sends a strict json_schema response_format, the bearer key and max_completion_tokens', () async {
      final server = FakeServer(() => openAiBody('{"steps": []}'));
      final reply = await request(
        buildCandidate(
          id: 'openai',
          apiKey: 'k-1',
          transport: server.transport,
        ),
      );
      expect(
        server.lastUrl,
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      expect(server.lastHeaders, containsPair('Authorization', 'Bearer k-1'));
      final body = jsonDecode(server.lastBody!) as Map<String, Object?>;
      expect(body['max_completion_tokens'], 2048);
      expect(body['model'], 'gpt-5-mini');
      final format = body['response_format'] as Map<String, Object?>;
      expect(format['type'], 'json_schema');
      final jsonSchema = format['json_schema'] as Map<String, Object?>;
      expect(jsonSchema['strict'], true);
      expect(jsonSchema['schema'], jsonDecode(schemaJson));
      expect(reply.output, isA<TextOutput>());
    });
  });

  group('Gemini — generateContent with responseSchema', () {
    http.Response geminiBody(List<String> texts) => ok(
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                for (final text in texts) {'text': text},
              ],
            },
          },
        ],
      }),
    );

    test('maps the canonical schema, sends the key in a header, extracts text parts', () async {
      final server = FakeServer(() => geminiBody(['{"steps": ']));
      final reply = await request(
        buildCandidate(
          id: 'gemini',
          apiKey: 'g-1',
          transport: server.transport,
        ),
      );
      expect(
        server.lastUrl,
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
        ),
      );
      expect(server.lastHeaders, containsPair('x-goog-api-key', 'g-1'));
      final body = jsonDecode(server.lastBody!) as Map<String, Object?>;
      final parts = ((body['contents'] as List).first as Map)['parts'] as List;
      expect(parts.first['text'], 'PROMPT');
      final inline = parts.last['inline_data'] as Map;
      expect(inline['mime_type'], 'image/jpeg');
      expect(inline['data'], base64Encode(imageBytes));
      final config = body['generationConfig'] as Map<String, Object?>;
      expect(config['responseMimeType'], 'application/json');
      final responseSchema = config['responseSchema'] as Map<String, Object?>;
      expect(responseSchema['type'], 'OBJECT');
      final steps =
          (responseSchema['properties'] as Map)['steps']
              as Map<String, Object?>;
      expect(steps['type'], 'ARRAY');
      final items = steps['items'] as Map<String, Object?>;
      expect(items['type'], 'OBJECT');
      expect(items['required'], ['text', 'duration_minutes']);
      expect(responseSchema.containsKey('additionalProperties'), isFalse);
      expect(reply.output, isA<TextOutput>());
    });

    test('joins multiple text parts into one first-attempt payload', () async {
      final server = FakeServer(() => geminiBody(['{"steps": ', '[]}', '']));
      final reply = await request(
        buildCandidate(
          id: 'gemini',
          apiKey: 'g-1',
          transport: server.transport,
        ),
      );
      expect((reply.output as TextOutput).text, '{"steps": []}');
    });
  });

  group('Anthropic — messages with a tool-borne schema', () {
    http.Response anthropicBody(List<Map<String, Object?>> blocks) =>
        ok(jsonEncode({'content': blocks}));

    test('rides the schema on emit_slice_plan, forces the tool, extracts the decoded input', () async {
      final server = FakeServer(
        () => anthropicBody([
          {'type': 'text', 'text': 'thinking out loud'},
          {
            'type': 'tool_use',
            'name': 'emit_slice_plan',
            'input': {'steps': []},
          },
        ]),
      );
      final reply = await request(
        buildCandidate(
          id: 'anthropic',
          apiKey: 'a-1',
          transport: server.transport,
        ),
      );
      expect(
        server.lastUrl,
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      expect(server.lastHeaders, containsPair('x-api-key', 'a-1'));
      expect(
        server.lastHeaders,
        containsPair('anthropic-version', '2023-06-01'),
      );
      final body = jsonDecode(server.lastBody!) as Map<String, Object?>;
      expect(body['max_tokens'], 2048);
      expect(body['model'], 'claude-sonnet-4-5');
      final content =
          ((body['messages'] as List).first as Map)['content'] as List;
      expect(content.first['type'], 'image');
      final source = content.first['source'] as Map;
      expect(source['media_type'], 'image/jpeg');
      expect(source['data'], base64Encode(imageBytes));
      expect((content.last as Map)['text'], 'PROMPT');
      final tool = (body['tools'] as List).single as Map<String, Object?>;
      expect(tool['name'], 'emit_slice_plan');
      expect(tool['input_schema'], jsonDecode(schemaJson));
      expect(body['tool_choice'], {'type': 'tool', 'name': 'emit_slice_plan'});
      expect(
        reply.output,
        isA<DecodedOutput>().having((o) => o.value, 'value', {'steps': []}),
      );
    });

    test('a 200 that answers text instead of calling the tool is an absent output, not a crash', () async {
      final server = FakeServer(
        () => anthropicBody([
          {'type': 'text', 'text': 'lo siento, no puedo'},
        ]),
      );
      final reply = await request(
        buildCandidate(
          id: 'anthropic',
          apiKey: 'a-1',
          transport: server.transport,
        ),
      );
      expect(
        reply.output,
        isA<OutputAbsent>().having(
          (o) => o.reason,
          'reason',
          contains('tool_use'),
        ),
      );
    });
  });

  group('extraction edge cases', () {
    test('OpenAI-shaped: missing choices or non-string content records an absent output', () async {
      final server = FakeServer(() => ok('{"choices": []}'));
      final reply = await request(
        buildCandidate(id: 'openai', apiKey: 'k', transport: server.transport),
      );
      expect(reply.output, isA<OutputAbsent>());

      final server2 = FakeServer(
        () => ok('{"choices": [{"message": {"content": 7}}]}'),
      );
      final reply2 = await request(
        buildCandidate(id: 'openai', apiKey: 'k', transport: server2.transport),
      );
      expect(reply2.output, isA<OutputAbsent>());
    });

    test('Gemini-shaped: no candidates records an absent output', () async {
      final server = FakeServer(() => ok('{"candidates": []}'));
      final reply = await request(
        buildCandidate(id: 'gemini', apiKey: 'k', transport: server.transport),
      );
      expect(reply.output, isA<OutputAbsent>());
    });
  });
}
