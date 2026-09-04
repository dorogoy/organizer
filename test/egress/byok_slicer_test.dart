import 'dart:async';

import 'package:fake_async/fake_async.dart';

import 'dart:convert';
import 'dart:io';

import 'package:core/ports/files_port.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/slicer/rescue_steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:organizer/egress/byok_slicer.dart';
import 'package:organizer/egress/byok_wire.dart';
import 'package:organizer/egress/local_slicer.dart';
import 'package:organizer/egress/provider_allowlist.dart';
import 'package:organizer/egress/rescue_contract.dart';
import 'package:organizer/platform/credentials/credentials_cipher.dart';
import 'package:organizer/vault/credential_vault.dart';

import 'egress_fixtures.dart';

/// The BYOK Slicer's contract (Story 4-4) — every matrix row: the
/// four per-wire request shapes (URL, headers, body, ZDR, schema,
/// prompt composition), the extraction per wire, the cause
/// classification (401/403, 429, 5xx, socket, unparseable), the
/// credential family (no selection, no envelope, corrupt envelope —
/// nothing sent on any of them), one-send-only, and per-call
/// provider resolution.
void main() {
  // --- The fake vault's pieces: the real vault over in-memory Files
  // and a transparent cipher whose envelope is the plaintext itself,
  // so a seeded key reads back verbatim and header assertions can
  // name it.
  final files = _FakeFiles();
  late CredentialVault vault;

  setUp(() {
    files.blobs.clear();
    vault = CredentialVault(files: files, cipher: const _TransparentCipher());
  });

  ByokSlicer slicerWith(http.Client client, String? selected) => ByokSlicer(
    client: client,
    vault: vault,
    readSelectedProvider: () async => selected,
  );

  Future<void> seedKey(String provider, String key) async {
    await vault.saveCredential(provider, key);
  }

  const rescue = RescueSliceRequest(
    originContext: 'la mesa del salón',
    task: 'recoger la mesa',
  );

  http.Response jsonResponse(Object body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: {contentTypeHeader: jsonContentType},
  );

  final recorded = <http.Request>[];
  MockClient recording(http.Response Function(http.Request) answer) =>
      MockClient((request) async {
        recorded.add(request);
        return answer(request);
      });

  setUp(recorded.clear);

  group('the four per-wire rescue happy paths', () {
    test(
      'gemini: x-goog-api-key, responseSchema dialect, parts extracted',
      () async {
        await seedKey('gemini', 'g-key-1');
        final client = recording(
          (request) => jsonResponse({
            candidatesKey: [
              {
                contentKey: {
                  partsKey: [
                    {textKey: '{"steps":['},
                    {textKey: '{"text":"x","duration_seconds":30}]}'},
                  ],
                },
              },
            ],
          }),
        );
        final outcome = await slicerWith(client, 'gemini').slice(rescue);

        expect(outcome, isA<SlicerDelivered>());
        expect(
          (outcome as SlicerDelivered).responseBody,
          '{"steps":[{"text":"x","duration_seconds":30}]}',
          reason: 'gemini text parts join into one slice text',
        );
        expect(recorded, hasLength(1), reason: 'one send per slice');
        final request = recorded.single;
        expect(
          request.followRedirects,
          isFalse,
          reason: 'a 3xx must not replay the API key off the allowlist',
        );
        expect(
          request.url.toString(),
          'https://generativelanguage.googleapis.com/v1beta/models/'
          'gemini-3.5-flash-lite:generateContent',
        );
        expect(request.headers[xGoogApiKeyHeader], 'g-key-1');
        expect(request.headers[contentTypeHeader], jsonContentType);
        expect(request.headers.containsKey(authorizationHeader), isFalse);
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final parts = (body[contentsKey] as List).single[partsKey] as List;
        expect(
          parts.single[textKey],
          rescuePromptFor(rescue.originContext, rescue.task),
        );
        expect(
          parts.single,
          isNot(contains(inlineDataTypeValue)),
          reason: 'a rescue rides text only',
        );
        final generation = body[generationConfigKey] as Map<String, Object?>;
        expect(generation[responseMimeTypeKey], applicationJsonValue);
        // The schema rides Gemini's dialect: uppercase types, no
        // additionalProperties.
        final schema = generation[responseSchemaKey] as Map<String, Object?>;
        expect(schema[typeKey], 'OBJECT');
        expect(schema.containsKey(additionalPropertiesWireKey), isFalse);
        final stepsSchema =
            (schema[propertiesKey] as Map<String, Object?>)[stepsWireKey]
                as Map<String, Object?>;
        expect(stepsSchema[typeKey], 'ARRAY');
        // The dialect deliberately drops what Gemini's
        // structured-output subset does not carry:
        // additionalProperties, minItems/maxItems — and the
        // minimum/maximum bounds with them, because a bound Gemini
        // cannot enforce would be a lie in the request. The bounds
        // stay in the strict wires and are re-enforced downstream by
        // 4-6's parse.
        expect(stepsSchema.containsKey(minItemsWireKey), isFalse);
        expect(stepsSchema.containsKey(maxItemsWireKey), isFalse);
        expect(stepsSchema.containsKey(additionalPropertiesWireKey), isFalse);
        final stepShape =
            (stepsSchema[itemsKey] as Map<String, Object?>)[propertiesKey]
                as Map<String, Object?>;
        final durationShape =
            stepShape[durationSecondsWireKey] as Map<String, Object?>;
        expect(durationShape.containsKey(minimumWireKey), isFalse);
        expect(durationShape.containsKey(maximumWireKey), isFalse);
      },
    );

    test('openai: Bearer, strict json_schema, content extracted', () async {
      await seedKey('openai', 'o-key-2');
      final client = recording(
        (request) => jsonResponse({
          choicesKey: [
            {
              messageKey: {contentKey: '{"steps":[]}'},
            },
          ],
        }),
      );
      final outcome = await slicerWith(client, 'openai').slice(rescue);

      expect((outcome as SlicerDelivered).responseBody, '{"steps":[]}');
      final request = recorded.single;
      expect(request.url.toString(), openAiChatCompletionsUrl);
      expect(request.headers[authorizationHeader], 'Bearer o-key-2');
      expect(request.headers.containsKey(xGoogApiKeyHeader), isFalse);
      final body = jsonDecode(request.body) as Map<String, Object?>;
      expect(body[modelKey], openAiModelId);
      final content = (body[messagesKey] as List).single[contentKey] as List;
      expect(
        content.single[textKey],
        rescuePromptFor(rescue.originContext, rescue.task),
      );
      final format = body[responseFormatKey] as Map<String, Object?>;
      expect(format[typeKey], jsonSchemaTypeValue);
      final jsonSchema = format[jsonSchemaKey] as Map<String, Object?>;
      expect(jsonSchema[schemaNameKey], slicePlanSchemaName);
      expect(jsonSchema[strictKey], true);
      expect(
        (jsonSchema[schemaKey] as Map<String, Object?>)[requiredKey],
        contains(stepsWireKey),
      );
      // The canonical bounds ride the strict wire untouched — the
      // per-field minimum/maximum included.
      final strictSteps =
          ((jsonSchema[schemaKey] as Map<String, Object?>)[propertiesKey]
                  as Map<String, Object?>)[stepsWireKey]
              as Map<String, Object?>;
      expect(strictSteps[minItemsWireKey], 2);
      expect(strictSteps[maxItemsWireKey], 4);
      final strictStepShape =
          (strictSteps[itemsKey] as Map<String, Object?>)[propertiesKey]
              as Map<String, Object?>;
      final strictDuration =
          strictStepShape[durationSecondsWireKey] as Map<String, Object?>;
      expect(strictDuration[minimumWireKey], 1);
      expect(strictDuration[maximumWireKey], 60);
      expect(body[maxCompletionTokensKey], wireMaxCompletionTokens);
      expect(
        body.containsKey(maxTokensKey),
        isFalse,
        reason: 'max_tokens is the OpenRouter wire\'s ceiling field',
      );
      expect(
        body.containsKey(providerRoutingKey),
        isFalse,
        reason: 'the ZDR flag is OpenRouter-only',
      );
    });

    test(
      'anthropic: x-api-key + version, forced tool, input extracted',
      () async {
        await seedKey('anthropic', 'a-key-3');
        final client = recording(
          (request) => jsonResponse({
            contentKey: [
              {typeKey: textTypeValue, textKey: 'thinking out loud'},
              {
                typeKey: toolUseTypeValue,
                nameKey: emitSlicePlanToolName,
                inputKey: {
                  stepsWireKey: [
                    {textWireKey: 'x', durationSecondsWireKey: 30},
                  ],
                },
              },
            ],
          }),
        );
        final outcome = await slicerWith(client, 'anthropic').slice(rescue);

        expect(
          (outcome as SlicerDelivered).responseBody,
          '{"steps":[{"text":"x","duration_seconds":30}]}',
          reason: 'the tool input re-encodes as the slice text',
        );
        final request = recorded.single;
        expect(request.url.toString(), anthropicMessagesUrl);
        expect(request.headers[xApiKeyHeader], 'a-key-3');
        expect(request.headers[anthropicVersionHeader], anthropicVersionValue);
        expect(request.headers.containsKey(authorizationHeader), isFalse);
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body[modelKey], anthropicModelId);
        expect(body[maxTokensKey], wireMaxCompletionTokens);
        final tools = body[toolsKey] as List;
        expect((tools.single as Map)[nameKey], emitSlicePlanToolName);
        expect(
          (tools.single as Map)[inputSchemaKey],
          jsonDecode(rescueSliceSchemaJson),
        );
        final choice = body[toolChoiceKey] as Map<String, Object?>;
        expect(choice[typeKey], toolTypeValue);
        expect(choice[nameKey], emitSlicePlanToolName);
      },
    );

    test(
      'openrouter: Bearer, ZDR slug, per-request provider.zdr: true',
      () async {
        await seedKey('openrouter', 'r-key-4');
        final client = recording(
          (request) => jsonResponse({
            choicesKey: [
              {
                messageKey: {contentKey: '{"steps":[]}'},
              },
            ],
          }),
        );
        final outcome = await slicerWith(client, 'openrouter').slice(rescue);

        expect((outcome as SlicerDelivered).responseBody, '{"steps":[]}');
        final request = recorded.single;
        expect(request.url.toString(), openRouterChatCompletionsUrl);
        expect(request.headers[authorizationHeader], 'Bearer r-key-4');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body[modelKey], openRouterModelSlug);
        // The app's own enforcement of the no-training gate: every
        // request carries the ZDR routing preference.
        final routing = body[providerRoutingKey] as Map<String, Object?>;
        expect(routing[zdrRoutingKey], true);
        final format = body[responseFormatKey] as Map<String, Object?>;
        expect(format[typeKey], jsonSchemaTypeValue);
        // OpenRouter's documented ceiling parameter is max_tokens —
        // the OpenAI-direct max_completion_tokens stays off this
        // wire.
        expect(body[maxTokensKey], wireMaxCompletionTokens);
        expect(
          body.containsKey(maxCompletionTokensKey),
          isFalse,
          reason: 'the ceiling field is per-wire',
        );
      },
    );
  });

  group('the rescue prompt composition', () {
    test('the origin context and task land in their slots, verbatim', () async {
      await seedKey('gemini', 'g-key');
      final client = recording(
        (request) => jsonResponse({
          candidatesKey: [
            {
              contentKey: {
                partsKey: [
                  {textKey: '{"steps":[]}'},
                ],
              },
            },
          ],
        }),
      );
      await slicerWith(client, 'gemini').slice(rescue);
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      final parts = (body[contentsKey] as List).single[partsKey] as List;
      final prompt = parts.single[textKey] as String;
      expect(prompt, rescuePromptFor(rescue.originContext, rescue.task));
      expect(prompt, contains(rescue.originContext));
      expect(prompt, contains(rescue.task));
      expect(prompt, contains('2 a 4 pasos'));
      expect(prompt, contains('60 segundos o menos'));
      expect(prompt, contains(durationSecondsWireKeyJson));
    });
  });

  group('the credential family — nothing is sent', () {
    test('no provider selected: credentialUnavailable, zero sends', () async {
      final client = recording((request) => jsonResponse({}));
      final outcome = await slicerWith(client, null).slice(rescue);
      expect(
        outcome,
        const SlicerFailed(SlicerFailureCause.credentialUnavailable),
      );
      expect(recorded, isEmpty);
    });

    test('selected but unallowlisted: the same quiet refusal', () async {
      final client = recording((request) => jsonResponse({}));
      final outcome = await slicerWith(
        client,
        'some_other_provider',
      ).slice(rescue);
      expect(
        outcome,
        const SlicerFailed(SlicerFailureCause.credentialUnavailable),
      );
      expect(recorded, isEmpty);
    });

    test('no envelope stored: credentialUnavailable, zero sends', () async {
      final client = recording((request) => jsonResponse({}));
      final outcome = await slicerWith(client, 'openai').slice(rescue);
      expect(
        outcome,
        const SlicerFailed(SlicerFailureCause.credentialUnavailable),
      );
      expect(recorded, isEmpty);
    });

    test('corrupt envelope: credentialUnavailable, zero sends — the vault '
        'folds its measurement', () async {
      final corrupt = CredentialVault(
        files: files,
        cipher: const _CorruptUnsealCipher(),
      );
      await corrupt.saveCredential('openai', 'o-key');
      final client = recording((request) => jsonResponse({}));
      final outcome = await ByokSlicer(
        client: client,
        vault: corrupt,
        readSelectedProvider: () async => 'openai',
      ).slice(rescue);
      expect(
        outcome,
        const SlicerFailed(SlicerFailureCause.credentialUnavailable),
      );
      expect(recorded, isEmpty);
    });
  });

  group('the cause classification', () {
    Future<SlicerFailureCause> causeOf(
      http.Response Function() answer, {
      Object? thrown,
    }) async {
      await seedKey('openai', 'o-key');
      final client = MockClient((request) async {
        recorded.add(request);
        if (thrown != null) {
          throw thrown;
        }
        return answer();
      });
      final outcome = await slicerWith(client, 'openai').slice(rescue);
      return (outcome as SlicerFailed).cause;
    }

    test('401 and 403 read invalidKey — terminal', () async {
      expect(
        await causeOf(() => jsonResponse({}, status: 401)),
        SlicerFailureCause.invalidKey,
      );
      expect(
        await causeOf(() => jsonResponse({}, status: 403)),
        SlicerFailureCause.invalidKey,
      );
    });

    test('429 reads quotaExhausted', () async {
      expect(
        await causeOf(() => jsonResponse({}, status: 429)),
        SlicerFailureCause.quotaExhausted,
      );
    });

    test('5xx reads providerUnreachable', () async {
      expect(
        await causeOf(() => jsonResponse({}, status: 500)),
        SlicerFailureCause.providerUnreachable,
      );
      expect(
        await causeOf(() => jsonResponse({}, status: 503)),
        SlicerFailureCause.providerUnreachable,
      );
    });

    test('residual non-2xx statuses read providerUnreachable — status '
        'evidence is a reachability fact', () async {
      expect(
        await causeOf(() => jsonResponse({}, status: 404)),
        SlicerFailureCause.providerUnreachable,
      );
      expect(
        await causeOf(() => jsonResponse({}, status: 400)),
        SlicerFailureCause.providerUnreachable,
      );
      expect(
        await causeOf(() => jsonResponse({}, status: 402)),
        SlicerFailureCause.providerUnreachable,
      );
    });

    test('a socket failure reads networkUnreachable', () async {
      expect(
        await causeOf(
          () => jsonResponse({}),
          thrown: const SocketException('offline'),
        ),
        SlicerFailureCause.networkUnreachable,
      );
    });

    test('a TLS handshake failure reads networkUnreachable', () async {
      expect(
        await causeOf(
          () => jsonResponse({}),
          thrown: HandshakeException('bad handshake'),
        ),
        SlicerFailureCause.networkUnreachable,
      );
    });

    test('a ClientException reads networkUnreachable', () async {
      expect(
        await causeOf(
          () => jsonResponse({}),
          thrown: http.ClientException('transport failed'),
        ),
        SlicerFailureCause.networkUnreachable,
      );
    });

    test('an unparseable 200 body reads malformedResponse', () async {
      await seedKey('openai', 'o-key');
      final client = recording(
        (request) => http.Response('not json at all', 200),
      );
      final outcome = await slicerWith(client, 'openai').slice(rescue);
      expect(outcome, const SlicerFailed(SlicerFailureCause.malformedResponse));
    });

    test(
      'a parseable 200 with nothing extractable reads malformedResponse',
      () async {
        await seedKey('openai', 'o-key');
        final client = recording(
          (request) => jsonResponse({choicesKey: <Object>[]}),
        );
        final outcome = await slicerWith(client, 'openai').slice(rescue);
        expect(
          outcome,
          const SlicerFailed(SlicerFailureCause.malformedResponse),
        );
      },
    );
  });

  group('one send per slice, and per-call provider resolution', () {
    test('exactly one request per slice, whatever the outcome', () async {
      await seedKey('openai', 'o-key');
      final client = recording((request) => jsonResponse({}, status: 500));
      await slicerWith(client, 'openai').slice(rescue);
      expect(recorded, hasLength(1), reason: 'no retry exists anywhere');
    });

    test('the reader is consulted per call — a switch mid-flight switches '
        'the wire', () async {
      await seedKey('gemini', 'g-key');
      await seedKey('openai', 'o-key');
      var selected = 'gemini';
      final client = recording(
        (request) => jsonResponse({
          candidatesKey: [
            {
              contentKey: {
                partsKey: [
                  {textKey: '{"steps":[]}'},
                ],
              },
            },
          ],
          choicesKey: [
            {
              messageKey: {contentKey: '{"steps":[]}'},
            },
          ],
        }),
      );
      final slicer = ByokSlicer(
        client: client,
        vault: vault,
        readSelectedProvider: () async => selected,
      );
      await slicer.slice(rescue);
      selected = 'openai';
      await slicer.slice(rescue);
      expect(recorded, hasLength(2));
      expect(recorded.first.url.toString(), contains('generativelanguage'));
      expect(recorded.last.url.toString(), openAiChatCompletionsUrl);
    });
  });

  group('the other two request kinds ride their payloads verbatim', () {
    test('a genesis request rides its text with no schema', () async {
      await seedKey('openai', 'o-key');
      final client = recording(
        (request) => jsonResponse({
          choicesKey: [
            {
              messageKey: {contentKey: '{"steps":[]}'},
            },
          ],
        }),
      );
      final outcome = await slicerWith(
        client,
        'openai',
      ).slice(const GenesisSliceRequest(text: 'un proyecto de fotos'));
      expect(outcome, isA<SlicerDelivered>());
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      final content = (body[messagesKey] as List).single[contentKey] as List;
      expect(content.single[textKey], 'un proyecto de fotos');
      expect(
        body.containsKey(responseFormatKey),
        isFalse,
        reason: 'no authored scan/genesis contract exists yet',
      );
    });

    test(
      'a scan request rides its image through the cap, prompt verbatim',
      () async {
        await seedKey('gemini', 'g-key');
        final client = recording(
          (request) => jsonResponse({
            candidatesKey: [
              {
                contentKey: {
                  partsKey: [
                    {textKey: '{"steps":[]}'},
                  ],
                },
              },
            ],
          }),
        );
        final bytes = gradientJpeg(640, 480);
        final outcome = await slicerWith(client, 'gemini').slice(
          ScanSliceRequest(imageBytes: bytes, prompt: 'describe el rincón'),
        );
        expect(outcome, isA<SlicerDelivered>());
        final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
        final parts = (body[contentsKey] as List).single[partsKey] as List;
        expect((parts[0] as Map)[textKey], 'describe el rincón');
        final image = parts[1] as Map<String, Object?>;
        expect(
          image.containsKey(typeKey),
          isFalse,
          reason: 'generateContent nests mime+data under inline_data',
        );
        final inline = image[inlineDataTypeValue] as Map<String, Object?>;
        expect(inline[inlineMimeTypeKey], imageJpegMimeType);
        final decoded = base64Decode(inline[inlineDataKey] as String);
        expect(
          decoded,
          equals(bytes),
          reason: 'an in-cap scan payload rides the wire byte-identical',
        );
      },
    );

    test('an OpenAI scan rides an image_url data-URI', () async {
      await seedKey('openai', 'o-key');
      final client = recording(
        (request) => jsonResponse({
          choicesKey: [
            {
              messageKey: {contentKey: '{"steps":[]}'},
            },
          ],
        }),
      );
      final bytes = gradientJpeg(640, 480);
      await slicerWith(client, 'openai').slice(
        ScanSliceRequest(imageBytes: bytes, prompt: 'describe el rincón'),
      );
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      final content = (body[messagesKey] as List).single[contentKey] as List;
      expect((content[0] as Map)[textKey], 'describe el rincón');
      final image = content[1] as Map<String, Object?>;
      expect(image[typeKey], imageUrlTypeValue);
      final url = (image[imageUrlKey] as Map)[imageUrlUrlKey] as String;
      expect(
        url.startsWith(
          dataUriSchemePrefix + imageJpegMimeType + dataUriBase64Middle,
        ),
        isTrue,
      );
      expect(base64Decode(url.split(dataUriBase64Middle).last), bytes);
    });

    test('an OpenRouter scan rides the same data-URI and keeps ZDR', () async {
      await seedKey('openrouter', 'r-key');
      final client = recording(
        (request) => jsonResponse({
          choicesKey: [
            {
              messageKey: {contentKey: '{"steps":[]}'},
            },
          ],
        }),
      );
      final bytes = gradientJpeg(640, 480);
      await slicerWith(client, 'openrouter').slice(
        ScanSliceRequest(imageBytes: bytes, prompt: 'describe el rincón'),
      );
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      final content = (body[messagesKey] as List).single[contentKey] as List;
      final image = content[1] as Map<String, Object?>;
      expect(image[typeKey], imageUrlTypeValue);
      final routing = body[providerRoutingKey] as Map<String, Object?>;
      expect(routing[zdrRoutingKey], true);
      expect(
        base64Decode(
          ((image[imageUrlKey] as Map)[imageUrlUrlKey] as String)
              .split(dataUriBase64Middle)
              .last,
        ),
        bytes,
      );
    });

    test('an Anthropic scan rides a base64 image source', () async {
      await seedKey('anthropic', 'a-key');
      final client = recording(
        (request) => jsonResponse({
          contentKey: [
            {typeKey: textTypeValue, textKey: '{"steps":[]}'},
          ],
        }),
      );
      final bytes = gradientJpeg(640, 480);
      await slicerWith(client, 'anthropic').slice(
        ScanSliceRequest(imageBytes: bytes, prompt: 'describe el rincón'),
      );
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      final content = (body[messagesKey] as List).single[contentKey] as List;
      final image = content[0] as Map<String, Object?>;
      expect(image[typeKey], imageTypeValue);
      final source = image[sourceKey] as Map<String, Object?>;
      expect(source[typeKey], base64TypeValue);
      expect(source[mediaTypeKey], imageJpegMimeType);
      expect(base64Decode(source[dataKey] as String), bytes);
      expect((content[1] as Map)[textKey], 'describe el rincón');
    });

    test('an in-cap PNG keeps image/png on the OpenAI data-URI', () async {
      await seedKey('openai', 'o-key');
      final client = recording(
        (request) => jsonResponse({
          choicesKey: [
            {
              messageKey: {contentKey: '{"steps":[]}'},
            },
          ],
        }),
      );
      final bytes = gradientPng(200, 100);
      await slicerWith(
        client,
        'openai',
      ).slice(ScanSliceRequest(imageBytes: bytes, prompt: 'png'));
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      final content = (body[messagesKey] as List).single[contentKey] as List;
      final url =
          ((content[1] as Map)[imageUrlKey] as Map)[imageUrlUrlKey] as String;
      expect(
        url.startsWith(
          dataUriSchemePrefix + imagePngMimeType + dataUriBase64Middle,
        ),
        isTrue,
      );
    });
  });

  group('the review patches (4-4 review round)', () {
    test('the canonical schema\'s field names parse — the single source '
        'every restatement derives from', () {
      final names = rescueSchemaFieldNames();
      expect(names.steps, 'steps');
      expect(names.text, 'text');
      expect(names.durationSeconds, 'duration_seconds');
    });

    test('a stalling provider hits the send timeout once and reads '
        'providerUnreachable — no retry follows', () {
      fakeAsync((async) {
        SlicerOutcome? outcome;
        var sends = 0;
        final client = MockClient((request) async {
          sends++;
          return Completer<http.Response>().future;
        });
        // Everything is constructed inside the fake clock's zone —
        // a vault minted outside it (setUp's) would settle on the
        // real event loop and the elapse below would never drive it.
        final stallingVault = CredentialVault(
          files: _FakeFiles(),
          cipher: const _TransparentCipher(),
        );
        final slicer = ByokSlicer(
          client: client,
          vault: stallingVault,
          readSelectedProvider: () async => 'openai',
        );
        unawaited(
          stallingVault.saveCredential('openai', 'o-key').then((_) async {
            outcome = await slicer.slice(rescue);
          }),
        );
        // Advance a sliver of time: the save→read→unseal→send chain
        // runs on microtasks the elapse flushes, well before the
        // two-minute bound.
        async.elapse(const Duration(milliseconds: 100));
        expect(sends, 1, reason: 'the stall accepted the one send');
        async.elapse(wireSendTimeout);
        async.flushMicrotasks();
        expect(sends, 1, reason: 'the stall bound is one attempt, no retry');
        expect(outcome, isA<SlicerFailed>());
        expect(
          (outcome as SlicerFailed).cause,
          SlicerFailureCause.providerUnreachable,
          reason: 'a stall is the no-answer bucket',
        );
      });
    });

    test('a throwing provider reader folds to providerUnreachable — the '
        'port answers outcomes only', () async {
      final client = recording((request) => jsonResponse({}));
      final slicer = ByokSlicer(
        client: client,
        vault: vault,
        readSelectedProvider: () async => throw StateError('log read refused'),
      );
      final outcome = await slicer.slice(rescue);
      expect(outcome, isA<SlicerFailed>());
      expect(
        (outcome as SlicerFailed).cause,
        SlicerFailureCause.providerUnreachable,
      );
      expect(recorded, isEmpty);
    });

    test('a throwing vault read folds to providerUnreachable — nothing '
        'sent, no throw crosses the port', () async {
      final refusing = CredentialVault(
        files: _ThrowingReadFiles()..throwOnRead = true,
        cipher: const _TransparentCipher(),
      );
      final client = recording((request) => jsonResponse({}));
      final outcome = await ByokSlicer(
        client: client,
        vault: refusing,
        readSelectedProvider: () async => 'openai',
      ).slice(rescue);
      expect(outcome, isA<SlicerFailed>());
      expect(
        (outcome as SlicerFailed).cause,
        SlicerFailureCause.providerUnreachable,
      );
      expect(recorded, isEmpty);
    });

    test('a 2xx body that is not valid UTF-8 reads malformedResponse — '
        'delivered but unusable, not a transport failure', () async {
      await seedKey('openai', 'o-key');
      final client = recording(
        (request) => http.Response.bytes([0xff, 0xfe, 0xfd], 200),
      );
      final outcome = await slicerWith(client, 'openai').slice(rescue);
      expect(outcome, isA<SlicerFailed>());
      expect(
        (outcome as SlicerFailed).cause,
        SlicerFailureCause.malformedResponse,
      );
    });

    test('a schema-less gemini call sends no generationConfig — the JSON '
        'mode rides with the schema or not at all', () async {
      await seedKey('gemini', 'g-key');
      final client = recording(
        (request) => jsonResponse({
          candidatesKey: [
            {
              contentKey: {
                partsKey: [
                  {textKey: 'prose for a genesis'},
                ],
              },
            },
          ],
        }),
      );
      final outcome = await slicerWith(
        client,
        'gemini',
      ).slice(const GenesisSliceRequest(text: 'un proyecto'));
      expect((outcome as SlicerDelivered).responseBody, 'prose for a genesis');
      final body = jsonDecode(recorded.single.body) as Map<String, Object?>;
      expect(
        body.containsKey(generationConfigKey),
        isFalse,
        reason: 'a schema-less gemini answer is prose, never coerced',
      );
      final parts = (body[contentsKey] as List).single[partsKey] as List;
      expect(parts, hasLength(1), reason: 'no image half on a genesis');
    });

    test('anthropic: a text-block answer extracts when no tool_use '
        'answers — the schema-less shapes', () async {
      await seedKey('anthropic', 'a-key');
      final client = recording(
        (request) => jsonResponse({
          contentKey: [
            {typeKey: textTypeValue, textKey: 'una respuesta en prosa'},
          ],
        }),
      );
      final outcome = await slicerWith(
        client,
        'anthropic',
      ).slice(const GenesisSliceRequest(text: 'un proyecto'));
      expect(
        (outcome as SlicerDelivered).responseBody,
        'una respuesta en prosa',
      );
    });

    test('anthropic: the tool_use answer stays preferred when a text '
        'block answers too', () async {
      final extracted = extractSliceText(
        wireKind: SlicerWireKind.anthropicMessages,
        responseBody: jsonEncode({
          contentKey: [
            {typeKey: textTypeValue, textKey: 'thinking out loud'},
            {
              typeKey: toolUseTypeValue,
              nameKey: emitSlicePlanToolName,
              inputKey: {
                stepsWireKey: [
                  {textWireKey: 'x', durationSecondsWireKey: 30},
                ],
              },
            },
          ],
        }),
      );
      expect(
        extracted,
        '{"steps":[{"text":"x","duration_seconds":30}]}',
        reason: 'the forced tool is the structured contract\'s answer',
      );
    });

    test('the gemini dialect translation throws on a non-object property '
        '— total, never silently narrower', () {
      expect(
        () =>
            geminiSchemaFrom('{"type":"object","properties":{"steps":"oops"}}'),
        throwsStateError,
      );
    });
  });

  group('the 4-6 parity pin — the shell contract and the core parse agree', () {
    // The contract of record lives here (rescue_contract.dart); the
    // parse of record lives in core (rescue_steps.dart, AD-5) and
    // cannot import it. This group is the pin: a drift in either
    // direction — a renamed wire field, a stub outside the bounds —
    // fails the gate.
    test('the canonical schema\'s derived field names ARE the core '
        'parser\'s wire names — the two statements of the three '
        'cannot drift', () {
      final names = rescueSchemaFieldNames();
      expect(rescueWireStepsField, names.steps);
      expect(rescueWireTextField, names.text);
      expect(rescueWireDurationField, names.durationSeconds);
    });

    test('the Local stub\'s canned body parses in core — the debug '
        'stub stays inside the runtime contract', () async {
      const stub = LocalSlicer(cannedMarker: 'rebanada enlatada');
      final outcome = await stub.slice(rescue);
      final steps = parseRescueSteps((outcome as SlicerDelivered).responseBody);
      expect(steps, isNotNull);
      // Literals, deliberately not the stub's own constants: a paired
      // stub-plus-constant change must fail here, not stay green.
      expect(steps!.length, 2);
      expect(steps.first.durationSeconds, 30);
      expect(steps.last.durationSeconds, 45);
      expect(steps.first.text, 'rebanada enlatada');
    });

    test('a gemini-dialect extraction — the joined text parts of the '
        'happy path — parses in core against the same contract', () async {
      await seedKey('gemini', 'g-key-1');
      final client = recording(
        (request) => jsonResponse({
          candidatesKey: [
            {
              contentKey: {
                partsKey: [
                  {textKey: '{"steps":['},
                  {textKey: '{"text":"x","duration_seconds":30}]}'},
                ],
              },
            },
          ],
        }),
      );
      final outcome = await slicerWith(client, 'gemini').slice(rescue);
      final steps = parseRescueSteps((outcome as SlicerDelivered).responseBody);
      // One step is under the contract's least count: the parse is
      // where the bounds hold, whatever a wire dropped on the way out
      // (the extraction itself was sound JSON).
      expect(
        steps,
        isNull,
        reason:
            'a body the core cannot weave as work reads '
            'malformedResponse downstream — no repair exists',
      );
    });

    test('the prompt\'s own JSON-shape example round-trips as '
        'structure — a provider answering the shape it was shown '
        'parses', () {
      final names = rescueSchemaFieldNames();
      final body = jsonEncode(<String, Object?>{
        names.steps: <Map<String, Object?>>[
          {
            names.text: 'Sacar todo lo de encima de la mesa',
            names.durationSeconds: 60,
          },
          {
            names.text: 'Pasarlo a su sitio con una pasada',
            names.durationSeconds: 45,
          },
          {names.text: 'Repasar con un trapo', names.durationSeconds: 20},
        ],
      });
      final steps = parseRescueSteps(body);
      expect(steps, isNotNull);
      expect(steps!.length, 3);
      expect(steps[1].durationSeconds, 45);
    });

    test('the contract edges hold through the shell shape — 2 and 4 '
        'steps admit, 0 s, 61 s and empty text reject', () {
      final names = rescueSchemaFieldNames();
      String edgeBody(List<Map<String, Object?>> steps) =>
          jsonEncode(<String, Object?>{names.steps: steps});
      Map<String, Object?> edgeStep(String text, int seconds) => {
        names.text: text,
        names.durationSeconds: seconds,
      };
      expect(
        parseRescueSteps(edgeBody([edgeStep('Uno', 30), edgeStep('Dos', 30)])),
        isNotNull,
      );
      expect(
        parseRescueSteps(
          edgeBody([
            edgeStep('Uno', 30),
            edgeStep('Dos', 30),
            edgeStep('Tres', 30),
            edgeStep('Cuatro', 30),
          ]),
        ),
        isNotNull,
      );
      expect(
        parseRescueSteps(edgeBody([edgeStep('Uno', 0), edgeStep('Dos', 30)])),
        isNull,
      );
      expect(
        parseRescueSteps(edgeBody([edgeStep('Uno', 61), edgeStep('Dos', 30)])),
        isNull,
      );
      expect(
        parseRescueSteps(edgeBody([edgeStep('', 30), edgeStep('Dos', 30)])),
        isNull,
      );
    });
  });
}

