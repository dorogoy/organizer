import 'package:core/ports/scan_consent.dart';
import 'package:test/test.dart';

/// The consent token's whole contract (Story 5.4, AD-8): bound at
/// mint, unconsumed by default, consumable exactly once, and a
/// surface that leaks nothing — the capability exists only as this
/// type, and nothing readable of the binding can escape it.
void main() {
  test('the mint binds the token to its scanId — the scan cache '
      'subdirectory identity', () {
    final token = mintScanConsent(scanId: 'scan-1');
    expect(token.scanId, 'scan-1');
    expect(mintScanConsent(scanId: 'scan-2').scanId, 'scan-2');
  });

  test('a fresh token is unconsumed: the first consume is silent', () {
    final token = mintScanConsent(scanId: 'scan-1');
    expect(() => token.consume(), returnsNormally);
  });

  test('one-way: the second consume throws StateError — a programmer '
      'error that propagates raw', () {
    final token = mintScanConsent(scanId: 'scan-1');
    token.consume();
    expect(() => token.consume(), throwsA(isA<StateError>()));
  });

  test('once-ness is per token, never shared between mints — even for '
      'the same scanId', () {
    final first = mintScanConsent(scanId: 'scan-1');
    final second = mintScanConsent(scanId: 'scan-1');
    first.consume();
    expect(
      () => second.consume(),
      returnsNormally,
      reason:
          'one token authorizes one dispatch entry; a second mint '
          'is a second authorization',
    );
  });

  test('no-leak surface: identity semantics only — no equality, no '
      'human-readable rendering, nothing reconstructible (AD-8)', () {
    final one = mintScanConsent(scanId: 'scan-1');
    final other = mintScanConsent(scanId: 'scan-1');
    // No == override exists to override: two tokens for the same scan
    // are never equal — consuming one never authorizes a second
    // dispatch through structural comparison.
    expect(one, isNot(equals(other)));
    // No toString override exists to override: the default rendering
    // names no scanId, so the binding cannot leak through a log line.
    expect(one.toString(), isNot(contains('scan-1')));
    expect(one.toString(), isNot(contains('scanId')));
  });
}
