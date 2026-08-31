import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_core_purity.dart';

/// Story 1.11 — the Silent-Rescheduler search (FR-14, AD-1) and the
/// shell mint census: masked scans of the app shell and the core for
/// rescheduling/postponement/lateness identifier segments — zero
/// findings, because nothing was assigned to a future day, so nothing
/// needs re-planning — plus the shell's write-path census: the card and
/// moment wire names appear nowhere in `lib/`, records over core
/// `LogEntryContent` are constructed only in the Dispenser's six
/// user-act append sites plus the session, settings and crash channels
/// the census maps enumerate, the adapter's store module owns the only
/// drift insert companions, and no pool-fact write exists outside the
/// adapter.
/// Masking reuses `tool/check_core_purity.dart`'s
/// `maskCommentsAndStrings` (the `test/tool/` import precedent), so
/// prose and string contents cannot move the identifier pins — only a
/// real identifier can.

/// Strips nested line and block comments — line structure preserved — so doc
/// prose mentioning a wire name cannot move the literal scans. Strings remain
/// intact while comments are found.
String _withoutComments(String source) {
  final out = source.split('');
  void blank(int index) {
    if (out[index] != '\n') {
      out[index] = ' ';
    }
  }

  var i = 0;
  while (i < source.length) {
    final quote = source[i];
    if (quote == "'" || quote == '"') {
      final triple =
          i + 2 < source.length &&
          source[i + 1] == quote &&
          source[i + 2] == quote;
      i += triple ? 3 : 1;
      while (i < source.length) {
        if (!triple && source[i] == r'\' && i + 1 < source.length) {
          i += 2;
          continue;
        }
        if (source[i] == quote &&
            (!triple ||
                (i + 2 < source.length &&
                    source[i + 1] == quote &&
                    source[i + 2] == quote))) {
          i += triple ? 3 : 1;
          break;
        }
        i++;
      }
      continue;
    }
    if (source[i] != '/' || i + 1 >= source.length) {
      i++;
      continue;
    }
    if (source[i + 1] == '/') {
      blank(i++);
      blank(i++);
      while (i < source.length && source[i] != '\n') {
        blank(i++);
      }
      continue;
    }
    if (source[i + 1] == '*') {
      var depth = 1;
      blank(i++);
      blank(i++);
      while (i < source.length && depth > 0) {
        if (i + 1 < source.length && source[i] == '/' && source[i + 1] == '*') {
          depth++;
          blank(i++);
          blank(i++);
        } else if (i + 1 < source.length &&
            source[i] == '*' &&
            source[i + 1] == '/') {
          depth--;
          blank(i++);
          blank(i++);
        } else {
          blank(i++);
        }
      }
      continue;
    }
    i++;
  }
  return out.join();
}

/// Every `.dart` file under [root], sorted — the forbidden-vocabulary
/// check's own walk.
List<File> _dartFilesUnder(String root) {
  final files = <File>[];
  void collect(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name != '.dart_tool') {
          collect(entity);
        }
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }

  collect(Directory(root));
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// The path of [file], `/`-separated.
String _key(File file) => file.path.replaceAll('\\', '/');

