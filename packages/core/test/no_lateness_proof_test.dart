import 'dart:io';

import 'package:core/log/log_entry.dart';
import 'package:test/test.dart';

/// Story 1.11 — the substrate's no-overdue proof (NFR9, FR-14): the
/// exact field set of every persisted and derived shape, frozen against
/// its own source by the house precedent (`facade_test.dart` reads its
/// own source; the substrate suite audits its exact columns). The
/// extraction regexes are naive about formatting on purpose — `dart
/// format` in the story gate is the stability guarantee — but never
/// about declaration forms: every way a field can be declared is
/// caught, and the extractor's own self-test pins that claim against a
/// synthetic source exercising every form. A failing freeze is a
/// deliberate renegotiation, never a test to bend.

/// The core lib tree, resolved for either invocation root: `dart test`
/// inside packages/core, or `flutter test packages/core/test/...` from
/// the repository root.
final String _libRoot = Directory('packages/core/lib').existsSync()
    ? 'packages/core/lib'
    : 'lib';

/// The repository root, resolved the same way — the anchor for pins
/// that must see across both lib trees (the core's and the shell's):
/// from the repository root it is here; from packages/core it is the
/// package's parent's parent.
final String _repoRoot = Directory('packages/core/lib').existsSync()
    ? '.'
    : '../..';

String _source(String path) => File('$_libRoot/$path').readAsStringSync();

/// A shell lib source, repo-root relative (`lib/...`) — the twin of
/// [_source] for the cross-tree censuses.
String _shellSource(String path) => File('$_repoRoot/$path').readAsStringSync();

/// Every `.dart` file under the shell's `lib/`, repo-root relative
/// and sorted — the census twin of [_coreLibFiles].
List<String> _shellLibFiles() {
  final files = <String>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .last;
        if (name != '.dart_tool') {
          walk(entity);
        }
      } else if (entity is File && entity.path.endsWith('.dart')) {
        // Normalize the invocation root away: `lib/...` either way
        // (the lister prefixes the walked path as given — `./lib`
        // from the repository root, `../../lib` from packages/core).
        final path = entity.path.replaceAll('\\', '/');
        files.add(path.replaceFirst(RegExp(r'^(\./|\.\./)+'), ''));
      }
    }
  }

  walk(Directory('$_repoRoot/lib'));
  return files..sort();
}

/// Strips nested line and block comments — line structure preserved — so
/// prose cannot move a pin. Strings remain intact while comments are found.
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

/// Blanks string-literal contents (newlines preserved) over an
/// already comment-stripped source, so a string like `'☹('` or `'{)'`
/// cannot skew the brace/paren depth walk. A naive quote scanner —
/// escapes skipped, unterminated literals recovered at end of line —
/// because the field extractor reads identifiers, and no field name
/// lives inside a string.
String _withoutStrings(String source) {
  final out = source.split('');
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c != "'" && c != '"') {
      i++;
      continue;
    }
    final triple =
        i + 2 < source.length && source[i + 1] == c && source[i + 2] == c;
    final quote = c;
    void blank(int index) {
      if (index < out.length && out[index] != '\n') {
        out[index] = ' ';
      }
    }

    final openEnd = triple ? i + 3 : i + 1;
    for (var b = i; b < openEnd; b++) {
      blank(b);
    }
    i = openEnd;
    while (i < source.length) {
      if (!triple && source[i] == r'\' && i + 1 < source.length) {
        blank(i);
        blank(i + 1);
        i += 2;
        continue;
      }
      if (source[i] == quote) {
        if (triple) {
          if (i + 2 < source.length &&
              source[i + 1] == quote &&
              source[i + 2] == quote) {
            blank(i);
            blank(i + 1);
            blank(i + 2);
            i += 3;
            break;
          }
        } else {
          blank(i);
          i++;
          break;
        }
      }
      if (source[i] == '\n' && !triple) {
        // An unterminated single-line literal (malformed input):
        // recover so the rest of the file still gets scanned.
        i++;
        break;
      }
      blank(i);
      i++;
    }
  }
  return out.join();
}

/// The extraction source of a file path: comments and string contents
/// both gone.
String _extractionSource(String path) => _extractionSourceOf(_source(path));

/// The extraction source of raw text: comments and string contents
/// both gone, so neither prose nor literal text can move a pin or a
/// depth counter.
String _extractionSourceOf(String raw) =>
    _withoutStrings(_withoutComments(raw));

/// The index of the first real assignment `=` in [line] — never `==`,
/// `=>`, `<=`, `>=`, `!=` or `~/=` — or -1 when the line assigns
/// nothing.
int _assignmentIndex(String line) {
  for (var i = 0; i < line.length; i++) {
    if (line[i] != '=') {
      continue;
    }
    final next = i + 1 < line.length ? line[i + 1] : '';
    final previous = i > 0 ? line[i - 1] : '';
    if (next == '=' ||
        next == '>' ||
        previous == '=' ||
        previous == '<' ||
        previous == '>' ||
        previous == '!' ||
        previous == '~') {
      continue;
    }
    return i;
  }
  return -1;
}

const Set<String> _fieldModifiers = {
  'late',
  'final',
  'var',
  'const',
  'static',
  'abstract',
  'external',
  'covariant',
};

final RegExp _trailingIdentifier = RegExp(r'[A-Za-z_]\w*\s*$');

/// Splits [text] on commas at nesting depth zero — parens, brackets,
/// braces and angle brackets all guard their inner commas — so
/// `Map<String, int>` and `void Function(int, String)` stay whole while
/// `int a = 1, b = 2` splits.
List<String> _splitTopLevelCommas(String text) {
  final parts = <String>[];
  var start = 0;
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    switch (text[i]) {
      case '(':
      case '[':
      case '{':
      case '<':
        depth++;
      case ')':
      case ']':
      case '}':
      case '>':
        depth--;
      case ',':
        if (depth == 0) {
          parts.add(text.substring(start, i));
          start = i + 1;
        }
    }
  }
  parts.add(text.substring(start));
  return parts;
}

/// Extracts every field name a member-level declaration declares, in
/// declaration order. Every form counts: `this.x` arrives pre-extracted
/// by the caller; uninitialized and initialized finals of any type
/// shape (primitives, generics, nullable, record-typed,
/// function-typed), `late final` and mutable fields, multi-declarators,
/// initializer-list entries, and formatter-wrapped declarations the
/// caller has already joined. Getters, setters and method signatures
/// declare nothing.
void _extractFieldNames(String candidate, void Function(String) add) {
  var text = candidate.trim();
  if (text.startsWith(':')) {
    // A wrapped initializer-list entry (`: x = 1,`) — the name is a
    // field.
    text = text.substring(1).trim();
  }
  if (text.isEmpty || RegExp(r'\b(get|set)\b').hasMatch(text)) {
    return;
  }
  // Split on top-level commas FIRST so multi-declarators (`int a = 1,
  // b = 2;`) keep every declarator — commas inside types, parameter
  // lists and initializers are depth-guarded and never split.
  for (final part in _splitTopLevelCommas(text)) {
    var piece = part.trim();
    if (piece.isEmpty) {
      continue;
    }
    final assignment = _assignmentIndex(piece);
    var left = assignment >= 0 ? piece.substring(0, assignment).trim() : piece;
    if (left.contains('(')) {
      // A `(` in the declaration is either a method/constructor
      // signature (`name(...)` — the tail after the last `)` is empty,
      // `async`, `{` or an arrow) or a function/record-typed field
      // whose name follows the type (`void Function(int) cb;` or
      // `({int year})? dueDay;` — the tail is an optional `?`, a bare
      // identifier, then the terminator). The tail decides; `async`/
      // `sync` without an initializer are method markers, never names.
      final lastParen = left.lastIndexOf(')');
      if (lastParen < 0) {
        continue;
      }
      final tail = left.substring(lastParen + 1);
      final field = RegExp(r'^\s*\??\s*([A-Za-z_]\w*)\s*(?:;|,|=|$)')
          .firstMatch(tail);
      final name = field?.group(1);
      if (field != null &&
          name != null &&
          !(assignment < 0 && (name == 'async' || name == 'sync'))) {
        add(name);
      }
      continue;
    }
    left = left.replaceFirst(RegExp(r'[;,]$'), '').trim();
    // Strip leading field modifiers; the type (whatever shape)
    // follows, and the field name is the identifier nearest the
    // terminator.
    while (true) {
      final head = RegExp(r'^\w+').firstMatch(left)?.group(0);
      if (head == null || head == left || !_fieldModifiers.contains(head)) {
        break;
      }
      left = left.substring(head.length).trim();
    }
    if (left.isEmpty) {
      continue;
    }
    final name = _trailingIdentifier.firstMatch(left)?.group(0);
    if (name != null) {
      add(name);
    }
  }
}

/// The class's own field names in source order, deduplicated: `this.x`
/// constructor parameters (member level, never inside method bodies),
/// constructor initializer-list assignments, uninitialized and
/// initialized `final` fields of any type shape, `late final` and
/// mutable instance fields, multi-declarators and formatter-wrapped
/// declarations. The brace-range scan runs over source with comments
/// AND string contents masked, fails loudly on unbalanced braces rather
/// than scanning to end-of-file, and refuses the class-alias form
/// (`class A = B with C;`) loudly instead of scanning the next class.
List<String> _classOwnFields(String className, String path) =>
    _classOwnFieldsOf(className, _extractionSource(path));

