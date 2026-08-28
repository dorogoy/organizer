import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // `driftDatabase` cannot be opened in a VM test (no platform plumbing),
  // and every functional refusal test goes through `NativeDatabase.memory()`
  // + `beforeOpen`, bypassing the production options entirely. The
  // per-connection `setup` layer is therefore pinned the way this repo pins
  // architecture: as a source contract this test fails if it is removed.
  test('the production connection executes the pragma on every native connection (AD-2)', () {
    final connection = File('lib/store/connection.dart').readAsStringSync();
    expect(connection, contains('setup: _configureConnection'));
    expect(connection, contains('db.execute(recursiveTriggersPragma)'));

    final substrate = File('lib/store/substrate.dart').readAsStringSync();
    expect(substrate, contains('beforeOpen'));
  });
}