void main() {
  test(
    'the scan roots are present and non-trivial — no scan below runs vacuously',
    () {
      for (final root in ['lib', 'packages/core/lib']) {
        expect(Directory(root).existsSync(), isTrue, reason: '$root/ is gone');
      }
      expect(_dartFilesUnder('lib'), hasLength(greaterThanOrEqualTo(20)));
      expect(
        _dartFilesUnder('packages/core/lib'),
        hasLength(greaterThanOrEqualTo(10)),
      );
    },
  );

  test('comment stripping preserves syntax after comment-looking strings', () {
    final stripped = _withoutComments(
      "final url = 'https://example.invalid'; final cardDone = 1; "
      '/* outer /* inner */ outer */ final marker = 2;',
    );
    expect(stripped, contains('cardDone'));
    expect(stripped, contains('marker'));
  });

  test('no Silent Rescheduler exists: a masked scan of lib/ and '
      'packages/core/lib/ for rescheduling, postponement and lateness '
      'identifier segments finds zero (FR-14, AD-1)', () {
    // Every segment below was verified zero over masked lib/ and
    // packages/core/lib/ before being pinned. Deliberately omitted:
    // `late` (the Dart `late` modifier is a keyword in declaration
    // position, not lateness — the forbidden-vocabulary lint owns its
    // carve-out), `due` (substring-unsafe: it would match inside
    // unrelated identifiers), and `plan` (substring-matches the
    // Spanish *planta(s)* of the shipped gardening catalogue's
    // identifiers — a legitimate trip; the lint owns the two-segment
    // `dueDate` form). The lint itself owns the nine banned tokens;
    // this scan adds the rescheduler and Spanish stems it lacks.
    final pattern = RegExp(
      'reschedul|scheduler|postpon|overdue|missed|defer|assign'
      '|atrasad|vencid|aplazad|retras',
      caseSensitive: false,
    );
    final findings = <String>[];
    for (final root in ['lib', 'packages/core/lib']) {
      for (final file in _dartFilesUnder(root)) {
        final masked = maskCommentsAndStrings(file.readAsStringSync());
        for (final match in pattern.allMatches(masked)) {
          findings.add('${file.path}:${_lineOf(masked, match.start)}');
        }
      }
    }
    expect(
      findings,
      isEmpty,
      reason: 'nothing was assigned to a future day, so nothing needs re-planning — a rescheduler or postponement identifier in the shell or the core is the schema change FR-14 and NFR9 forbid',
    );
  });

  test("the shell mints no card rows: no card or moment wire-name literal, "
      'no kind constant outside the crash channel, and LogEntryRecord '
      'constructed over LogEntryContent only in the two sanctioned append '
      'sites (AD-3, AD-12, AD-25)', () {
    final sources = {
      for (final file in _dartFilesUnder('lib'))
        _key(file): _withoutComments(file.readAsStringSync()),
    };
    expect(sources, isNotEmpty);

    // The absolute ban, ten wire names wide: every user-act and
    // moment kind exists in the shell only inside the core's own
    // constants — a quoted wire name in lib/ is a minter that
    // bypasses the vocabulary. (crash_recorded is not banned here:
    // the crash channel's constant idiom is pinned below.)
    const bannedWireNames = [
      'card_done',
      'card_dealt',
      'card_skipped',
      'session_started',
      'session_ended',
      'session_extended',
      'app_opened',
      'setting_changed',
      'energy_set',
      'report_answered',
    ];
    final wireOffenders = <String>[];
    for (final entry in sources.entries) {
      for (final name in bannedWireNames) {
        for (final match in RegExp("['\"]$name['\"]").allMatches(entry.value)) {
          wireOffenders.add(
            '${entry.key}:${_lineOf(entry.value, match.start)}',
          );
        }
      }
    }
    expect(
      wireOffenders,
      isEmpty,
      reason: 'the shell may reference the kinds only through the core constants — a wire-name literal is a silent minter',
    );

    // The literal-scan machinery itself is anchored: the adapter's
    // one sanctioned string literal must be visible to it, so an
    // empty result can never mean a blind scanner.
    expect(
      RegExp("['\"]rowid['\"]")
          .allMatches(sources['lib/store/drift_store.dart'] ?? ''),
      isNotEmpty,
      reason:
          "the adapter's 'rowid' literal anchors the scan — a "
          'missing anchor means the scan went blind',
    );

    // The constant-based mint path: `cardDealt` as an identifier is
    // zero anywhere in the shell, and no `LogKind.card*` constant is
    // referenced at all (the one legal constant idiom is the crash
    // channel's `LogKind.crashRecorded`, pinned by name below).
    // `cardDone`/`cardSkipped` appear exactly twice in the shell —
    // the two core-command invocations in the sanctioned Dispenser
    // controller, each as a call — and `sessionExtend` exactly once,
    // the checkpoint's minter — which is the LogEntryContent path
    // this census exists to protect.
    final constantOffenders = <String>[];
    for (final entry in sources.entries) {
      for (final match in RegExp(
        r'\bcardDealt\b|LogKind\s*\.\s*card(Dealt|Done|Skipped)\b',
      ).allMatches(entry.value)) {
        constantOffenders.add(
          '${entry.key}:${_lineOf(entry.value, match.start)}',
        );
      }
    }
    expect(
      constantOffenders,
      isEmpty,
      reason: 'no card-kind identifier or constant reference exists in the shell — the crash channel\'s LogKind.crashRecorded is the one sanctioned constant',
    );
    final crashChannel = sources['lib/crash.dart'] ?? '';
    expect(
      RegExp(r'LogKind\s*\.\s*crashRecorded\b').allMatches(crashChannel),
      isNotEmpty,
      reason:
          'the crash channel\'s sanctioned constant idiom moved — '
          'renegotiate the census',
    );
    final dispenser = sources['lib/dispenser/dispenser_controller.dart'];
    expect(dispenser, isNotNull, reason: 'the sanctioned append site is gone');
    final dispenserSource = dispenser ?? '';
    expect(
      RegExp(r'\bcardDone\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core cardDone command invocation — the '
          'LogEntryContent path',
    );
    expect(
      RegExp(r'\bcardSkipped\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core cardSkipped command invocation — the '
          'LogEntryContent path',
    );
    expect(
      RegExp(r'\bsessionExtend\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core sessionExtend command invocation — the '
          'checkpoint extension\'s LogEntryContent path (Story 2.4)',
    );
    expect(
      RegExp(r'\benergySet\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core energySet command invocation — the check-in '
          'answer\'s LogEntryContent path (Story 2.5)',
    );

    // The append-site census, exact per file: `appendLogEntry` calls
    // (a receiver-dotted call, never the adapter's own
    // implementation) are, inside the Dispenser controller, its six
    // user-act append sites over core LogEntryContent — the two
    // answers, the pocket declaration (Story 2.2), the pause
    // (Story 2.3), the checkpoint extension (Story 2.4) and the
    // check-in answer (Story 2.5) — beside
    // the session and settings channels and AD-12's crash channel,
    // each mapped below; together, the only paths that can mint
    // user-act and session kinds. The exact counts pin an unlisted
    // call site even inside a sanctioned file; tear-offs
    // (`.appendLogEntry` without a call) are zero.
    final callCounts = <String, int>{};
    final contentCounts = <String, int>{};
    for (final entry in sources.entries) {
      final calls = RegExp(r'\.\s*appendLogEntry\s*\(')
          .allMatches(entry.value)
          .length;
      if (calls > 0) {
        callCounts[entry.key] = calls;
      }
      final overContent = RegExp(r'content\s*\.\s*kind\s*\.\s*name')
          .allMatches(entry.value)
          .length;
      if (overContent > 0) {
        contentCounts[entry.key] = overContent;
      }
    }
    expect(
      callCounts,
      {
        'lib/crash.dart': 1,
        'lib/dispenser/dispenser_controller.dart': 6,
        'lib/session/session_controller.dart': 1,
        'lib/settings/settings_controller.dart': 1,
      },
      reason:
          'the exact census of append sites changed — an unlisted '
          'construction site is a candidate silent minter; freeze it or '
          'renegotiate the census',
    );
    expect(
      contentCounts,
      {
        'lib/dispenser/dispenser_controller.dart': 6,
        'lib/session/session_controller.dart': 1,
        'lib/settings/settings_controller.dart': 1,
      },
      reason:
          'records constructed over core LogEntryContent exist '
          'only in the sanctioned append sites',
    );
    final tearOffs = <String>[];
    for (final entry in sources.entries) {
      for (final match in RegExp(
        r'\.\s*appendLogEntry\b(?!\s*\()',
      ).allMatches(entry.value)) {
        tearOffs.add('${entry.key}:${_lineOf(entry.value, match.start)}');
      }
    }
    expect(
      tearOffs,
      isEmpty,
      reason: 'an appendLogEntry tear-off is a write path this census cannot see — pin it or call it',
    );
  });

  test('the store module owns persistence: drift insert companions exist '
      'only in the adapter, and no pool-fact write exists outside it '
      '(AD-2, AD-21)', () {
    final storeSources = {
      for (final file in _dartFilesUnder('lib/store'))
        if (!file.path.endsWith('.g.dart'))
          _key(file): _withoutComments(file.readAsStringSync()),
    };
    expect(storeSources, isNotEmpty);

    // The adapter's own sanctioned insert sites: exactly one log
    // companion and one pool companion, both in drift_store.dart.
    // (Generated `*.g.dart` files are drift's own table machinery,
    // regenerated by `make codegen` — not a write path anyone
    // hand-edits, so the census reads hand-written code only.)
    final companionCounts = <String, int>{};
    for (final entry in storeSources.entries) {
      final inserts = RegExp(
        r'(LogEntriesCompanion|PoolFactsCompanion)\s*\.\s*insert\s*\(',
      ).allMatches(entry.value).length;
      if (inserts > 0) {
        companionCounts[entry.key] = inserts;
      }
    }
    expect(
      companionCounts,
      {'lib/store/drift_store.dart': 2},
      reason:
          'drift insert companions exist only inside the adapter, '
          'at its two sanctioned insert sites — a third companion or a '
          'second store module is a silent writer',
    );

    // No pool-fact write path exists in the shell at all: the only
    // `appendPoolFact` in lib/ is the adapter's own implementation
    // (an override declaration, no receiver), and zero call sites or
    // tear-offs reference it.
    final poolWrites = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _withoutComments(file.readAsStringSync());
      for (final match in RegExp(r'\.\s*appendPoolFact\b').allMatches(source)) {
        poolWrites.add('${_key(file)}:${_lineOf(source, match.start)}');
      }
    }
    expect(
      poolWrites,
      isEmpty,
      reason: 'no shell code calls or tears off appendPoolFact — pool facts enter the store through the adapter alone',
    );
    expect(
      RegExp(r'Future\s*<\s*void\s*>\s*appendPoolFact\s*\(')
          .allMatches(storeSources['lib/store/drift_store.dart'] ?? ''),
      hasLength(1),
      reason:
          'the adapter\'s appendPoolFact implementation anchors the '
          'scan — a missing anchor means the scan went blind',
    );
  });
}
