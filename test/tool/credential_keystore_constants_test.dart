// The Keystore service's load-bearing constants (Story 4.3, AD-22),
// pinned by source text: a silent drift in any of them bricks every
// stored envelope — a renamed alias orphans the key the envelopes
// were sealed under, a different transformation or tag length stops
// the decrypt, a different IV length mis-splits the envelope — and
// nothing else in the build reads these values, so nothing else
// could catch the drift. The pin reads the Kotlin source itself,
// exactly as the wire-contract check reads its two halves: the raw
// literals are the contract.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String keystoreSourcePath =
    'android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialKeystore.kt';

void main() {
  test('the wrapping key\'s alias is pinned — a renamed alias orphans '
      'every stored envelope', () {
    final source = File(keystoreSourcePath).readAsStringSync();
    expect(
      source,
      contains('WRAPPING_KEY_ALIAS = "organizer_credential_wrapping"'),
    );
  });

  test('the AEAD shape is pinned — transformation, IV length, tag length', () {
    final source = File(keystoreSourcePath).readAsStringSync();
    expect(source, contains('TRANSFORMATION = "AES/GCM/NoPadding"'));
    expect(source, contains('IV_LENGTH_BYTES = 12'));
    expect(source, contains('TAG_LENGTH_BITS = 128'));
  });

  test('the key length is pinned — 256-bit, the envelope contract\'s own', () {
    final source = File(keystoreSourcePath).readAsStringSync();
    expect(source, contains('KEY_LENGTH_BITS = 256'));
  });
}
