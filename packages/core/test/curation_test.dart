import 'package:core/catalogue/catalogue.dart';
import 'package:core/curation/curation.dart';
import 'package:core/day/calendar.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import 'test_util.dart';

CurationObservation _obs(
  CurationCluster cluster,
  bool enabled,
  int micros, {
  int offsetSeconds = 0,
}) => (
  cluster: cluster,
  enabled: enabled,
  instantUtcMicros: micros,
  offsetSeconds: offsetSeconds,
);

void main() {
  // The fixture week is anchored Monday 2026-08-24 and closes at Monday
  // 2026-08-31 04:00 — every timing case below turns on that boundary.
  final wednesday = utcMicros(2026, 8, 26, 12);
  final thursday = utcMicros(2026, 8, 27, 12);
  final sundayNight = utcMicros(2026, 8, 30, 22);
  final boundaryExact = utcMicros(2026, 8, 31, 4);
  final boundaryJustBefore = utcMicros(2026, 8, 31, 3, 59, 59, 999, 999);
  final nextWeek = utcMicros(2026, 9, 1, 12);
  final weekAfterNextBoundary = utcMicros(2026, 9, 7, 4);

  test('the default is all-active: no observations, nothing curated away '
      '(AD-16)', () {
    expect(activeClustersAt(const [], wednesday), allCurationClusters);
    expect(
      activeClustersAt([
        _obs(CurationCluster.anclas, true, wednesday),
      ], wednesday),
      allCurationClusters,
    );
  });

  test('clusters derive from the tuple only: cadence, size and zone '
      '(AD-16)', () {
    CurationCluster clusterOf(
      String id,
      Size size,
      Cadence cadence, {
      Zone? zone,
    }) => curationClusterOfEntry(
      CatalogueEntry(
        id: id,
        size: size,
        cadence: cadence,
        zone: zone,
        name: 'Tarea de $id',
      ),
    );
    expect(
      clusterOf('habito', Size.instant, Cadence.daily),
      CurationCluster.anclas,
    );
    expect(
      clusterOf('upkeep', Size.maintenance, Cadence.daily),
      CurationCluster.sosten,
    );
    expect(
      clusterOf('cierre', Size.focus, Cadence.daily),
      CurationCluster.sosten,
    );
    expect(
      clusterOf('zona', Size.focus, Cadence.weekly, zone: Zone.z3),
      CurationCluster.z3,
    );
    expect(
      clusterOf('fondo', Size.focus, Cadence.seasonal),
      CurationCluster.fondo,
    );
    expect(
      clusterOf('zona-manten', Size.maintenance, Cadence.weekly, zone: Zone.z5),
      CurationCluster.z5,
    );

    for (final zone in Zone.values) {
      expect(curationClusterOfZone(zone).name, zone.name);
      expect(zoneOfCurationCluster(curationClusterOfZone(zone)), zone);
    }
    expect(zoneOfCurationCluster(CurationCluster.anclas), isNull);
    expect(zoneOfCurationCluster(CurationCluster.sosten), isNull);
    expect(zoneOfCurationCluster(CurationCluster.fondo), isNull);
  });

  test('a hand-built weekly entry with no zone fails fast, named — never a '
      'null dereference', () {
    expect(
      () => curationClusterOfEntry(
        CatalogueEntry(
          id: 'zona-fantasma',
          size: Size.focus,
          cadence: Cadence.weekly,
          name: 'Tarea de zona-fantasma',
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('zona-fantasma'),
            contains('A12.4'),
            contains('parseCatalogue'),
          ),
        ),
      ),
      reason:
          'parseCatalogue guarantees the zone on the asset path; only a '
          'drifted fixture can reach this, and it fails named like '
          'walkLog\'s duplicate-id guard',
    );
  });

  group('weekly-zone changes take effect after the observation\'s week '
      '(AD-16)', () {
    test('a mid-week disable keeps its zone active for the rest of the '
        'week, then turns it away', () {
      final disabledMidWeek = [
        _obs(CurationCluster.z2, false, utcMicros(2026, 8, 26, 10)),
      ];
      // Still the observation's own week — Sunday composes z2.
      expect(
        activeClustersAt(disabledMidWeek, utcMicros(2026, 8, 30, 12)),
        allCurationClusters,
      );
      // The next week: only z2 left the set.
      expect(
        activeClustersAt(disabledMidWeek, nextWeek),
        _allBut(CurationCluster.z2),
      );
    });

    test('an instant exactly on the week boundary belongs to the new week', () {
      final disabledMidWeek = [
        _obs(CurationCluster.z2, false, utcMicros(2026, 8, 26, 10)),
      ];
      final justBefore = activeClustersAt(disabledMidWeek, boundaryJustBefore);
      expect(justBefore.contains(CurationCluster.z2), isTrue);
      final exact = activeClustersAt(disabledMidWeek, boundaryExact);
      expect(exact.contains(CurationCluster.z2), isFalse);
      expect(exact, _allBut(CurationCluster.z2));
    });

    test('a Sunday change takes effect at Monday 04:00 — hours later, not '
        'next Sunday', () {
      final disabledSundayNight = [
        _obs(CurationCluster.z1, false, sundayNight),
      ];
      expect(
        activeClustersAt(
          disabledSundayNight,
          boundaryJustBefore,
        ).contains(CurationCluster.z1),
        isTrue,
        reason: 'the Sunday the observation was made keeps its zone',
      );
      expect(
        activeClustersAt(disabledSundayNight, boundaryExact),
        _allBut(CurationCluster.z1),
      );
    });
  });

  group('anclas, sostén and fondo changes take effect on their own day '
      '(AD-16, FR-31)', () {
    test('a disable is effective the same domestic day, even an instant '
        'before it was made', () {
      final disabledAtTen = [
        _obs(CurationCluster.anclas, false, utcMicros(2026, 8, 26, 10)),
      ];
      // Earlier the same domestic day: the whole day sees the change.
      expect(
        activeClustersAt(disabledAtTen, utcMicros(2026, 8, 26, 9)),
        _allBut(CurationCluster.anclas),
      );
      expect(
        activeClustersAt(disabledAtTen, utcMicros(2026, 8, 26, 12)),
        _allBut(CurationCluster.anclas),
      );
      // The day before: nothing effective yet.
      expect(
        activeClustersAt(disabledAtTen, utcMicros(2026, 8, 25, 12)),
        allCurationClusters,
      );
    });

    test('fondo and sostén behave the same — their own day, immediately', () {
      expect(
        activeClustersAt([
          _obs(CurationCluster.fondo, false, thursday),
        ], thursday),
        _allBut(CurationCluster.fondo),
      );
      expect(
        activeClustersAt([
          _obs(CurationCluster.sosten, false, wednesday),
        ], utcMicros(2026, 8, 26, 12, 30)),
        _allBut(CurationCluster.sosten),
      );
    });

    test('a change at exactly 04:00 belongs to its new day', () {
      expect(
        activeClustersAt([
          _obs(CurationCluster.fondo, false, boundaryExact),
        ], boundaryExact),
        _allBut(CurationCluster.fondo),
      );
      expect(
        activeClustersAt([
          _obs(CurationCluster.fondo, false, boundaryExact),
        ], boundaryJustBefore),
        allCurationClusters,
      );
    });

    test('a pre-04:00 observation belongs to the previous civil date\'s '
        'day, effective from that day\'s opening', () {
      // Set at 02:00 on the civil 27th — before 04:00, so its domestic
      // day is 2026-08-26, which opened at the 26th's 04:00.
      const calendar = Calendar();
      final observedDay = calendar.dayOf(utcMicros(2026, 8, 27, 2), 0);
      expect(observedDay.label, '2026-08-26');
      final fondoOffAtTwoAm = [
        _obs(CurationCluster.fondo, false, utcMicros(2026, 8, 27, 2)),
      ];
      // Still the 25th's night: nothing effective yet.
      expect(
        activeClustersAt(fondoOffAtTwoAm, utcMicros(2026, 8, 26, 1)),
        allCurationClusters,
      );
      // From the observed day's 04:00 opening — the whole domestic day,
      // including instants before the observation itself was made.
      expect(
        activeClustersAt(fondoOffAtTwoAm, utcMicros(2026, 8, 26, 4)),
        _allBut(CurationCluster.fondo),
      );
      expect(
        activeClustersAt(fondoOffAtTwoAm, utcMicros(2026, 8, 27, 2, 30)),
        _allBut(CurationCluster.fondo),
      );
    });
  });

  group('the newest effective observation wins', () {
    test('a later enable supersedes an earlier disable once both are '
        'effective', () {
      final both = [
        _obs(CurationCluster.z3, false, utcMicros(2026, 8, 24, 12)),
        _obs(CurationCluster.z3, true, utcMicros(2026, 8, 26, 12)),
      ];
      // Same observation week: neither effective yet inside it.
      expect(
        activeClustersAt(both, utcMicros(2026, 8, 28, 12)),
        allCurationClusters,
      );
      // After the boundary both are effective — the newest, the enable.
      expect(activeClustersAt(both, nextWeek), allCurationClusters);
      final disableOnly = [
        _obs(CurationCluster.z3, false, utcMicros(2026, 8, 24, 12)),
      ];
      expect(
        activeClustersAt(disableOnly, nextWeek),
        _allBut(CurationCluster.z3),
      );
    });

    test('the newest observation not yet effective supersedes nothing — '
        'the effective one governs', () {
      // Disabled in the fixture week (effective at its close), enabled
      // the next Wednesday (effective a week Monday after that).
      final observations = [
        _obs(CurationCluster.z1, false, wednesday),
        _obs(CurationCluster.z1, true, utcMicros(2026, 9, 2, 12)),
      ];
      // Thursday of week two: the disable is effective, the enable is
      // not yet — z1 stays away.
      expect(
        activeClustersAt(observations, utcMicros(2026, 9, 3, 12)),
        _allBut(CurationCluster.z1),
      );
      // After the second boundary the enable governs.
      expect(
        activeClustersAt(observations, weekAfterNextBoundary),
        allCurationClusters,
      );
    });

    test('an exact-instant tie resolves to the later-in-input observation', () {
      expect(
        activeClustersAt([
          _obs(CurationCluster.z4, false, wednesday),
          _obs(CurationCluster.z4, true, wednesday),
        ], nextWeek),
        allCurationClusters,
      );
      expect(
        activeClustersAt([
          _obs(CurationCluster.z4, true, wednesday),
          _obs(CurationCluster.z4, false, wednesday),
        ], nextWeek),
        _allBut(CurationCluster.z4),
      );
    });
  });

  test('every cluster disabled leaves an empty active set', () {
    final allOff = [
      for (final cluster in allCurationClusters)
        _obs(cluster, false, utcMicros(2026, 8, 24, 12)),
    ];
    expect(activeClustersAt(allOff, nextWeek), isEmpty);
    // And before the weekly boundary only the daily clusters are off.
    expect(activeClustersAt(allOff, wednesday), {
      CurationCluster.z1,
      CurationCluster.z2,
      CurationCluster.z3,
      CurationCluster.z4,
      CurationCluster.z5,
    });
  });

  test('each observation is judged in its own stored frame (AD-4)', () {
    // z2 disabled at 2026-08-26 10:00 −05:00 — domestic day 2026-08-26
    // in that frame, week anchored 2026-08-24, closing at Monday
    // 2026-08-31 04:00 −05:00 = 09:00 UTC in the same frame.
    final z2Off = [
      _obs(
        CurationCluster.z2,
        false,
        utcMicros(2026, 8, 26, 15),
        offsetSeconds: -18000,
      ),
    ];
    // 08:59 UTC on the 31st is still that frame's Sunday: z2 active.
    expect(
      activeClustersAt(
        z2Off,
        utcMicros(2026, 8, 31, 8, 59),
      ).contains(CurationCluster.z2),
      isTrue,
    );
    // 09:00 UTC is Monday 04:00 −05:00 — the boundary instant belongs to
    // the new week and z2 turns away exactly there.
    expect(
      activeClustersAt(z2Off, utcMicros(2026, 8, 31, 9)),
      _allBut(CurationCluster.z2),
    );
  });
}

Set<CurationCluster> _allBut(CurationCluster removed) => {
  for (final cluster in allCurationClusters)
    if (cluster != removed) cluster,
};