/// Canonical-schema vocabulary the assertions share with the wire —
/// the field names are DERIVED from the canonical schema's parse
/// (the single source; the schema-key spellings below are the walk
/// vocabulary, not restatements of the contract's names).
const String additionalPropertiesWireKey = 'additionalProperties';
const String minimumWireKey = 'minimum';
const String maximumWireKey = 'maximum';
const String minItemsWireKey = 'minItems';
const String maxItemsWireKey = 'maxItems';
final String stepsWireKey = rescueSchemaFieldNames().steps;
final String textWireKey = rescueSchemaFieldNames().text;
final String durationSecondsWireKey = rescueSchemaFieldNames().durationSeconds;
final String durationSecondsWireKeyJson = '"$durationSecondsWireKey"';
final String stepsWireKeyJson = '"$stepsWireKey"';

/// A Files fake whose reads can be made to throw — the fold test's
/// infrastructure-refusal shape.
class _ThrowingReadFiles implements FilesPort {
  var throwOnRead = false;

  @override
  Future<List<int>?> read(String scope, String name) async {
    if (throwOnRead) {
      throw StateError('storage refused');
    }
    return null;
  }

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}
}

/// An in-memory Files fake (the vault suite's own shape).
class _FakeFiles implements FilesPort {
  final Map<String, List<int>> blobs = {};

