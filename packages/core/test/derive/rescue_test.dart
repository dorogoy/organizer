import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/derive/eligible_day.dart';
import 'package:core/derive/rescue.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:test/test.dart';

import '../test_util.dart';

/// The refusal counter and the dissolution (Story 4.6, FR-5, AD-24) —
/// derived over the ONE EligibleDay predicate, its session-day
/// attribution and nothing else: skips feed only these counters, and
/// no cumulative skip total exists anywhere (AD-1's own shape).
///
/// The fixture: a manual capture `cap-a` (focus) created on day 0,
/// sittings that deal and skip it (or a shipped entry, fact-less), and
/// activations (`slice_requested`) where a reset is under test. Day 0
/// is Monday 2026-08-24; hours stay at-or-after 04:00 so the civil
/// date and the domestic day agree.

CatalogueEntry _entry(String id, Size size) => CatalogueEntry(
  id: id,
  size: size,
  cadence: Cadence.weekly,
  name: 'Tarea de $id',
);

final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: [
    _entry('zona-z1-a', Size.focus),
    _entry('man-a', Size.maintenance),
    _entry('hab-a', Size.instant),
  ],
);

PoolFact _fact(
  String id,
  Size size,
  int micros, {
  String? rescueOf,
  int? estimateSeconds,
}) => PoolFact(
  id: id,
  origin: Origin.manual,
  size: size,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  originContext: 'Llamar al dentista',
  rescueOf: rescueOf,
  estimateSeconds: estimateSeconds,
);

SessionStartEntry _started(int micros) => SessionStartEntry(
  id: 'started-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionStarted,
);

MomentEntry _ended(int micros) => MomentEntry(
  id: 'ended-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionEnded,
);