List<String> _classOwnFieldsOf(String className, String source) {
  final decl = RegExp('\\bclass $className\\b').firstMatch(source);
  expect(decl, isNotNull, reason: 'class $className not found in source');
  final remainder = source.substring(decl!.end);
  final toBrace = remainder.indexOf('{');
  final toSemicolon = remainder.indexOf(';');
  expect(
    toBrace,
    greaterThan(-1),
    reason: 'class $className has no body — malformed source',
  );
  expect(
    toSemicolon >= 0 && toSemicolon < toBrace,
    isFalse,
    reason:
        'class $className is a class alias (`class $className = … with …;`) '
        '— the extractor refuses to scan past it',
  );
  final open = decl.end + toBrace;
  var depth = 0;
  var end = -1;
  for (var i = open; i < source.length; i++) {
    if (source[i] == '{') {
      depth++;
    }
    if (source[i] == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  expect(
    end,
    greaterThan(-1),
    reason:
        'unbalanced braces in class $className — the freeze refuses to '
        'scan to end-of-file',
  );
  final body = source.substring(open, end + 1);

  final names = <String>[];
  void add(String name) {
    if (!names.contains(name)) {
      names.add(name);
    }
  }

  var braces = 0;
  var parens = 0;
  var brackets = 0;
  var buffer = '';

  /// Whether an accumulated candidate is still continuing: its openers
  /// are unbalanced, or it ends in a type shape (`>`, `,`, `?`) — an
  /// arrow (`=>`) never continues anything.
  bool continues(String candidate) {
    final opens =
        '('.allMatches(candidate).length +
        '['.allMatches(candidate).length +
        '{'.allMatches(candidate).length;
    final closes =
        ')'.allMatches(candidate).length +
        ']'.allMatches(candidate).length +
        '}'.allMatches(candidate).length;
    final arrow = candidate.endsWith('=>');
    final typeShaped =
        candidate.endsWith('>') ||
        candidate.endsWith(',') ||
        candidate.endsWith('?');
    return opens > closes || (!arrow && typeShaped);
  }

  for (final rawLine in body.split('\n')) {
    final line = rawLine.trim();
    final startBraces = braces;
    final startParens = parens;
    final startBrackets = brackets;
    final insideMethodBody = startBraces >= 2 && startParens == 0;

    // `this.x` parameters and one-line initializer lists name fields
    // wherever they sit at member level — inside a constructor's
    // parameter list (a paren depth is open) or on the class body's own
    // lines — never inside a method body, and never on an arrow-bodied
    // line (an expression body is not a declaration).
    if (!insideMethodBody && !line.contains('=>')) {
      for (final match in RegExp(r'\bthis\.(\w+)').allMatches(line)) {
        add(match.group(1)!);
      }
      final initializerColon = RegExp(r'\)\s*:').firstMatch(line);
      if (initializerColon != null) {
        for (final match in RegExp(
          r'(\w+)\s*=(?!=|>)',
        ).allMatches(line.substring(initializerColon.end))) {
          add(match.group(1)!);
        }
      }
    }

    for (var i = 0; i < line.length; i++) {
      switch (line[i]) {
        case '{':
          braces++;
        case '}':
          braces--;
        case '(':
          parens++;
        case ')':
          parens--;
        case '[':
          brackets++;
        case ']':
          brackets--;
      }
    }

    // While a declaration continues, every line belongs to it — member
    // level or not — until the accumulated candidate balances; that is
    // what carries constructor parameter lists, method bodies and
    // formatter-wrapped declarations whole. Otherwise only member-level
    // lines declare.
    String candidate;
    if (buffer.isNotEmpty) {
      candidate = '$buffer $line';
    } else if (startBraces == 1 && startParens == 0 && startBrackets == 0) {
      candidate = line.replaceAll(RegExp(r'^@\w+\s*'), '').trim();
      if (candidate.isEmpty || candidate == '{' || candidate == '}') {
        continue;
      }
    } else {
      continue;
    }
    if (continues(candidate)) {
      buffer = candidate;
      continue;
    }
    buffer = '';
    _extractFieldNames(candidate, add);
  }
  if (buffer.isNotEmpty) {
    _extractFieldNames(buffer, add);
  }
  return names;
}

/// The record typedef's field names in declaration order — one per
/// comma, so both shapes `dart format` writes (one field per line, or
/// a short typedef collapsed to a single line) read the same.
List<String> _recordFields(String path, String name) {
  final source = _withoutComments(_source(path));
  final decl = RegExp('typedef $name = \\(\\{').firstMatch(source);
  expect(decl, isNotNull, reason: 'typedef $name not found in $path');
  final end = source.indexOf('});', decl!.end);
  final body = _withoutComments(source.substring(decl.end, end));
  return [
    for (final field in body.split(','))
      if (field.trim().isNotEmpty) field.trim().split(RegExp(r'\s+')).last,
  ];
}

/// Every `.dart` file under the core lib tree, as a path relative to
/// it.
List<String> _coreLibFiles() {
  final files = <String>[];
  void collect(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        collect(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity.path.substring(_libRoot.length + 1));
      }
    }
  }

  collect(Directory(_libRoot));
  files.sort();
  return files;
}

