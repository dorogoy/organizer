// The export redaction check's own contract (AD-22, Story 4.3): the
// export fixtures may carry no credential plaintext (a
// credential-family property with a non-empty value), no provider→key
// pair shape, and no persisted availability claim asserted true —
// while the clean export shape (the sanctioned selected_provider
// text included) passes untouched.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_export_redaction.dart';

const String _cleanExport = '''
{
  "format": "organizer-export",
  "schemaVersion": 8,
  "log": [
    {
      "id": "01923f8f-5f1e-7abc-8def-0123456789b2",
      "kind": "setting_changed",
      "instantUtcMicros": 1788010200000000,
      "offsetSeconds": 7200,
      "settingKey": "selected_provider",
      "textValue": "openai"
    }
  ],
  "pool": []
}
''';

void main() {
  test('the clean export shape passes — selected_provider text included', () {
    expect(scanExport(file: 'clean.json', source: _cleanExport), isEmpty);
  });

  test('the shipped fixture itself is clean', () {
    final source = File('$exportFixturesPath/clean.json').readAsStringSync();
    expect(
      scanExport(file: '$exportFixturesPath/clean.json', source: source),
      isEmpty,
    );
  });

  test('a credential-family property with a non-empty value is rejected', () {
    for (final key in [
      'credential',
      'providerKey',
      'provider_key',
      'apiKey',
      'api_key',
      'secret',
      'token',
      'password',
      'plaintext',
    ]) {
      final findings = scanExport(
        file: 'leak.json',
        source: '{"$key": "sk-1234567890"}',
      );
      expect(findings, hasLength(1), reason: key);
      expect(findings.single.message, contains('non-empty value'));
      expect(findings.single.message, contains('AD-22 export redaction'));
    }
  });

  test(
    'a credential-family property with non-string non-empty value is rejected',
    () {
      for (final payload in ['12345', '[1, 2, 3]', '{"nested": "secret"}']) {
        final findings = scanExport(
          file: 'leak.json',
          source: '{"api_key": $payload}',
        );
        expect(findings, hasLength(1), reason: payload);
        expect(findings.single.message, contains('non-empty value'));
      }
    },
  );

  test(
    'an empty or absent credential-family property is the clean absence',
    () {
      expect(
        scanExport(file: 'clean.json', source: '{"credential": ""}'),
        isEmpty,
      );
      expect(
        scanExport(file: 'clean.json', source: '{"credential": null}'),
        isEmpty,
      );
    },
  );

  test(
    'a provider→key pair shape is rejected — key slot beside a provider',
    () {
      final findings = scanExport(
        file: 'pair.json',
        source: '{"provider": "openai", "apiKey": ""}',
      );
      expect(findings, hasLength(1));
      expect(findings.single.message, contains('provider→key pair shape'));
    },
  );

  test('a providers map is the pair shape even when every value is empty', () {
    final findings = scanExport(
      file: 'map.json',
      source: '{"providers": {"openai": "", "anthropic": ""}}',
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('provider→key pair shape'));
  });

  test('a persisted availability claim asserted true is rejected — and '
      'false is not; the provider-prefixed form is the same claim', () {
    for (final key in [
      'keyExists',
      'key_exists',
      'credentialAvailable',
      'credential_configured',
      'providerConfigured',
      'provider_configured',
    ]) {
      final findings = scanExport(file: 'claim.json', source: '{"$key": true}');
      expect(findings, hasLength(1), reason: key);
      expect(findings.single.message, contains('availability claim'));
      expect(
        scanExport(file: 'claim.json', source: '{"$key": false}'),
        isEmpty,
        reason: key,
      );
    }
  });

  test('nested leaks are found wherever they sit in the document', () {
    final findings = scanExport(
      file: 'nested.json',
      source: '''
{
  "log": [
    {"kind": "app_opened", "metadata": {"secret": "hunter2"}}
  ],
  "pool": [{"origin": "capture", "notes": [{"token": "abc"}]}]
}
''',
    );
    expect(findings, hasLength(2));
    expect(
      findings.every((finding) => finding.message.contains('non-empty value')),
      isTrue,
    );
  });

  test('a finding names its file and a best-effort line — the offending '
      'property located in the raw text, line 1 only as the fallback', () {
    final findings = scanExport(
      file: 'test/fixtures/export_redaction/leak.json',
      source: '{\n  "format": "organizer-export",\n  "secret": "abc"\n}\n',
    );
    expect(
      findings.single.toString(),
      startsWith('test/fixtures/export_redaction/leak.json:3: '),
    );

    // A single-line document finds line 1; a probe that appears
    // nowhere (a writer that quotes differently) falls back to 1
    // without crashing.
    expect(
      scanExport(file: 'one.json', source: '{"secret": "abc"}').single.line,
      1,
    );
  });

  test('a fixture that is not valid JSON is a finding, never a skip', () {
    final findings = scanExport(file: 'broken.json', source: '{not json');
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('not valid JSON'));
  });

  group('the executable', () {
    Directory fixtureRoot({required String violating}) {
      final root = Directory.systemTemp.createTempSync('export_redaction');
      addTearDown(() => root.deleteSync(recursive: true));
      final dir = Directory('${root.path}/test/fixtures/export_redaction')
        ..createSync(recursive: true);
      File('${dir.path}/clean.json').writeAsStringSync(_cleanExport);
      if (violating.isNotEmpty) {
        File('${dir.path}/leak.json').writeAsStringSync(violating);
      }
      return root;
    }

    test('exits 0 over a clean fixtures directory', () async {
      final root = fixtureRoot(violating: '');
      final result = await Process.run('dart', [
        'run',
        'tool/check_export_redaction.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(
        result.stdout as String,
        contains('export redaction check passed'),
      );
    });

    test('exits 1 and prints file:line over a leaking fixture', () async {
      final root = fixtureRoot(violating: '{"apiKey": "sk-1"}');
      final result = await Process.run('dart', [
        'run',
        'tool/check_export_redaction.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('leak.json:1:'));
      expect(out, contains('export redaction check FAILED'));
    });

    test('exits 2 when the fixtures directory is missing', () async {
      final root = Directory.systemTemp.createTempSync('export_redaction');
      addTearDown(() => root.deleteSync(recursive: true));
      final result = await Process.run('dart', [
        'run',
        'tool/check_export_redaction.dart',
        root.path,
      ]);
      expect(result.exitCode, 2);
    });
  });
}