  @override
  Future<List<int>?> read(String scope, String name) async =>
      blobs['$scope/$name'];

  @override
  Future<void> write(String scope, String name, List<int> bytes) async =>
      blobs['$scope/$name'] = List.of(bytes);

  @override
  Future<void> delete(String scope, String name) async =>
      blobs.remove('$scope/$name');
}

/// A transparent cipher: the envelope is the plaintext, so a seeded
/// key reads back verbatim.
class _TransparentCipher implements CredentialsCipher {
  const _TransparentCipher();

  @override
  Future<CredentialsSealConversion> seal(List<int> plaintext) async =>
      (envelope: List<int>.of(plaintext), failure: null);

  @override
  Future<CredentialsUnsealConversion> unseal(List<int> envelope) async =>
      (plaintext: List<int>.of(envelope), failure: null);
}

/// A cipher whose every unseal fails as corrupt.
class _CorruptUnsealCipher implements CredentialsCipher {
  const _CorruptUnsealCipher();

  @override
  Future<CredentialsSealConversion> seal(List<int> plaintext) async =>
      (envelope: List<int>.of(plaintext), failure: null);

  @override
  Future<CredentialsUnsealConversion> unseal(List<int> envelope) async =>
      (plaintext: null, failure: CredentialsCipherFailure.corrupt);
}
