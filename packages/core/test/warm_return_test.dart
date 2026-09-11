import 'package:core/curation/curation.dart';
import 'package:core/derive/warm_return.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MomentEntry _opened(int micros, {int offsetSeconds = 0, String id = 'open'}) =>
    MomentEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: offsetSeconds,
      kind: LogKind.appOpened,
    );

SessionStartEntry _started(
  int micros, {
  int offsetSeconds = 0,
  String id = 'start',
}) => SessionStartEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: offsetSeconds,
  kind: LogKind.sessionStarted,
);

MomentEntry _ended(int micros, {int offsetSeconds = 0, String id = 'end'}) =>
    MomentEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: offsetSeconds,
      kind: LogKind.sessionEnded,
    );

ItemActEntry _dealt(int micros, String itemId, {String id = 'deal'}) =>
    ItemActEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.cardDealt,
      itemId: itemId,
      itemOrigin: Origin.shipped,
    );

ItemActEntry _done(int micros, String itemId, {String id = 'done'}) =>
    ItemActEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.cardDone,
      itemId: itemId,
      itemOrigin: Origin.shipped,
    );

ItemActEntry _skipped(int micros, String itemId, {String id = 'skip'}) =>
    ItemActEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.cardSkipped,
      itemId: itemId,
      itemOrigin: Origin.shipped,
    );

ItemActEntry _captured(int micros, String itemId, {String id = 'capture'}) =>
    ItemActEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.captureCreated,
      itemId: itemId,
      itemOrigin: Origin.manual,
    );

TriageEntry _triaged(
  int micros, {
  TriageDestination destination = TriageDestination.keep,
  CoarseVolumeTag? volumeTag,
  String? boxId,
  String id = 'triage',
}) => TriageEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  destination: destination,
  volumeTag: volumeTag,
  boxId: boxId,
);

BoxCreatedEntry _boxCreated(int micros, {String id = 'box'}) =>
    BoxCreatedEntry(id: id, instantUtcMicros: micros, offsetSeconds: 0);

SessionExtendEntry _extended(int micros, {String id = 'extend'}) =>
    SessionExtendEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      pocketMinutes: 15,
    );

SettingEntry _setting(int micros, {String id = 'setting'}) => SettingEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  key: 'time_bag',
  value: 20,
);

EnergySetEntry _energy(int micros, {String id = 'energy'}) => EnergySetEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  level: EnergyLevel.low,
);

ReportAnsweredEntry _report(int micros, {String id = 'report'}) =>
    ReportAnsweredEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      value: 3,
      week: 1389,
    );

CrashEntry _crash(int micros, {String id = 'crash'}) => CrashEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  stack: 'Failed to load the catalogue',
);

UnknownEntry _unknown(int micros, {String id = 'unknown'}) => UnknownEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.parse('future_kind'),
);

SliceEntry _slice(LogKind kind, int micros) => SliceEntry(
  id: 'slice-${kind.name}-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: kind,
  itemId: 'cap-a',
  itemOrigin: Origin.manual,
);

MomentEntry _consented(int micros, {String id = 'consent'}) => MomentEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.consentGranted,
);

MomentEntry _declined(int micros, {String id = 'decline'}) => MomentEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.consentDeclined,
);

MomentEntry _abandoned(int micros, {String id = 'abandon'}) => MomentEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.scanAbandoned,
);

ItemActEntry _suggestionDismissed(
  int micros, {
  String id = 'dismiss',
  String itemId = 'epic-a',
}) => ItemActEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.suggestionDismissed,
  itemId: itemId,
  itemOrigin: Origin.cloud,
);

