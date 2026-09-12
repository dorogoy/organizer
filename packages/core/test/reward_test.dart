/// The reward derivations' contract (Story 7.1, FR-17, AD-25): the
/// two milestone facts and the Before lookup, over the weave's own
/// group fold and the walk's own answered fold — pure, deterministic,
/// writing nothing. Fixtures build groups exactly as a landed slice
/// does: facts with origin cloud/local, `rescueOf` null and
/// `stepText` set, all sharing one landing instant and description
/// (the insert-only grouping key), the group's STABLE id being its
/// first fact's id.
library;

import 'package:core/derive/reward.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

const Origin _origin = Origin.cloud;

PoolFact _step(
  String id,
  int instant, {
  String description = 'Un rincón con cajas',
  Origin origin = _origin,
}) => PoolFact(
  id: id,
  origin: origin,
  size: Size.maintenance,
  instantUtcMicros: instant,
  offsetSeconds: 3600,
  originContext: description,
  dictated: null,
  rescueOf: null,
  estimateSeconds: 240,
  stepText: 'Recoger una caja',
);

LogEntry _start(int instant) => SessionStartEntry(
  id: 'start-$instant',
  instantUtcMicros: instant,
  offsetSeconds: 3600,
  kind: LogKind.sessionStarted,
);

LogEntry _deal(String itemId, int instant) => ItemActEntry(
  id: 'deal-$itemId-$instant',
  instantUtcMicros: instant,
  offsetSeconds: 3600,
  kind: LogKind.cardDealt,
  itemId: itemId,
  itemOrigin: _origin,
);

LogEntry _done(String itemId, int instant, {Origin origin = _origin}) =>
    ItemActEntry(
      id: 'done-$itemId-$instant',
      instantUtcMicros: instant,
      offsetSeconds: 3600,
      kind: LogKind.cardDone,
      itemId: itemId,
      itemOrigin: origin,
    );

LogEntry _before(String groupId, String blobName, int instant) =>
    BeforeSavedEntry(
      id: 'before-$groupId-$instant',
      instantUtcMicros: instant,
      offsetSeconds: 3600,
      itemId: groupId,
      itemOrigin: _origin,
      blobName: blobName,
    );