ItemActEntry _row(LogKind kind, int micros, String itemId) => ItemActEntry(
  id: '${kind.name}-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: kind,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

EnergySetEntry _energySet(int micros, EnergyLevel level) => EnergySetEntry(
  id: 'energy-$micros-${level.name}',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  level: level,
);

SliceEntry _slice(LogKind kind, int micros, String itemId) => SliceEntry(
  id: 'slice-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: kind,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

const int _microsPerDay = 24 * 60 * 60 * 1000 * 1000;

/// Noon on the [days]-th day of the fixture's run.
int _day(int days) => utcMicros(2026, 8, 24, 12) + days * _microsPerDay;

/// One sitting on the [days]-th day that deals [itemId] and skips it —
/// the honest decline shape: a card the resolver dealt, the user
/// passed, the sitting closed.
List<LogEntry> _decline(int days, String itemId) => [
  _started(_at(days, 10)),
  _row(LogKind.cardDealt, _at(days, 10, 0, 1), itemId),
  _row(LogKind.cardSkipped, _at(days, 10, 0, 2), itemId),
  _ended(_at(days, 10, 0, 3)),
];

/// An instant on the [days]-th day at the given wall clock.
int _at(int days, int hour, [int minute = 0, int second = 0]) =>
    utcMicros(2026, 8, 24, hour, minute, second) + days * _microsPerDay;

/// The read instant: after everything the fixtures hold.
final int _now = _at(30, 14);

int declineDays(
  List<LogEntry> entries,
  String itemId, {
  List<PoolFact> facts = const [],
  int? at,
}) => rescueDeclineDays(
  entries: entries,
  poolFacts: facts,
  catalogue: _catalogue,
  itemId: itemId,
  instantUtcMicros: at ?? _now,
);

bool warranted(
  List<LogEntry> entries,
  String itemId, {
  List<PoolFact> facts = const [],
}) => rescueWarranted(
  entries: entries,
  poolFacts: facts,
  catalogue: _catalogue,
  itemId: itemId,
  instantUtcMicros: _now,
);

void main() {
  const calendar = Calendar();

  Day dayOf(int days) => calendar.dayOf(_day(days), 0);

  group('the refusal counter (FR-5, AD-24)', () {
    test('declines on 3 distinct eligible days count three, and the '
        'warrant fires (AC: the same Micro-task declined on 3 different '
        'eligible days)', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        ..._decline(2, 'cap-a'),
        ..._decline(3, 'cap-a'),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 3);
      expect(warranted(entries, 'cap-a', facts: [fact]), isTrue);
    });

    test('dealt-but-never-skipped days count zero — answers are not '
        'refusals, and a bare deal is not a decline', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      List<LogEntry> answered(int days) => [
        _started(_at(days, 10)),
        _row(LogKind.cardDealt, _at(days, 10, 0, 1), 'cap-a'),
        _row(LogKind.cardDone, _at(days, 10, 0, 2), 'cap-a'),
        _ended(_at(days, 10, 0, 3)),
      ];
      // Two answered days plus a dealt-only day: neither shape feeds
      // the skipped map a counter reading the dealt map would see.
      final entries = [
        ...answered(1),
        ...answered(2),
        _started(_at(3, 10)),
        _row(LogKind.cardDealt, _at(3, 10, 0, 1), 'cap-a'),
        _ended(_at(3, 10, 0, 2)),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 0);
      expect(warranted(entries, 'cap-a', facts: [fact]), isFalse);
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: [fact],
          instantUtcMicros: _now,
        ),
        isEmpty,
      );
    });

    test('another item\'s activation leaves this counter alone — '
        'resets are item-scoped', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        ..._decline(2, 'cap-a'),
        _started(_at(3, 10)),
        _slice(LogKind.sliceRequested, _at(3, 10, 0, 1), 'cap-b'),
        _ended(_at(3, 10, 0, 2)),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 2);
    });

    test('two eligible days do not warrant — the width is the capture '
        'window\'s own named three', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [..._decline(1, 'cap-a'), ..._decline(2, 'cap-a')];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 2);
      expect(warranted(entries, 'cap-a', facts: [fact]), isFalse);
    });

    test('an absence day neither increments nor resets — a day with no '
        'session start is not an eligible day, and the count freezes '
        'across it exactly as the capture window\'s does', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        ..._decline(2, 'cap-a'),
        // Days 3–9: nothing at all. Day 10 declines again.
        ..._decline(10, 'cap-a'),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 3);
      expect(warranted(entries, 'cap-a', facts: [fact]), isTrue);
    });

    test('a non-dealt day counts for nothing — a sitting that deals '
        'and skips a DIFFERENT item leaves this counter untouched', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        ..._decline(2, 'cap-b'),
        ..._decline(3, 'cap-a'),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 2);
    });

    test('energy filtering neither increments nor resets — a day whose '
        'sitting a low-energy row precedes is not an eligible day for a '
        'focus item, and the count freezes across it', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        // Day 2: baja before the sitting — the focus size is excluded
        // at the start, so the day is not eligible whatever was dealt.
        _energySet(_at(2, 9), EnergyLevel.low),
        ..._decline(2, 'cap-a'),
        ..._decline(3, 'cap-a'),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 2);
      expect(warranted(entries, 'cap-a', facts: [fact]), isFalse);
    });

    test('same-day re-skips stay one day — the set semantics the dealt '
        'days already hold', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        _started(_at(1, 10)),
        _row(LogKind.cardDealt, _at(1, 10, 0, 1), 'cap-a'),
        _row(LogKind.cardSkipped, _at(1, 10, 0, 2), 'cap-a'),
        _row(LogKind.cardDealt, _at(1, 11, 0, 1), 'cap-a'),
        _row(LogKind.cardSkipped, _at(1, 11, 0, 2), 'cap-a'),
        _ended(_at(1, 12)),
        ..._decline(2, 'cap-a'),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 2);
    });

    test('the skip charges to its session\'s day — a sitting that '
        'crosses 04:00 counts the decline on the day the sitting '
        'started, never the crossed-into day', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      // A sitting starting 03:50 on Aug 25 belongs to domestic day 0
      // (Aug 24 — the 04:00 boundary); its skip lands at 04:10, on the
      // crossed-into civil date, still day 0's charge.
      final crossing = [
        _started(utcMicros(2026, 8, 25, 3, 50)),
        _row(LogKind.cardDealt, utcMicros(2026, 8, 25, 4, 5), 'cap-a'),
        _row(LogKind.cardSkipped, utcMicros(2026, 8, 25, 4, 10), 'cap-a'),
        _ended(utcMicros(2026, 8, 25, 4, 15)),
      ];
      expect(walkLog(crossing).skippedDaysByItemId['cap-a'], {
        dayOf(0),
      }, reason: 'the crossed-into day (day 1) stays free of the charge');
      // Beside a day-2 decline of its own sitting, the union is the
      // two distinct session days — never three from two sittings.
      final entries = [...crossing, ..._decline(2, 'cap-a')];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 2);
    });

    test('an activation resets the counter — the latest '
        'slice_requested is the anchor, whatever follows (AC: success, '
        'failure or no-Slicer degradation alike)', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        // The activation: day 2's rescue (which then failed — the
        // slice_failed row rides beside it).
        _slice(LogKind.sliceRequested, _at(2, 10), 'cap-a'),
        _slice(LogKind.sliceFailed, _at(2, 10, 0, 1), 'cap-a'),
        ..._decline(3, 'cap-a'),
      ];
      expect(
        declineDays(entries, 'cap-a', facts: [fact]),
        1,
        reason:
            'day 1\'s decline precedes the activation; only day 3 '
            'counts — a failed rescue cannot re-fire on every deal',
      );
      expect(warranted(entries, 'cap-a', facts: [fact]), isFalse);
    });

    test('the skip after a failed rescue on that sitting counts '
        'toward the fresh cycle — EligibleDay keeps the item\'s '
        'genesis, and activation only filters earlier skips', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        _started(_at(2, 10)),
        _row(LogKind.cardDealt, _at(2, 10, 0, 1), 'cap-a'),
        _slice(LogKind.sliceRequested, _at(2, 10, 0, 2), 'cap-a'),
        _slice(LogKind.sliceFailed, _at(2, 10, 0, 3), 'cap-a'),
        _row(LogKind.cardSkipped, _at(2, 10, 0, 4), 'cap-a'),
        _ended(_at(2, 10, 0, 5)),
        ..._decline(3, 'cap-a'),
        ..._decline(4, 'cap-a'),
      ];
      expect(
        declineDays(entries, 'cap-a', facts: [fact]),
        3,
        reason:
            'day 1 precedes the activation; the sitting\'s own skip '
            'plus days 3 and 4 are the fresh cycle — the I/O row '
            '"Second tap after failure"',
      );
      expect(warranted(entries, 'cap-a', facts: [fact]), isTrue);
    });

    test('a skip from before the activation does not leak back when '
        'a later session starts on the same domestic day', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        _started(_at(2, 9)),
        _row(LogKind.cardDealt, _at(2, 9, 0, 1), 'cap-a'),
        _row(LogKind.cardSkipped, _at(2, 9, 0, 2), 'cap-a'),
        _ended(_at(2, 9, 0, 3)),
        _started(_at(2, 14)),
        _row(LogKind.cardDealt, _at(2, 14, 0, 1), 'cap-a'),
        _slice(LogKind.sliceRequested, _at(2, 14, 0, 2), 'cap-a'),
        _slice(LogKind.sliceFailed, _at(2, 14, 0, 3), 'cap-a'),
        _ended(_at(2, 14, 0, 4)),
        _started(_at(2, 18)),
        _ended(_at(2, 18, 0, 1)),
      ];
      expect(
        declineDays(entries, 'cap-a', facts: [fact]),
        0,
        reason:
            'the morning skip precedes the activation; an evening '
            'session start does not revive it',
      );
    });

    test('the latest activation is the last slice_requested in append '
        'order, even when an earlier row carries a later instant', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        _slice(LogKind.sliceRequested, _at(4, 12), 'cap-a'),
        _slice(LogKind.sliceRequested, _at(2, 10), 'cap-a'),
        ..._decline(3, 'cap-a'),
      ];
      expect(
        declineDays(entries, 'cap-a', facts: [fact]),
        1,
        reason:
            'the position-latest request is the day-2 row; day 3\'s '
            'skip follows it in the log and counts, whatever the '
            'day-4 instant on the earlier row',
      );
    });

    test('a delivered rescue resets the same way — slice_returned '
        'names no fresh decline, and the counter reads from the '
        'activation', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        ..._decline(2, 'cap-a'),
        _slice(LogKind.sliceRequested, _at(3, 10), 'cap-a'),
        _slice(LogKind.sliceReturned, _at(3, 10, 0, 1), 'cap-a'),
      ];
      expect(declineDays(entries, 'cap-a', facts: [fact]), 0);
    });

    test('rows after the read instant are skipped — the readers\' '
        'convention', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [
        ..._decline(1, 'cap-a'),
        ..._decline(2, 'cap-a'),
        ..._decline(3, 'cap-a'),
      ];
      expect(
        declineDays(entries, 'cap-a', facts: [fact], at: _at(2, 23)),
        2,
        reason: 'day 3\'s decline is still in the future at the read',
      );
    });
  });

  group('the fact-less catalogue anchor (FR-5, AD-24)', () {
    test('a shipped entry counts ever — no pool fact bounds "no '
        'earlier than", and the size reads off the entry', () {
      // Declines of a shipped focus entry across three eligible days,
      //with no fact anywhere in the pool.
      final entries = [
        ..._decline(1, 'zona-z1-a'),
        ..._decline(5, 'zona-z1-a'),
        ..._decline(9, 'zona-z1-a'),
      ];
      expect(declineDays(entries, 'zona-z1-a'), 3);
      expect(warranted(entries, 'zona-z1-a'), isTrue);
    });

    test('a shipped entry\'s activation bounds it — the catalogue '
        'anchor resets like the fact one', () {
      final entries = [
        ..._decline(1, 'zona-z1-a'),
        ..._decline(2, 'zona-z1-a'),
        _slice(LogKind.sliceRequested, _at(3, 10), 'zona-z1-a'),
        ..._decline(4, 'zona-z1-a'),
      ];
      expect(declineDays(entries, 'zona-z1-a'), 1);
    });

    test('an id no source knows answers nothing', () {
      expect(declineDays(const [], 'nobody'), 0);
      expect(warranted(const [], 'nobody'), isFalse);
    });

    test('energy filtering on a shipped focus entry neither '
        'increments nor resets — the catalogue adapter reads the '
        'entry\'s size into the one EligibleDay energy clause', () {
      final entries = [
        ..._decline(1, 'zona-z1-a'),
        _energySet(_at(2, 9), EnergyLevel.low),
        ..._decline(2, 'zona-z1-a'),
        ..._decline(3, 'zona-z1-a'),
      ];
      expect(
        declineDays(entries, 'zona-z1-a'),
        2,
        reason:
            'day 2\'s 🔴 start excludes the focus size, so the '
            'shipped entry\'s skip that sitting does not count',
      );
      expect(warranted(entries, 'zona-z1-a'), isFalse);
    });
  });

  group('the depth cap\'s derivation half (FR-5)', () {
    test('a rescue step has no counter at all — its declines feed '
        'dissolution, never a second rescue', () {
      final parent = _fact('cap-a', Size.focus, _at(0, 9));
      final step = _fact(
        'step-1',
        Size.instant,
        _at(1, 9),
        rescueOf: 'cap-a',
        estimateSeconds: 45,
      );
      final entries = [
        ..._decline(2, 'step-1'),
        ..._decline(3, 'step-1'),
        ..._decline(4, 'step-1'),
      ];
      expect(
        declineDays(entries, 'step-1', facts: [parent, step]),
        0,
        reason:
            'the warrant and the counter agree by construction: no '
            'ask can ever re-slice a step',
      );
      expect(warranted(entries, 'step-1', facts: [parent, step]), isFalse);
    });
  });

  group('the chain-level atomic dissolution (FR-5, AD-25)', () {
    test('declines of any chain steps on 3 distinct eligible days '
        'retire the whole chain — the union counts days, not steps', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('step-1', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
        _fact('step-2', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
      ];
      final entries = [
        ..._decline(2, 'step-1'),
        ..._decline(3, 'step-1'),
        ..._decline(4, 'step-2'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        {'cap-a'},
      );
    });

    test('same-day declines across steps count once — the union '
        'counts days, not steps', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('step-1', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
        _fact('step-2', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
      ];
      // Day 2 declines two steps in two sittings, day 3 one: two
      // distinct days, no dissolution.
      final entries = [
        ..._decline(2, 'step-1'),
        _started(_at(2, 11)),
        _row(LogKind.cardDealt, _at(2, 11, 0, 1), 'step-2'),
        _row(LogKind.cardSkipped, _at(2, 11, 0, 2), 'step-2'),
        _ended(_at(2, 11, 0, 3)),
        ..._decline(3, 'step-1'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        isEmpty,
      );
    });

    test('a completed step neither joins the union nor blocks it — '
        'parent and pending dissolve, the done step stays done', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('step-1', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
        _fact('step-2', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
      ];
      List<LogEntry> doneStep(int days) => [
        _started(_at(days, 10)),
        _row(LogKind.cardDealt, _at(days, 10, 0, 1), 'step-1'),
        _row(LogKind.cardDone, _at(days, 10, 0, 2), 'step-1'),
        _ended(_at(days, 10, 0, 3)),
      ];
      final entries = [
        ...doneStep(2),
        ..._decline(2, 'step-2'),
        ..._decline(3, 'step-2'),
        ..._decline(4, 'step-2'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        {'cap-a'},
      );
    });

    test('two distinct days retire nothing — a surviving chain is not '
        'a fragment re-woven forever, it is still live', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('step-1', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
      ];
      final entries = [..._decline(2, 'step-1'), ..._decline(3, 'step-1')];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        isEmpty,
      );
    });

    test('steps of different chains never union — each chain is its '
        'own refused thing', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('cap-b', Size.focus, _at(0, 9)),
        _fact('step-a1', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
        _fact('step-b1', Size.instant, _at(1, 9), rescueOf: 'cap-b'),
      ];
      final entries = [
        ..._decline(2, 'step-a1'),
        ..._decline(3, 'step-a1'),
        ..._decline(4, 'step-b1'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        isEmpty,
      );
    });

    test('a day the step\'s own creation precedes bounds the count — '
        'the fact\'s instant is the anchor\'s "no earlier than"', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        // The step exists only from day 2 on.
        _fact('step-1', Size.instant, _at(2, 9), rescueOf: 'cap-a'),
      ];
      // A decline row naming the step on day 1 — before its fact —
      // charges a day the anchor refuses.
      final entries = [
        ..._decline(1, 'step-1'),
        ..._decline(3, 'step-1'),
        ..._decline(4, 'step-1'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        isEmpty,
        reason: 'only days 3 and 4 count: two, short of three',
      );
    });

    test('an instant step is never energy-excluded — a low-energy day '
        'still counts toward the dissolution (the ≤ 60 s band passes '
        'the 🔴 ceiling by construction)', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('step-1', Size.instant, _at(1, 9), rescueOf: 'cap-a'),
      ];
      final entries = [
        ..._decline(2, 'step-1'),
        _energySet(_at(3, 9), EnergyLevel.low),
        ..._decline(3, 'step-1'),
        ..._decline(4, 'step-1'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        {'cap-a'},
      );
    });

    test('a parentless decline contributes nothing — captures feed '
        'their own counter, never a dissolution', () {
      final facts = [
        _fact('cap-a', Size.focus, _at(0, 9)),
        _fact('cap-b', Size.focus, _at(0, 9)),
      ];
      final entries = [
        ..._decline(2, 'cap-b'),
        ..._decline(3, 'cap-b'),
        ..._decline(4, 'cap-b'),
      ];
      expect(
        dissolvedChainParentIds(
          entries: entries,
          poolFacts: facts,
          instantUtcMicros: _now,
        ),
        isEmpty,
      );
    });
  });

  group('the anchor refactor (AD-24 — one predicate, two adapters)', () {
    test('the fact adapter equals the anchor form over the same fact', () {
      final fact = _fact('cap-a', Size.focus, _at(0, 9));
      final entries = [_started(_at(1, 10))];
      expect(
        eligibleDay(
          entries: entries,
          fact: fact,
          day: dayOf(1),
          instantUtcMicros: _now,
        ),
        eligibleDayOfAnchor(
          entries: entries,
          anchor: eligibleDayAnchorOfFact(fact),
          day: dayOf(1),
          instantUtcMicros: _now,
        ),
      );
    });

    test('the unbounded start admits any session — "no earlier than" '
        '= ever for a fact-less item', () {
      expect(eligibleDayUnboundedStart, lessThan(0));
      final entries = [_started(_at(1, 10))];
      expect(
        eligibleDayOfAnchor(
          entries: entries,
          anchor: (
            size: Size.focus,
            noEarlierThanUtcMicros: eligibleDayUnboundedStart,
          ),
          day: dayOf(1),
          instantUtcMicros: _now,
        ),
        isTrue,
      );
    });

    test('the walk exposes the counter\'s input — skippedDaysByItemId '
        'charges a decline to its session\'s day (the skip row\'s own '
        'attribution, never a second copy of the rule)', () {
      final entries = [..._decline(1, 'cap-a')];
      final facts = walkLog(entries).skippedDaysByItemId;
      expect(facts['cap-a'], {dayOf(1)});
    });
  });
}
