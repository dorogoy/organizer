// ignore_for_file: avoid_print
//
// AD-15's SM-C2 audit rule, as a build-time check.
//
// The audit list is every key in the shipped ARB minus the keys carrying an
// explicit `x-audit-exclude` — so silence ADDS a string to the audit rather
// than omitting one. The seven FR-29 no-Slicer strings and their
// single exit (`noSlicerExit`, Story 4-5) are pinned by key and
// must carry BOTH a non-placeholder value AND an `x-signoff` reviewer
// marker inside their `@key` block: existence and review are separate
// gates.
//
// Per-key audit metadata lives inside each key's `@key` block in
// `app_es.arb` itself — never a second file — as free-text strings
// (`"<name>, <date>"` / `"<reason>"`), never booleans, so existence and
// review stay separately verifiable (AD-15, AD-21).
//
// Output: the computed audit list (the review surface for SM-C2's
// "guilt events = 0"), then pass/fail. Exit 1 on any violation.
import 'dart:convert';
import 'dart:io';

const String arbPath = 'lib/l10n/app_es.arb';

/// The seven FR-29 no-Slicer strings plus their single exit, pinned by
/// key. A cause's string (or the exit's) missing, empty,
/// placeholder-shaped, or unsigned fails the build.
const Set<String> pinnedNoSlicerKeys = {
  'noSlicerNoKey',
  'noSlicerInvalidKey',
  'noSlicerQuotaExhausted',
  'noSlicerUnreachable',
  'noSlicerOffline',
  'noSlicerConsentDeclined',
  'personInFrame',
  'noSlicerExit',
};

final RegExp _signoffShape = RegExp(r'^([^,]+),\s*(\d{4}-\d{2}-\d{2})$');

/// A sign-off date must be a real calendar date, exactly formatted —
/// `2026-13-45` matches the shape regex but is not a review anyone made.
bool _isValidSignoffDate(String date) {
  final parsed = DateTime.tryParse(date);
  // tryParse normalizes impossible dates (2026-02-30 → March 2), so a
  // prefix round-trip rejects them while accepting real ones.
  return parsed != null && parsed.toIso8601String().startsWith(date);
}

final RegExp _placeholderShape = RegExp(
  r'^(?:\s*|\.{3,}|TODO.*|FIXME.*|TBD.*|XXX.*|WIP.*|lorem .*|xxx.*|pending.*)$',
  caseSensitive: false,
);

class AuditResult {
  AuditResult({
    required this.keys,
    required this.auditList,
    required this.findings,
  });

  /// Every string key in the ARB.
  final List<String> keys;

  /// Every key minus those carrying `x-audit-exclude` — the SM-C2 audit
  /// list, computed so silence adds to it.
  final List<String> auditList;

  final List<String> findings;

  bool get isClean => findings.isEmpty;
}

AuditResult auditStringTable(Map<String, dynamic> arb) {
  final findings = <String>[];
  final keys = <String>[];
  final auditList = <String>[];

  arb.forEach((key, value) {
    if (key.startsWith('@')) {
      return;
    }
    keys.add(key);
    final metadata = arb['@$key'];
    if (metadata != null && metadata is! Map<String, dynamic>) {
      findings.add('@$key: metadata block is not an object');
      auditList.add(key);
      return;
    }
    final meta = metadata as Map<String, dynamic>?;

    // Audit metadata is free-text strings, never booleans.
    for (final field in const ['x-signoff', 'x-audit-exclude']) {
      final entry = meta?[field];
      if (entry != null && entry is! String) {
        findings.add(
          '@$key.$field must be a free-text string, never a boolean '
          '(AD-15, AD-21)',
        );
      }
    }

    final excluded = meta?['x-audit-exclude'];
    if (excluded is String) {
      if (excluded.trim().isEmpty) {
        findings.add('@$key.x-audit-exclude must contain a reviewed reason');
      } else {
        if (pinnedNoSlicerKeys.contains(key)) {
          findings.add(
            '$key: a pinned no-Slicer key cannot be excluded from the '
            'SM-C2 audit (AD-15)',
          );
        } else {
          // Explicitly reviewed exclusion — the only way off the audit list.
          return;
        }
      }
    }
    auditList.add(key);

    if (pinnedNoSlicerKeys.contains(key)) {
      final text = value;
      if (text is! String || _placeholderShape.hasMatch(text.trim())) {
        findings.add(
          '$key: pinned no-Slicer string is missing or a '
          'placeholder (AD-15)',
        );
      }
      final signoff = meta?['x-signoff'];
      if (signoff is! String || signoff.trim().isEmpty) {
        findings.add(
          '@$key: pinned no-Slicer key lacks an x-signoff reviewer marker '
          '"<name>, <date>" (AD-15)',
        );
      } else {
        final trimmedSignoff = signoff.trim();
        final comma = trimmedSignoff.indexOf(',');
        final shape = _signoffShape.firstMatch(trimmedSignoff);
        if (comma >= 0 && trimmedSignoff.substring(0, comma).trim().isEmpty) {
          findings.add('@$key: x-signoff reviewer name is empty (AD-15)');
        } else if (shape == null) {
          findings.add(
            '@$key: x-signoff "$signoff" is not "<name>, <date>" (AD-15)',
          );
        } else if (!_isValidSignoffDate(shape.group(2)!)) {
          findings.add(
            '@$key: x-signoff date "${shape.group(2)}" is not a real '
            'calendar date (AD-15)',
          );
        }
      }
    }
  });

  for (final pinned in pinnedNoSlicerKeys) {
    if (!keys.contains(pinned)) {
      findings.add('$pinned: pinned no-Slicer key is absent from the ARB');
    }
  }

  keys.sort();
  auditList.sort();
  findings.sort();
  return AuditResult(keys: keys, auditList: auditList, findings: findings);
}

AuditResult auditArbFile(String path) {
  final text = File(path).readAsStringSync();
  final Object decoded;
  try {
    decoded = jsonDecode(text);
  } catch (error) {
    return AuditResult(
      keys: const [],
      auditList: const [],
      findings: ['$path: not valid JSON ($error)'],
    );
  }
  if (decoded is! Map<String, dynamic>) {
    return AuditResult(
      keys: const [],
      auditList: const [],
      findings: ['$path: top level is not a JSON object'],
    );
  }
  return auditStringTable(decoded);
}

Future<int> runCheck([String repoRoot = '']) async {
  final path = repoRoot.isEmpty ? arbPath : '$repoRoot/$arbPath';
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('ARB not found at $path');
    return 2;
  }
  final result = auditArbFile(path);

  print(
    'SM-C2 audit list (${result.auditList.length} of '
    '${result.keys.length} keys):',
  );
  for (final key in result.auditList) {
    final pinned = pinnedNoSlicerKeys.contains(key) ? '  [pinned]' : '';
    print('  $key$pinned');
  }

  for (final finding in result.findings) {
    print(finding);
  }
  if (!result.isClean) {
    print(
      'string-table audit check FAILED: ${result.findings.length} finding(s)',
    );
    return 1;
  }
  print('string-table audit check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}
