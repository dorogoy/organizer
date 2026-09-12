// The album read model's contract (Story 7.2, FR-18, AD-13, AD-21):
// the two folds — live entries and pinned names — over the log's
// album acts alone. No table, no manifest: membership and pins
// reconstruct from `before_saved`, `album_entry_added`,
// `album_entry_deleted` and `album_purged` rows, and every unlink
// decision routes through the pin fold's answer.
import 'package:core/derive/album.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

const Origin _origin = Origin.cloud;

LogEntry _before(String groupId, String blobName, int instant) =>
    BeforeSavedEntry(
      id: 'before-$groupId-$instant',
      instantUtcMicros: instant,
      offsetSeconds: 3600,
      itemId: groupId,
      itemOrigin: _origin,
      blobName: blobName,
    );

LogEntry _added(
  String groupId,
  String beforeName,
  String afterName,
  int instant,
) => AlbumEntryAddedEntry(
  id: 'added-$groupId-$instant',
  instantUtcMicros: instant,
  offsetSeconds: 3600,
  itemId: groupId,
  itemOrigin: _origin,
  beforeName: beforeName,
  afterName: afterName,
);

LogEntry _deleted(
  String groupId,
  String beforeName,
  String afterName,
  int instant,
) => AlbumEntryDeletedEntry(
  id: 'deleted-$groupId-$instant',
  instantUtcMicros: instant,
  offsetSeconds: 3600,
  itemId: groupId,
  itemOrigin: _origin,
  beforeName: beforeName,
  afterName: afterName,
);

LogEntry _purged(int instant) => AlbumPurgedEntry(
  id: 'purged-$instant',
  instantUtcMicros: instant,
  offsetSeconds: 3600,
);

