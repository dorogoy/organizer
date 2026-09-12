import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_core_purity.dart';

/// Story 1.11 — the Silent-Rescheduler search (FR-14, AD-1) and the
/// shell mint census: masked scans of the app shell and the core for
/// rescheduling/postponement/lateness identifier segments — zero
/// findings, because nothing was assigned to a future day, so nothing
/// needs re-planning — plus the shell's write-path census: the card and
/// moment wire names appear nowhere in `lib/`, records over core
/// `LogEntryContent` are constructed only in the Dispenser's seven
/// user-act append sites plus the session, settings, capture, scan and
/// genesis channels the census maps enumerate, the adapter's store
/// module owns the only drift insert companions, and the pool-fact
/// writes the shell owns are the capture channel's, the rescue
/// landing's and the scan and genesis landings' single sanctioned
/// appends each (the adapter apart, nothing else calls
/// `appendPoolFact`).
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
    // unrelated identifiers), `plan` (substring-matches the
    // Spanish *planta(s)* of the shipped gardening catalogue's
    // identifiers — a legitimate trip; the lint owns the two-segment
    // `dueDate` form), and — since Story 5.13 — `missed`, now as the
    // word-bounded `\bmissed\b` alternative: it matches a bare
    // `missed` token while the `missed` inside `suggestion_dismissed`
    // / `suggestionDismissed` / the dismiss paths never trips it
    // (word characters bound both sides there), so the scan keeps
    // its own independent `missed` coverage instead of leaning on
    // the segment-aware lint. The lint itself owns
    // the nine banned tokens; this scan adds the rescheduler and
    // Spanish stems it lacks.
    final pattern = RegExp(
      'reschedul|scheduler|postpon|overdue|\\bmissed\\b|defer|assign'
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

  test('slack appears on no surface: a masked scan of lib/ui and the raw '
      'string table for buffer, slack and remaining-days vocabulary finds '
      'zero (FR-13, §1.1 P4, Story 5.10)', () {
    // The buffer derivation (core's epicBufferedTargets, Story 5.10)
    // is invisible-by-position, not unnameable: the words stay legal
    // in the core and illegal on every surface — which is the entire
    // doctrine of the invisible buffer. The scan therefore reads the
    // surfaces alone: lib/ui (strings intact — user-visible copy is
    // exactly what must not carry the vocabulary — comments stripped,
    // so prose cannot move the pin; the identifier channels are
    // covered too, since a daysRemaining variable is as visible as a
    // string) and the lib/l10n/*.arb string table — parsed, its KEYS
    // (they name the generated accessors) and RENDERED VALUES
    // scanned, its `@`-translator prose exempt.
    // `image_cap`'s byte buffers (lib/egress) live outside the scope:
    // a JPEG read buffer is not slack. Deliberately omitted:
    // `progreso|progress` — AD-26's achievement figures may
    // legitimately name cumulative achievement later, and that is a
    // different doctrine from remaining-time slack.
    expect(
      Directory('lib/ui').existsSync(),
      isTrue,
      reason: 'lib/ui/ is gone — the surface scan would run vacuously',
    );
    expect(
      Directory('lib/l10n').existsSync(),
      isTrue,
      reason: 'lib/l10n/ is gone — the string table scan would run vacuously',
    );
    final uiFiles = _dartFilesUnder('lib/ui');
    expect(
      uiFiles,
      hasLength(greaterThanOrEqualTo(20)),
      reason: 'the UI tree shrank below a non-trivial surface count',
    );
    final arbFiles = Directory('lib/l10n')
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .toList();
    expect(arbFiles, isNotEmpty, reason: 'no string table to scan');

    // Every segment below was verified zero over the masked surfaces
    // before being pinned — Spanish and English, identifiers and
    // strings alike. Stems, not words, so the whole family trips:
    // `restan` catches «restante» and «Te restan», `venc` catches
    // «vence/vencerá/vencimiento/vencid», `atras` catches
    // «atraso/atrasad@», `remaining` catches `daysRemaining` and the
    // core's own `remainingSteps` term should it ever leak to a
    // surface, `deadline` the English loan. `progreso|progress` stays
    // out (AD-26's achievement figures) and `horizonte|horizon` too
    // (a neutral word the achievement surfaces may someday own).
    final pattern = RegExp(
      'buffer|slack|holgura|restan|quedan|faltan|plazo|venc|atras'
      '|remaining|deadline',
      caseSensitive: false,
    );
    // A positive control for every alternative, so removing one branch
    // from the RegExp cannot pass the pin while that vocabulary family
    // goes unscanned.
    for (final sample in [
      'buffer',
      'slack',
      'holgura',
      'Te restan 3 pasos',
      'quedan 3 pasos',
      'faltan 3 pasos',
      'plazo',
      'vencimiento',
      'atraso',
      'daysRemaining',
      'deadline',
    ]) {
      expect(
        pattern.hasMatch(sample),
        isTrue,
        reason: 'positive control missing for "$sample"',
      );
    }
    final findings = <String>[];
    for (final file in uiFiles) {
      final masked = _withoutComments(file.readAsStringSync());
      for (final match in pattern.allMatches(masked)) {
        findings.add(
          '${_key(file)}:${_lineOf(masked, match.start)}:'
          ' ${match.group(0)}',
        );
      }
    }
    // The string table's leg reads KEYS and RENDERED VALUES only:
    // parsed as JSON, every `@`-metadata entry is skipped. Translator
    // prose is where this vocabulary law is *stated* — e.g.
    // `@pocketTrigger`'s "never remaining minutes" — never where it
    // renders; a key name leaks into the generated accessors, a
    // value renders on screen, and both stay under the scan.
    for (final file in arbFiles) {
      final table = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in table.entries) {
        if (entry.key.startsWith('@')) {
          continue;
        }
        final scanned = '${entry.key} ${entry.value}';
        for (final match in pattern.allMatches(scanned)) {
          findings.add('${_key(file)}:${entry.key}: ${match.group(0)}');
        }
      }
    }
    expect(
      findings,
      isEmpty,
      reason:
          'slack must appear on no surface — no bar, no percentage, no '
          'days-remaining, no configuration row; a buffer or slack '
          'string on a UI surface or in the string table is a visible '
          'buffer, which FR-13 forbids',
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

    // The ban list, eighteen wire names wide — deliberately not
    // exhaustive by kind: the scan chain's `consent_granted`,
    // `consent_declined` and `scan_abandoned` rows are minted only
    // through the core's sanctioned minters and are fenced by the
    // exact per-file append census and the `scanAbandoned(` ×1
    // invocation pin below instead (Story 5.6's recorded decision —
    // `bannedWireNames` unchanged). Since Story 5.13 the list also
    // carries `suggestion_dismissed` — the strongest fence, chosen
    // over fence-by-pin-only: the dismissal is the one strip row a
    // future copy-paste could carry into the shell verbatim, and the
    // ban plus the ×1 invocation pin below fence both halves at once.
    // What the list does claim: every
    // wire name it carries — the user-act and moment kinds it lists,
    // the `permission_refused` system event since Story 3.4, the
    // three `slice_*` rescue rows since 4.6, the `face_refused` scan
    // row since 5.2 — exists in the shell only inside the core's own
    // constants: a quoted wire name in lib/ is a minter that
    // bypasses the vocabulary.
    // (crash_recorded is not banned here: the crash channel's constant
    // idiom is pinned below.)
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
      'capture_created',
      'permission_refused',
      'slice_requested',
      'slice_returned',
      'slice_failed',
      'face_refused',
      'cluster_curation_changed',
      'suggestion_dismissed',
      // Story 7.1: the reward's two album-mutation rows — minted only
      // through the core's sanctioned minters, fenced by wire ban plus
      // the invocation pins below (the strongest fence, the dismissal
      // row's own precedent).
      'before_saved',
      'album_entry_added',
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
    expect(
      RegExp(r'\breportAnswered\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core reportAnswered command invocation — the '
          'report answer\'s LogEntryContent path (Story 2.6)',
    );
    expect(
      RegExp(r'\brescueRequested\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core rescueRequested command invocation — the '
          'rescue activation\'s LogEntryContent path (Story 4.6)',
    );
    expect(
      RegExp(r'\brescueReturned\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core rescueReturned command invocation — the '
          'rescue landing\'s LogEntryContent path (Story 4.6)',
    );
    expect(
      RegExp(r'\brescueFailed\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core rescueFailed command invocation — the '
          'rescue failure\'s LogEntryContent path (Story 4.6)',
    );
    final capture = sources['lib/capture/capture_controller.dart'];
    expect(capture, isNotNull, reason: 'the capture channel is gone');
    final captureSource = capture ?? '';
    expect(
      RegExp(r'\bcaptureCreate\s*\(').allMatches(captureSource),
      hasLength(1),
      reason:
          'exactly one core captureCreate command invocation — the '
          'capture channel\'s LogEntryContent path (Story 3.2)',
    );
    final dictation = sources['lib/capture/dictation_controller.dart'];
    expect(dictation, isNotNull, reason: 'the dictation channel is gone');
    final dictationSource = dictation ?? '';
    expect(
      RegExp(r'\bpermissionRefuse\s*\(').allMatches(dictationSource),
      hasLength(1),
      reason:
          'exactly one core permissionRefuse command invocation — the '
          'dictation channel\'s LogEntryContent path (Story 3.4)',
    );
    final scan = sources['lib/scan/scan_controller.dart'];
    expect(scan, isNotNull, reason: 'the scan channel is gone');
    final scanSource = scan ?? '';
    expect(
      RegExp(r'\bpermissionRefuse\s*\(').allMatches(scanSource),
      hasLength(1),
      reason:
          'exactly one core permissionRefuse command invocation — the '
          'scan channel\'s single refusal wrapper, serving both camera '
          'attempts (the open\'s, Story 5.2, and the Before-offer\'s '
          'denied open, Story 7.1)',
    );
    expect(
      RegExp(r'\bfaceRefused\s*\(').allMatches(scanSource),
      hasLength(1),
      reason:
          'exactly one core faceRefused command invocation — the scan '
          'channel\'s face refusal (Story 5.2)',
    );
    expect(
      RegExp(r'\bscanAbandoned\s*\(').allMatches(scanSource),
      hasLength(1),
      reason:
          'exactly one core scanAbandoned command invocation — the scan '
          'channel\'s wait abandonment, minted only by close() through the '
          '_appendScanAbandoned wrapper on the shared content copier '
          '(Story 5.6)',
    );
    expect(
      RegExp(r'\bscanSliceFailed\s*\(').allMatches(scanSource),
      hasLength(1),
      reason:
          'exactly one core scanSliceFailed command invocation — the '
          'scan channel\'s single sanctioned failure row, minted only '
          'through the _appendScanSliceFailed wrapper on the shared '
          'content copier (Story 5.7)',
    );
    expect(
      RegExp(r'\bepicActivated\s*\(').allMatches(scanSource),
      hasLength(1),
      reason:
          'exactly one core epicActivated command invocation — the '
          'scan channel\'s landing, minted only after the fact loop '
          'inside _appendScanLanded (Story 5.9)',
    );
    final genesis = sources['lib/genesis/genesis_controller.dart'];
    expect(genesis, isNotNull, reason: 'the genesis channel is gone');
    final genesisSource = genesis ?? '';
    expect(
      RegExp(r'\bconsentGranted\s*\(').allMatches(genesisSource),
      hasLength(1),
      reason:
          'exactly one core consentGranted command invocation — the '
          'genesis channel\'s consent act row, the scan channel\'s own '
          'minter (Story 5.8)',
    );
    expect(
      RegExp(r'\bscanAbandoned\s*\(').allMatches(genesisSource),
      hasLength(1),
      reason:
          'exactly one core scanAbandoned command invocation — the '
          'genesis channel\'s wait abandonment, minted only by close() '
          'through the _appendScanAbandoned wrapper (Story 5.8, the scan '
          'channel\'s own minter)',
    );
    expect(
      RegExp(r'\bscanSliceFailed\s*\(').allMatches(genesisSource),
      hasLength(1),
      reason:
          'exactly one core scanSliceFailed command invocation — the '
          'genesis channel\'s single sanctioned failure row (Story 5.8, '
          'the scan channel\'s own minter)',
    );
    expect(
      RegExp(r'\bepicActivated\s*\(').allMatches(genesisSource),
      hasLength(1),
      reason:
          'exactly one core epicActivated command invocation — the '
          'genesis channel\'s landing, minted only after the fact loop '
          'inside _appendGenesisLanded (Story 5.9, the scan channel\'s '
          'own minter)',
    );
    final reward = sources['lib/reward/reward_controller.dart'];
    expect(reward, isNotNull, reason: 'the reward channel is gone');
    final rewardSource = reward ?? '';
    expect(
      RegExp(r'\balbumEntryAdded\s*\(').allMatches(rewardSource),
      hasLength(1),
      reason:
          'exactly one core albumEntryAdded command invocation — the '
          'saved pair\'s single sanctioned minter, riding the channel\'s '
          'shared content copier (Story 7.1)',
    );
    expect(
      RegExp(r'\bpermissionRefuse\s*\(').allMatches(rewardSource),
      hasLength(1),
      reason:
          'exactly one core permissionRefuse command invocation — the '
          'reward\'s own open carrying its denial row (Story 7.1, ruling '
          '1-B, the scan channel\'s own duty)',
    );
    expect(
      RegExp(r'\bbeforeSaved\s*\(').allMatches(scanSource),
      hasLength(1),
      reason:
          'exactly one core beforeSaved command invocation — the '
          'Before-offer\'s shot, the kind\'s single sanctioned minter, '
          'riding the scan channel\'s shared content copier (Story 7.1)',
    );

    final settingsChannel = sources['lib/settings/settings_controller.dart'];
    expect(settingsChannel, isNotNull, reason: 'the settings channel is gone');
    final settingsSource = settingsChannel ?? '';
    expect(
      RegExp(r'\bclusterCurationChanged\s*\(').allMatches(settingsSource),
      hasLength(1),
      reason:
          'exactly one core clusterCurationChanged command invocation — '
          'the settings channel\'s curation flip, the kind\'s single '
          'sanctioned minter (Story 5.11)',
    );
    expect(
      RegExp(r'\bsuggestionDismissed\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core suggestionDismissed command invocation — the '
          'seasonal suggestion\'s ✕, the kind\'s single sanctioned minter, '
          'riding the controller\'s shared content copier (Story 5.13)',
    );
    expect(
      RegExp(r'\bepicActivated\s*\(').allMatches(dispenserSource),
      hasLength(1),
      reason:
          'exactly one core epicActivated command invocation — the '
          'seasonal suggestion\'s accept tap, the landing paths\' own minter '
          'from the one new pinned call site (Story 5.13)',
    );

    // The append-site census, exact per file: `appendLogEntry` calls
    // (a receiver-dotted call, never the adapter's own
    // implementation) are, inside the Dispenser controller, its ONE
    // shared append helper over core LogEntryContent — the seven
    // user-act write paths of Stories 1.9–2.6 plus, since Story 4.6,
    // the rescue channel's activation and landing rows, all through
    // the same copier — beside the session, settings and capture
    // channels, the dictation channel's refusal append (Story 3.4)
    // and AD-12's crash channel, each mapped below; together, the
    // only paths that can mint user-act and session kinds. The exact
    // counts pin an unlisted call site even inside a sanctioned
    // file; tear-offs (`.appendLogEntry` without a call) are zero.
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
        'lib/capture/capture_controller.dart': 1,
        'lib/capture/dictation_controller.dart': 1,
        'lib/crash.dart': 1,
        'lib/dispenser/dispenser_controller.dart': 1,
        'lib/session/session_controller.dart': 1,
        // Story 4-4 grows the settings channel's append sites to
        // two: the Time Bag's int row and the selected provider's
        // text row, both through the same sanctioned minter. Story
        // 5.2 folds them into the channel's one shared content
        // copier (the dispenser's own idiom) and adds the camera
        // toggle's row beside them — one site, three rows. Story 5.11
        // adds the curation flip's row through the same copier —
        // four rows, still one site (the census maps stay unchanged).
        'lib/settings/settings_controller.dart': 1,
        // Story 5.2: the scan channel's two refusal rows — the
        // camera permission refusal and the face refusal — through
        // one shared content copier. Story 5.9 adds a second site: the
        // landing's own `epic_activated` append, inline in
        // `_appendScanLanded` beside its `appendPoolFact` calls rather
        // than through the shared copier (the landing already builds
        // its fact records inline; the activation row follows the same
        // local idiom).
        'lib/scan/scan_controller.dart': 2,
        // Story 5.8: the genesis channel's rows — the consent act,
        // the wait's abandonment, the failure arms — through one
        // shared content copier of its own. Story 5.9 adds the same
        // second site as the scan channel's: the landing's own
        // `epic_activated` append, inline in `_appendGenesisLanded`.
        'lib/genesis/genesis_controller.dart': 2,
        // Story 7.1: the reward channel's own rows — the After shot's
        // `album_entry_added` append and a denied open's camera
        // refusal — through one shared content copier of its own.
        'lib/reward/reward_controller.dart': 1,
      },
      reason:
          'the exact census of append sites changed — an unlisted '
          'construction site is a candidate silent minter; freeze it or '
          'renegotiate the census',
    );
    expect(
      contentCounts,
      {
        'lib/capture/capture_controller.dart': 1,
        'lib/capture/dictation_controller.dart': 1,
        'lib/dispenser/dispenser_controller.dart': 1,
        'lib/session/session_controller.dart': 1,
        'lib/settings/settings_controller.dart': 1,
        'lib/scan/scan_controller.dart': 2,
        'lib/genesis/genesis_controller.dart': 2,
        'lib/reward/reward_controller.dart': 1,
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

    // No pool-fact write path exists in the shell besides the capture
    // channel and the three Slicer landings: the only `appendPoolFact`
    // calls in lib/ are the capture controller's single sanctioned
    // append (Story 3.2 — the pool's first writer, one fact then the
    // entry referencing it), the Dispenser controller's single
    // sanctioned append (Story 4.6 — the rescue steps' landing, the
    // facts the `slice_returned` row names), the scan controller's
    // single sanctioned append (Story 5.7 — the delivered scan's step
    // facts, one call inside the landing loop over the core's seeds)
    // and the genesis controller's single sanctioned append (Story
    // 5.8 — the delivered typed slice's step facts, the same landing
    // loop over the same seeds); the adapter's own implementation is
    // an override declaration with no receiver, and zero other call
    // sites or tear-offs reference it.
    final poolWrites = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final source = _withoutComments(file.readAsStringSync());
      if (_key(file) == 'lib/capture/capture_controller.dart') {
        // The capture channel's own sanctioned call, pinned by count.
        expect(
          RegExp(r'\.\s*appendPoolFact\s*\(').allMatches(source),
          hasLength(1),
          reason:
              'the capture channel holds exactly one pool-fact append — '
              'a second would be a silent writer',
        );
        continue;
      }
      if (_key(file) == 'lib/dispenser/dispenser_controller.dart') {
        // The rescue channel's own sanctioned call, pinned by count
        // (Story 4.6): the step facts the landing mints.
        expect(
          RegExp(r'\.\s*appendPoolFact\s*\(').allMatches(source),
          hasLength(1),
          reason:
              'the rescue channel holds exactly one pool-fact append — '
              'the steps'
              ' landing; a second would be a silent writer',
        );
        continue;
      }
      if (_key(file) == 'lib/scan/scan_controller.dart') {
        // The scan channel's own sanctioned call, pinned by count
        // (Story 5.7): the delivered slice's step facts, one append
        // inside the landing loop over the core's seeds.
        expect(
          RegExp(r'\.\s*appendPoolFact\s*\(').allMatches(source),
          hasLength(1),
          reason:
              'the scan channel holds exactly one pool-fact append — '
              'the delivered steps landing; a second would be a silent '
              'writer',
        );
        continue;
      }
      if (_key(file) == 'lib/genesis/genesis_controller.dart') {
        // The genesis channel's own sanctioned call, pinned by count
        // (Story 5.8): the delivered typed slice's step facts, one
        // append inside the same landing loop over the same seeds.
        expect(
          RegExp(r'\.\s*appendPoolFact\s*\(').allMatches(source),
          hasLength(1),
          reason:
              'the genesis channel holds exactly one pool-fact append '
              '— the delivered steps landing; a second would be a '
              'silent writer',
        );
        continue;
      }
      for (final match in RegExp(r'\.\s*appendPoolFact\b').allMatches(source)) {
        poolWrites.add('${_key(file)}:${_lineOf(source, match.start)}');
      }
    }
    expect(
      poolWrites,
      isEmpty,
      reason:
          'no shell code outside the capture channel calls or tears off '
          'appendPoolFact — pool facts enter the store through the adapter '
          'and the capture channel alone',
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
