import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/rescue_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:test/test.dart';

import 'test_util.dart';

/// The Rescue Mode command triple (Story 4.6, FR-5, AD-3): the
/// activation that refuses a step (the depth cap, in core so no shell
/// path routes around it), the landing that mints the step facts and
/// the supersede pair — mirroring `_answered`'s answer-row + bundled
/// next `card_dealt` grammar — and the terminal failure row. Nothing
/// here mints ids or instants: the shell does, at the commit of the
/// act.

CatalogueEntry _catalogueEntry(String id, Size size) => CatalogueEntry(
  id: id,
  size: size,
  cadence: Cadence.daily,
  name: 'Tarea de $id',
);

final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: [
    _catalogueEntry('zona-a', Size.focus),
    _catalogueEntry('man-a', Size.maintenance),
    _catalogueEntry('hab-a', Size.instant),
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

ItemActEntry _dealt(int micros, String itemId) => ItemActEntry(
  id: 'dealt-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDealt,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

ItemActEntry _done(int micros, String itemId) => ItemActEntry(
  id: 'done-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDone,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

ItemActEntry _skipped(int micros, String itemId) => ItemActEntry(
  id: 'skipped-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardSkipped,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

SliceEntry _slice(LogKind kind, int micros, String itemId) => SliceEntry(
  id: 'slice-${kind.name}-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: kind,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

const List<RescueStepSeed> _seeds = [
  (
    id: 'step-000000000001',
    step: (
      text: 'Buscar el desengrasante bajo el fregadero',
      durationSeconds: 45,
    ),
  ),
  (
    id: 'step-000000000002',
    step: (text: 'Rociar la campana y dejar actuar', durationSeconds: 60),
  ),
  (
    id: 'step-000000000003',
    step: (text: 'Secar con un trapo limpio', durationSeconds: 30),
  ),
];

void main() {
  final parentFact = _fact('cap-a', Size.focus, utcMicros(2026, 8, 24, 9));

  /// The standing-deal log: one sitting holding the parent's dealt,
  /// unanswered card.
  List<LogEntry> standingLog() => [
    _started(utcMicros(2026, 8, 25, 10)),
    _dealt(utcMicros(2026, 8, 25, 10, 0, 1), 'cap-a'),
  ];

  group('rescueRequested — the activation (FR-5)', () {
    test('a normal item appends exactly one slice_requested row naming '
        'it, no counter consulted, no payload beyond the item pair', () {
      final contents = rescueRequested(
        itemId: 'cap-a',
        origin: Origin.manual,
        poolFacts: [parentFact],
        log: const [],
      );
      expect(contents, hasLength(1));
      final row = contents.single;
      expect(row.kind, LogKind.sliceRequested);
      expect(row.itemId, 'cap-a');
      expect(row.itemOrigin, Origin.manual);
      expect(row.sliceCause, isNull);
      expect(row.stack, isNull);
      expect(row.settingKey, isNull);
      expect(row.pocketMinutes, isNull);
      expect(row.energyLevel, isNull);
      expect(row.reportValue, isNull);
      expect(row.permission, isNull);
    });

    test('a shipped item appends its row too — the id is either '
        'shape\'s own, and no fact is required', () {
      final contents = rescueRequested(
        itemId: 'zona-a',
        origin: Origin.shipped,
        poolFacts: const [],
        log: const [],
      );
      expect(contents, hasLength(1));
      expect(contents.single.kind, LogKind.sliceRequested);
      expect(contents.single.itemId, 'zona-a');
      expect(contents.single.itemOrigin, Origin.shipped);
    });

    test('the depth cap lives here: a rescue step is refused outright '
        '— nothing appends, no refusal row exists, no error state is '
        'reachable', () {
      final stepFact = _fact(
        'step-1',
        Size.instant,
        utcMicros(2026, 8, 24, 9),
        rescueOf: 'cap-a',
        estimateSeconds: 45,
      );
      expect(
        rescueRequested(
          itemId: 'step-1',
          origin: Origin.manual,
          poolFacts: [parentFact, stepFact],
          log: const [],
        ),
        isEmpty,
      );
    });

    test('no second chain: an item whose steps already stand — live, '
        'completed or dissolved alike — is refused, whatever its rows '
        'say (the facts are the chain)', () {
      final stepFact = _fact(
        'step-1',
        Size.instant,
        utcMicros(2026, 8, 24, 9),
        rescueOf: 'cap-a',
        estimateSeconds: 45,
      );
      // Even a log holding no slice row at all (a corrupted or
      // partial history): the pool's chain is the chain.
      expect(
        rescueRequested(
          itemId: 'cap-a',
          origin: Origin.manual,
          poolFacts: [parentFact, stepFact],
          log: const [],
        ),
        isEmpty,
      );
      // And beside a delivered history the refusal holds too.
      expect(
        rescueRequested(
          itemId: 'cap-a',
          origin: Origin.manual,
          poolFacts: [parentFact, stepFact],
          log: [
            _slice(LogKind.sliceRequested, utcMicros(2026, 8, 24, 10), 'cap-a'),
            _slice(
              LogKind.sliceReturned,
              utcMicros(2026, 8, 24, 10, 0, 1),
              'cap-a',
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('a discard leaves no chain: a slice_returned that minted '
        'nothing (the parent was answered in flight) does not brick '
        'the item — its next ask appends', () {
      expect(
        rescueRequested(
          itemId: 'cap-a',
          origin: Origin.manual,
          poolFacts: [parentFact],
          log: [
            _slice(LogKind.sliceRequested, utcMicros(2026, 8, 24, 10), 'cap-a'),
            _slice(
              LogKind.sliceReturned,
              utcMicros(2026, 8, 24, 10, 0, 1),
              'cap-a',
            ),
          ],
        ),
        hasLength(1),
        reason: 'no fact names cap-a as its parent, so no chain exists',
      );
    });

    test('no pending double activation: a slice_requested no later '
        'slice row matched is refused — a second in-flight request '
        'would dangle beside the first', () {
      expect(
        rescueRequested(
          itemId: 'cap-a',
          origin: Origin.manual,
          poolFacts: [parentFact],
          log: [
            _slice(LogKind.sliceRequested, utcMicros(2026, 8, 24, 10), 'cap-a'),
          ],
        ),
        isEmpty,
      );
    });

    test('a matched activation re-arms: after slice_returned (no '
        'chain minted) or slice_failed, the next ask appends — a '
        'failed rescue never bricks the tap path', () {
      expect(
        rescueRequested(
          itemId: 'cap-a',
          origin: Origin.manual,
          poolFacts: [parentFact],
          log: [
            _slice(LogKind.sliceRequested, utcMicros(2026, 8, 24, 10), 'cap-a'),
            _slice(
              LogKind.sliceFailed,
              utcMicros(2026, 8, 24, 10, 0, 1),
              'cap-a',
            ),
          ],
        ),
        hasLength(1),
      );
    });
  });

  group('rescueReturned — the landing (FR-5)', () {
    test('the steps mint as facts — origin inherited from the parent '
        '(AD-14), size the fixed instant band, the Slicer\'s tag '
        'verbatim, the step\'s own text as its Origin Context — and '
        'the supersede pair lands with the HEAD step as the bundled '
        'deal (rescue precedence, nothing buries it)', () {
      final now = utcMicros(2026, 8, 25, 10, 0, 30);
      final returned = rescueReturned(
        itemId: 'cap-a',
        origin: Origin.manual,
        seeds: _seeds,
        catalogue: _catalogue,
        log: standingLog(),
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 25,
        poolFacts: [parentFact],
      );

      expect(returned.facts, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(
          returned.facts[i].origin,
          Origin.manual,
          reason: 'origin inherited, re-slice is not re-authorship',
        );
        expect(returned.facts[i].originContext, _seeds[i].step.text);
        expect(returned.facts[i].rescueOf, 'cap-a');
        expect(
          returned.facts[i].estimateSeconds,
          _seeds[i].step.durationSeconds,
        );
      }

      expect(returned.entries, hasLength(2));
      expect(returned.entries[0].kind, LogKind.sliceReturned);
      expect(returned.entries[0].itemId, 'cap-a');
      expect(returned.entries[1].kind, LogKind.cardDealt);
      expect(
        returned.entries[1].itemId,
        _seeds.first.id,
        reason:
            'the head step is the deal — the chain\'s first '
            'not-yet-answered step, at rescue precedence',
      );
      expect(returned.entries[1].itemOrigin, Origin.manual);
    });

    test('a parent answered in flight discards the steps: the row '
        'still logs, nothing supersedes, no fact mints (the frozen '
        'matrix\'s own row)', () {
      final now = utcMicros(2026, 8, 25, 10, 0, 30);
      final log = [
        ...standingLog(),
        _done(utcMicros(2026, 8, 25, 10, 0, 10), 'cap-a'),
      ];
      final returned = rescueReturned(
        itemId: 'cap-a',
        origin: Origin.manual,
        seeds: _seeds,
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 25,
        poolFacts: [parentFact],
      );
      expect(returned.facts, isEmpty);
      expect(returned.entries, hasLength(1));
      expect(returned.entries.single.kind, LogKind.sliceReturned);
      expect(returned.entries.single.itemId, 'cap-a');
    });

    test('a parent SKIPPED in flight discards the steps the same way: '
        'the deal the rescue was converting is gone, a supersede '
        'against a card that no longer stands would mint a chain '
        'behind the resolver\'s back — the row logs, nothing else '
        'lands', () {
      final now = utcMicros(2026, 8, 25, 10, 0, 30);
      final log = [
        ...standingLog(),
        // The activation this rescue is landing for...
        _slice(
          LogKind.sliceRequested,
          utcMicros(2026, 8, 25, 10, 0, 5),
          'cap-a',
        ),
        // ...then the user passed the stuck card while the provider
        // was still thinking: the skip ends the deal, and the skip's
        // own bundled next deal has already moved the sitting on.
        _skipped(utcMicros(2026, 8, 25, 10, 0, 20), 'cap-a'),
        _dealt(utcMicros(2026, 8, 25, 10, 0, 21), 'man-a'),
      ];
      final returned = rescueReturned(
        itemId: 'cap-a',
        origin: Origin.manual,
        seeds: _seeds,
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 25,
        poolFacts: [parentFact],
      );
      expect(
        returned.facts,
        isEmpty,
        reason: 'no step mints behind a deal that ended',
      );
      expect(returned.entries, hasLength(1));
      expect(returned.entries.single.kind, LogKind.sliceReturned);
    });

    test('a skip BEFORE the activation discards nothing — an old '
        'decline is not an in-flight interleaving, and the standing '
        'card of THIS deal supersedes normally', () {
      final now = utcMicros(2026, 8, 25, 10, 0, 30);
      // Yesterday's sitting skipped the item; today's sitting dealt it
      // again and asked — the skip precedes the activation.
      final log = [
        _started(utcMicros(2026, 8, 24, 10)),
        _dealt(utcMicros(2026, 8, 24, 10, 0, 1), 'cap-a'),
        _skipped(utcMicros(2026, 8, 24, 10, 0, 2), 'cap-a'),
        _started(utcMicros(2026, 8, 25, 10)),
        _dealt(utcMicros(2026, 8, 25, 10, 0, 1), 'cap-a'),
        _slice(
          LogKind.sliceRequested,
          utcMicros(2026, 8, 25, 10, 0, 5),
          'cap-a',
        ),
      ];
      final returned = rescueReturned(
        itemId: 'cap-a',
        origin: Origin.manual,
        seeds: _seeds,
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 25,
        poolFacts: [parentFact],
      );
      expect(returned.facts, hasLength(3));
      expect(returned.entries.last.kind, LogKind.cardDealt);
      expect(returned.entries.last.itemId, _seeds.first.id);
    });

    test('no silent truncation: every seed lands — the id and its '
        'step travel in one list, so a divergent parallel count is a '
        'shape this API cannot express', () {
      final now = utcMicros(2026, 8, 25, 10, 0, 30);
      final returned = rescueReturned(
        itemId: 'cap-a',
        origin: Origin.manual,
        seeds: _seeds,
        catalogue: _catalogue,
        log: standingLog(),
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 25,
        poolFacts: [parentFact],
      );
      // One fact per seed, in seed order, each carrying its own
      // step's text and tag verbatim — the whole batch or nothing.
      expect(returned.facts, hasLength(_seeds.length));
      for (final seed in _seeds) {
        expect(
          returned.facts.any(
            (fact) =>
                fact.originContext == seed.step.text &&
                fact.estimateSeconds == seed.step.durationSeconds,
          ),
          isTrue,
          reason: 'the seed ${seed.id} landed whole',
        );
      }
    });

    test('a session closed during flight deals nothing: the steps '
        'stand in the pool for the next sitting (no open session, no '
        'deal — the resolver\'s own line)', () {
      final now = utcMicros(2026, 8, 25, 10, 0, 30);
      final returned = rescueReturned(
        itemId: 'cap-a',
        origin: Origin.manual,
        seeds: _seeds,
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 25,
        poolFacts: [parentFact],
      );
      expect(returned.facts, hasLength(3));
      expect(returned.entries, hasLength(1));
      expect(returned.entries.single.kind, LogKind.sliceReturned);
    });
  });

  group('rescueFailed — the terminal failure (FR-5, FR-29)', () {
    test('appends exactly one slice_failed row carrying the cause '
        'wire name — the kind\'s single sanctioned minter', () {
      final contents = rescueFailed(
        itemId: 'cap-a',
        origin: Origin.manual,
        cause: SlicerFailureCause.networkUnreachable,
      );
      expect(contents, hasLength(1));
      final row = contents.single;
      expect(row.kind, LogKind.sliceFailed);
      expect(row.itemId, 'cap-a');
      expect(row.sliceCause, 'networkUnreachable');
      expect(row.permission, isNull);
    });
  });
}