void main() {
  group('albumEntries (the live fold, Story 7.2)', () {
    test('an empty log is an empty album — no table, no manifest, '
        'absence by absence (AD-21)', () {
      expect(albumEntries(const []), isEmpty);
    });

    test('adds appear as live entries in log order, carrying the pair, '
        'both names and the act\'s own instant', () {
      final entries = albumEntries([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _added('g2', 'c.jpg', 'd.jpg', 2000),
      ]);
      expect(entries, hasLength(2));
      expect(entries[0], (
        groupId: 'g1',
        origin: _origin,
        beforeName: 'a.jpg',
        afterName: 'b.jpg',
        addedUtcMicros: 1000,
        offsetSeconds: 3600,
      ));
      expect(entries[1].groupId, 'g2');
      expect(entries[1].afterName, 'd.jpg');
    });

    test('a delete tombstones the matching add by its before/after '
        'pair — and only that one', () {
      final entries = albumEntries([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _added('g2', 'c.jpg', 'd.jpg', 2000),
        _deleted('g1', 'a.jpg', 'b.jpg', 3000),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.groupId, 'g2');
    });

    test('a delete of an already-dead entry no-ops — the quiet '
        'idempotence a retry owes (the I/O matrix\'s double '
        'invocation)', () {
      final entries = albumEntries([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _deleted('g1', 'a.jpg', 'b.jpg', 2000),
        _deleted('g1', 'a.jpg', 'b.jpg', 3000),
      ]);
      expect(entries, isEmpty);
    });

    test('a purge clears everything before it — and an add after the '
        'purge lives', () {
      final entries = albumEntries([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _purged(2000),
        _added('g2', 'c.jpg', 'd.jpg', 3000),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.groupId, 'g2');
    });

    test('a delete that precedes its add kills nothing — order is '
        'the fold\'s whole clock (a re-saved pair lives)', () {
      final entries = albumEntries([
        _deleted('g1', 'a.jpg', 'b.jpg', 1000),
        _added('g1', 'a.jpg', 'b.jpg', 2000),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.groupId, 'g1');
    });

    test('the same group can hold two live entries with different '
        'pairs — one milestone each, never a per-group collapse', () {
      final entries = albumEntries([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _added('g1', 'c.jpg', 'd.jpg', 2000),
      ]);
      expect(entries, hasLength(2));
    });

    test('the delete match is group-scoped: a byte-identical pair in '
        'another group is that group\'s own transformation — deleting '
        'group A leaves group B\'s entry live (FR-18 deletes entries '
        'individually)', () {
      final entries = albumEntries([
        _added('gA', 'same.jpg', 'twin.jpg', 1000),
        _added('gB', 'same.jpg', 'twin.jpg', 2000),
        _deleted('gA', 'same.jpg', 'twin.jpg', 3000),
      ]);
      expect(entries, hasLength(1));
      expect(entries.single.groupId, 'gB');
      expect(entries.single.beforeName, 'same.jpg');
      expect(entries.single.afterName, 'twin.jpg');
    });
  });

  group('albumPinnedNames (the pin fold, Story 7.2)', () {
    test('a before_saved pins its Before name; an added pins both '
        'names', () {
      final pinned = albumPinnedNames([
        _before('g1', 'a.jpg', 500),
        _added('g1', 'a.jpg', 'b.jpg', 1000),
      ]);
      expect(pinned, {'a.jpg', 'b.jpg'});
    });

    test('deletion unpins the after blob while the before blob stays '
        'pinned by its own before_saved — the deliberate shot for the '
        'space (FR-25, the I/O matrix\'s exclusive-after row)', () {
      final pinned = albumPinnedNames([
        _before('g1', 'a.jpg', 500),
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _deleted('g1', 'a.jpg', 'b.jpg', 2000),
      ]);
      expect(pinned, {'a.jpg'});
    });

    test('a shared after name stays pinned while another live entry '
        'claims it — content addressing makes the pin a name '
        'equality, nothing more (the I/O matrix\'s shared-after row)', () {
      final pinned = albumPinnedNames([
        _before('g1', 'a.jpg', 500),
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _added('g2', 'c.jpg', 'b.jpg', 1500),
        _deleted('g1', 'a.jpg', 'b.jpg', 2000),
      ]);
      expect(pinned, {'a.jpg', 'c.jpg', 'b.jpg'});
    });

    test('an added without its before_saved still pins both names — '
        'the act is the claim, not the shot', () {
      final pinned = albumPinnedNames([_added('g1', 'a.jpg', 'b.jpg', 1000)]);
      expect(pinned, {'a.jpg', 'b.jpg'});
    });

    test('a purge kills every earlier claim, before_saved included — '
        'and a before_saved after the purge is effective (the '
        'post-purge milestone row)', () {
      final pinned = albumPinnedNames([
        _before('g1', 'a.jpg', 500),
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _purged(2000),
        _before('g2', 'c.jpg', 3000),
      ]);
      expect(pinned, {'c.jpg'});
    });

    test('a delete claims nothing: with no other claimant the killed '
        'entry\'s names leave the pin set entirely', () {
      final pinned = albumPinnedNames([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _deleted('g1', 'a.jpg', 'b.jpg', 2000),
      ]);
      expect(pinned, isEmpty);
    });

    test('a pair re-saved after its delete is pinned again — the '
        'delete killed only the earlier act', () {
      final pinned = albumPinnedNames([
        _added('g1', 'a.jpg', 'b.jpg', 1000),
        _deleted('g1', 'a.jpg', 'b.jpg', 2000),
        _added('g1', 'a.jpg', 'b.jpg', 3000),
      ]);
      expect(pinned, {'a.jpg', 'b.jpg'});
    });

    test('non-album kinds contribute nothing to the pin set', () {
      final pinned = albumPinnedNames([
        MomentEntry(
          id: 'm',
          instantUtcMicros: 1000,
          offsetSeconds: 0,
          kind: LogKind.appOpened,
        ),
      ]);
      expect(pinned, isEmpty);
    });

    test('the kill match is group-scoped too: another group\'s '
        'byte-identical pair stays pinned — one rule, no second '
        'definition', () {
      final pinned = albumPinnedNames([
        _added('gA', 'same.jpg', 'twin.jpg', 1000),
        _added('gB', 'same.jpg', 'twin.jpg', 2000),
        _deleted('gA', 'same.jpg', 'twin.jpg', 3000),
      ]);
      expect(pinned, {
        'same.jpg',
        'twin.jpg',
      }, reason: 'group B\'s live entry claims both names');
    });
  });

  group('albumUnlinkedByDelete (the unlink oracle over the pending '
      'act, Story 7.2)', () {
    test('answers the after blob alone when the before stays pinned '
        'by its own before_saved — the controller\'s exact unlink', () {
      final unlinked = albumUnlinkedByDelete(
        [_before('g1', 'a.jpg', 500), _added('g1', 'a.jpg', 'b.jpg', 1000)],
        groupId: 'g1',
        origin: _origin,
        beforeName: 'a.jpg',
        afterName: 'b.jpg',
        instantUtcMicros: 2000,
        offsetSeconds: 3600,
      );
      expect(unlinked, {'b.jpg'});
    });

    test('answers nothing while another live entry shares the after '
        'name — the shared-name pin through the pending act', () {
      final unlinked = albumUnlinkedByDelete(
        [
          _before('g1', 'a.jpg', 500),
          _before('g2', 'c.jpg', 600),
          _added('g1', 'a.jpg', 'b.jpg', 1000),
          _added('g2', 'c.jpg', 'b.jpg', 1500),
        ],
        groupId: 'g1',
        origin: _origin,
        beforeName: 'a.jpg',
        afterName: 'b.jpg',
        instantUtcMicros: 2000,
        offsetSeconds: 3600,
      );
      expect(unlinked, isEmpty);
    });

    test('answers both names when no claim stands — an added with no '
        'before_saved and no sibling', () {
      final unlinked = albumUnlinkedByDelete(
        [_added('g1', 'a.jpg', 'b.jpg', 1000)],
        groupId: 'g1',
        origin: _origin,
        beforeName: 'a.jpg',
        afterName: 'b.jpg',
        instantUtcMicros: 2000,
        offsetSeconds: 3600,
      );
      expect(unlinked, {'a.jpg', 'b.jpg'});
    });

    test('cross-group: deleting group A\'s byte-identical pair '
        'unlinks nothing — group B\'s live entry pins the shared '
        'names', () {
      final unlinked = albumUnlinkedByDelete(
        [
          _before('gA', 'same.jpg', 500),
          _before('gB', 'same.jpg', 600),
          _added('gA', 'same.jpg', 'twin.jpg', 1000),
          _added('gB', 'same.jpg', 'twin.jpg', 2000),
        ],
        groupId: 'gA',
        origin: _origin,
        beforeName: 'same.jpg',
        afterName: 'twin.jpg',
        instantUtcMicros: 3000,
        offsetSeconds: 3600,
      );
      expect(unlinked, isEmpty);
    });
  });
}
