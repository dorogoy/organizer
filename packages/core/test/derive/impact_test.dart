import 'package:core/catalogue/catalogue.dart';
import 'package:core/derive/impact.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:test/test.dart';

import '../test_util.dart';

/// The cumulative impact read (Story 7.4, FR-23, AD-26): the AD-26
/// crossing surface over the walk, the metric and the album fold —
/// work figures charged session-independently through the one
/// table, per-tag volume tallies over liberated rows alone, and the
/// three newest highlights with the group-fold place join and each
/// act's own civil-day offset (AD-4).
void main() {
  final catalogue = Catalogue(
    version: 1,
    entries: const [
      CatalogueEntry(
        id: 'focus-a',
        size: Size.focus,
        cadence: Cadence.daily,
        name: 'Tarea de focus-a',
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

  ItemActEntry act(
    LogKind kind,
    int micros,
    String itemId, {
    Origin origin = Origin.shipped,
  }) => ItemActEntry(
    id: 'a-$micros-$itemId',
    instantUtcMicros: micros,
    offsetSeconds: 0,
    kind: kind,
    itemId: itemId,
    itemOrigin: origin,
  );

  SessionStartEntry started(int micros) => SessionStartEntry(
    id: 's-$micros',
    instantUtcMicros: micros,
    offsetSeconds: 0,
    kind: LogKind.sessionStarted,
    pocketMinutes: 15,
  );

  MomentEntry ended(int micros) => MomentEntry(
    id: 'e-$micros',
    instantUtcMicros: micros,
    offsetSeconds: 0,
    kind: LogKind.sessionEnded,
  );

  TriageEntry triage(
    String id,
    TriageDestination destination, {
    CoarseVolumeTag? volumeTag,
    int instant = 1000,
  }) => TriageEntry(
    id: id,
    instantUtcMicros: instant,
    offsetSeconds: 0,
    destination: destination,
    volumeTag: volumeTag,
  );

  AlbumEntryAddedEntry albumEntry(
    String group,
    int micros, {
    Origin origin = Origin.cloud,
    int offsetSeconds = 0,
  }) => AlbumEntryAddedEntry(
    id: 'al-$group-$micros',
    instantUtcMicros: micros,
    offsetSeconds: offsetSeconds,
    itemId: group,
    itemOrigin: origin,
    beforeName: 'before-$group.jpg',
    afterName: 'after-$group.jpg',
  );

  /// One scan group's head fact — a slicer-origin step carrying the
  /// space description the caption joins on.
  PoolFact scanFact(
    String id,
    String context, {
    int instant = 500,
    String? stepText = 'Primer paso',
  }) => PoolFact(
    id: id,
    origin: Origin.cloud,
    size: Size.maintenance,
    instantUtcMicros: instant,
    offsetSeconds: 0,
    originContext: context,
    stepText: stepText,
    estimateSeconds: 240,
  );

  test('zero rows derive every figure zero and no highlights — zero is '
      'the honest cumulative, and the empty album is the empty read '
      '(FR-23, UX-DR51)', () {
    final read = deriveImpact(
      entries: const [],
      catalogue: catalogue,
      poolFacts: const [],
    );
    expect(read.answeredSecondsAllTime, 0);
    expect(read.cardDoneCount, 0);
    expect(read.liberatedBolsa, 0);
    expect(read.liberatedCaja, 0);
    expect(read.liberatedCajaGrande, 0);
    expect(read.liberatedMueble, 0);
    expect(read.highlights, isEmpty);
  });

  test('estimates charge session-independently — a done outside any '
      'session still counts, and a closed session never resets the '
      'all-time figure (Story 7.4, FR-23)', () {
    final open = utcMicros(2026, 9, 1, 10);
    final close = utcMicros(2026, 9, 1, 11);
    final later = utcMicros(2026, 9, 2, 10);
    final read = deriveImpact(
      entries: [
        // Inside a session: the sitting's own charge.
        started(open),
        act(LogKind.cardDone, open + 1, 'focus-a'),
        ended(close),
        // Outside any session (no sanctioned writer mints one, AD-23
        // carries it): still charged — completed work is never
        // un-done by a missing session.
        act(LogKind.cardDone, later, 'hab-a'),
        // And a done inside a LATER session: the all-time figure sums
        // across every boundary.
        started(later + 1),
        act(LogKind.cardDone, later + 2, 'man-a'),
      ],
      catalogue: catalogue,
      poolFacts: const [],
    );
    expect(read.answeredSecondsAllTime, 15 * 60 + 30 + 3 * 60);
    expect(read.cardDoneCount, 3);
  });

  test('a rescue step charges its OWN verbatim estimate, never its '
      "size's default — the duration-consuming rules read the estimate "
      '(Story 4.6 rule, read here through 7.4)', () {
    final step = PoolFact(
      id: 'rescue-1',
      origin: Origin.shipped,
      size: Size.instant,
      instantUtcMicros: 500,
      offsetSeconds: 0,
      originContext: 'Un paso más fácil',
      rescueOf: 'man-a',
      estimateSeconds: 45,
    );
    final read = deriveImpact(
      entries: [act(LogKind.cardDone, 1000, 'rescue-1')],
      catalogue: catalogue,
      poolFacts: [step],
    );
    expect(
      read.answeredSecondsAllTime,
      45,
      reason: 'the recorded tag, never estimateSecondsOf(Size.instant)',
    );
  });

  test('a done purge charges its fixed 60 s, and an unknown id charges '
      'no seconds while its act still counts (Story 6.1, AD-23, FR-23)', () {
    final read = deriveImpact(
      entries: [
        act(LogKind.cardDone, 1000, 'purge:g1'),
        act(LogKind.cardDone, 2000, 'id-never-known'),
      ],
      catalogue: catalogue,
      poolFacts: const [],
    );
    expect(read.answeredSecondsAllTime, purgeStepEstimateSeconds);
    expect(
      read.cardDoneCount,
      2,
      reason: 'the unknown id charged no seconds, but the act happened',
    );
  });

  test('per-tag volume tallies cross from the metric verbatim — tags on '
      'liberated rows alone, kept and quarantined tags tally nothing '
      '(FR-22, AD-26)', () {
    final read = deriveImpact(
      entries: [
        triage(
          't-1',
          TriageDestination.donate_sell,
          volumeTag: CoarseVolumeTag.bolsa,
        ),
        triage(
          't-2',
          TriageDestination.trash_recycle,
          volumeTag: CoarseVolumeTag.caja,
        ),
        triage(
          't-3',
          TriageDestination.donate_sell,
          volumeTag: CoarseVolumeTag.caja_grande,
        ),
        triage(
          't-4',
          TriageDestination.trash_recycle,
          volumeTag: CoarseVolumeTag.mueble,
        ),
        triage('t-5', TriageDestination.donate_sell),
        triage(
          't-6',
          TriageDestination.keep,
          volumeTag: CoarseVolumeTag.mueble,
        ),
        triage('t-7', TriageDestination.quarantine),
      ],
      catalogue: catalogue,
      poolFacts: const [],
    );
    expect(read.liberatedBolsa, 1);
    expect(read.liberatedCaja, 1);
    expect(read.liberatedCajaGrande, 1);
    expect(read.liberatedMueble, 1);
  });

  test('highlights are the three newest live entries, newest first, '
      'with the group-fold place join (Story 7.4, mockup §3)', () {
    final groups = [
      scanFact('g1', 'La mesa del salón'),
      scanFact('g2', 'El trastero', instant: 600),
      scanFact('g3', 'La entrada', instant: 700),
      scanFact('g4', 'El armario', instant: 800),
    ];
    final read = deriveImpact(
      entries: [
        albumEntry('g1', 1000, offsetSeconds: 3600),
        albumEntry('g2', 2000, offsetSeconds: 7200),
        albumEntry('g3', 3000, offsetSeconds: -7200),
        // Older than every highlight and dead besides: a tombstoned
        // entry surfaces nowhere.
        albumEntry('g-dead', 500),
        AlbumEntryDeletedEntry(
          id: 'del-1',
          instantUtcMicros: 600,
          offsetSeconds: 0,
          itemId: 'g-dead',
          itemOrigin: Origin.cloud,
          beforeName: 'before-g-dead.jpg',
          afterName: 'after-g-dead.jpg',
        ),
        // The fourth-newest live entry: outside the row.
        albumEntry('g4', 4000),
      ],
      catalogue: catalogue,
      poolFacts: groups,
    );
    expect(read.highlights.map((highlight) => highlight.beforeName).toList(), [
      'before-g4.jpg',
      'before-g3.jpg',
      'before-g2.jpg',
    ], reason: 'newest first, the gallery order, newest three only');
    expect(read.highlights.first.place, 'El armario');
    expect(read.highlights[1].place, 'La entrada');
    expect(read.highlights[2].place, 'El trastero');
    expect(read.highlights.first.addedUtcMicros, 4000);
    // The civil-day recovery (AD-4): each highlight carries the offset
    // its own add act recorded — recovered by the group-and-instant
    // key off the raw entries — so the caption's short date is the
    // act's own recorded civil day, never the reading device's zone.
    expect(read.highlights.map((highlight) => highlight.offsetSeconds), [
      0,
      -7200,
      7200,
    ], reason: 'newest first: g4 (0), g3 (-7200), g2 (7200)');
  });

  test('a missing group lookup or a null Origin Context renders no '
      'place — the caption degrades to the date alone, never an '
      'invented label (matrix: missing origin context)', () {
    // A typed-genesis-style fact with no retained context, plus an
    // album entry whose group no fold knows.
    final contextless = PoolFact(
      id: 'g-silent',
      origin: Origin.cloud,
      size: Size.maintenance,
      instantUtcMicros: 500,
      offsetSeconds: 0,
      estimateSeconds: 240,
      stepText: 'Paso sin contexto',
    );
    final read = deriveImpact(
      entries: [albumEntry('g-silent', 1000), albumEntry('g-unknown', 2000)],
      catalogue: catalogue,
      poolFacts: [contextless],
    );
    expect(read.highlights, hasLength(2));
    expect(
      read.highlights[0].place,
      isNull,
      reason: 'no group fold knows g-unknown',
    );
    expect(
      read.highlights[1].place,
      isNull,
      reason: 'the group resolves but its context is null',
    );
    // The names and the instant still cross — the pair renders, the
    // caption is simply dateless.
    expect(read.highlights[0].beforeName, 'before-g-unknown.jpg');
    expect(read.highlights[1].afterName, 'after-g-silent.jpg');
    expect(read.highlights[1].addedUtcMicros, 1000);
  });

  test('the derivation is pure — two calls over the same inputs derive '
      'identical figures (AD-1)', () {
    final entries = [
      started(utcMicros(2026, 9, 1, 10)),
      act(LogKind.cardDone, utcMicros(2026, 9, 1, 10, 1), 'focus-a'),
      triage(
        't-1',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.caja,
      ),
      albumEntry('g1', 4000),
    ];
    final facts = [scanFact('g1', 'La mesa del salón')];
    final first = deriveImpact(
      entries: entries,
      catalogue: catalogue,
      poolFacts: facts,
    );
    final second = deriveImpact(
      entries: entries,
      catalogue: catalogue,
      poolFacts: facts,
    );
    expect(first.answeredSecondsAllTime, second.answeredSecondsAllTime);
    expect(first.cardDoneCount, second.cardDoneCount);
    expect(first.liberatedCaja, second.liberatedCaja);
    expect(first.highlights.length, second.highlights.length);
    expect(
      first.highlights.map((highlight) => highlight.beforeName),
      second.highlights.map((highlight) => highlight.beforeName),
    );
  });

  // The crossing surface's closed shape (AD-26) is enforced by
  // construction and pinned at compile time: this suite reads only the
  // seven fields the typedef declares, and no field of `DeclutterMetric`
  // beyond the four tallies is spread into the record — a `liberatedItems`
  // subtotal or a per-destination count reaching the dashboard would
  // have to be named here first.
}
