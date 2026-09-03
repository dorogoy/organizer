import 'package:core/commands/settings_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';
import 'package:test/test.dart';

SettingEntry _setting(int micros, String key, int value) => SettingEntry(
  id: 'setting-$micros-$key-$value',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  key: key,
  value: value,
);

SettingEntry _textSetting(int micros, String key, String textValue) =>
    SettingEntry(
      id: 'setting-$micros-$key-text',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      key: key,
      textValue: textValue,
    );

MomentEntry _moment(int micros) => MomentEntry(
  id: 'moment-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.appOpened,
);

void main() {
  group(
    'the derived Time Bag (FR-7, AD-1 — a derived cache, never stored)',
    () {
      test('an empty log derives the default, 15', () {
        expect(deriveTimeBagMinutes(const []), defaultTimeBagMinutes);
        expect(defaultTimeBagMinutes, 15);
      });

      test('a log with no setting rows derives the default', () {
        expect(
          deriveTimeBagMinutes([_moment(1000), _moment(2000)]),
          defaultTimeBagMinutes,
        );
      });

      test('the latest valid time_bag entry wins — store read order', () {
        expect(
          deriveTimeBagMinutes([
            _moment(1000),
            _setting(2000, 'time_bag', 25),
            _moment(3000),
            _setting(4000, 'time_bag', 10),
          ]),
          10,
        );
      });

      test('a same-instant pair resolves by store read order — the later '
          'row in the input wins (AD-3)', () {
        // Two setting rows at one instant: the store breaks the tie by
        // append sequence (instant, rowid), and logEntriesOf preserves
        // it — so the input list's later row is the later row, and it
        // wins regardless of its value's direction.
        expect(
          deriveTimeBagMinutes([
            _setting(5000, 'time_bag', 30),
            _setting(5000, 'time_bag', 5),
          ]),
          5,
        );
        expect(
          deriveTimeBagMinutes([
            _setting(5000, 'time_bag', 5),
            _setting(5000, 'time_bag', 30),
          ]),
          30,
        );
      });

      test('a value outside 5–30 is treated as absent — the previous value '
          'or the default stands, and the entry is never repaired (AD-23)', () {
        expect(
          deriveTimeBagMinutes([_setting(1000, 'time_bag', 4)]),
          defaultTimeBagMinutes,
        );
        expect(
          deriveTimeBagMinutes([_setting(1000, 'time_bag', 31)]),
          defaultTimeBagMinutes,
        );
        expect(
          deriveTimeBagMinutes([
            _setting(1000, 'time_bag', 20),
            _setting(2000, 'time_bag', 31),
          ]),
          20,
        );
        expect(
          deriveTimeBagMinutes([
            _setting(1000, 'time_bag', 31),
            _setting(2000, 'time_bag', 20),
          ]),
          20,
        );
      });

      test('an unknown setting key derives nothing — carried, never read '
          '(AD-23)', () {
        expect(
          deriveTimeBagMinutes([
            _setting(1000, 'future_setting', 30),
            _setting(2000, 'time_bag', 10),
            _setting(3000, 'another_setting', 25),
          ]),
          10,
        );
      });

      test('an in-range value off the stepped ladder still derives — FR-7 '
          'fixes the range, not the granularity', () {
        expect(deriveTimeBagMinutes([_setting(1000, 'time_bag', 17)]), 17);
      });

      test('a text-valued time_bag row derives the default — the '
          'exactly-one-of shape at the derivation, tolerated for '
          'value: null (Story 4.3)', () {
        expect(
          deriveTimeBagMinutes([_textSetting(1000, 'time_bag', 'openai')]),
          defaultTimeBagMinutes,
        );
        // And it does not shadow a valid int beside it.
        expect(
          deriveTimeBagMinutes([
            _setting(1000, 'time_bag', 20),
            _textSetting(2000, 'time_bag', 'openai'),
          ]),
          20,
        );
      });

      test('the boundary values 5 and 30 are valid; 10 is the weave\'s own '
          'threshold, not the setting\'s', () {
        expect(deriveTimeBagMinutes([_setting(1, 'time_bag', 5)]), 5);
        expect(deriveTimeBagMinutes([_setting(1, 'time_bag', 30)]), 30);
        expect(timeBagLeastMinutes, 5);
        expect(timeBagMostMinutes, 30);
        expect(timeBagOptions, [5, 10, 15, 20, 25, 30]);
      });

      test(
        'the derivation reads no instants — ordering is the input\'s '
        '(AD-3: ordering reads the store\'s replay order, never id bits)',
        () {
          // A later-in-input row at an EARLIER instant still wins: the
          // input is already in store read order, and the derivation
          // trusts it exactly as walkLog does.
          expect(
            deriveTimeBagMinutes([
              _setting(9000, 'time_bag', 30),
              _setting(1000, 'time_bag', 5),
            ]),
            5,
          );
        },
      );
    },
  );

  group('the setting_changed command (the single sanctioned minter)', () {
    test('an in-range time_bag value mints exactly one content row', () {
      for (final value in timeBagOptions) {
        final contents = settingChanged(key: timeBagSettingKey, value: value);
        expect(contents, hasLength(1));
        expect(contents.single.kind, LogKind.settingChanged);
        expect(contents.single.settingKey, timeBagSettingKey);
        expect(contents.single.settingValue, value);
        expect(contents.single.itemId, isNull);
        expect(contents.single.itemOrigin, isNull);
        expect(contents.single.stack, isNull);
      }
    });

    test('an in-range value off the stepped ladder mints too', () {
      expect(settingChanged(key: timeBagSettingKey, value: 17), hasLength(1));
    });

    test('an out-of-range value returns no content — nothing appended, '
        'no error surface anywhere', () {
      for (final value in [-1, 0, 4, 31, 45, 1000]) {
        expect(settingChanged(key: timeBagSettingKey, value: value), isEmpty);
      }
    });

    test('a key this build does not know returns no content (AD-23: this '
        'build does not write what it cannot read)', () {
      expect(settingChanged(key: 'future_setting', value: 15), isEmpty);
    });
  });

  group('the derived selected provider (Story 4.3, AD-22 — text, never a '
      'credential, never an availability claim)', () {
    test('an empty log derives null — no choice stands', () {
      expect(deriveSelectedProvider(const []), isNull);
    });

    test('the latest valid selected_provider text wins — store read '
        'order', () {
      expect(
        deriveSelectedProvider([
          _moment(1000),
          _textSetting(2000, 'selected_provider', 'openai'),
          _moment(3000),
          _textSetting(4000, 'selected_provider', 'anthropic'),
        ]),
        'anthropic',
      );
    });

    test('a text outside the provider charset is treated as absent — the '
        'previous choice or none stands (AD-23)', () {
      expect(
        deriveSelectedProvider([
          _textSetting(1000, 'selected_provider', '../evil'),
        ]),
        isNull,
      );
      expect(
        deriveSelectedProvider([
          _textSetting(1000, 'selected_provider', 'UPPER'),
        ]),
        isNull,
      );
      expect(
        deriveSelectedProvider([
          _textSetting(1000, 'selected_provider', 'a' * 65),
        ]),
        isNull,
      );
      // An empty text is not a value: the earlier valid choice
      // stands, exactly as if the row were not there.
      expect(
        deriveSelectedProvider([
          _textSetting(1000, 'selected_provider', 'openai'),
          _textSetting(2000, 'selected_provider', ''),
        ]),
        'openai',
      );
      expect(
        deriveSelectedProvider([
          _textSetting(1000, 'selected_provider', 'not openai!'),
          _textSetting(2000, 'selected_provider', 'openai'),
        ]),
        'openai',
      );
    });

    test('an int-valued selected_provider row derives nothing — the '
        'exactly-one-of rule, read side', () {
      expect(
        deriveSelectedProvider([_setting(1000, 'selected_provider', 15)]),
        isNull,
      );
    });

    test('the boundary values of the charset derive — 1 and 64 chars', () {
      expect(
        deriveSelectedProvider([_textSetting(1000, 'selected_provider', 'a')]),
        'a',
      );
      expect(
        deriveSelectedProvider([
          _textSetting(1000, 'selected_provider', 'a' * 64),
        ]),
        'a' * 64,
      );
    });

    test('the charset rule is shared and pinned — the vault refuses what '
        'the derivation ignores', () {
      expect(isValidProviderId('openai'), isTrue);
      expect(isValidProviderId('anthropic'), isTrue);
      expect(isValidProviderId('gemini_2'), isTrue);
      expect(isValidProviderId(''), isFalse);
      expect(isValidProviderId('../evil'), isFalse);
      expect(isValidProviderId('UPPER'), isFalse);
      expect(isValidProviderId('openai '), isFalse);
      expect(isValidProviderId('a' * 64), isTrue);
      expect(isValidProviderId('a' * 65), isFalse);
    });
  });

  group('the derived providerConfigured (Story 4.3, AD-22)', () {
    test('both halves are required — the choice and the live credential', () {
      expect(deriveProviderConfigured('openai', true), isTrue);
      expect(deriveProviderConfigured('openai', false), isFalse);
      expect(deriveProviderConfigured(null, true), isFalse);
      expect(deriveProviderConfigured(null, false), isFalse);
    });

    test('the restore story: the choice survived, the credential did not — '
        'false until a credential is saved again', () {
      final selected = deriveSelectedProvider([
        _textSetting(1000, 'selected_provider', 'openai'),
      ]);
      expect(selected, 'openai');
      expect(deriveProviderConfigured(selected, false), isFalse);
      expect(deriveProviderConfigured(selected, true), isTrue);
    });
  });

  group('the selected_provider minter (the single sanctioned writer)', () {
    test('a charset-valid provider id mints exactly one text row', () {
      final contents = settingChanged(
        key: selectedProviderSettingKey,
        textValue: 'openai',
      );
      expect(contents, hasLength(1));
      expect(contents.single.kind, LogKind.settingChanged);
      expect(contents.single.settingKey, selectedProviderSettingKey);
      expect(contents.single.settingValue, isNull);
      expect(contents.single.settingTextValue, 'openai');
      expect(contents.single.itemId, isNull);
      expect(contents.single.stack, isNull);
    });

    test('a text outside the charset returns no content — refusal is '
        'silence', () {
      for (final text in ['', '../evil', 'UPPER', 'a' * 65, 'sp ace']) {
        expect(
          settingChanged(key: selectedProviderSettingKey, textValue: text),
          isEmpty,
          reason: text,
        );
      }
    });

    test('the two value halves never cross — an int on the text key or a '
        'text on the int key returns no content', () {
      expect(
        settingChanged(key: selectedProviderSettingKey, value: 15),
        isEmpty,
      );
      expect(
        settingChanged(key: timeBagSettingKey, textValue: 'openai'),
        isEmpty,
      );
      expect(
        settingChanged(
          key: selectedProviderSettingKey,
          value: 15,
          textValue: 'openai',
        ),
        isEmpty,
      );
    });

    test('neither value returns no content — the exactly-one-of rule at '
        'the mint, refusal as silence', () {
      expect(settingChanged(key: timeBagSettingKey), isEmpty);
      expect(settingChanged(key: selectedProviderSettingKey), isEmpty);
      expect(settingChanged(key: 'future_setting'), isEmpty);
    });
  });
}