void main() {
  group('retiringGroupId (the project milestone, Story 7.1)', () {
    test('the card_done that answers a group\'s last step retires '
        'it — the stable id, not the step id, is the answer', () {
      final pool = [_step('s1', 1000), _step('s2', 1000)];
      final log = [_deal('s1', 2000), _done('s1', 2100), _done('s2', 2200)];
      final retired = retiringGroupId(pool, log, completedItemId: 's2');
      expect(retired, isNotNull);
      expect(retired!.groupId, 's1');
      expect(retired.origin, _origin);
    });

    test('the answer is the named item\'s own — never the log\'s tail: '
        'a later card_done on another group cannot be mistaken for the '
        'completion that fired the derivation (the explicit contract)', () {
      // s2 retired the group at 2200; a LATER unrelated answer (a
      // capture on another space) lands at 2300. The tail inference
      // would read the capture's answer; the explicit id reads the
      // completion the call site actually made.
      final pool = [_step('s1', 1000), _step('s2', 1000)];
      final log = [_done('s1', 2100), _done('s2', 2200), _done('man-9', 2300)];
      final retired = retiringGroupId(pool, log, completedItemId: 's2');
      expect(retired, isNotNull);
      expect(retired!.groupId, 's1');
      // The mirror: naming the later answer retires nothing — its
      // item owns no group.
      expect(retiringGroupId(pool, log, completedItemId: 'man-9'), isNull);
    });

    test('a card_done leaving steps unanswered retires nothing', () {
      final pool = [_step('s1', 1000), _step('s2', 1000)];
      final log = [_done('s1', 2100)];
      expect(retiringGroupId(pool, log, completedItemId: 's1'), isNull);
    });

    test('a local-origin group retires with its local origin intact', () {
      const origin = Origin.local;
      final pool = [
        _step('s1', 1000, origin: origin),
        _step('s2', 1000, origin: origin),
      ];
      final retired = retiringGroupId(pool, [
        _done('s1', 2100, origin: origin),
        _done('s2', 2200, origin: origin),
      ], completedItemId: 's2');
      expect(retired, isNotNull);
      expect(retired!.groupId, 's1');
      expect(retired.origin, origin);
    });

    test('a card_done naming no group step retires nothing — the '
        'catalogue, a capture, a rescue step and a purge id alike', () {
      final pool = [
        _step('s1', 1000),
        PoolFact(
          id: 'manual-1',
          origin: Origin.manual,
          size: Size.instant,
          instantUtcMicros: 900,
          offsetSeconds: 0,
          originContext: 'una línea',
          dictated: null,
          rescueOf: null,
          estimateSeconds: null,
          stepText: null,
        ),
      ];
      expect(
        retiringGroupId(pool, [
          _done('manual-1', 2100),
        ], completedItemId: 'manual-1'),
        isNull,
      );
      expect(
        retiringGroupId(pool, [
          _done('unknown', 2100),
        ], completedItemId: 'unknown'),
        isNull,
      );
      expect(
        retiringGroupId(pool, [
          _done('purge:s1', 2100),
        ], completedItemId: 'purge:s1'),
        isNull,
      );
    });

    test('a step fact with no stepText is no group — the fold is the '
        'weave\'s own (a rescue step never retires a group here)', () {
      final pool = [
        PoolFact(
          id: 'r1',
          origin: _origin,
          size: Size.instant,
          instantUtcMicros: 1000,
          offsetSeconds: 0,
          originContext: 'chain',
          dictated: null,
          rescueOf: 'parent',
          estimateSeconds: 30,
          stepText: null,
        ),
      ];
      expect(
        retiringGroupId(pool, [_done('r1', 2100)], completedItemId: 'r1'),
        isNull,
      );
    });

    test('an empty log retires nothing', () {
      expect(
        retiringGroupId([_step('s1', 1000)], const [], completedItemId: 's1'),
        isNull,
      );
    });
  });

  group('sessionMilestoneGroupId (the session milestone, Story 7.1)', () {
    test('the space with the most in-session completions wins — one '
        'space per session', () {
      // Two steps answered of three: the group stands unretired with
      // two completions, against the other group's one.
      final pool = [
        _step('a1', 1000),
        _step('a2', 1000),
        _step('a3', 1000),
        _step('b1', 2000),
        _step('b2', 2000),
      ];
      final log = [
        _start(100),
        _done('a1', 300),
        _done('b1', 400),
        _done('a2', 500),
      ];
      final milestone = sessionMilestoneGroupId(
        poolFacts: pool,
        log: log,
        sessionStartUtcMicros: 100,
      );
      expect(milestone, isNotNull);
      expect(milestone!.groupId, 'a1');
      expect(milestone.origin, _origin);
    });

    test('completions before the session\'s start count for nothing', () {
      final pool = [_step('a1', 1000)];
      final log = [_done('a1', 50), _start(100)];
      expect(
        sessionMilestoneGroupId(
          poolFacts: pool,
          log: log,
          sessionStartUtcMicros: 100,
        ),
        isNull,
      );
    });

    test('append order excludes a prior session after a clock rollback', () {
      final pool = [
        _step('a1', 1000),
        _step('a2', 1000),
        _step('b1', 2000),
        _step('b2', 2000),
      ];
      final log = [
        _start(1000),
        _done('a1', 1200),
        MomentEntry(
          id: 'end-1201',
          instantUtcMicros: 1201,
          offsetSeconds: 3600,
          kind: LogKind.sessionEnded,
        ),
        _start(1100), // The device clock was moved backwards.
        _done('b1', 1110),
      ];
      expect(
        sessionMilestoneGroupId(
          poolFacts: pool,
          log: log,
          sessionStartUtcMicros: 1100,
        )!.groupId,
        'b1',
      );
    });

    test('a local-origin group can earn the session milestone', () {
      const origin = Origin.local;
      final pool = [
        _step('a1', 1000, origin: origin),
        _step('a2', 1000, origin: origin),
      ];
      final milestone = sessionMilestoneGroupId(
        poolFacts: pool,
        log: [
          _start(100),
          _done('a1', 300, origin: origin),
        ],
        sessionStartUtcMicros: 100,
      );
      expect(milestone, isNotNull);
      expect(milestone!.groupId, 'a1');
      expect(milestone.origin, origin);
    });

    test('a group retired within the session is excluded — the '
        'project milestone owns that moment', () {
      final pool = [_step('a1', 1000), _step('b1', 2000), _step('b2', 2000)];
      final log = [
        _start(100),
        _done('a1', 300), // retires group a
        _done('b1', 400), // b's first step — b is not retired
      ];
      final milestone = sessionMilestoneGroupId(
        poolFacts: pool,
        log: log,
        sessionStartUtcMicros: 100,
      );
      expect(milestone, isNotNull);
      expect(milestone!.groupId, 'b1');
    });

    test('a session with no group completion names no space', () {
      final pool = [_step('a1', 1000)];
      final log = [_start(100), _deal('a1', 300)];
      expect(
        sessionMilestoneGroupId(
          poolFacts: pool,
          log: log,
          sessionStartUtcMicros: 100,
        ),
        isNull,
      );
    });

    test('ties break by earliest group creation instant, then stable '
        'id — deterministic over facts that exist (AD-3)', () {
      final pool = [
        _step('z1', 2000),
        _step('z2', 2000),
        _step('a1', 1000),
        _step('a2', 1000),
      ];
      final log = [_start(100), _done('z1', 300), _done('a1', 400)];
      expect(
        sessionMilestoneGroupId(
          poolFacts: pool,
          log: log,
          sessionStartUtcMicros: 100,
        )!.groupId,
        'a1',
      );
      final sameInstantPool = [
        _step('z1', 1000, description: 'otro rincón'),
        _step('z2', 1000, description: 'otro rincón'),
        _step('a1', 1000),
        _step('a2', 1000),
      ];
      expect(
        sessionMilestoneGroupId(
          poolFacts: sameInstantPool,
          log: log,
          sessionStartUtcMicros: 100,
        )!.groupId,
        'a1',
      );
    });
  });

  group('spaceBeforeName (the Before lookup, Story 7.1)', () {
    test('the latest before_saved row naming the group wins', () {
      final log = [
        _before('g', 'old.jpg', 1000),
        _before('g', 'new.jpg', 2000),
      ];
      expect(spaceBeforeName(log, 'g'), 'new.jpg');
    });

    test('a row naming another group answers nothing', () {
      final log = [_before('other', 'a.jpg', 1000)];
      expect(spaceBeforeName(log, 'g'), isNull);
    });

    test('no row at all is the no-Before space — declined, '
        'camera-blocked and typed-genesis alike', () {
      expect(spaceBeforeName(const [], 'g'), isNull);
    });
  });
}