void main() {
  // "Now" for every read — Saturday 2026-08-29 12:00 UTC, the house
  // matrix clock. The 48 h boundary lands Thursday 2026-08-27 12:00.
  final now = utcMicros(2026, 8, 29, 12);

  // Instant offsets as microseconds — the read and the rows are plain
  // ints (AD-3: the core reads no clock, the tests hand it instants).
  int before(Duration gap) => now - gap.inMicroseconds;
  int after(Duration gap) => now + gap.inMicroseconds;

  bool due(List<LogEntry> entries, [int? at]) =>
      warmReturnDue(entries: entries, instantUtcMicros: at ?? now);

  test('the threshold is 48 h of wall clock — never a day count (AD-24)', () {
    expect(warmReturnThresholdMicros, const Duration(hours: 48).inMicroseconds);
  });

  group('the I/O matrix (FR-6)', () {
    test('first-ever open: one app_opened alone — no contact before it, '
        'not due', () {
      expect(due([_opened(now)]), isFalse);
      // And the read may land any time inside that lone opening.
      expect(due([_opened(now)], after(const Duration(minutes: 1))), isFalse);
    });

    test('boundary: contact exactly 48 h before the read — due, the '
        'comparison is inclusive', () {
      // A prior opening as the contact...
      expect(
        due([_opened(before(const Duration(hours: 48))), _opened(now)]),
        isTrue,
      );
      // ...and a user act as the contact: the prior day's stop, closed
      // exactly on the boundary.
      expect(
        due([
          _opened(utcMicros(2026, 8, 27, 11)),
          _ended(before(const Duration(hours: 48))),
          _opened(now),
        ]),
        isTrue,
      );
    });

    test('just under: contact 47 h 59 m 59 s before the read — not due', () {
      expect(
        due([
          _opened(before(const Duration(hours: 47, minutes: 59, seconds: 59))),
          _opened(now),
        ]),
        isFalse,
      );
    });

    test('a cluster curation flip is contact — it moves the anchor like '
        'any other user act (Story 5.11, AD-21)', () {
      // The 5-4 consent_granted discriminating shape: a 49 h-old open
      // plus a curation flip 47 h before the read reads not-due — the
      // flip is the later anchor.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          ClusterCurationChangedEntry(
            id: 'curation',
            instantUtcMicros: before(const Duration(hours: 47)),
            offsetSeconds: 0,
            cluster: CurationCluster.z1,
            enabled: false,
          ),
          _opened(now),
        ]),
        isFalse,
      );
      // The far-past arm: a flip alone long before the window does
      // not rescue the greeting — non-contact in that direction too.
      expect(
        due([
          ClusterCurationChangedEntry(
            id: 'curation-old',
            instantUtcMicros: before(const Duration(hours: 96)),
            offsetSeconds: 0,
            cluster: CurationCluster.fondo,
            enabled: true,
          ),
          _opened(before(const Duration(hours: 49))),
          _opened(now),
        ]),
        isTrue,
      );
    });

    test('daily lurker: a peek every 24 h moves the anchor — never due', () {
      expect(
        due([
          _opened(before(const Duration(hours: 72))),
          _opened(before(const Duration(hours: 48))),
          _opened(before(const Duration(hours: 24))),
          _opened(now),
        ]),
        isFalse,
      );
    });

    test('an act 30 m into the morning open is the anchor — the later of '
        'the open and the act', () {
      // The act sits 48 h 30 m before the read: due.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _dealt(before(const Duration(hours: 48, minutes: 30)), 'a'),
          _opened(now),
        ]),
        isTrue,
      );
      // The same shape with the act 47 h before the read: not due —
      // the act moved the anchor past the 49 h-old open, so the open's
      // own age counts for nothing.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _dealt(before(const Duration(hours: 47)), 'a'),
          _opened(now),
        ]),
        isFalse,
      );
    });

    test('every payload-carrying user-act kind moves the anchor — each '
        'act 47 h before the read makes the 49 h-old open count for '
        'nothing', () {
      // Had any kind contributed nothing (the crash and unknown
      // defaults), the anchor would stay on the 49 h-old open and the
      // predicate would read true — the false is the discriminator.
      final openBefore = _opened(before(const Duration(hours: 49)));
      final acts = <LogEntry>[
        _done(before(const Duration(hours: 47)), 'a'),
        _skipped(before(const Duration(hours: 47)), 'a'),
        _extended(before(const Duration(hours: 47))),
        _setting(before(const Duration(hours: 47))),
        _energy(before(const Duration(hours: 47))),
        _report(before(const Duration(hours: 47))),
        _captured(before(const Duration(hours: 47)), 'man-cap-a'),
        _triaged(
          before(const Duration(hours: 47)),
          volumeTag: CoarseVolumeTag.caja,
        ),
        // Story 6.5's rows: the quarantine act's `item_triaged` row
        // and its `box_created` sibling are both the user's own tap —
        // contact exactly as every other act is. Each act in this
        // loop stands ALONE as the newest act, so the box row's own
        // iteration is also the standalone partial-act shape: a
        // quarantine act whose triage append failed leaves the lone
        // box row as the last contact, and it still moves the anchor.
        _triaged(
          before(const Duration(hours: 47)),
          destination: TriageDestination.quarantine,
          boxId: 'box-1',
        ),
        _boxCreated(before(const Duration(hours: 47))),
        // Story 7.1's rows: the reward's two shots — the Before at
        // delivery and the album's pair — are the user holding the
        // camera and taking a photo, contact exactly as a capture is
        // (the `capture_created` precedent).
        BeforeSavedEntry(
          id: 'before-act',
          instantUtcMicros: before(const Duration(hours: 47)),
          offsetSeconds: 0,
          itemId: 'group-1',
          itemOrigin: Origin.cloud,
          blobName: 'a.jpg',
        ),
        AlbumEntryAddedEntry(
          id: 'album-act',
          instantUtcMicros: before(const Duration(hours: 47)),
          offsetSeconds: 0,
          itemId: 'group-1',
          itemOrigin: Origin.cloud,
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ];
      for (final act in acts) {
        expect(
          due([openBefore, act, _opened(now)]),
          isFalse,
          reason:
              '${act.kind.name} is a user act — the anchor is the '
              'act\'s own instant, under the threshold',
        );
      }
    });

    test('the rescue channel splits exactly (Story 4.6, AD-21): '
        '`slice_requested` and `slice_returned` are the user\'s ask '
        'and its delivery — contact — while `slice_failed` is a '
        'system event that must not reset the absence clock', () {
      final openBefore = _opened(before(const Duration(hours: 49)));
      // The ask and the delivery move the anchor: not due.
      for (final kind in [LogKind.sliceRequested, LogKind.sliceReturned]) {
        expect(
          due([
            openBefore,
            _slice(kind, before(const Duration(hours: 47))),
            _opened(now),
          ]),
          isFalse,
          reason: '${kind.name} is contact — the anchor moved',
        );
      }
      // The failure does not: an auto-heuristic that found no Slicer,
      //with no user act beside it, leaves a deserved Warm Return
      // standing — still due.
      expect(
        due([
          openBefore,
          _slice(LogKind.sliceFailed, before(const Duration(hours: 47))),
          _opened(now),
        ]),
        isTrue,
        reason: 'a system event never resets the 48 h clock',
      );
    });

    test('a crash row is never contact: excluded after the last contact — '
        'still due — and alone before the open — still not due', () {
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _crash(before(const Duration(hours: 1))),
          _opened(now),
        ]),
        isTrue,
      );
      expect(
        due([_crash(before(const Duration(hours: 49))), _opened(now)]),
        isFalse,
      );
    });

    test('a permission refusal is never contact — the user turning the '
        'app away is not the user using it (Story 3.4, AD-21, the '
        'crash precedent)', () {
      PermissionRefusedEntry refused(int micros, {String id = 'refusal'}) =>
          PermissionRefusedEntry(
            id: id,
            instantUtcMicros: micros,
            offsetSeconds: 0,
            permission: Permission.microphone,
          );
      // Alone before the open at any distance: not contact, so not due.
      expect(
        due([refused(before(const Duration(hours: 96))), _opened(now)]),
        isFalse,
      );
      // After real contact: the refusal moves the anchor not at all,
      // and the 49 h-old contact still anchors the greeting.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          refused(before(const Duration(hours: 1))),
          _opened(now),
        ]),
        isTrue,
      );
    });

    test('a consent grant is contact — the user actively using the app '
        '(Story 5.4, AD-8, the session_ended register)', () {
      // Alone before the first open the grant IS the prior contact —
      // the exact inverse of the refusal's shape above: the greeting
      // anchors on the act's own instant and reads due at 96 h.
      expect(
        due([_consented(before(const Duration(hours: 96))), _opened(now)]),
        isTrue,
        reason: 'consent_granted is contact — the anchor is the act',
      );
      // The discriminating shape: the grant sits 47 h before the read
      // and moves the anchor off the 49 h-old open — not due. Had the
      // kind defaulted to non-contact, the predicate would read true.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _consented(before(const Duration(hours: 47))),
          _opened(now),
        ]),
        isFalse,
        reason:
            'consent_granted is a user act — the anchor is the act\'s '
            'own instant, under the threshold',
      );
    });

    test('a consent decline is never contact — the user turning the '
        'photo down is not the user using the app (Story 5.5, FR-25, '
        'AD-21, the permission-refusal register)', () {
      // Alone before the open at any distance: not contact, so not due.
      expect(
        due([_declined(before(const Duration(hours: 96))), _opened(now)]),
        isFalse,
        reason:
            'a decline logs, but is not contact — no greeting owes '
            'on it',
      );
      // The discriminating shape: the decline sits 47 h before the
      // read and must not move the anchor off the 49 h-old open. Had
      // the kind defaulted to contact, the predicate would read false.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _declined(before(const Duration(hours: 47))),
          _opened(now),
        ]),
        isTrue,
        reason: 'the anchor is the open — the decline moved it not at all',
      );
    });

    test('an abandonment is never contact — the user walking away from '
        'the wait is not the user using it (Story 5.6, FR-16, AD-8, '
        'AD-21, the same-pass rule pinned: the moment default holds, '
        'warm return is unmoved by a departure)', () {
      // Alone before the open at any distance: not contact, so not
      // due — the naming table's user-act register never means
      // engagement, and no greeting owes on a walk-away.
      expect(
        due([_abandoned(before(const Duration(hours: 96))), _opened(now)]),
        isFalse,
        reason:
            'an abandonment logs, but is not contact — no greeting '
            'owes on it',
      );
      // The discriminating shape: the abandonment sits 47 h before
      // the read and must not move the anchor off the 49 h-old open.
      // Had the kind defaulted to contact, the predicate would read
      // false — the open's contact still anchors the greeting.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _abandoned(before(const Duration(hours: 47))),
          _opened(now),
        ]),
        isTrue,
        reason: 'the anchor is the open — the abandonment moved it not at all',
      );
    });

    test('a seasonal-suggestion dismissal is never contact — the ✕ of '
        'the strip is a decline, and FR-15\'s zero-side-effects '
        'consequence makes the carve-out load-bearing (Story 5.13, '
        'FR-15, AD-21 — a deserved warm return stays due with the '
        'dismissal as the latest row)', () {
      // Alone before the open at any distance: not contact, so not
      // due — the item-act shape carries the pair, but the fold
      // classifies by meaning, never shape.
      expect(
        due([
          _suggestionDismissed(before(const Duration(hours: 96))),
          _opened(now),
        ]),
        isFalse,
        reason:
            'a dismissal logs, but is not contact — no greeting owes '
            'on a decline',
      );
      // The discriminating shape (the `consent_declined` pin's own):
      // a 49 h-old opening with real contact 48.5 h back, then the
      // dismissal 47.5 h back, then a fresh open and the read. Had
      // the kind defaulted to contact — ItemActEntry\'s unconditional
      // fold before 5.13 — the dismissal would have become the
      // anchor and a deserved warm return would read false.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _dealt(before(const Duration(hours: 48, minutes: 30)), 'hab-a'),
          _suggestionDismissed(before(const Duration(hours: 47, minutes: 30))),
          _opened(now),
        ]),
        isTrue,
        reason: 'the anchor is the deal — the dismissal moved it not at all',
      );
    });

    test('the consent act obeys the same 48 h boundary discipline as '
        'every contact kind — at the threshold due, just under not '
        '(Story 5.4)', () {
      // The grant exactly 48 h before the read is the anchor: due —
      // the comparison is inclusive, the boundary test's own shape.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _consented(before(const Duration(hours: 48))),
          _opened(now),
        ]),
        isTrue,
        reason: 'contact exactly on the 48 h edge is due',
      );
      // One second inside the threshold: not due.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _consented(
            before(const Duration(hours: 47, minutes: 59, seconds: 59)),
          ),
          _opened(now),
        ]),
        isFalse,
        reason: 'contact 47 h 59 m 59 s old sits under the threshold',
      );
    });

    test('the opening batch at the open\'s own instant contributes nothing — '
        'the anchor is prior contact', () {
      // A prior day, contacted 49 h 30 m before the read; today's
      // opening carries the batch shape one minted instant serves
      // (session_started and card_dealt at the open's own instant, in
      // store order after it). Had the batch counted as contact, the
      // anchor would be the opening's own instant and the predicate
      // could never fire.
      final prior = before(const Duration(hours: 50));
      expect(
        due([
          _opened(prior),
          _started(prior + const Duration(seconds: 1).inMicroseconds),
          _dealt(prior + const Duration(seconds: 2).inMicroseconds, 'a'),
          _ended(prior + const Duration(minutes: 30).inMicroseconds),
          _opened(now),
          _started(now),
          _dealt(now, 'b'),
        ]),
        isTrue,
      );
    });

    test('mid-session read: a tap inside the opening never moves the '
        'anchor — due stands through the session', () {
      final entries = [
        _opened(before(const Duration(hours: 49))),
        _opened(now),
        _dealt(after(const Duration(minutes: 10)), 'a'),
      ];
      expect(due(entries, after(const Duration(minutes: 10))), isTrue);
      // Later still, with more acts after the last open: the anchor
      // holds.
      final longer = [...entries, _ended(after(const Duration(minutes: 20)))];
      expect(due(longer, after(const Duration(minutes: 25))), isTrue);
    });

    test('the next opening inside 48 h: gone by derivation alone', () {
      // A warm opening (due) at `now`; acts land inside it; the next
      // opening arrives an hour later — the anchor is now those acts,
      // and the gap is under an hour.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _opened(now),
          _dealt(after(const Duration(minutes: 5)), 'a'),
          _ended(after(const Duration(minutes: 6))),
          _opened(after(const Duration(hours: 1))),
        ], after(const Duration(hours: 1))),
        isFalse,
      );
    });

    test('a second consecutive 48 h gap is due again — the greeting '
        'legitimately repeats', () {
      // Two back-to-back 48 h gaps: each open's contact is the open
      // before it, so both reads land exactly on the inclusive
      // boundary. No once-per-anything state exists to consume.
      expect(
        due([
          _opened(before(const Duration(hours: 96))),
          _opened(before(const Duration(hours: 48))),
          _opened(now),
        ]),
        isTrue,
      );
    });

    test('no app_opened at all: no current opening is defined — false '
        '(the pure-function edge)', () {
      expect(
        due([
          _started(before(const Duration(hours: 49))),
          _dealt(before(const Duration(hours: 48)), 'a'),
          _ended(before(const Duration(hours: 47))),
        ]),
        isFalse,
      );
    });

    test('an unknown kind row contributes nothing to the anchor', () {
      // The unknown row is newer than the real contact and inside
      // 48 h: had it counted, the anchor would move inside the window
      // and the predicate would flip — it does not.
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _unknown(before(const Duration(hours: 47))),
          _opened(now),
        ]),
        isTrue,
      );
    });

    test('rows after the read instant are skipped — a future app_opened '
        'in the list does not become the current opening', () {
      // Contact 48 h 59 m before the read; a same-cycle open 47 h
      // before it; then an open stamped past the read instant. With
      // the skip, the anchor is the prior day's contact (due); without
      // it, the future open would be current and the anchor its
      // 47 h-old predecessor (not due).
      expect(
        due([
          _opened(before(const Duration(hours: 49))),
          _ended(before(const Duration(hours: 48, minutes: 59))),
          _opened(before(const Duration(hours: 47))),
          _opened(after(const Duration(hours: 1))),
        ]),
        isTrue,
      );
    });
  });
}
