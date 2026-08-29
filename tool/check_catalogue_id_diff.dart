// ignore_for_file: avoid_print
//
// The catalogue id-continuity check (AD-23): catalogue ids are permanent
// once shipped, because `card_dealt` rows reference them — an id that
// disappears, or silently changes size, breaks every derived read model on
// an upgraded phone (the rotation, the coverage floor, FR-5's counter).
//
// `tool/catalogue_baseline.json` is the checked-in id→size snapshot of the
// shipped set. The check fails naming the id on any disappearance or size
// change; additions pass. The baseline is updated only in a commit
// deliberately evolving the catalogue — never to smuggle a removal or a
// re-size past this check (that is a human act, AD-23 renegotiation).
//
// The asset side is parsed by the core parser (the same delegation the
// floor check uses), so the check and the runtime loader cannot disagree
// about what a valid entry is; the baseline keeps a tolerant minimal
// reader, plus a domain check on every size token so a typo like "huge"
// fails here instead of passing vacuously.
//
// Output contract (Story 1.1 AC 2): one `file:line: message` line per
// finding, exit 1 when any finding exists, exit 2 when an input file is
// missing. Registered under `make check` (NFR20); `runCheck` takes both
// paths so the fixture self-test can drive it directly.
import 'dart:convert';
import 'dart:io';

import 'package:core/catalogue/catalogue.dart';

import 'catalogue_shared.dart';
import 'check_core_purity.dart';

const String baselinePath = 'tool/catalogue_baseline.json';
const String assetPath = 'assets/evergreen/catalogue.json';

const Set<String> _sizeTokens = {'instant', 'maintenance', 'focus'};

int _lineForId(String text, String id) {
  final probe = text.indexOf('"$id"');
  return probe == -1 ? 1 : lineOf(text, probe);
}

/// Diffs the id→size snapshot in [baselineSource] against the asset in
/// [assetSource]. Pure: tests feed fixture contents directly. Findings
/// point at the baseline file — the file a deliberate evolution edits.
List<Finding> diffBaseline({
  required String baselineFile,
  required String baselineSource,
  required String assetFile,
  required String assetSource,
}) {
  final findings = <Finding>[];
  final Map<String, String>? assetSizes = _assetIdSizes(
    assetFile,
    assetSource,
    findings,
  );
  if (assetSizes == null) {
    return findings;
  }
  final Object? baselineDecoded = _decodeOrReport(
    baselineFile,
    baselineSource,
    findings,
  );
  if (baselineDecoded is! Map<String, dynamic>) {
    if (baselineDecoded != null) {
      findings.add(
        Finding(
          baselineFile,
          1,
          'baseline top level is not a JSON object of id → size',
        ),
      );
    }
    return findings;
  }

  final ids = baselineDecoded.keys.toList()..sort();
  for (final id in ids) {
    final baselineSize = baselineDecoded[id];
    if (baselineSize is! String || !_sizeTokens.contains(baselineSize)) {
      findings.add(
        Finding(
          baselineFile,
          _lineForId(baselineSource, id),
          'entry "$id": baseline size ${jsonEncode(baselineSize)} is not '
          'one of instant, maintenance, focus',
        ),
      );
      continue;
    }
    if (!assetSizes.containsKey(id)) {
      findings.add(
        Finding(
          baselineFile,
          _lineForId(baselineSource, id),
          'entry "$id" disappeared from the asset — catalogue ids are '
          'permanent once shipped; update the baseline only in a commit '
          'deliberately evolving the catalogue (AD-23)',
        ),
      );
    } else if (assetSizes[id] != baselineSize) {
      findings.add(
        Finding(
          baselineFile,
          _lineForId(baselineSource, id),
          'entry "$id" changed size: baseline "$baselineSize" ≠ asset '
          '"${assetSizes[id]}" — re-sizing a shipped entry breaks '
          '`card_dealt` continuity (AD-23)',
        ),
      );
    }
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

Object? _decodeOrReport(String file, String source, List<Finding> findings) {
  try {
    return jsonDecode(source) as Object;
  } catch (error) {
    findings.add(Finding(file, 1, 'not valid JSON ($error)'));
    return null;
  }
}

/// Parses the asset with the core parser and returns id → size name, or
/// null when the asset does not parse (a finding is added; disappearances
/// measured against an unparseable asset would be noise).
Map<String, String>? _assetIdSizes(
  String assetFile,
  String assetSource,
  List<Finding> findings,
) {
  try {
    final catalogue = parseCatalogue(assetSource, nameOf: (_) => '');
    return {for (final entry in catalogue.entries) entry.id: entry.size.name};
  } on FormatException catch (error) {
    findings.add(
      Finding(
        assetFile,
        lineForEntryError(assetSource, error.message),
        error.message,
      ),
    );
    return null;
  }
}

/// Runs the check against the explicit [baseline] and [asset] paths,
/// printing one `file:line: message` line per finding. Returns the process
/// exit code: 0 clean, 1 findings, 2 an input file missing.
Future<int> runCheck(String baseline, String asset) async {
  final baselineFile = File(baseline);
  final assetFile = File(asset);
  if (!baselineFile.existsSync()) {
    stderr.writeln('baseline not found at $baseline');
    return 2;
  }
  if (!assetFile.existsSync()) {
    stderr.writeln('catalogue asset not found at $asset');
    return 2;
  }
  final findings = diffBaseline(
    baselineFile: baseline,
    baselineSource: baselineFile.readAsStringSync(),
    assetFile: asset,
    assetSource: assetFile.readAsStringSync(),
  );
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'catalogue id diff check FAILED: ${findings.length} finding(s) — '
      'ids are permanent once shipped (AD-23)',
    );
    return 1;
  }
  print('catalogue id diff check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  final baseline = args.isNotEmpty ? args.first : baselinePath;
  final asset = args.length > 1 ? args[1] : assetPath;
  exit(await runCheck(baseline, asset));
}
