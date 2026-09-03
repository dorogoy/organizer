import 'dart:convert';
import 'dart:io';

import 'package:core/settings/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/egress/provider_allowlist.dart';

/// The frozen allowlist's contract (Story 4-4, AD-9, AD-10): four
/// entries with charset-valid unique ids, fixed model ids (the
/// OpenRouter one its ZDR-list slug), the compile-time constant that
/// is never fetched — and the ARB coverage pin: every id renders a
/// provider name and a terms sentence, with no extras the allowlist
/// does not carry.
void main() {
  test('exactly four entries exist, in display order', () {
    expect(slicerProviderAllowlist, hasLength(4));
    expect(slicerProviderAllowlist.map((entry) => entry.id).toList(), [
      'gemini',
      'openai',
      'anthropic',
      'openrouter',
    ]);
  });

  test(
    'every id is charset-valid and unique — storable as setting and scope',
    () {
      final ids = slicerProviderAllowlist.map((entry) => entry.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(isValidProviderId(id), isTrue, reason: id);
      }
    },
  );

  test('the fixed model ids are the decided ones — the fixing act itself', () {
    final byId = {
      for (final entry in slicerProviderAllowlist) entry.id: entry.modelId,
    };
    expect(byId['gemini'], 'gemini-3.5-flash-lite');
    expect(byId['openai'], 'gpt-5.6-luna');
    expect(byId['anthropic'], 'claude-haiku-4.5');
    // The OpenRouter entry carries its ZDR-list slug, not a bare id.
    expect(byId['openrouter'], 'google/gemini-3.5-flash-lite');
  });

  test('every wire kind is spoken by exactly one entry', () {
    expect(
      slicerProviderAllowlist.map((entry) => entry.wireKind).toSet(),
      hasLength(4),
    );
    expect(
      SlicerWireKind.values.toSet(),
      containsAll(slicerProviderAllowlist.map((e) => e.wireKind)),
    );
  });

  test('allowlistEntryById answers the entry, or null for anything else', () {
    expect(allowlistEntryById('gemini')?.modelId, geminiModelId);
    expect(
      allowlistEntryById('openrouter')?.wireKind,
      SlicerWireKind.openRouterChat,
    );
    // Charset-valid but unallowlisted: the quiet refusal.
    expect(allowlistEntryById('some_other_provider'), isNull);
    // Charset-invalid (what the settings minter would already refuse):
    expect(allowlistEntryById('../traversal'), isNull);
    expect(allowlistEntryById(''), isNull);
  });

  test('the list is a compile-time constant — const-context constructible', () {
    const entries = slicerProviderAllowlist;
    expect(identical(entries, slicerProviderAllowlist), isTrue);
  });

  group(
    'the ARB coverage pin — rendered copy covers exactly the allowlist',
    () {
      late Map<String, dynamic> arb;

      setUpAll(() {
        arb = jsonDecode(
          File('lib/l10n/app_es.arb').readAsStringSync(),
        ) as Map<String, dynamic>;
      });

      String capitalized(String id) => id[0].toUpperCase() + id.substring(1);

      test('every id renders a provider name, and no extra names exist', () {
        final nameKeys = arb.keys
            .where((key) => key.startsWith('providerName'))
            .toSet();
        final expected = {
          for (final entry in slicerProviderAllowlist)
            'providerName${capitalized(entry.id)}',
        };
        expect(nameKeys, expected);
        for (final key in nameKeys) {
          final value = arb[key];
          expect(value, isA<String>());
          expect((value as String).trim(), isNotEmpty, reason: key);
        }
      });

      test('every id renders a terms sentence, and no extra terms exist', () {
        final termsKeys = arb.keys
            .where((key) => key.startsWith('providerTerms'))
            .toSet();
        final expected = {
          for (final entry in slicerProviderAllowlist)
            'providerTerms${capitalized(entry.id)}',
        };
        expect(termsKeys, expected);
        for (final key in termsKeys) {
          final value = arb[key];
          expect(value, isA<String>());
          expect((value as String).trim(), isNotEmpty, reason: key);
        }
      });

      test('every terms sentence states its baked date — "that day, and not '
          'since", with no age indicator or re-check vocabulary', () {
        final termsKeys = arb.keys.where(
          (key) => key.startsWith('providerTerms'),
        );
        for (final key in termsKeys) {
          final value = arb[key] as String;
          expect(value, contains('verificados el'));
          expect(value, contains('ese día, y no desde entonces'));
          // The verified-on dates this build baked: the first three
          // 2026-08-26, OpenRouter 2026-09-03.
          expect(
            value.contains('26 de agosto de 2026') ||
                value.contains('3 de septiembre de 2026'),
            isTrue,
            reason: '$key carries a baked verification date',
          );
          expect(
            value.contains('hace'),
            isFalse,
            reason: '$key: no age indicator',
          );
          expect(
            value.toLowerCase().contains('revis'),
            isFalse,
            reason: '$key: no re-check vocabulary',
          );
        }
      });
    },
  );
}
