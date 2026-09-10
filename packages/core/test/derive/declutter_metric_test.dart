import 'package:core/derive/declutter_metric.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

/// The cumulative declutter metric (Story 6.7, FR-22, AD-26):
/// per-destination counts over every `item_triaged` row, and tag
/// tallies over liberated rows alone — counts only, zero not null,
/// pure over the entries it is given.
void main() {
  TriageEntry triage(
    String id,
    TriageDestination destination, {
    String? boxId,
    CoarseVolumeTag? volumeTag,
    int instant = 1000,
  }) => TriageEntry(
    id: id,
    instantUtcMicros: instant,
    offsetSeconds: 3600,
    destination: destination,
    volumeTag: volumeTag,
    boxId: boxId,
  );

  const zero = (
    keepCount: 0,
    donateSellCount: 0,
    trashRecycleCount: 0,
    quarantineCount: 0,
    liberatedItems: 0,
    liberatedBolsa: 0,
    liberatedCaja: 0,
    liberatedCajaGrande: 0,
    liberatedMueble: 0,
  );

  test('an empty log derives every count zero, never null — zero is the '
      'honest cumulative (FR-22)', () {
    expect(deriveDeclutterMetric([]), zero);
  });

  test('an untagged liberated row counts its destination and '
      'liberatedItems, and no tag tally — declining to tag writes '
      'nothing (FR-22)', () {
    final metric = deriveDeclutterMetric([
      triage('t-1', TriageDestination.donate_sell),
    ]);
    expect(metric.keepCount, 0);
    expect(metric.donateSellCount, 1);
    expect(metric.trashRecycleCount, 0);
    expect(metric.quarantineCount, 0);
    expect(metric.liberatedItems, 1);
    expect(metric.liberatedBolsa, 0);
    expect(metric.liberatedCaja, 0);
    expect(metric.liberatedCajaGrande, 0);
    expect(metric.liberatedMueble, 0);
  });

  test('a tagged liberated row counts its destination, liberatedItems '
      'and its tag tally alone (FR-22, AD-26)', () {
    final metric = deriveDeclutterMetric([
      triage(
        't-1',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.caja,
      ),
      triage(
        't-2',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.bolsa,
      ),
      triage(
        't-3',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.caja_grande,
      ),
      triage(
        't-4',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.mueble,
      ),
    ]);
    expect(metric.trashRecycleCount, 2);
    expect(metric.donateSellCount, 2);
    expect(metric.liberatedItems, 4);
    expect(metric.liberatedBolsa, 1);
    expect(metric.liberatedCaja, 1);
    expect(metric.liberatedCajaGrande, 1);
    expect(metric.liberatedMueble, 1);
  });

  test('a tagged kept row counts its destination only — the tag '
      'contributes to no volume: a kept object liberates nothing '
      '(FR-22, AD-26)', () {
    final metric = deriveDeclutterMetric([
      triage('t-1', TriageDestination.keep, volumeTag: CoarseVolumeTag.caja),
    ]);
    expect(metric.keepCount, 1);
    expect(metric.liberatedItems, 0);
    expect(metric.liberatedCaja, 0);
  });

  test('a quarantine row counts its destination only — never '
      'liberated, no tally: a quarantined object liberates nothing '
      '(FR-21, FR-22, AD-26)', () {
    final metric = deriveDeclutterMetric([
      triage('t-1', TriageDestination.quarantine, boxId: 'box-1'),
    ]);
    expect(metric.quarantineCount, 1);
    expect(metric.liberatedItems, 0);
    expect(metric.liberatedCaja, 0);
  });

  test('read-boundary pairings the minter refuses are tolerated and '
      'counted by their facts alone — a tagged quarantine row tallies '
      'nothing, a boxed donate row still liberates (AD-23, FR-22)', () {
    final metric = deriveDeclutterMetric([
      triage(
        't-rogue-1',
        TriageDestination.quarantine,
        boxId: 'box-1',
        volumeTag: CoarseVolumeTag.caja,
      ),
      triage('t-rogue-2', TriageDestination.donate_sell, boxId: 'box-2'),
    ]);
    expect(metric.quarantineCount, 1);
    expect(
      metric.liberatedCaja,
      0,
      reason:
          'the minter refuses this shape, but a restored log may '
          'carry it — the fold counts facts, never repairs them',
    );
    expect(metric.donateSellCount, 1);
    expect(metric.liberatedItems, 1);
  });

  test('a full log across all four destinations counts every row, '
      'liberatedItems equals donate_sell + trash_recycle only, and '
      'tag tallies count tags on liberated rows alone (FR-22, AC)', () {
    final metric = deriveDeclutterMetric([
      triage('t-keep-1', TriageDestination.keep),
      triage(
        't-keep-2',
        TriageDestination.keep,
        volumeTag: CoarseVolumeTag.mueble,
      ),
      triage('t-donate-1', TriageDestination.donate_sell),
      triage(
        't-donate-2',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.bolsa,
      ),
      triage(
        't-donate-3',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.bolsa,
      ),
      triage(
        't-trash-1',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.caja,
      ),
      triage('t-quarantine-1', TriageDestination.quarantine, boxId: 'box-1'),
    ]);
    expect(metric.keepCount, 2);
    expect(metric.donateSellCount, 3);
    expect(metric.trashRecycleCount, 1);
    expect(metric.quarantineCount, 1);
    expect(metric.liberatedItems, 4);
    expect(metric.liberatedBolsa, 2);
    expect(metric.liberatedCaja, 1);
    expect(metric.liberatedCajaGrande, 0);
    expect(
      metric.liberatedMueble,
      0,
      reason:
          'the mueble tag rides a kept row — kept tags tally '
          'nowhere',
    );
  });

  test('the derivation is pure — two calls over the same entries '
      'derive identical records, and nothing but item_triaged rows '
      'move the fold (AD-1, FR-22)', () {
    final entries = [
      const MomentEntry(
        id: 'm-1',
        instantUtcMicros: 100,
        offsetSeconds: 0,
        kind: LogKind.appOpened,
      ),
      triage(
        't-1',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.caja,
      ),
      const ItemActEntry(
        id: 'a-1',
        instantUtcMicros: 2000,
        offsetSeconds: 0,
        kind: LogKind.cardDone,
        itemId: 'item-1',
        itemOrigin: Origin.shipped,
      ),
      const BoxCreatedEntry(
        id: 'box-1',
        instantUtcMicros: 3000,
        offsetSeconds: 3600,
      ),
      UnknownEntry(
        id: 'u-1',
        instantUtcMicros: 4000,
        offsetSeconds: 0,
        kind: LogKind.parse('future_kind_v99'),
      ),
    ];
    expect(deriveDeclutterMetric(entries), const (
      keepCount: 0,
      donateSellCount: 1,
      trashRecycleCount: 0,
      quarantineCount: 0,
      liberatedItems: 1,
      liberatedBolsa: 0,
      liberatedCaja: 1,
      liberatedCajaGrande: 0,
      liberatedMueble: 0,
    ));
    expect(deriveDeclutterMetric(entries), deriveDeclutterMetric(entries));
  });

  test('the counting fold is order-independent — a permuted snapshot '
      'derives the identical record, unlike the replay-order-sensitive '
      'quarantine fold (AD-1, FR-22)', () {
    final entries = [
      triage(
        't-1',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.caja,
      ),
      triage('t-2', TriageDestination.keep),
      triage(
        't-3',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.bolsa,
      ),
      triage('t-4', TriageDestination.quarantine, boxId: 'box-1'),
    ];
    expect(
      deriveDeclutterMetric(entries.reversed.toList()),
      deriveDeclutterMetric(entries),
    );
  });

  test('a later read that sees more rows derives counts that only '
      'grow — cumulative, never reset (FR-22, AC)', () {
    final early = deriveDeclutterMetric([
      triage(
        't-1',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.caja,
      ),
    ]);
    final later = deriveDeclutterMetric([
      triage(
        't-1',
        TriageDestination.donate_sell,
        volumeTag: CoarseVolumeTag.caja,
      ),
      triage(
        't-2',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.caja,
      ),
      triage('t-3', TriageDestination.keep),
    ]);
    expect(later.donateSellCount, early.donateSellCount);
    expect(later.trashRecycleCount, early.trashRecycleCount + 1);
    expect(later.liberatedItems, early.liberatedItems + 1);
    expect(later.liberatedCaja, early.liberatedCaja + 1);
    expect(later.keepCount, early.keepCount + 1);
    // The untouched fields stay put: growth is monotonic field by
    // field, not just on the five the appends move (FR-22).
    expect(later.quarantineCount, early.quarantineCount);
    expect(later.liberatedBolsa, early.liberatedBolsa);
    expect(later.liberatedCajaGrande, early.liberatedCajaGrande);
    expect(later.liberatedMueble, early.liberatedMueble);
  });

  // The counts-only shape (FR-22, AD-26) is enforced by
  // construction and pinned at compile time: the full-record const
  // literals above (the `zero` fixture and the purity expectation)
  // fail to compile the moment the typedef gains, loses or retypes
  // a field — the record's shape cannot drift silently. A runtime
  // `isA<int>` chain would re-assert the declared static types and
  // could never fail, so no such test lives here.
}
