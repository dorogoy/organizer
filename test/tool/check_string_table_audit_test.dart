import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_string_table_audit.dart';

/// All seven pinned keys, each with real text and a signed `@key` block —
/// the minimum clean table, since absence of any pinned key is a finding.
Map<String, dynamic> _pinnedSigned() => <String, dynamic>{
  for (final key in pinnedNoSlicerKeys) key: 'Frase fija para $key.',
  for (final key in pinnedNoSlicerKeys)
    '@$key': <String, dynamic>{
      'description': 'No-Slicer surface',
      'x-signoff': 'Sergio, 2026-08-27',
    },
};

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('string_audit_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

Directory _arbRoot(String label, Map<String, dynamic> arb) {
  final root = _makeTemp(label);
  final dir = Directory('${root.path}/lib/l10n')..createSync(recursive: true);
  File('${dir.path}/app_es.arb').writeAsStringSync(jsonEncode(arb));
  return root;
}

void main() {
  group('auditStringTable', () {
    test('a pinned key lacking x-signoff is a finding', () {
      final arb = <String, dynamic>{
        'noSlicerOffline': 'El móvil está sin conexión.',
        '@noSlicerOffline': {'description': 'no network'},
      };
      final result = auditStringTable(arb);
      expect(result.isClean, isFalse);
      expect(result.findings, contains(contains('lacks an x-signoff')));
    });

    test('a malformed x-signoff shape is a finding', () {
      final arb = _pinnedSigned();
      arb['@noSlicerOffline']['x-signoff'] = 'Sergio';
      expect(
        auditStringTable(arb).findings,
        contains(contains('is not "<name>, <date>"')),
      );
    });

    test('an impossible sign-off date is a finding', () {
      final arb = _pinnedSigned();
      arb['@noSlicerOffline']['x-signoff'] = 'Sergio, 2026-13-45';
      expect(
        auditStringTable(arb).findings,
        contains(contains('not a real calendar date')),
      );
    });

    test('a whitespace-only reviewer name is a finding', () {
      final arb = _pinnedSigned();
      arb['@noSlicerOffline']['x-signoff'] = '   , 2026-08-27';
      expect(
        auditStringTable(arb).findings,
        contains(contains('reviewer name is empty')),
      );
    });

    test('a placeholder-shaped pinned string is a finding', () {
      for (final placeholder in ['TODO: write me', 'TBD', 'FIXME', 'pending']) {
        final arb = _pinnedSigned();
        arb['noSlicerOffline'] = placeholder;
        expect(
          auditStringTable(arb).findings,
          contains(contains('missing or a placeholder')),
          reason: '"$placeholder" is placeholder-shaped',
        );
      }
    });

    test('a fully signed pinned table passes', () {
      final result = auditStringTable(_pinnedSigned());
      expect(result.isClean, isTrue);
      expect(result.auditList, contains('noSlicerOffline'));
    });

    test('a new key with no x-audit-exclude surfaces in the audit list', () {
      final arb = _pinnedSigned()
        ..addAll({
          'brandNewKey': 'Cadena nueva',
          '@brandNewKey': {'description': 'just added, silent'},
        });
      final result = auditStringTable(arb);
      expect(result.auditList, contains('brandNewKey'));
      expect(result.auditList, contains('noSlicerOffline'));
    });

    test('an excluded key is the only way off the audit list', () {
      final arb = _pinnedSigned()
        ..addAll({
          'reviewedKey': 'Cadena revisada',
          '@reviewedKey': {
            'description': 'reviewed out',
            'x-audit-exclude': 'debug-only, removed before launch',
          },
        });
      final result = auditStringTable(arb);
      expect(result.auditList, isNot(contains('reviewedKey')));
      expect(result.auditList, contains('noSlicerOffline'));
      expect(result.isClean, isTrue);
    });

    test('a whitespace-only exclusion stays audited and is a finding', () {
      final arb = _pinnedSigned()
        ..addAll({
          'reviewedKey': 'Cadena revisada',
          '@reviewedKey': {'x-audit-exclude': '   '},
        });
      final result = auditStringTable(arb);
      expect(result.auditList, contains('reviewedKey'));
      expect(
        result.findings,
        contains(contains('must contain a reviewed reason')),
      );
    });

    test('leading whitespace does not hide a placeholder', () {
      final arb = _pinnedSigned();
      arb['noSlicerOffline'] = '   TODO: write me';
      expect(
        auditStringTable(arb).findings,
        contains(contains('missing or a placeholder')),
      );
    });

    test('a pinned key can never be excluded from the audit', () {
      final arb = _pinnedSigned();
      arb['@noSlicerOffline']['x-audit-exclude'] = 'sneaky';
      final result = auditStringTable(arb);
      expect(result.isClean, isFalse);
      expect(result.auditList, contains('noSlicerOffline'));
      expect(result.findings, contains(contains('cannot be excluded')));
    });

    test('audit metadata must be free-text strings, never booleans', () {
      final arb = _pinnedSigned();
      arb['@noSlicerOffline']['x-audit-exclude'] = true;
      expect(
        auditStringTable(arb).findings,
        contains(contains('never a boolean')),
      );
    });

    test('a pinned key absent from the ARB is a finding', () {
      final arb = _pinnedSigned()
        ..remove('noSlicerQuotaExhausted')
        ..remove('@noSlicerQuotaExhausted');
      final result = auditStringTable(arb);
      expect(
        result.findings,
        contains(
          contains('noSlicerQuotaExhausted: pinned no-Slicer key is absent'),
        ),
      );
    });

    test('a non-object metadata block is a finding', () {
      final arb = _pinnedSigned();
      arb['@noSlicerOffline'] = 'not an object';
      expect(
        auditStringTable(arb).findings,
        contains(contains('not an object')),
      );
    });
  });

  group('auditArbFile', () {
    test('the shipped ARB passes with every pinned key signed', () {
      final result = auditArbFile('lib/l10n/app_es.arb');
      expect(result.isClean, isTrue);
      for (final pinned in pinnedNoSlicerKeys) {
        expect(result.keys, contains(pinned));
      }
    });

    test('invalid JSON becomes a finding, not a crash', () {
      final root = _makeTemp('json');
      final dir = Directory('${root.path}/lib/l10n')
        ..createSync(recursive: true);
      File('${dir.path}/app_es.arb').writeAsStringSync('{ not json');
      final result = auditArbFile('${dir.path}/app_es.arb');
      expect(result.isClean, isFalse);
      expect(result.findings.first, contains('not valid JSON'));
    });
  });

  group('the executable', () {
    test('exits 1 for an unsigned pinned key and prints the finding', () async {
      final root = _arbRoot('cli_violating', {
        'noSlicerOffline': 'El móvil está sin conexión.',
        '@noSlicerOffline': {'description': 'no network'},
      });

      final result = await Process.run('dart', [
        'run',
        'tool/check_string_table_audit.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('lacks an x-signoff'));
      expect(result.stdout as String, contains('FAILED'));
    });

    test('exits 0, prints the audit list, for a signed table', () async {
      final root = _arbRoot('cli_clean', _pinnedSigned());

      final result = await Process.run('dart', [
        'run',
        'tool/check_string_table_audit.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('SM-C2 audit list'));
      expect(
        result.stdout as String,
        contains('string-table audit check passed'),
      );
    });
  });
}
