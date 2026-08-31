import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/day/calendar.dart';
import 'package:core/derive/checkpoint.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';
import 'package:test/test.dart';

import 'test_util.dart';

final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: [
    CatalogueEntry(
      id: 'zona-a',
      size: Size.focus,
      cadence: Cadence.weekly,
      zone: Zone.z1,
      name: 'Tarea de zona-a',
    ),
    CatalogueEntry(
      id: 'man-a',
      size: Size.maintenance,
      cadence: Cadence.daily,
      name: 'Tarea de man-a',
    ),
    CatalogueEntry(
      id: 'hab-a',
      size: Size.instant,
      cadence: Cadence.daily,
      name: 'Tarea de hab-a',
    ),
  ],
);

SessionStartEntry _started(int micros, {String id = 's', int? pocketMinutes}) =>
    SessionStartEntry(
      id: '$id-$micros',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.sessionStarted,
      pocketMinutes: pocketMinutes,
    );

MomentEntry _ended(int micros) => MomentEntry(
  id: 'e-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionEnded,
);

SessionExtendEntry _extended(int micros, int minutes) => SessionExtendEntry(
  id: 'x-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  pocketMinutes: minutes,
);

ItemActEntry _dealt(int micros, String itemId) => ItemActEntry(
  id: 'd-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDealt,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

ItemActEntry _done(int micros, String itemId) => ItemActEntry(
  id: 'a-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDone,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

void main() {
  test('the interval is the builder constant fifteen, pinned inside '
      '§10.1\'s 10–15 range — never a Settings row', () {
    expect(checkpointIntervalMinutes, 15);
    expect(checkpointIntervalMinutes, greaterThanOrEqualTo(10));
    expect(checkpointIntervalMinutes, lessThanOrEqualTo(15));
  });

  group('the I/O matrix (Story 2.4, FR-10)', () {
    test('mid-pocket multiple: a 45-pocket read at cumulative 15 or '
        'more is due, and one extension answers it and lifts the '
        'pocket', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_started(start, pocketMinutes: 45)];

      // The open span truncated at the read instant: 16 minutes
      // crossed the first multiple.
      final at16 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 16 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(at16.offerDue, isTrue);
      expect(
        at16.offerPreemptsStandingDeal,
        isFalse,
        reason:
            'no card stands; the controller reads offerDue alone '
            'as the offer leading the read over the deal that would '
            'resolve',
      );

      // Just below the interval: not due.
      final at14 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 14 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(at14.offerDue, isFalse);

      // The extension answers: the multiple floor at its own instant
      // (1) meets the crossed count, and the pocket lifts 45 → 60.
      final extended = [...log, _extended(start + 16 * microsPerMinute, 15)];
      final after = deriveCheckpoint(
        entries: extended,
        instantUtcMicros: start + 17 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(after.offerDue, isFalse);
      expect(
        walkLog(extended).openSessionPocketMinutes,
        60,
        reason:
            'the extension lifts the declared pocket (deadline and '
            'ceiling); the sum may pass the declarable range',
      );
    });

    test('three offers in a 45-pocket: extends accepted at 15 and 30 '
        'leave the third multiple due, and the ceiling runs '
        '45→60→75', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 45),
        _extended(start + 16 * microsPerMinute, 15),
        _extended(start + 31 * microsPerMinute, 15),
      ];
      final facts = walkLog(log);
      expect(facts.openSessionPocketMinutes, 75);

      final at46 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 46 * microsPerMinute,
        offsetSeconds: 0,
      );
      // The original 45-minute deadline elapsed at 45, but the lifted
      // pocket (75) holds the sitting open past it — and crossed 3
      // stands above answered 2.
      expect(at46.offerDue, isTrue);
    });

    test('stop at the offer: the close never consumes the multiple — '
        'the next sitting\'s first read offers once more', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 45),
        _ended(start + 16 * microsPerMinute),
      ];
      final afterStop = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 20 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(afterStop.offerDue, isFalse, reason: 'no session is open');

      // The next same-day sitting faces the standing permission at
      // its first read: the multiple survived the stop.
      final nextSitting = [
        ...log,
        _started(start + 30 * microsPerMinute, id: 's2', pocketMinutes: 10),
      ];
      final resumed = deriveCheckpoint(
        entries: nextSitting,
        instantUtcMicros: start + 30 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(resumed.offerDue, isTrue);
    });

    test('chained short pockets: four ten-minute sittings leave both '
        'crossed multiples standing, and one extension answers them '
        'both', () {
      final log = <LogEntry>[
        _started(utcMicros(2026, 8, 28, 10), id: 's1', pocketMinutes: 10),
        _ended(utcMicros(2026, 8, 28, 10, 10)),
        _started(utcMicros(2026, 8, 28, 10, 20), id: 's2', pocketMinutes: 10),
        _ended(utcMicros(2026, 8, 28, 10, 30)),
        _started(utcMicros(2026, 8, 28, 10, 40), id: 's3', pocketMinutes: 10),
        _ended(utcMicros(2026, 8, 28, 10, 50)),
        _started(utcMicros(2026, 8, 28, 11), id: 's4', pocketMinutes: 10),
        _ended(utcMicros(2026, 8, 28, 11, 10)),
        _started(utcMicros(2026, 8, 28, 11, 20), id: 's5', pocketMinutes: 10),
      ];
      final firstRead = deriveCheckpoint(
        entries: log,
        instantUtcMicros: utcMicros(2026, 8, 28, 11, 20),
        offsetSeconds: 0,
      );
      expect(
        firstRead.offerDue,
        isTrue,
        reason: 'cumulative 40 minutes: crossing 15 and 30 both stand',
      );

      final answered = [...log, _extended(utcMicros(2026, 8, 28, 11, 21), 15)];
      final after = deriveCheckpoint(
        entries: answered,
        instantUtcMicros: utcMicros(2026, 8, 28, 11, 22),
        offsetSeconds: 0,
      );
      expect(
        after.offerDue,
        isFalse,
        reason:
            'the floor at the extension\'s instant (2) answers '
            'every lower multiple too',
      );
    });

    test('card in flight at the crossing: dealt at cumulative 13, the '
        'card stays finishable and the offer waits; after it resolves '
        'the offer leads', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 45),
        _dealt(start + 13 * microsPerMinute, 'man-a'),
      ];
      final inFlight = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 16 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(inFlight.offerDue, isTrue);
      expect(
        inFlight.offerPreemptsStandingDeal,
        isFalse,
        reason:
            'the card was dealt before the crossing: the multiple '
            'floor at its deal instant is 0, not above answered',
      );

      final resolved = [...log, _done(start + 17 * microsPerMinute, 'man-a')];
      final afterAnswer = deriveCheckpoint(
        entries: resolved,
        instantUtcMicros: start + 18 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(afterAnswer.offerDue, isTrue);
      expect(
        afterAnswer.offerPreemptsStandingDeal,
        isFalse,
        reason:
            'no card stands any more; the controller reads this '
            'combination as the offer leading the read',
      );
    });

    test('card dealt into the pending offer: a deal at cumulative 17 '
        'yields to the offer, and the extension returns that card '
        'without re-dealing', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 45),
        _dealt(start + 17 * microsPerMinute, 'man-a'),
      ];
      final preempted = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 18 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(preempted.offerDue, isTrue);
      expect(preempted.offerPreemptsStandingDeal, isTrue);

      final extended = [...log, _extended(start + 19 * microsPerMinute, 15)];
      final after = deriveCheckpoint(
        entries: extended,
        instantUtcMicros: start + 20 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(after.offerDue, isFalse);
      expect(
        walkLog(extended).dealtUnanswered,
        (itemId: 'man-a', itemOrigin: Origin.shipped),
        reason:
            'the extension touches no card row: Quiero seguir '
            'returns the standing card, never a re-deal',
      );
    });

    test('coincides with close: a 15-pocket at cumulative 15 is the '
        'close\'s instant — the standing close wins, the offer is '
        'never due (UJ-1)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_started(start, pocketMinutes: 15)];
      final atClose = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 15 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(atClose.offerDue, isFalse);
    });

    test('short first session: the day\'s only session under one '
        'interval closes without an offer — the close is the '
        'permission (FR-10)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 10),
        _ended(start + 10 * microsPerMinute),
      ];
      final after = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 12 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(after.offerDue, isFalse);
    });

    test('day boundary: a session crossing 04:00 charges its span to '
        'its start day, and other days\' extensions answer nothing '
        'today', () {
      // 03:40 civil time sits on the earlier domestic day (the 04:00
      // boundary); the sitting crosses into the next civil day.
      final start = utcMicros(2026, 8, 28, 3, 40);
      final log = [_started(start, pocketMinutes: 60)];
      const calendar = Calendar();
      final startDay = calendar.dayOf(start, 0);
      expect(startDay.label, '2026-08-27');

      // A previous day's extension answers nothing for today's anchor.
      final yesterday = [
        _started(utcMicros(2026, 8, 26, 10), id: 'old', pocketMinutes: 30),
        _extended(utcMicros(2026, 8, 26, 10, 20), 15),
        _ended(utcMicros(2026, 8, 26, 10, 30)),
        ...log,
      ];
      final crossed = deriveCheckpoint(
        entries: yesterday,
        instantUtcMicros: utcMicros(2026, 8, 28, 4, 10),
        offsetSeconds: 0,
      );
      expect(
        crossed.offerDue,
        isTrue,
        reason:
            '30 minutes of the crossing sitting: crossed 2, '
            'answered 0 — the other day\'s extension is not '
            'today\'s answer',
      );

      // The crossing sitting's own extension, past the boundary,
      // charges to its start day and answers for it: the 04:05
      // extension stands on cumulative 15 (one multiple), and the
      // 04:10 read's cumulative 20 has crossed no second multiple.
      // Mis-charging the extension to its own instant's day would
      // leave answered 0 and the offer due — this pin is what fails.
      final ownExtend = [
        _started(utcMicros(2026, 8, 28, 3, 50), id: 's2', pocketMinutes: 60),
        _extended(utcMicros(2026, 8, 28, 4, 5), 15),
      ];
      final answered = deriveCheckpoint(
        entries: ownExtend,
        instantUtcMicros: utcMicros(2026, 8, 28, 4, 10),
        offsetSeconds: 0,
      );
      expect(answered.offerDue, isFalse);
    });

    test('an unbounded sitting (the auto-open, no declared pocket) '
        'offers at the crossing too: the cumulative alone decides, no '
        'deadline exists to elapse', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_started(start)];
      final at16 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 16 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(at16.offerDue, isTrue);
      final at14 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 14 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(at14.offerDue, isFalse);
    });

    test('an out-of-range start pocket derives absent (AD-23): the '
        'sitting reads unbounded — an extension on it bounds nothing — '
        'and the offer still derives off the cumulative', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 90),
        _extended(start + 16 * microsPerMinute, 15),
      ];
      expect(
        walkLog(log).openSessionPocketMinutes,
        isNull,
        reason:
            'the start row derives as absent and the extension '
            'cannot bound what no start declared',
      );
      final at46 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 46 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(
        at46.offerDue,
        isTrue,
        reason:
            'crossed 3 against answered 1: the derivation reads the '
            'cumulative and the acceptance, never the absent pocket',
      );
    });

    test('a prior sitting\'s acceptance answers for the day: the '
        'extension belongs to an ended same-day sitting, and the open '
        'sitting\'s first read owes no second offer', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, id: 's1', pocketMinutes: 20),
        _extended(start + 16 * microsPerMinute, 15),
        _ended(start + 20 * microsPerMinute),
        _started(start + 25 * microsPerMinute, id: 's2', pocketMinutes: 20),
      ];
      final resumed = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 25 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(
        resumed.offerDue,
        isFalse,
        reason:
            'the prior sitting\'s same-day acceptance answered the '
            'multiple (1 ≥ 1): an open-sitting-only answered rule would '
            're-offer here',
      );
    });

    test('a stray session_started while a span stands open abandons it '
        'at the new start\'s instant — no time is charged twice '
        '(imported logs; the shell\'s own sessionStart guards)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, id: 'abandoned', pocketMinutes: 60),
        _started(start + 10 * microsPerMinute, id: 'stray'),
      ];
      // At cumulative 14 (10 abandoned + 4 stray) no multiple has
      // crossed; charging the abandoned span through the read instant
      // would read 18 and cross the first multiple early.
      final at14 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 14 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(at14.offerDue, isFalse);
      final at16 = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 16 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(at16.offerDue, isTrue);
    });

    test('a session_extended interposed in a same-instant supersede '
        'pair degrades quietly: no crash, the card is not carried, and '
        'the orphan extension sums nothing (the walk\'s boundary)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final pairInstant = start + 10 * microsPerMinute;
      final log = [
        _started(start, id: 'a', pocketMinutes: 20),
        _dealt(start + 60 * 1000 * 1000, 'man-a'),
        _ended(pairInstant),
        _extended(pairInstant, 15),
        _started(pairInstant, id: 'b', pocketMinutes: 20),
      ];
      final facts = walkLog(log);
      expect(
        facts.dealtUnanswered,
        isNull,
        reason:
            'the interposed row breaks the pair\'s adjacency: the '
            'start clears the standing card instead of carrying it — '
            'the degraded boundary, never a crash',
      );
      expect(facts.openSessionPocketMinutes, 20);
      final state = deriveCheckpoint(
        entries: log,
        instantUtcMicros: start + 12 * microsPerMinute,
        offsetSeconds: 0,
      );
      expect(state.offerDue, isFalse);
    });
  });

  group('the close-continue probe (Story 2.4, UJ-1)', () {
    test('an elapsed pocket with candidates is the offer: the probe '
        'finds a deal, and after the extension the resolver deals '
        'it', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_started(start, pocketMinutes: 15)];
      final atClose = start + 15 * microsPerMinute;

      expect(
        nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isNull,
        reason: 'the pocket filter closes the deal',
      );
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isTrue,
        reason:
            'the pool holds candidates: the close carries Quiero '
            'seguir',
      );

      final extended = [...log, _extended(atClose, 15)];
      final deal = nextDeal(
        catalogue: _catalogue,
        log: extended,
        instantUtcMicros: atClose,
        offsetSeconds: 0,
      );
      expect(
        deal,
        isNotNull,
        reason:
            'the lifted pocket (30) re-opens the filter: the read '
            'after the tap deals',
      );
      expect(walkLog(extended).openSessionPocketMinutes, 30);
    });

    test('a pool-exhausted close probes false: no candidates anywhere, '
        'the close carries nothing', () {
      final start = utcMicros(2026, 8, 28, 10);
      // The canonical exhausted day inside the one sitting: the chunk
      // answered, all three maintenance and all five habit draws
      // dealt and answered. The sitting lingers derived-open, its
      // pocket long elapsed.
      final log = <LogEntry>[_started(start, pocketMinutes: 60)];
      var second = 1;
      for (final id in [
        'zona-a',
        'man-a',
        'man-a',
        'man-a',
        'hab-a',
        'hab-a',
        'hab-a',
        'hab-a',
        'hab-a',
      ]) {
        final at = start + second++ * 1000000;
        log
          ..add(_dealt(at, id))
          ..add(_done(at + 1000000, id));
        second++;
      }
      final atClose = start + 20 * microsPerMinute;

      expect(
        nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isNull,
      );
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isFalse,
        reason:
            'the day\'s draws are spent and the slot is closed: '
            'the lifted filter finds nothing either',
      );
    });

    test('an empty pool probes false, and no open session probes '
        'false — the probe is total over the close\'s states', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_started(start, pocketMinutes: 15)];
      final atClose = start + 15 * microsPerMinute;
      expect(
        dealExistsIgnoringPocket(
          catalogue: Catalogue(version: 1, entries: const []),
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isFalse,
      );
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: [...log, _ended(atClose)],
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isFalse,
        reason: 'no open session, no deal would exist',
      );
    });

    test('the probe reads the tiers beneath the chunk: a closed slot '
        'with maintenance draws remaining still finds a deal', () {
      final start = utcMicros(2026, 8, 28, 10);
      // The chunk answered (its slot closed), no maintenance drawn:
      // the maintenance tier must answer the probe on its own.
      final log = <LogEntry>[
        _started(start, pocketMinutes: 15),
        _dealt(start + 1000000, 'zona-a'),
        _done(start + 2000000, 'zona-a'),
      ];
      final atClose = start + 15 * microsPerMinute;
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isTrue,
        reason:
            'the maintenance tier alone carries the close\'s '
            'continue offer',
      );
    });

    test('the instant tier alone still finds a deal: chunk answered '
        'and all three maintenance draws spent', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = <LogEntry>[
        _started(start, pocketMinutes: 15),
        _dealt(start + 1000000, 'zona-a'),
        _done(start + 2000000, 'zona-a'),
        for (var draw = 0; draw < 3; draw++) ...[
          _dealt(start + (3000000 + draw * 2000000), 'man-a'),
          _done(start + (4000000 + draw * 2000000), 'man-a'),
        ],
      ];
      final atClose = start + 15 * microsPerMinute;
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: atClose,
          offsetSeconds: 0,
        ),
        isTrue,
        reason:
            'the instant tier alone carries the close\'s continue '
            'offer — deleting its branch from the shared ladder fails '
            'exactly here',
      );
    });

    test('the close-continue window: one more interval must reach '
        'beyond the read — just-elapsed offers (UJ-1), long-elapsed '
        'and unbounded sittings carry nothing (FR-10\'s dead-action '
        'rule)', () {
      final start = utcMicros(2026, 8, 28, 10);
      // Elapsed exactly at the read: the deadline plus one interval
      // (10:30) still holds instants beyond 10:15.
      final justElapsed = walkLog([_started(start, pocketMinutes: 15)]);
      expect(
        closeContinueReachable(
          facts: justElapsed,
          instantUtcMicros: start + 15 * microsPerMinute,
        ),
        isTrue,
      );

      // Forty minutes past a 15-pocket: the one interval reaches only
      // to 10:30, long gone — the tap would visibly change nothing.
      final longElapsed = walkLog([_started(start, pocketMinutes: 15)]);
      expect(
        closeContinueReachable(
          facts: longElapsed,
          instantUtcMicros: start + 40 * microsPerMinute,
        ),
        isFalse,
      );

      // The window rides the lifted pocket: one acceptance at the
      // close buys the next interval's window too.
      final extended = walkLog([
        _started(start, pocketMinutes: 15),
        _extended(start + 15 * microsPerMinute, 15),
      ]);
      expect(
        closeContinueReachable(
          facts: extended,
          instantUtcMicros: start + 40 * microsPerMinute,
        ),
        isTrue,
        reason:
            'the lifted pocket (30) plus one interval reaches to '
            '10:45',
      );

      // An unbounded sitting has no deadline to lift; no session, no
      // window either.
      expect(
        closeContinueReachable(
          facts: walkLog([_started(start)]),
          instantUtcMicros: start + 40 * microsPerMinute,
        ),
        isFalse,
      );
      expect(
        closeContinueReachable(
          facts: walkLog(const []),
          instantUtcMicros: start,
        ),
        isFalse,
      );
    });
  });

  group('the minter (Story 2.4, FR-10, AD-19)', () {
    test('sessionExtend appends exactly one session_extended row '
        'carrying the interval, and only while a session is open', () {
      final start = utcMicros(2026, 8, 28, 10);
      final open = [_started(start, pocketMinutes: 45)];
      final contents = sessionExtend(log: open);
      expect(contents, hasLength(1));
      expect(contents.single.kind, LogKind.sessionExtended);
      expect(contents.single.pocketMinutes, checkpointIntervalMinutes);
      expect(contents.single.itemId, isNull);
      expect(contents.single.itemOrigin, isNull);

      expect(
        sessionExtend(log: const []),
        isEmpty,
        reason: 'nothing open: the quiet no-op',
      );
      expect(
        sessionExtend(log: [...open, _ended(start + 16 * microsPerMinute)]),
        isEmpty,
        reason:
            'the session is closed: nothing appends, nothing '
            're-opens',
      );
    });
  });
}
