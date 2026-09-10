import 'package:core/derive/quarantine.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

/// The Quarantine Box derivation (Story 6.5, FR-21, AD-1, AD-3):
/// boxes from `box_created` rows alone, contents from linked
/// quarantine `item_triaged` rows alone — no other source consulted,
/// orphans skipped, never invented into boxes.
void main() {
  BoxCreatedEntry box(String id, {int instant = 1000}) =>
      BoxCreatedEntry(id: id, instantUtcMicros: instant, offsetSeconds: 3600);

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

  test('an empty log derives no boxes — and no other source exists to '
      'consult (AD-1)', () {
    expect(deriveQuarantine([]), isEmpty);
  });

  test('a box with no linked rows reconstructs as an honest empty box — '
      'the partial-act shape (a failed retry\'s orphan box)', () {
    final boxes = deriveQuarantine([box('box-1')]);
    expect(boxes, hasLength(1));
    expect(boxes.single.id, 'box-1');
    expect(boxes.single.instantUtcMicros, 1000);
    expect(boxes.single.offsetSeconds, 3600);
    expect(boxes.single.contents, isEmpty);
  });

  test('boxes derive in log order with their contents by link alone — '
      'the two kinds are the only source (FR-21, AD-3)', () {
    final boxes = deriveQuarantine([
      box('box-1', instant: 1000),
      triage('t-1', TriageDestination.quarantine, boxId: 'box-1'),
      triage('t-2', TriageDestination.quarantine, boxId: 'box-1'),
      triage('t-3', TriageDestination.donate_sell),
      triage(
        't-4',
        TriageDestination.trash_recycle,
        volumeTag: CoarseVolumeTag.bolsa,
      ),
      box('box-2', instant: 2000),
      triage('t-5', TriageDestination.quarantine, boxId: 'box-2'),
    ]);
    expect(boxes.map((b) => b.id).toList(), ['box-1', 'box-2']);
    expect(boxes.first.contents.map((e) => e.id).toList(), ['t-1', 't-2']);
    expect(boxes.last.contents.map((e) => e.id).toList(), ['t-5']);
    // The box's date is its own row's instant (AD-4) — not its
    // contents', not a maximum, not a stored value.
    expect(boxes.last.instantUtcMicros, 2000);
  });

  test('orphans are skipped, never invented into boxes — a missing link, '
      'an unmatched link and a non-quarantine row all contribute nothing '
      '(AD-23: tolerance, never repair)', () {
    final boxes = deriveQuarantine([
      triage('t-orphan-null', TriageDestination.quarantine),
      triage(
        't-orphan-unmatched',
        TriageDestination.quarantine,
        boxId: 'no-such-box',
      ),
      box('box-1'),
      triage('t-keep', TriageDestination.keep, boxId: 'box-1'),
    ]);
    expect(boxes, hasLength(1));
    expect(boxes.single.id, 'box-1');
    expect(
      boxes.single.contents,
      isEmpty,
      reason:
          'the keep row links a box but is not quarantine — membership is '
          'the link AND the destination, and neither alone invents it',
    );
  });

  test('a quarantine row linking a box minted later in the log is an '
      'orphan too — the fold reads one pass in replay order, the act\'s '
      'own shape (box first, then its content)', () {
    final boxes = deriveQuarantine([
      triage('t-early', TriageDestination.quarantine, boxId: 'box-late'),
      box('box-late'),
    ]);
    expect(boxes, hasLength(1));
    expect(boxes.single.id, 'box-late');
    expect(boxes.single.contents, isEmpty);
  });

  test('same-date boxes stay distinct rows — any date-collapse is 6.6\'s '
      'derivation concern, never this fold\'s', () {
    final boxes = deriveQuarantine([
      box('box-1', instant: 5000),
      triage(
        't-1',
        TriageDestination.quarantine,
        boxId: 'box-1',
        instant: 5000,
      ),
      box('box-2', instant: 5000),
      triage(
        't-2',
        TriageDestination.quarantine,
        boxId: 'box-2',
        instant: 5000,
      ),
    ]);
    expect(boxes.map((b) => b.id).toList(), ['box-1', 'box-2']);
    expect(boxes.first.contents.map((e) => e.id).toList(), ['t-1']);
    expect(boxes.last.contents.map((e) => e.id).toList(), ['t-2']);
  });

  test('the derivation is pure — nothing outside the two kinds moves the '
      'fold (every other entry type is skipped)', () {
    final boxes = deriveQuarantine([
      const MomentEntry(
        id: 'm-1',
        instantUtcMicros: 100,
        offsetSeconds: 0,
        kind: LogKind.appOpened,
      ),
      box('box-1'),
      const ItemActEntry(
        id: 'a-1',
        instantUtcMicros: 2000,
        offsetSeconds: 0,
        kind: LogKind.cardDone,
        itemId: 'item-1',
        itemOrigin: Origin.shipped,
      ),
    ]);
    expect(boxes, hasLength(1));
    expect(boxes.single.id, 'box-1');
  });

  test('no field of the derived box can hold a follow-up date — the '
      'shape is id, instant, offset and contents, nothing more (AD-1: '
      'six months is 6.6\'s derivation, never a stored value)', () {
    final boxes = deriveQuarantine([box('box-1')]);
    final single = boxes.single;
    expect(single.id, isA<String>());
    expect(single.instantUtcMicros, isA<int>());
    expect(single.offsetSeconds, isA<int>());
    expect(single.contents, isA<List<TriageEntry>>());
  });
}
