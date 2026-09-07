import 'dart:io';
import 'dart:typed_data';

import 'package:core/ports/files_port.dart';
import 'package:core/ports/scan_consent.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/slicer/rescue_steps.dart';
import 'package:core/slicer/scan_steps.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer/egress/byok_slicer.dart';
import 'package:organizer/egress/local_slicer.dart';
import 'package:organizer/egress/managed_slicer.dart';
import 'package:organizer/egress/slicer_factory.dart';
import 'package:organizer/platform/credentials/credentials_cipher.dart';
import 'package:organizer/vault/credential_vault.dart';

import '../../tool/check_core_purity.dart';

/// The port's second and third shapes plus the factory's gate
/// (Story 4-4, AD-9): the Local stub's canned marker body, the
/// Managed shape's inert `managedUnavailable`, the compile-time
/// reachability pinned (env flag default false ∧ kDebugMode), and
/// the no-call-site rule — nothing outside `lib/egress/` names
/// either shape.
void main() {
  group('the Local shape — canned, unmistakable', () {
    test('each flight\'s canned body carries the marker in every slot '
        'and parses against its OWN contract — the scan shape via '
        'parseScanSlice, the rescue shape via parseRescueSteps '
        '(Story 5.7)', () async {
      const slicer = LocalSlicer(cannedMarker: 'marca local');
      // The scan flight: description + `duration_minutes` 3–5, core's
      // own wire names — the scan parse is its single reader, so a
      // stub drift from the contract fails this pin.
      final scan = parseScanSlice(
        (await slicer.slice(
          ScanSliceRequest(
            imageBytes: Uint8List(0),
            prompt: '',
            scanId: 'scan-1',
            consent: mintScanConsent(scanId: 'scan-1'),
          ),
        ) as SlicerDelivered).responseBody,
      );
      expect(scan, isNotNull);
      expect(scan!.description, 'marca local');
      expect(scan.steps, hasLength(2));
      for (final step in scan.steps) {
        expect(step.text, 'marca local');
        expect(step.durationMinutes, greaterThanOrEqualTo(3));
        expect(step.durationMinutes, lessThanOrEqualTo(5));
      }
      // The rescue flight: steps + `duration_seconds` 1–60 (the
      // pre-5.7 values) — a scan-shaped answer here would break the
      // rescue flight by construction, so this pin reads the rescue
      // parse, never the scan one.
      final rescue = parseRescueSteps(
        (await slicer.slice(
          const RescueSliceRequest(originContext: 'x', task: 'y'),
        ) as SlicerDelivered).responseBody,
      );
      expect(rescue, isNotNull);
      expect(rescue, hasLength(2));
      for (final step in rescue!) {
        expect(step.text, 'marca local');
        expect(step.durationSeconds, greaterThanOrEqualTo(1));
        expect(step.durationSeconds, lessThanOrEqualTo(60));
      }
    });

    test(
      'the canned answer is request-independent — recognisably canned',
      () async {
        const slicer = LocalSlicer(cannedMarker: 'marca local');
        final first = await slicer.slice(
          const GenesisSliceRequest(text: 'un proyecto'),
        );
        final second = await slicer.slice(
          const RescueSliceRequest(originContext: 'a', task: 'b'),
        );
        expect(
          (first as SlicerDelivered).responseBody,
          (second as SlicerDelivered).responseBody,
          reason: 'no request fact enters the canned body',
        );
      },
    );
  });

  group('the Managed shape — inert, third', () {
    test(
      'every request kind answers managedUnavailable, no exception',
      () async {
        const slicer = ManagedSlicer();
        for (final request in [
          ScanSliceRequest(
            imageBytes: Uint8List(0),
            prompt: '',
            scanId: 'scan-1',
            consent: mintScanConsent(scanId: 'scan-1'),
          ),
          const GenesisSliceRequest(text: 'x'),
          const RescueSliceRequest(originContext: 'x', task: 'y'),
        ]) {
          expect(
            await slicer.slice(request),
            const SlicerFailed(SlicerFailureCause.managedUnavailable),
          );
        }
      },
    );
  });

  group('the factory gate — compile-time, unreachable in release', () {
    test('the environment flag defaults false in this (undefined) run', () {
      expect(localSlicerEnvironmentKey, 'ORGANIZER_LOCAL_SLICER');
      expect(
        localSlicerEnvironmentFlag,
        isFalse,
        reason: 'no dart-define is set in the test run',
      );
    });

    test('reachability is exactly flag ∧ kDebugMode — a false const in '
        'release', () {
      expect(localSlicerReachable, localSlicerEnvironmentFlag && kDebugMode);
      // The test run is debug with the flag unset: unreachable here,
      // and in release kDebugMode folds false whatever the flag says.
      expect(localSlicerReachable, isFalse);
    });

    test('the gate closed, the factory composes the BYOK shape', () {
      final slicer = buildSlicer(
        vault: CredentialVault(
          files: const _NullFiles(),
          cipher: const _NullCipher(),
        ),
        readSelectedProvider: () async => null,
        localCannedMarker: 'marca local',
      );
      expect(slicer, isA<ByokSlicer>());
    });
  });

  group('the no-call-site rule — adding Local or Managed changes nothing '
      'outside lib/egress/', () {
    test('no file outside lib/egress/ names either shape', () {
      final offenders = <String>[];
      void walk(Directory dir) {
        for (final entity in dir.listSync(followLinks: false)) {
          if (entity is Directory) {
            final name = entity.uri.pathSegments
                .where((s) => s.isNotEmpty)
                .last;
            if (name != '.dart_tool') {
              walk(entity);
            }
          } else if (entity is File && entity.path.endsWith('.dart')) {
            final normalized = entity.path.replaceAll('\\', '/');
            if (normalized.startsWith('lib/egress/')) {
              continue;
            }
            if (normalized.startsWith('lib/')) {
              // Comment/string-masked source (the census tooling's
              // `maskCommentsAndStrings` discipline, the no-lateness
              // proof's import precedent): only code moves this pin —
              // a doc comment mentioning either shape is not a call
              // site.
              final source = maskCommentsAndStrings(entity.readAsStringSync());
              // Story 5.7's one sanctioned exception: the scan
              // controller names LocalSlicer exactly once — the
              // origin derivation (`local` on the debug stub,
              // `cloud` on BYOK), the landing's own expression.
              // Every other reference, and ManagedSlicer anywhere,
              // stays an offender.
              if (normalized == 'lib/scan/scan_controller.dart') {
                expect(
                  RegExp('LocalSlicer').allMatches(source),
                  hasLength(1),
                  reason:
                      'the scan controller names LocalSlicer for the '
                      'origin derivation alone — a second reference is '
                      'a call site this rule cannot see',
                );
                expect(
                  source.contains('ManagedSlicer'),
                  isFalse,
                  reason: 'the Managed shape is never wired anywhere',
                );
                continue;
              }
              if (source.contains('LocalSlicer') ||
                  source.contains('ManagedSlicer')) {
                offenders.add(normalized);
              }
            }
          }
        }
      }

      walk(Directory('lib'));
      expect(
        offenders,
        isEmpty,
        reason: 'the shapes live and die inside the egress module',
      );
    });
  });
}

/// Inert Files/cipher fakes: the factory composes without sending, so
/// the vault it hands ByokSlicer is never touched.
class _NullFiles implements FilesPort {
  const _NullFiles();

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}
}

class _NullCipher implements CredentialsCipher {
  const _NullCipher();

  @override
  Future<CredentialsSealConversion> seal(List<int> plaintext) async =>
      (envelope: null, failure: CredentialsCipherFailure.corrupt);

  @override
  Future<CredentialsUnsealConversion> unseal(List<int> envelope) async =>
      (plaintext: null, failure: CredentialsCipherFailure.corrupt);
}
