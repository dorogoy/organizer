import 'package:core/commands/triage_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:test/test.dart';

/// Story 6.3's minter (FR-22, AD-3, AD-21): the triage act's single
/// sanctioned writer — pure content, no id, no instant, no offset, and
/// a payload that cannot hold a number by construction.
void main() {
  test('returns exactly one item_triaged content row carrying the '
      'destination and the tag', () {
    final contents = triageItem(
      destination: TriageDestination.donate_sell,
      volumeTag: CoarseVolumeTag.caja,
    );
    expect(contents, hasLength(1));
    final content = contents.single;
    expect(content.kind, LogKind.itemTriaged);
    expect(content.triageDestination, TriageDestination.donate_sell);
    expect(content.triageVolumeTag, CoarseVolumeTag.caja);
    // Pure content: the shell mints the id, the instant and the offset.
    expect(content.itemId, isNull);
    expect(content.itemOrigin, isNull);
    expect(content.stack, isNull);
    expect(content.settingKey, isNull);
    expect(content.settingValue, isNull);
    expect(content.settingTextValue, isNull);
    expect(content.pocketMinutes, isNull);
    expect(content.energyLevel, isNull);
    expect(content.reportValue, isNull);
    expect(content.reportWeek, isNull);
    expect(content.permission, isNull);
    expect(content.sliceCause, isNull);
    expect(content.cluster, isNull);
    expect(content.enabled, isNull);
  });

  test('the tag is optional — a declined act carries null and writes '
      'nothing for volume (FR-22)', () {
    for (final destination in TriageDestination.values) {
      final content = triageItem(destination: destination).single;
      expect(content.triageVolumeTag, isNull, reason: destination.name);
      expect(content.triageDestination, destination);
    }
  });

  test('no field of the content can hold a number — the enum payload is '
      'the value space, never a numeric volume (FR-22)', () {
    // Every numeric field the write shape offers stays null, and the
    // two payload fields are enums: a numeric volume is unrepresentable
    // by construction, not by convention.
    final content = triageItem(
      destination: TriageDestination.trash_recycle,
      volumeTag: CoarseVolumeTag.mueble,
    ).single;
    expect(content.triageDestination, isA<TriageDestination>());
    expect(content.triageVolumeTag, isA<CoarseVolumeTag>());
    expect(content.settingValue, isNull);
    expect(content.pocketMinutes, isNull);
    expect(content.energyLevel, isNull);
    expect(content.reportValue, isNull);
    expect(content.reportWeek, isNull);
  });

  test('every destination and tag mints through the same single row', () {
    for (final destination in TriageDestination.values) {
      for (final tag in CoarseVolumeTag.values) {
        final contents = triageItem(destination: destination, volumeTag: tag);
        expect(contents, hasLength(1));
        expect(contents.single.triageDestination, destination);
        expect(contents.single.triageVolumeTag, tag);
      }
    }
  });

  test('the minter drives the read boundary end to end — the wire names '
      'the shell will copy land as the entry the derivations will read', () {
    // The seam the hand-typed round-trips elsewhere skip: minter →
    // `.name` wires (what every shell copier writes) → record → the
    // read boundary. A wrong wire name anywhere in that chain would
    // surface here as a flaw or a mismatched entry.
    for (final destination in TriageDestination.values) {
      for (final tag in CoarseVolumeTag.values) {
        final content = triageItem(
          destination: destination,
          volumeTag: tag,
        ).single;
        final LogEntryRecord record = (
          id: 'triage-${destination.name}-${tag.name}',
          kind: content.kind.name,
          instantUtcMicros: 1000,
          offsetSeconds: 3600,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          settingTextValue: content.settingTextValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
          reportValue: content.reportValue,
          reportWeek: content.reportWeek,
          permission: content.permission?.name,
          sliceCause: content.sliceCause,
          cluster: content.cluster?.name,
          enabled: content.enabled,
          triageDestination: content.triageDestination?.name,
          triageVolumeTag: content.triageVolumeTag?.name,
        );
        final converted = convertLogEntryRecord(record);
        expect(
          converted.flaw,
          isNull,
          reason: '${destination.name}/${tag.name}',
        );
        final entry = converted.entry as TriageEntry;
        expect(
          entry.destination,
          destination,
          reason: '${destination.name}/${tag.name}',
        );
        expect(entry.volumeTag, tag, reason: '${destination.name}/${tag.name}');
      }
    }
  });
}