void main() {
  test('the core lib tree is present and non-trivial — no scan below runs vacuously', () {
    expect(Directory(_libRoot).existsSync(), isTrue);
    expect(_coreLibFiles(), hasLength(greaterThanOrEqualTo(10)));
  });

  test('comment stripping preserves syntax after comment-looking strings', () {
    final stripped = _withoutComments(
      "final url = 'https://example.invalid'; final dueDay = 1; "
      '/* outer /* inner */ outer */ final marker = 2;',
    );
    expect(stripped, contains('dueDay'));
    expect(stripped, contains('marker'));
  });

  test('the extractor self-test: every declaration form a field can take '
      'is caught, and nothing else is — the completeness claim is pinned '
      'by a test that can fail', () {
    // A synthetic class held only inside this string literal (the
    // forbidden-vocabulary lint scans identifiers, and a string is
    // not one), exercising every form: this.x parameters, a one-line
    // initializer list, uninitialized nullable/generic/record-typed/
    // function-typed fields, an initialized generic tally, late
    // final, a mutable field, a multi-declarator, a formatter-wrapped
    // generic declaration, a string literal containing skew-shaped
    // punctuation, a getter, and a method body calling this.… —
    // which must NOT count.
    const kitchenSink = '''
final class KitchenSink {
  const KitchenSink({
    required this.id,
    this.callback,
  }) : seededNames = const [];

  final String id;

  final String? targetDay;

  final Map<String, int> missedDays = {};

  final ({int year, int month})? dueDay;

  final void Function(int) callback;

  final Map<String, int>
      wrappedNames;

  final void Function(
    int,
  ) wrappedCallback;

  late final int lazyAnchor;

  int mutableCount = 0;

  int a = 1, b = 2;

  final String glyph = '\\u2639(';

  String get label => 'x';

  void method() {
    this.methodHelper();
  }

  void methodHelper() {}
}
''';
    // The synthetic source goes through the same preparation a real
    // file does — comments and string contents masked — so the pinned
    // forms are read exactly as production source is.
    final extracted = _classOwnFieldsOf(
      'KitchenSink',
      _extractionSourceOf(kitchenSink),
    );
    expect(extracted, [
      'id',
      'callback',
      'seededNames',
      'targetDay',
      'missedDays',
      'dueDay',
      'wrappedNames',
      'wrappedCallback',
      'lazyAnchor',
      'mutableCount',
      'a',
      'b',
      'glyph',
    ]);
  });

  group('the frozen shapes (NFR9 — no field may express lateness)', () {
    test('PoolFact', () {
      // The pool fact carries no owner, no date-only value and no
      // assignment to a future day (AD-1, AD-14) — and, since Story
      // 3.2, the nullable Origin Context: a manual capture's own
      // single line, never a deadline any derivation could read. Since
      // Story 3.4 the nullable dictation boolean: a provenance fact
      // (who authored the line), outside origin arithmetic and never
      // an obligation. Since Story 4.6 the nullable rescue pair: the
      // parent a step rescues and the step's verbatim estimate — a
      // genesis fact and a duration, never a deferral. Since Story
      // 5.7 the nullable step text: a scan step's own words, the
      // task itself, never a deadline.
      expect(
        _classOwnFields('PoolFact', 'pool/pool_fact.dart'),
        equals([
          'id',
          'origin',
          'size',
          'instantUtcMicros',
          'offsetSeconds',
          'originContext',
          'dictated',
          'rescueOf',
          'estimateSeconds',
          'stepText',
        ]),
      );
    });

    test('LogEntry (base)', () {
      // Every entry carries only its id, its instant and its offset —
      // an entry asserts an act or an event, never an absence (AD-21).
      expect(
        _classOwnFields('LogEntry', 'log/log_entry.dart'),
        equals(['id', 'instantUtcMicros', 'offsetSeconds']),
      );
    });

    test('ItemActEntry', () {
      // A user act on a pool item: the kind and the referenced item's
      // id and origin — no count, no tally, no debt (AD-14, AD-21).
      expect(
        _classOwnFields('ItemActEntry', 'log/log_entry.dart'),
        equals(['kind', 'itemId', 'itemOrigin']),
      );
    });

    test('MomentEntry', () {
      // A moment in the product's life: the kind alone (AD-21). Since
      // Story 2.2 the family holds `session_ended` and `app_opened`
      // only — `session_started` carries the declared pocket and lives
      // in its own subtype below.
      expect(
        _classOwnFields('MomentEntry', 'log/log_entry.dart'),
        equals(['kind']),
      );
    });

    test('SessionStartEntry', () {
      // A session start: the kind and the declared pocket — a quantity
      // the user offered for this sitting, never an obligation, a
      // remainder or a close cause (Story 2.2, AD-19). An out-of-range
      // value stays in the log and derives as absent: tolerance, never
      // repair (AD-23).
      expect(
        _classOwnFields('SessionStartEntry', 'log/log_entry.dart'),
        equals(['kind', 'pocketMinutes']),
      );
    });

    test('SessionExtendEntry', () {
      // A checkpoint extension (Story 2.4, FR-10, AD-19): the minutes
      // the user added to the sitting's declared pocket, reusing the
      // pocket fact `session_started` already carries — no new column,
      // no schema bump (AD-23). `kind` extracts after the constructor
      // parameter because it is an initialized override.
      expect(
        _classOwnFields('SessionExtendEntry', 'log/log_entry.dart'),
        equals(['pocketMinutes', 'kind']),
      );
    });

    test('CrashEntry', () {
      // The crash payload is its stack and its pinned kind — and
      // nothing else rides along (AD-12; `kind` extracts after the
      // constructor parameter because it is an initialized override).
      expect(
        _classOwnFields('CrashEntry', 'log/log_entry.dart'),
        equals(['stack', 'kind']),
      );
    });

    test('SettingEntry', () {
      // The settings payload is its key and exactly one of its two
      // values — the int since 2.1, the text additively since 4.3
      // (AD-22: the selected provider, never a credential, never an
      // availability claim). The settings record is a derived cache
      // over these rows (AD-1). `kind` extracts after the
      // constructor parameters because it is an initialized
      // override.
      expect(
        _classOwnFields('SettingEntry', 'log/log_entry.dart'),
        equals(['key', 'value', 'textValue', 'kind']),
      );
    });

    test('UnknownEntry', () {
      // An unknown kind is carried verbatim: the kind alone (AD-23).
      expect(
        _classOwnFields('UnknownEntry', 'log/log_entry.dart'),
        equals(['kind']),
      );
    });

    test('EnergySetEntry', () {
      // The energy payload is the level and nothing else (Story 2.5,
      // FR-4): no session attribution, no source tag, no nag count —
      // the level is day-scoped in the derivation, never on the row.
      // `kind` extracts after the constructor parameters because it is
      // an initialized override.
      expect(
        _classOwnFields('EnergySetEntry', 'log/log_entry.dart'),
        equals(['level', 'kind']),
      );
    });

    test('ReportAnsweredEntry', () {
      // The weekly self-report payload is the tapped 1–5 answer and
      // the week it answers — the answered week's `Week.weekOrdinal`,
      // never a second week counter (Story 2.6, SM-2, AD-21) — and
      // nothing else rides the row: no question text, no dismissal
      // state, no notification fact. The week is a statement about
      // what was answered, never an obligation a week owes.
      // `kind` extracts after the constructor parameters because it is
      // an initialized override.
      expect(
        _classOwnFields('ReportAnsweredEntry', 'log/log_entry.dart'),
        equals(['value', 'week', 'kind']),
      );
    });

    test('PermissionRefusedEntry', () {
      // The permission-refusal payload is the refused permission and
      // its pinned kind — and nothing else rides along (Story 3.4,
      // FR-32, AD-17): no grant, no capability claim, no re-ask state
      // (AD-22's discipline), so no silent re-ask writer can grow from
      // the shape. `kind` extracts after the constructor parameters
      // because it is an initialized override.
      expect(
        _classOwnFields('PermissionRefusedEntry', 'log/log_entry.dart'),
        equals(['permission', 'kind']),
      );
    });

    test('SliceEntry', () {
      // The rescue channel's payload is the rescued item's pair, the
      // pinned kind and — on `slice_failed` alone — the port's closed
      // failure cause (Story 4.6, FR-5, AD-21): no prompt, no
      // delivered body, no provider and no pending state ride the row,
      // so no retry or queue writer can grow from the shape. `kind`
      // extracts after the constructor parameters because it is an
      // initialized override.
      expect(
        _classOwnFields('SliceEntry', 'log/log_entry.dart'),
        equals(['kind', 'itemId', 'itemOrigin', 'cause']),
      );
    });

    test('ScanConsent', () {
      // The consent token's own surface (Story 5.4, AD-8): the
      // binding to the scan's cache subdirectory identity and the
      // private one-way consumption state — and nothing else, so no
      // capability, timestamp or readable fact can ride the token.
      // Identity semantics are the contract: no equality, no
      // human-readable rendering, nothing reconstructible.
      expect(
        _classOwnFields('ScanConsent', 'ports/scan_consent.dart'),
        equals(['scanId', '_consumed']),
      );
    });

    test('ScanSliceRequest', () {
      // The scan request's own shape (Story 5.4, AD-8): the bytes,
      // the prompt, the in-memory scan identity and the required
      // consent token — and nothing else, so no nullable-consent or
      // `hasConsent` reshaping can pass silently: the precondition and
      // binding are compile-time plus dispatch-checked, and this census
      // is their census.
      expect(
        _classOwnFields('ScanSliceRequest', 'ports/slicer_port.dart'),
        equals(['imageBytes', 'prompt', 'scanId', 'consent']),
      );
    });

    test('ScanImagePrompt (the shell chokepoint)', () {
      // The payload's own shape (Story 5.4, AD-8), read from the
      // shell's egress module across the two lib trees: the same four
      // fields the port request carries — identity and token thread
      // through in memory, never serialize, and a nullable reshape
      // cannot pass silently here either.
      expect(
        _classOwnFieldsOf(
          'ScanImagePrompt',
          _extractionSourceOf(_shellSource('lib/egress/egress_payload.dart')),
        ),
        equals(['imageBytes', 'prompt', 'scanId', 'consent']),
      );
    });

    test('LogFacts', () {
      // The derived session states facts the log makes true — no
      // missed count, no debt, no deferral field (AD-1, AD-19, AD-25).
      // The two pocket facts (Story 2.2) are statements about what was
      // declared and answered inside the sitting, never about what is
      // owed: a spent pocket reads as a warm close, nothing else. The
      // charged dealt days (Story 3.3) are the deal window's only
      // input — statements about where deals charged, never about a
      // window's remainder. The charged skipped days and the carried
      // focus days (Story 4.6) are the refusal counter's input and the
      // rescue conversion's statement — where a decline landed and
      // which day's "1" a chain carries, never anything owed.
      expect(
        _classOwnFields('LogFacts', 'weave/session.dart'),
        equals([
          'lastDealtInstantByItemId',
          'focusSlotClosedDays',
          'dealtCountsByDay',
          'dealtDaysByItemId',
          'skippedDaysByItemId',
          'answeredItemIds',
          'openSessionStart',
          'dealtUnanswered',
          'openSessionPocketMinutes',
          'openSessionAnsweredSeconds',
          'focusSlotCarriedDays',
          'epicActivatedInstantByStableId',
        ]),
      );
    });

    test('Card', () {
      // The dealt card carries cost, name, origin and zone — no target
      // date rides along to the surface (AD-6).
      expect(
        _classOwnFields('Card', 'weave/weave.dart'),
        equals(['id', 'size', 'name', 'origin', 'zone', 'estimateSeconds']),
      );
    });

    test('DayComposition', () {
      // The composed day is today's derivation, never a stored plan
      // (AD-1).
      expect(
        _classOwnFields('DayComposition', 'weave/weave.dart'),
        equals(['focus', 'maintenance', 'instantHabits']),
      );
    });

    test('Candidate', () {
      // A work source's offering: identity, size, origin, zone,
      // precedence and — since Story 3.3 — the source's own creation
      // instant, the capture FIFO key. Since Story 4.6 a rescue step's
      // own verbatim estimate rides along, the duration-consuming
      // rules' number. No field may name a rescheduling role (AD-20),
      // and the instant is a recorded birth, never a target.
      expect(
        _classOwnFields('Candidate', 'weave/weave.dart'),
        equals([
          'itemId',
          'size',
          'name',
          'origin',
          'zone',
          'precedence',
          'createdInstantUtcMicros',
          'estimateSeconds',
        ]),
      );
    });

    test('CatalogueEntry', () {
      // The asset's four fields plus the resolved name — nothing else
      // may ride a shipped task (AD-16, FR-31).
      expect(
        _classOwnFields('CatalogueEntry', 'catalogue/catalogue.dart'),
        equals(['id', 'size', 'cadence', 'name', 'zone']),
      );
    });

    test('Catalogue', () {
      // A parsed catalogue is the version and the entries — read-only
      // by construction, never a work surface (AD-16).
      expect(
        _classOwnFields('Catalogue', 'catalogue/catalogue.dart'),
        equals(['version', 'entries']),
      );
    });

    test('Day', () {
      // The domestic day's label, weekday and bounds — the most
      // natural home of a date-only target field, which AD-1 forbids.
      expect(
        _classOwnFields('Day', 'day/calendar.dart'),
        equals([
          'year',
          'month',
          'day',
          'weekday',
          'offsetSeconds',
          'startUtcMicros',
          'endUtcMicros',
        ]),
      );
    });

    test('Week', () {
      // The week is its anchor Monday and its close — no per-week
      // target or tally may attach (AD-1, AD-4).
      expect(
        _classOwnFields('Week', 'day/calendar.dart'),
        equals(['monday', 'endUtcMicros']),
      );
    });

    test('Season', () {
      // The season's identity, frame and bounds — period math only,
      // no obligations ride a quarter (AD-4).
      expect(
        _classOwnFields('Season', 'day/calendar.dart'),
        equals([
          'kind',
          'anchorYear',
          'offsetSeconds',
          'startUtcMicros',
          'endUtcMicros',
        ]),
      );
    });

    test('PoolFactRecord', () {
      // The persisted pool DTO is field-identical to the domain fact —
      // the schema's exact columns, no more (AD-1, AD-5). The nullable
      // Origin Context column is schema v6's additive change (3.2);
      // the nullable dictation boolean is schema v7's (3.4); the
      // nullable rescue pair is schema v9's (4.6).
      expect(
        _recordFields('ports/store_port.dart', 'PoolFactRecord'),
        equals([
          'id',
          'origin',
          'size',
          'instantUtcMicros',
          'offsetSeconds',
          'originContext',
          'dictated',
          'rescueOf',
          'estimateSeconds',
          'stepText',
        ]),
      );
    });

    test('LogEntryRecord', () {
      // The persisted log DTO is field-identical to the entry shapes —
      // the schema's exact columns, no more (AD-1, AD-5). The two
      // nullable setting columns are schema v2's additive pair (2.1);
      // the nullable pocket column is schema v3's (2.2); the nullable
      // energy level column is schema v4's (2.5); the two nullable
      // report columns are schema v5's additive pair (2.6); the
      // nullable permission column is schema v7's (3.4); the nullable
      // setting text column is schema v8's (4.3); the nullable slice
      // cause column is schema v9's (4.6); the nullable cluster and
      // enabled columns are schema v11's additive pair (5.11); the
      // nullable triage destination and tag columns are schema v12's
      // additive pair (6.3); the nullable triage box-id column is
      // schema v13's (6.5).
      expect(
        _recordFields('ports/store_port.dart', 'LogEntryRecord'),
        equals([
          'id',
          'kind',
          'instantUtcMicros',
          'offsetSeconds',
          'itemId',
          'itemOrigin',
          'stack',
          'settingKey',
          'settingValue',
          'settingTextValue',
          'pocketMinutes',
          'energyLevel',
          'reportValue',
          'reportWeek',
          'permission',
          'sliceCause',
          'cluster',
          'enabled',
          'triageDestination',
          'triageVolumeTag',
          'triageBoxId',
        ]),
      );
    });

    test('LogEntryContent', () {
      // The one write shape: a kind and its payload — nothing else may
      // be appended, by anyone (AD-3, AD-21). The setting fields grew
      // the shape additively (2.1); the pocket field grows it again
      // (2.2); the energy level field grows it once more (2.5); the
      // two report fields grow it a last time (2.6); the permission
      // field grows it once (3.4); the setting text field grows it
      // once more (4.3); the slice cause field grows it once (4.6);
      // the cluster and enabled fields grow it once each (5.11); the
      // triage destination and tag fields grow it once each (6.3);
      // the triage box-id field grows it once (6.5).
      expect(
        _recordFields('commands/session_commands.dart', 'LogEntryContent'),
        equals([
          'kind',
          'itemId',
          'itemOrigin',
          'stack',
          'settingKey',
          'settingValue',
          'settingTextValue',
          'pocketMinutes',
          'energyLevel',
          'reportValue',
          'reportWeek',
          'permission',
          'sliceCause',
          'cluster',
          'enabled',
          'triageDestination',
          'triageVolumeTag',
          'triageBoxId',
        ]),
      );
    });

    test('CaptureFactContent', () {
      // The capture fact's payload: origin, size, the Origin Context
      // line — and, since 3.4, the dictation boolean, a provenance
      // fact written once at creation (FR-32). No field here can name
      // a deadline (AD-1).
      expect(
        _recordFields('commands/capture_commands.dart', 'CaptureFactContent'),
        equals(['origin', 'size', 'originContext', 'dictated']),
      );
    });

    test('RescueStepFactContent', () {
      // The rescue step's fact payload (Story 4.6, FR-5): the
      // inherited origin, the step's own text, the parent it rescues
      // and its verbatim estimate — a genesis fact and a duration,
      // never a deadline or a deferral (AD-1, AD-14). Since Story
      // 5.7 the size rides the payload as the ONE fixed banding's
      // own output (`sizeOfEstimateSeconds` — instant across the
      // rescue band), the single duration→size rule's answer, never
      // an independent value.
      expect(
        _recordFields('commands/rescue_commands.dart', 'RescueStepFactContent'),
        equals([
          'origin',
          'size',
          'originContext',
          'rescueOf',
          'estimateSeconds',
        ]),
      );
    });

    test('RescueReturnedContent', () {
      // One delivered rescue's whole write (Story 4.6): the step-fact
      // payloads and the entry contents — the row plus the bundled
      // head-step deal. Nothing queued, nothing pending, nothing owed
      // rides the shape (AD-21).
      expect(
        _recordFields('commands/rescue_commands.dart', 'RescueReturnedContent'),
        equals(['facts', 'entries']),
      );
    });

    test('RescueStepSeed', () {
      // The landing's unit of work (Story 4.6): the shell-minted id
      // travelling with the parsed step, so the lists cannot diverge.
      // An identifier and a duration-bearing step — never a deadline
      // or a deferral (AD-1, AD-3).
      expect(
        _recordFields('commands/rescue_commands.dart', 'RescueStepSeed'),
        equals(['id', 'step']),
      );
    });

    test('EligibleDayAnchor', () {
      // The one predicate's item half (Story 4.6): an effective
      // estimate and a no-earlier-than instant — a recorded birth and
      // the one duration the low-energy ceiling reads (Story 5.7's
      // estimate-first read), never a target (AD-24).
      expect(
        _recordFields('derive/eligible_day.dart', 'EligibleDayAnchor'),
        equals(['estimateSeconds', 'noEarlierThanUtcMicros']),
      );
    });

    test('RescueStep', () {
      // One parsed rescue step (Story 4.6, FR-5): its non-empty text
      // and its verbatim duration — the contract's whole yield, never
      // a deadline or an ordering field (the chain orders by fact
      // creation, not by step data).
      expect(
        _recordFields('slicer/rescue_steps.dart', 'RescueStep'),
        equals(['text', 'durationSeconds']),
      );
    });

    test('ScanStep', () {
      // One parsed scan step (Story 5.7, FR-16): its non-empty text
      // and its verbatim duration in minutes — the scan contract's
      // whole yield, never a deadline or an ordering field (the
      // steps land as independent facts, ordered by creation).
      expect(
        _recordFields('slicer/scan_steps.dart', 'ScanStep'),
        equals(['text', 'durationMinutes']),
      );
    });

    test('ScanSlice', () {
      // One parsed scan slice (Story 5.7, FR-16): the space's
      // description — the Origin Context every step fact of the
      // slice shares — plus the steps themselves; retained source
      // text and work, never a deadline or a plan identity.
      expect(
        _recordFields('slicer/scan_steps.dart', 'ScanSlice'),
        equals(['description', 'steps']),
      );
    });

    test('ScanSliceFactSeed', () {
      // One landed scan step's fact payload (Story 5.7, FR-16): the
      // origin, the banding's size, the shared Origin Context, the
      // step's own words and its verbatim estimate — genesis facts
      // and durations, never a deadline or a deferral (AD-1).
      expect(
        _recordFields('commands/scan_commands.dart', 'ScanSliceFactSeed'),
        equals([
          'origin',
          'size',
          'originContext',
          'stepText',
          'estimateSeconds',
        ]),
      );
    });

    test('EnergyObservation', () {
      // A future-kind payload as inert data: level, instant, offset —
      // no day-count, no carry (AD-4).
      expect(
        _recordFields('energy/energy.dart', 'EnergyObservation'),
        equals(['level', 'instantUtcMicros', 'offsetSeconds']),
      );
    });

    test('CurationObservation', () {
      // A future-kind payload as inert data: cluster, enabled, instant,
      // offset — nothing else (AD-16).
      expect(
        _recordFields('curation/curation.dart', 'CurationObservation'),
        equals(['cluster', 'enabled', 'instantUtcMicros', 'offsetSeconds']),
      );
    });

    test('CheckpointState', () {
      // The checkpoint derivation's state (Story 2.4, FR-10): two
      // boolean facts the log makes true at one read instant — the
      // offer's due-ness and its preemption of the standing deal. No
      // count, no remaining-minutes figure, no scheduled instant rides
      // the reveal to the surface: the offer's surface is two actions,
      // and a number that would have been higher is exactly what the
      // surface must never carry (UJ-1, UX-DR44).
      expect(
        _classOwnFields('CheckpointState', 'derive/checkpoint.dart'),
        equals(['offerDue', 'offerPreemptsStandingDeal']),
      );
    });

    test('StripState', () {
      // The ambient strip derivation's state (Story 2.5, FR-4,
      // UX-DR22; the report field since 2.6, SM-2; the suggestion
      // field since 5.13, FR-15): the one resident the precedence
      // order resolved to — at most one is ever visible — plus,
      // exactly when that resident is the weekly self-report, the due
      // week it asks about (a `Week.weekOrdinal`, recomputed at every
      // read), and, exactly when it is the seasonal suggestion, the
      // shown dormant Epic record (its stable id, origin and
      // description — the fact both one-tap paths act on, carried
      // from the read, never re-derived at tap time). No dismissal
      // flag, no answered marker, nothing the surface owes: a
      // dismissal is a log row precisely because the strip states
      // what was shown, and the pending week is never stored either
      // — it is derived, so persistence and supersession stay pure
      // folds.
      expect(
        _classOwnFields('StripState', 'derive/strip.dart'),
        equals(['resident', 'reportWeekOrdinal', 'suggestion']),
      );
    });
  });

  test('every top-level class, enum, mixin, extension and record typedef '
      'under core lib is frozen or exempted — a shape cannot be born '
      'unfrozen', () {
    // The frozen census, keyed by (path, name): the declarations this
    // map freezes — Story 4-4 adds the slicer port's sealed request
    // union, its two outcomes and the three request kinds; Story 5.7
    // adds the scan parse's two records and the scan landing's fact
    // seed; Story 5.11 adds the curation kind's entry; Story 6.5
    // adds the box row's own payload-less entry and the quarantine
    // derivation's box record.
    const frozen = {
      'pool/pool_fact.dart:PoolFact',
      'log/log_entry.dart:LogEntry',
      'log/log_entry.dart:ItemActEntry',
      'log/log_entry.dart:MomentEntry',
      'log/log_entry.dart:SessionStartEntry',
      'log/log_entry.dart:SessionExtendEntry',
      'log/log_entry.dart:CrashEntry',
      'log/log_entry.dart:SettingEntry',
      'log/log_entry.dart:EnergySetEntry',
      'log/log_entry.dart:ReportAnsweredEntry',
      'log/log_entry.dart:PermissionRefusedEntry',
      'log/log_entry.dart:SliceEntry',
      'log/log_entry.dart:ClusterCurationChangedEntry',
      'log/log_entry.dart:TriageEntry',
      // Story 6.5: the Quarantine Box's own row — payload-less, its id
      // and instant ARE the box (FR-21).
      'log/log_entry.dart:BoxCreatedEntry',
      'log/log_entry.dart:UnknownEntry',
      'weave/session.dart:LogFacts',
      'weave/weave.dart:Card',
      'weave/weave.dart:DayComposition',
      'weave/weave.dart:Candidate',
      'catalogue/catalogue.dart:CatalogueEntry',
      'catalogue/catalogue.dart:Catalogue',
      'day/calendar.dart:Day',
      'day/calendar.dart:Week',
      'day/calendar.dart:Season',
      'ports/store_port.dart:PoolFactRecord',
      'ports/store_port.dart:LogEntryRecord',
      'commands/session_commands.dart:LogEntryContent',
      'commands/capture_commands.dart:CaptureFactContent',
      'commands/capture_commands.dart:CaptureContent',
      'commands/rescue_commands.dart:RescueStepFactContent',
      'commands/rescue_commands.dart:RescueReturnedContent',
      'commands/rescue_commands.dart:RescueStepSeed',
      'derive/eligible_day.dart:EligibleDayAnchor',
      'slicer/rescue_steps.dart:RescueStep',
      // Story 5.7: the scan parse's own yield — the parsed step and
      // the parsed slice — and the scan landing's fact seed.
      'slicer/scan_steps.dart:ScanStep',
      'slicer/scan_steps.dart:ScanSlice',
      'commands/scan_commands.dart:ScanSliceFactSeed',
      'ports/recognizer_port.dart:RecognizerOutcome',
      'energy/energy.dart:EnergyObservation',
      'curation/curation.dart:CurationObservation',
      'derive/checkpoint.dart:CheckpointState',
      'derive/strip.dart:StripState',
      // Story 5.13: the seasonal suggestion's shown record — a
      // structural record type shared with weave by shape alone.
      'derive/strip.dart:StripSuggestion',
      // Story 6.5: the Quarantine Box derivation's own record — id,
      // instant, offset and contents, never a follow-up date (AD-1).
      'derive/quarantine.dart:QuarantineBox',
      'ports/slicer_port.dart:SlicerRequest',
      'ports/slicer_port.dart:ScanSliceRequest',
      'ports/slicer_port.dart:GenesisSliceRequest',
      'ports/slicer_port.dart:RescueSliceRequest',
      'ports/slicer_port.dart:SlicerOutcome',
      'ports/slicer_port.dart:SlicerDelivered',
      'ports/slicer_port.dart:SlicerFailed',
      // Story 5.2: the face gate port's sealed outcome union and its
      // two decided states.
      'ports/face_gate_port.dart:FaceGateOutcome',
      'ports/face_gate_port.dart:FaceGatePass',
      'ports/face_gate_port.dart:FaceGateRefusal',
      // Story 5.4: the scan consent token — the capability type
      // itself, its binding field and its one-way consumption state.
      'ports/scan_consent.dart:ScanConsent',
      // Story 5.4: the raw binding-violation subtype that keeps the
      // programmer error intact through the shell's broad Slicer boundary.
      'ports/scan_consent.dart:ScanConsentStateError',
    };
    // The deliberate exemptions, each with its reason:
    const exempted = {
      // JSON machinery, not a domain shape (catalogue parsing).
      'catalogue/strict_json.dart:StrictJsonFormatException',
      'catalogue/strict_json.dart:_StrictJsonReader',
      // The stateless instant→period converter; methods and two
      // private constants, no domain fields (AD-4).
      'day/calendar.dart:Calendar',
      // The kind vocabulary value type itself (AD-21).
      'log/log_entry.dart:LogKind',
      // The permission identity vocabulary (Story 3.4, AD-17) — an
      // enum with members and no fields, on the value-vocabularies'
      // own terms.
      'log/log_entry.dart:Permission',
      // The triage act's value vocabularies (Story 6.3, FR-22) — the
      // destination and coarse volume tag enums, members and no
      // fields, on the value-vocabularies' own terms (a numeric
      // volume has no member to ride).
      'log/log_entry.dart:TriageDestination',
      'log/log_entry.dart:CoarseVolumeTag',
      // The read boundary's result record — conversion output, not a
      // persisted or derived read model.
      'log/log_entry.dart:LogEntryConversion',
      // The port interfaces the adapters implement (AD-5) — method
      // contracts, no fields.
      'ports/store_port.dart:StorePort',
      'ports/clock_port.dart:ClockPort',
      'ports/recognizer_port.dart:RecognizerPort',
      'ports/files_port.dart:FilesPort',
      // The slicer port interface (Story 4-4, AD-9) — a method
      // contract, no fields, on the ports' own terms.
      'ports/slicer_port.dart:SlicerPort',
      // The face gate port interface (Story 5.2, AD-11) — a method
      // contract, no fields, on the ports' own terms.
      'ports/face_gate_port.dart:FaceGatePort',
      // The recognizer port's own state vocabularies (Story 3.4) —
      // enums with members and no fields.
      'ports/recognizer_port.dart:RecognizerAvailability',
      'ports/recognizer_port.dart:RecognizerStart',
      // The weave's private pipeline record (weave.dart internals).
      'weave/weave.dart:_DayPolicy',
      // The value vocabularies — enums with members and no fields
      // (a fielded enum would arrive unfrozen and fail this census).
      'pool/pool_fact.dart:Origin',
      'pool/pool_fact.dart:Size',
      'log/log_entry.dart:LogRecordFlaw',
      'energy/energy.dart:EnergyLevel',
      'catalogue/catalogue.dart:Cadence',
      'catalogue/catalogue.dart:Zone',
      'weave/weave.dart:CandidatePrecedence',
      'curation/curation.dart:CurationCluster',
      'day/calendar.dart:SeasonKind',
      // The ambient strip's resident vocabulary (Story 2.5) — the
      // precedence order's members, no fields.
      'derive/strip.dart:StripResident',
      // The slicer's failure-cause vocabulary (Story 4-4, FR-29;
      // story 5.3 gained malformedInput) — eight members and no
      // fields, the closed taxonomy itself.
      'ports/slicer_port.dart:SlicerFailureCause',
      // The no-Slicer cause vocabulary (Story 4-5, FR-29) — the UI's
      // seven renderable states, members and no fields, where the
      // total map from the failure taxonomy lands.
      'ports/no_slicer_cause.dart:NoSlicerCause',
    };

    final classDeclaration = RegExp(
      r'^[ \t]*(?:abstract[ \t]+|final[ \t]+|sealed[ \t]+|base[ \t]+|'
      r'interface[ \t]+|mixin[ \t]+)*class[ \t]+(\w+)',
      multiLine: true,
    );
    final enumDeclaration = RegExp(r'^[ \t]*enum[ \t]+(\w+)', multiLine: true);
    final mixinDeclaration = RegExp(
      r'^[ \t]*(?:base[ \t]+|sealed[ \t]+)*mixin[ \t]+(\w+)',
      multiLine: true,
    );
    final extensionDeclaration = RegExp(
      r'^[ \t]*extension(?:[ \t]+(\w+))?[ \t]+on[ \t]',
      multiLine: true,
    );
    final namedRecordTypedef = RegExp(
      r'^[ \t]*typedef[ \t]+(\w+)(?:[ \t]*<[^=]+>)?[ \t]*='
      r'[ \t]*\([ \t]*\{',
      multiLine: true,
    );
    final positionalRecordTypedef = RegExp(
      r'^[ \t]*typedef[ \t]+(\w+)(?:[ \t]*<[^=]+>)?[ \t]*='
      r'[ \t]*\((?![ \t]*\{)',
      multiLine: true,
    );
    final extensionTypeDeclaration = RegExp(
      r'^[ \t]*extension[ \t]+type[ \t]+(\w+)',
      multiLine: true,
    );

    expect(
      namedRecordTypedef.hasMatch('typedef Generic<T> = ({T value});'),
      isTrue,
    );
    expect(
      extensionTypeDeclaration.hasMatch('extension type Period(int value) {}'),
      isTrue,
    );

    final found = <String>{};
    void census(RegExp pattern, String path, String source) {
      for (final match in pattern.allMatches(source)) {
        final name = match.group(1);
        if (name != null && name.isNotEmpty) {
          found.add('$path:$name');
        }
      }
    }

    for (final path in _coreLibFiles()) {
      final source = _withoutComments(_source(path));
      census(classDeclaration, path, source);
      census(enumDeclaration, path, source);
      census(mixinDeclaration, path, source);
      census(extensionDeclaration, path, source);
      census(extensionTypeDeclaration, path, source);
      census(namedRecordTypedef, path, source);
      census(positionalRecordTypedef, path, source);
    }
    // Non-vacuous: the census is at least the pinned world, and a
    // vanished declaration is as much a finding as an unlisted one.
    expect(
      found,
      hasLength(greaterThanOrEqualTo(frozen.length + exempted.length)),
    );
    final unlisted =
        found
            .where((key) => !frozen.contains(key) && !exempted.contains(key))
            .toList()
          ..sort();
    expect(
      unlisted,
      isEmpty,
      reason:
          'a new top-level class, enum, mixin, extension or record '
          'typedef landed unfrozen — freeze it or renegotiate the '
          'exemption list, never leave a shape the no-overdue property '
          'has not examined',
    );
    final deadExemptions = exempted.difference(found).toList()..sort();
    expect(
      deadExemptions,
      isEmpty,
      reason:
          'the exemption list names declarations that no longer '
          'exist — renegotiate the pin',
    );
  });

  test('card_done and card_dealt are minted in exactly two files and read '
      'in exactly one, as identifiers and as wire-name literals — no third '
      'minter, so no synthetic-completion writer can appear silently '
      '(AD-3, AD-25)', () {
    // The four homes the vocabulary allows: the definition, the one
    // walk that reads the kinds, and the two command files that mint
    // them — the answer commands (`_answered`'s bundled deal) and,
    // since Story 4.6, the rescue commands (`rescueReturned`'s
    // supersede pair, the same grammar over the head step). An
    // identifier or wire-name reference anywhere else in core lib is
    // a finding.
    const allowed = {
      'log/log_entry.dart',
      'weave/session.dart',
      'commands/session_commands.dart',
      'commands/rescue_commands.dart',
    };
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\b(cardDone|cardDealt)\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'kind identifiers outside the definition, the walk and '
          'the two command files',
    );

    // The wire-name string literals are the definition's and the
    // registry's alone — a quoted 'card_done' anywhere else in core
    // lib is a minter that does not even use the constants.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]card_(done|dealt)['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "wire-name literals 'card_done'/'card_dealt' outside the "
          'definition home',
    );
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]card_dealt['\"]").allMatches(definitionHome),
      hasLength(2),
      reason: 'the definition and registry are the only card_dealt wire uses',
    );
    expect(
      RegExp("['\"]card_done['\"]").allMatches(definitionHome),
      hasLength(2),
      reason: 'the definition and registry are the only card_done wire uses',
    );
    expect(
      RegExp(r'\bcard(Dealt|Done)\b').allMatches(definitionHome),
      hasLength(6),
      reason:
          'the definition, registry and validation classifier are the only '
          'card-kind identifier uses in this file',
    );
    expect(
      RegExp(r'\bLogKind\.card(Dealt|Done)\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the validation classifier is the only qualified card-kind reader '
          'in the definition home',
    );

    // The mint sites: every reference in a command file names a row
    // being written — the answer commands mint both kinds, the rescue
    // commands mint the bundled head-step deal alone (`slice_returned`
    // owns its own row), and neither file ever reads what it mints.
    for (final commandPath in [
      'commands/session_commands.dart',
      'commands/rescue_commands.dart',
    ]) {
      final commands = _withoutComments(_source(commandPath));
      final commandRefs = RegExp(r'LogKind\.card(Dealt|Done)\b')
          .allMatches(commands)
          .length;
      final commandMints = RegExp(r'kind:\s*LogKind\.card(Dealt|Done)\b')
          .allMatches(commands)
          .length;
      expect(commandMints, greaterThan(0), reason: commandPath);
      expect(commandMints, commandRefs, reason: commandPath);
      expect(
        RegExp(r'==\s*LogKind\.card(Dealt|Done)\b').allMatches(commands),
        isEmpty,
        reason: '$commandPath mints rows, it never reads them',
      );
    }
    final answerCommands = _withoutComments(
      _source('commands/session_commands.dart'),
    );
    expect(
      RegExp(r'kind:\s*LogKind\.cardDealt\b').allMatches(answerCommands),
      isNotEmpty,
    );
    expect(
      RegExp(r'kind:\s*LogKind\.cardDone\b').allMatches(answerCommands),
      isNotEmpty,
    );
    final rescueCommands = _withoutComments(
      _source('commands/rescue_commands.dart'),
    );
    expect(
      RegExp(r'kind:\s*LogKind\.cardDealt\b').allMatches(rescueCommands),
      isNotEmpty,
      reason: 'the supersede pair bundles the head-step deal',
    );
    expect(
      RegExp(r'kind:\s*LogKind\.cardDone\b').allMatches(rescueCommands),
      isEmpty,
      reason: 'a rescue never completes a card — no synthetic writer',
    );

    // The one read site: every reference in the walk is a comparison
    // — the derivation reads the kinds, it never writes them.
    final walk = _withoutComments(_source('weave/session.dart'));
    final walkRefs = RegExp(r'LogKind\.card(Dealt|Done)\b')
        .allMatches(walk)
        .length;
    final walkReads = RegExp(r'==\s*LogKind\.card(Dealt|Done)\b')
        .allMatches(walk)
        .length;
    expect(walkReads, greaterThan(0));
    expect(walkReads, walkRefs);
    expect(
      RegExp(r'kind:\s*LogKind\.card(Dealt|Done)\b').allMatches(walk),
      isEmpty,
      reason: 'the walk reads rows, it never mints them',
    );

    // The definition home holds both wire names.
    expect(
      definitionHome,
      contains("static const cardDealt = LogKind._('card_dealt'"),
    );
    expect(
      definitionHome,
      contains("static const cardDone = LogKind._('card_done'"),
    );
  });

  test('setting_changed is minted in exactly one file and read nowhere in '
      'core — the derivation matches the entry type, never the kind '
      'constant (Story 2.1, AD-1, AD-3)', () {
    // The three homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary) and the one command
    // file that mints the kind. The derivation in core/settings reads
    // the SettingEntry *type* — a LogKind.settingChanged reference there
    // would be a second reader of the kind, and any reference anywhere
    // else in core lib is a finding.
    const allowed = {'log/log_entry.dart', 'commands/settings_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bsettingChanged\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the settingChanged identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'setting_changed' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]setting_changed['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'setting_changed' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry,
    // the read-boundary classifier and the SettingEntry override.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]setting_changed['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only setting_changed wire '
          'uses',
    );
    expect(
      RegExp(r'\bsettingChanged\b').allMatches(definitionHome),
      hasLength(4),
      reason:
          'the definition, registry, classifier and subtype override are '
          'the only settingChanged identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.settingChanged\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the classifier and the subtype override are the only '
          'qualified settingChanged readers in the definition home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(
      _source('commands/settings_commands.dart'),
    );
    final commandRefs = RegExp(r'LogKind\.settingChanged\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.settingChanged\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.settingChanged\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('energy_set is minted in exactly one file and read nowhere in '
      'core — the derivations match the entry type, never the kind '
      'constant (Story 2.5, AD-4, AD-3)', () {
    // The three homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary) and the one command
    // file that mints the kind. The derivations that read energy — the
    // live-pool seam and the strip's eligibility — read the
    // EnergySetEntry *type*, so a LogKind.energySet reference anywhere
    // else in core lib is a finding.
    const allowed = {'log/log_entry.dart', 'commands/energy_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\benergySet\b').hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the energySet identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'energy_set' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]energy_set['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'energy_set' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry,
    // the read-boundary classifier and the EnergySetEntry override.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]energy_set['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only energy_set wire '
          'uses',
    );
    expect(
      RegExp(r'\benergySet\b').allMatches(definitionHome),
      hasLength(4),
      reason:
          'the definition, registry, classifier and subtype override are '
          'the only energySet identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.energySet\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the classifier and the subtype override are the only '
          'qualified energySet readers in the definition home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(_source('commands/energy_commands.dart'));
    final commandRefs = RegExp(r'LogKind\.energySet\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.energySet\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.energySet\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('report_answered is minted in exactly one file and read nowhere in '
      'core — parts 2–3 derive over the rows, never the kind constant '
      '(Story 2.6, SM-2, AD-21, AD-3)', () {
    // The two homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary) and the one command
    // file that mints the kind. No derivation reads the kind yet —
    // part 2's eligibility reads the ReportAnsweredEntry *type* on the
    // energy seam's pattern — so a LogKind.reportAnswered reference
    // anywhere else in core lib is a finding.
    const allowed = {'log/log_entry.dart', 'commands/report_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\breportAnswered\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the reportAnswered identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'report_answered' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]report_answered['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'report_answered' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry,
    // the read-boundary classifier and the ReportAnsweredEntry override.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]report_answered['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only report_answered wire '
          'uses',
    );
    expect(
      RegExp(r'\breportAnswered\b').allMatches(definitionHome),
      hasLength(4),
      reason:
          'the definition, registry, classifier and subtype override are '
          'the only reportAnswered identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.reportAnswered\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the classifier and the subtype override are the only '
          'qualified reportAnswered readers in the definition home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(_source('commands/report_commands.dart'));
    final commandRefs = RegExp(r'LogKind\.reportAnswered\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.reportAnswered\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.reportAnswered\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('capture_created is minted in exactly one file and read nowhere in '
      'core — 3.3\'s derivation will read the rows, never the kind '
      'constant (Story 3.2, FR-27, AD-14, AD-3)', () {
    // The two homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary, through the item-act
    // family the kind joins) and the one command file that mints it.
    // No derivation reads the kind yet — 3.3's candidacy derivation
    // will read the pool facts and the ItemActEntry *type* — so a
    // LogKind.captureCreated reference anywhere else in core lib is a
    // finding.
    const allowed = {'log/log_entry.dart', 'commands/capture_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bcaptureCreated\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the captureCreated identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'capture_created' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]capture_created['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'capture_created' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry
    // and the item-act classifier — the kind has no subtype of its own
    // (ItemActEntry's kind is a constructor parameter, never an
    // initialized override).
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]capture_created['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only capture_created wire '
          'uses',
    );
    expect(
      RegExp(r'\bcaptureCreated\b').allMatches(definitionHome),
      hasLength(3),
      reason:
          'the definition, registry and item-act classifier are '
          'the only captureCreated identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.captureCreated\b').allMatches(definitionHome),
      hasLength(1),
      reason:
          'the item-act classifier is the only qualified captureCreated '
          'reader in the definition home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(
      _source('commands/capture_commands.dart'),
    );
    final commandRefs = RegExp(r'LogKind\.captureCreated\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.captureCreated\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.captureCreated\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('permission_refused is minted in exactly one file and read '
      'nowhere in core — the derivation matches the entry type, never '
      'the kind constant (Story 3.4, FR-32, AD-17, AD-3)', () {
    // The two homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary, through the
    // subtype the kind owns) and the one command file that mints it.
    // The derivation in core/derive reads the PermissionRefusedEntry
    // *type* — a LogKind.permissionRefused reference there would be a
    // second reader of the kind, and any reference anywhere else in
    // core lib is a finding.
    const allowed = {'log/log_entry.dart', 'commands/permission_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bpermissionRefused\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the permissionRefused identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'permission_refused' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]permission_refused['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'permission_refused' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry,
    // the read-boundary classifier and the PermissionRefusedEntry
    // override.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]permission_refused['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only permission_refused '
          'wire uses',
    );
    expect(
      RegExp(r'\bpermissionRefused\b').allMatches(definitionHome),
      hasLength(4),
      reason:
          'the definition, registry, classifier and subtype override are '
          'the only permissionRefused identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.permissionRefused\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the classifier and the subtype override are the only '
          'qualified permissionRefused readers in the definition home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(
      _source('commands/permission_commands.dart'),
    );
    final commandRefs = RegExp(r'LogKind\.permissionRefused\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.permissionRefused\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.permissionRefused\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('face_refused is minted in exactly one file and read nowhere in '
      'core — the kind rides the moment family and nothing else names it '
      '(Story 5.2, FR-25, AD-21, AD-3)', () {
    // The two homes the vocabulary allows: the definition (whose moment
    // classifier carries the kind — no subtype of its own, the
    // `app_opened` precedent) and the one command file that mints it.
    // Any reference anywhere else in core lib is a finding: the shell
    // reads nothing of the kind (no derivation consumes it — the calm
    // surface is the refusal's whole presentation), so even a reader
    // here would be vocabulary growing past its story.
    const allowed = {'log/log_entry.dart', 'commands/scan_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bfaceRefused\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the faceRefused identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'face_refused' anywhere else in core
    // lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]face_refused['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'face_refused' outside the definition "
          'home',
    );

    // The definition home: exactly the definition, the registry entry
    // and the moment classifier — no subtype override exists, the
    // `app_opened` precedent's own count.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]face_refused['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only face_refused wire '
          'uses',
    );
    expect(
      RegExp(r'\bfaceRefused\b').allMatches(definitionHome),
      hasLength(3),
      reason:
          'the definition, registry and moment classifier are the only '
          'faceRefused identifier uses in this file',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(_source('commands/scan_commands.dart'));
    final commandRefs = RegExp(r'LogKind\.faceRefused\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.faceRefused\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.faceRefused\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('consent_granted is minted in exactly one file and read only in '
      'the stated set — the kind rides the moment family and nothing '
      'else names it (Story 5.4, AD-8, FR-26, AD-21, AD-3)', () {
    // The three homes the vocabulary allows: the definition (whose
    // moment classifier carries the kind — no subtype of its own, the
    // `app_opened` precedent), the one command file that mints it, and
    // the one stated reader — the warm-return predicate (Story 5.4's
    // same-pass rule: the kind is contact, the user actively using the
    // app). Any reference anywhere else in core lib is a finding: no
    // derivation consumes the kind, and the token itself is never
    // logged, so even a reader here would be vocabulary growing past
    // its story.
    const allowed = {
      'log/log_entry.dart',
      'commands/scan_commands.dart',
      'derive/warm_return.dart',
    };
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bconsentGranted\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the consentGranted identifier outside the definition, the '
          'one minter and the stated reader',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'consent_granted' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]consent_granted['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'consent_granted' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry
    // and the moment classifier — no subtype override exists, the
    // `app_opened` precedent's own count.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]consent_granted['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only consent_granted '
          'wire uses',
    );
    expect(
      RegExp(r'\bconsentGranted\b').allMatches(definitionHome),
      hasLength(3),
      reason:
          'the definition, registry and moment classifier are the only '
          'consentGranted identifier uses in this file',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(_source('commands/scan_commands.dart'));
    final commandRefs = RegExp(r'LogKind\.consentGranted\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.consentGranted\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.consentGranted\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );

    // The stated reader: the warm-return predicate assigns the kind
    // its contact set in the same pass that added it (the doc's own
    // rule) — the one qualified reader outside the definition home.
    final reader = _withoutComments(_source('derive/warm_return.dart'));
    expect(
      RegExp(r'LogKind\.consentGranted\b').allMatches(reader),
      hasLength(1),
      reason: 'the contact assignment is the only read of the kind',
    );
  });

  test('the consent capability is minted by exactly one production '
      'caller and consumed by exactly one — the token has no second home '
      '(Story 5.4, AD-8; mint caller renegotiated additively by Story '
      '5.5)', () {
    // The walk covers both lib trees — the core's and the shell's —
    // over masked source (comments and string contents blanked, the
    // check_core_purity precedent), so a doc mention can never pose
    // as a call site and a quoted identifier can never pose as code.
    // `mintScanConsent` is legal only in its definition home (the
    // sanctioned minter itself) and in the one production caller the
    // consent act owns (the scan controller — Story 5.5's additive
    // renegotiation, exactly as this census's comment promised);
    // `.consume(` only there and in the dispatch's scan branch. Test
    // directories sit outside both trees and are not scanned: this
    // census pins production only.
    final masked = <String, String>{
      for (final path in _coreLibFiles())
        'packages/core/lib/$path': _withoutStrings(
          _withoutComments(_source(path)),
        ),
      for (final path in _shellLibFiles())
        path: _withoutStrings(_withoutComments(_shellSource(path))),
    };

    const mintAllowed = {
      'packages/core/lib/ports/scan_consent.dart',
      'lib/scan/scan_controller.dart',
    };
    const consumeAllowed = {
      'packages/core/lib/ports/scan_consent.dart',
      'lib/egress/egress_dispatch.dart',
    };

    final mintOffenders = <String>[];
    final consumeOffenders = <String>[];
    var mintSites = 0;
    var consumeSites = 0;
    masked.forEach((path, source) {
      final mints = RegExp(r'\bmintScanConsent\b').allMatches(source).length;
      final consumes = RegExp(r'\.consume\(').allMatches(source).length;
      if (mints > 0 && !mintAllowed.contains(path)) {
        mintOffenders.add(path);
      }
      if (consumes > 0 && !consumeAllowed.contains(path)) {
        consumeOffenders.add(path);
      }
      mintSites += mints;
      consumeSites += consumes;
    });
    expect(
      mintOffenders,
      isEmpty,
      reason:
          'a production mint caller outside the definition home and the '
          'one consent act — the token has no second home',
    );
    expect(
      consumeOffenders,
      isEmpty,
      reason:
          'a second consumption site — one token authorizes one '
          'dispatch entry, and only the dispatch consumes',
    );
    // Non-vacuous: the definition home carries the minter itself, the
    // scan controller is its one production caller, and the dispatch's
    // scan branch is the one consumption.
    expect(
      mintSites,
      2,
      reason: 'the sanctioned minter, defined once and called once',
    );
    expect(
      consumeSites,
      1,
      reason:
          'the one-way consumption, performed exactly once in '
          'production code',
    );
  });

  test('the session kinds are minted in exactly one file and read only '
      'in the stated set — no second session writer can appear silently '
      '(Story 2.2, AD-3, AD-19)', () {
    // The five homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary), the one walk that
    // reads the kinds, the one command file that mints them —
    // `app_opened`, `session_started` and `session_ended` exist nowhere
    // else in core lib, as identifiers or as wire-name literals — and,
    // for `app_opened` alone, the stated-reader set: the ambient
    // strip's first-opening predicate (Story 2.5 — the check-in's
    // eligibility reads the opening delimiters) and the warm-return
    // predicate (Story 2.7 — AD-24's greeting measures 48 h from the
    // latest contact before the current opening). The shell's own
    // census (test/no_lateness_proof_test.dart) carries the same line
    // over lib/.
    const allowed = {
      'log/log_entry.dart',
      'weave/session.dart',
      'commands/session_commands.dart',
      'derive/strip.dart',
      'derive/warm_return.dart',
    };
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\b(appOpened|sessionStart|sessionEnd|sessionDeclare)\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'session-command identifiers outside the definition, the walk '
          'and the command file',
    );

    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"](app_opened|session_started|session_ended)['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "wire-name literals 'app_opened'/'session_started'/"
          "'session_ended' outside the definition home",
    );

    // The definition home holds each wire name exactly twice — the
    // definition and the registry — and the classifier keeps the
    // session_started branch beside them.
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    for (final name in ['app_opened', 'session_started', 'session_ended']) {
      expect(
        RegExp("['\"]$name['\"]").allMatches(definitionHome),
        hasLength(2),
        reason: "the definition and registry are the only $name wire uses",
      );
    }

    // The one mint site: every reference in the command file names a
    // row being written or a kind it resolves over — never a
    // comparison against the walk's facts.
    final commands = _withoutComments(
      _source('commands/session_commands.dart'),
    );
    expect(
      RegExp(r'kind:\s*LogKind\.(appOpened|sessionStarted|sessionEnded)\b')
          .allMatches(commands)
          .isNotEmpty,
      isTrue,
      reason: 'the command file mints the session kinds',
    );
  });

  test('cluster_curation_changed is minted in exactly one file and read '
      'nowhere in core — the derivation matches the entry type, never '
      'the kind constant (Story 5.11, FR-31, AD-16, AD-3)', () {
    // The two homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary, on its own subtype)
    // and the one command file that mints the kind. The derivation
    // that reads curation — the fold in core/curation — reads the
    // ClusterCurationChangedEntry *type*, so a
    // LogKind.clusterCurationChanged reference anywhere else in core
    // lib is a finding: vocabulary growing past its story.
    const allowed = {'log/log_entry.dart', 'commands/curation_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bclusterCurationChanged\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the clusterCurationChanged identifier outside the definition '
          'and the one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'cluster_curation_changed' anywhere
    // else in core lib is a minter that does not even use the
    // constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]cluster_curation_changed['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'cluster_curation_changed' outside the "
          'definition home',
    );

    // The definition home: exactly the definition, the registry entry,
    // the read-boundary classifier and the subtype override — the
    // setting kind's own count (a subtype of its own exists).
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]cluster_curation_changed['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only '
          'cluster_curation_changed wire uses',
    );
    expect(
      RegExp(r'\bclusterCurationChanged\b').allMatches(definitionHome),
      hasLength(4),
      reason:
          'the definition, registry, classifier and subtype override are '
          'the only clusterCurationChanged identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.clusterCurationChanged\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the classifier and the subtype override are the only '
          'qualified clusterCurationChanged readers in the definition '
          'home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(
      _source('commands/curation_commands.dart'),
    );
    final commandRefs = RegExp(r'LogKind\.clusterCurationChanged\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.clusterCurationChanged\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.clusterCurationChanged\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );

    // The stated reader: the fold assigns the kind its derivation in
    // the same pass that added it (the doc's own rule) — the one
    // entry-type reader outside the definition home, reading the TYPE
    // and never the kind constant.
    final fold = _withoutComments(_source('curation/curation.dart'));
    expect(
      RegExp(r'\bClusterCurationChangedEntry\b').allMatches(fold),
      hasLength(1),
      reason: 'the fold is the kind\'s one derivation-side reader',
    );
  });

  test('item_triaged is minted in exactly one file and read nowhere in '
      'core — no derivation consumes the substrate yet, 6.5\'s '
      'Quarantine Box and 6.7\'s metric will read the entry type, never '
      'the kind constant (Story 6.3, FR-22, AD-21, AD-3)', () {
    // The two homes the vocabulary allows: the definition (which also
    // classifies the payload at the read boundary, on its own
    // subtype) and the one command file that mints the kind. The
    // derivations that will read triage read the TriageEntry *type*,
    // so a LogKind.itemTriaged reference anywhere else in core lib is
    // a finding: vocabulary growing past its story.
    const allowed = {'log/log_entry.dart', 'commands/triage_commands.dart'};
    final files = _coreLibFiles();
    final identifierOffenders = [
      for (final path in files)
        if (!allowed.contains(path) &&
            RegExp(r'\bitemTriaged\b')
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      identifierOffenders,
      isEmpty,
      reason:
          'the itemTriaged identifier outside the definition and the '
          'one minter',
    );

    // The wire-name string literal is the definition's and the
    // registry's alone — a quoted 'item_triaged' anywhere else in
    // core lib is a minter that does not even use the constant.
    final wireOffenders = [
      for (final path in files)
        if (path != 'log/log_entry.dart' &&
            RegExp("['\"]item_triaged['\"]")
                .hasMatch(_withoutComments(_source(path))))
          path,
    ];
    expect(
      wireOffenders,
      isEmpty,
      reason:
          "the wire-name literal 'item_triaged' outside the definition "
          'home',
    );

    // The definition home: exactly the definition, the registry entry,
    // the read-boundary classifier and the TriageEntry override — the
    // setting kind's own count (a subtype of its own exists).
    final definitionHome = _withoutComments(_source('log/log_entry.dart'));
    expect(
      RegExp("['\"]item_triaged['\"]").allMatches(definitionHome),
      hasLength(2),
      reason:
          'the definition and registry are the only item_triaged wire '
          'uses',
    );
    expect(
      RegExp(r'\bitemTriaged\b').allMatches(definitionHome),
      hasLength(4),
      reason:
          'the definition, registry, classifier and subtype override are '
          'the only itemTriaged identifier uses in this file',
    );
    expect(
      RegExp(r'LogKind\.itemTriaged\b').allMatches(definitionHome),
      hasLength(2),
      reason:
          'the classifier and the subtype override are the only '
          'qualified itemTriaged readers in the definition home',
    );

    // The one mint site: every reference in the command file names a
    // row being written — never a comparison.
    final commands = _withoutComments(_source('commands/triage_commands.dart'));
    final commandRefs = RegExp(r'LogKind\.itemTriaged\b')
        .allMatches(commands)
        .length;
    final commandMints = RegExp(r'kind:\s*LogKind\.itemTriaged\b')
        .allMatches(commands)
        .length;
    expect(commandMints, 1);
    expect(commandMints, commandRefs);
    expect(
      RegExp(r'==\s*LogKind\.itemTriaged\b').allMatches(commands),
      isEmpty,
      reason: 'the command file mints rows, it never reads them',
    );
  });

  test('no known kind name carries a rescheduling or lateness segment — '
      'the vocabulary cannot name an obligation (NFR9, AD-21)', () {
    // The registry guard: an empty registry would make this pin
    // vacuous.
    expect(LogKind.knownByName, isNotEmpty);
    // The one vetted substring accident (Story 5.13): 'dismissed'
    // contains 'missed' as a substring, but `suggestion_dismissed` is
    // the PRD's own frozen wire name for the ✕ of the seasonal
    // suggestion — a past act of declining, never an obligation or a
    // re-planning act. The exemption is scoped to the `missed`
    // SEGMENT alone: the vetted name still fails on every other
    // banned segment, and any other kind carrying any segment —
    // `missed` included — still fails.
    const vettedNames = {'suggestion_dismissed'};
    for (final name in LogKind.knownByName.keys) {
      final lower = name.toLowerCase();
      for (final segment in [
        'assign',
        'schedul',
        'defer',
        'plan',
        'overdue',
        'late',
        'missed',
        'due',
        'postpon',
      ]) {
        expect(
          lower.contains(segment) &&
              !(segment == 'missed' && vettedNames.contains(name)),
          isFalse,
          reason:
              "'$name' carries '$segment' — a kind name with that "
              'segment could only mean an obligation or a re-planning '
              'act, and the vocabulary holds neither',
        );
      }
    }
  });
}
