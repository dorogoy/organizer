import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_android_manifest.dart';

const fixtures = 'test/fixtures/android_manifest';

void main() {
  test('a clean release inventory passes the enumerated release set', () {
    final path = '$fixtures/release_clean.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'release',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings, isEmpty);
  });

  test('a clean debug inventory passes the enumerated debug set', () {
    final path = '$fixtures/debug_clean.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'debug',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings, isEmpty);
  });

  test('the launcher activity is enumerated; a clean inventory that '
      'declares it passes', () {
    final path = '$fixtures/debug_clean_with_activity.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'debug',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings, isEmpty);
  });

  test('INTERNET in release is outside its effective set, which the '
      'finding names in full', () {
    final path = '$fixtures/release_with_internet.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'release',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('android.permission.INTERNET'));
    expect(findings.single.message, contains('release'));
    expect(findings.single.message, contains('effective set'));
    // The full effective set — the platform injection included, not
    // just the app-authored half.
    expect(
      findings.single.message,
      contains('android.permission.RECORD_AUDIO'),
    );
    expect(
      findings.single.message,
      contains(
        'dev.dorogoy.organizer.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
      ),
    );
    expect(findings.single.message, contains('allowlist edit'));
  });

  test('an unknown service fails naming the component and variant', () {
    final path = '$fixtures/debug_with_sdk.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'debug',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    final service = findings
        .where((finding) => finding.message.contains('service '))
        .single;
    expect(service.message, contains('com.sneaky.sdk.PushService'));
    expect(service.message, contains('debug'));
    final permission = findings
        .where((finding) => finding.message.contains('ACCESS_FINE_LOCATION'))
        .single;
    expect(permission.message, contains("variant debug's effective set"));
  });

  test('a foreign activity and an activity-alias both fail; the launcher '
      'does not', () {
    final path = '$fixtures/debug_with_foreign_activity.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'debug',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings, hasLength(2));
    expect(
      findings
          .where((f) => f.message.contains('com.sneaky.sdk.TrackerActivity'))
          .single,
      isNotNull,
    );
    expect(
      findings
          .where(
            (f) => f.message.contains('activity-alias com.sneaky.sdk.Alias'),
          )
          .single,
      isNotNull,
    );
    expect(
      findings.where((f) => f.message.contains('MainActivity')),
      isEmpty,
      reason: 'the enumerated launcher is never a finding',
    );
  });

  test('a boot receiver outside the platform baseline fails', () {
    final path = '$fixtures/profile_with_receiver.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'profile',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('receiver'));
    expect(findings.single.message, contains('com.sneaky.sdk.BootReceiver'));
  });

  test('the enumerated permission sets are the decided per-variant ones', () {
    expect(permittedPermissionsByVariant['release'], {
      'android.permission.RECORD_AUDIO',
    });
    expect(permittedPermissionsByVariant['debug'], {
      'android.permission.RECORD_AUDIO',
      'android.permission.INTERNET',
    });
    expect(permittedPermissionsByVariant['profile'], {
      'android.permission.RECORD_AUDIO',
      'android.permission.INTERNET',
    });
    expect(permittedPermissionsByVariant, hasLength(3));
  });

  test('the platform baseline is minimal: one provider, one receiver, one '
      'launcher activity, no aliases', () {
    expect(permittedComponentsAllVariants, hasLength(2));
    expect(
      permittedComponentsAllVariants,
      containsAll([
        'provider androidx.startup.InitializationProvider',
        'receiver androidx.profileinstaller.ProfileInstallReceiver',
      ]),
    );
    expect(permittedActivitiesAllVariants, {
      'activity dev.dorogoy.organizer.MainActivity',
    });
    expect(
      permittedActivitiesAllVariants.where(
        (c) => c.startsWith('activity-alias'),
      ),
      isEmpty,
    );
  });

  test('enumeration reads multi-line tags and skips other elements', () {
    final inventory = enumerateManifest(
      File('$fixtures/debug_clean.xml').readAsStringSync(),
    );
    expect(inventory.permissions, {
      'android.permission.RECORD_AUDIO',
      'android.permission.INTERNET',
      'dev.dorogoy.organizer.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
    });
    expect(inventory.components, {
      'provider androidx.startup.InitializationProvider',
      'receiver androidx.profileinstaller.ProfileInstallReceiver',
    });
    expect(inventory.applicationName, 'android.app.Application');
    expect(inventory.metadata, isEmpty);
  });

  test('application and startup metadata are enumerated and allowlisted', () {
    final inventory = enumerateManifest('''
<manifest>
  <application android:name="android.app.Application">
    <activity android:name="dev.dorogoy.organizer.MainActivity">
      <meta-data android:name="io.flutter.embedding.android.NormalTheme" />
    </activity>
    <meta-data android:name="flutterEmbedding" />
    <provider android:name="androidx.startup.InitializationProvider">
      <meta-data android:name="androidx.lifecycle.ProcessLifecycleInitializer" />
    </provider>
  </application>
</manifest>
''');
    expect(inventory.applicationName, 'android.app.Application');
    expect(inventory.metadata, {
      'io.flutter.embedding.android.NormalTheme',
      'flutterEmbedding',
      'androidx.lifecycle.ProcessLifecycleInitializer',
    });
    expect(
      checkInventory(
        manifestPath: 'fixture.xml',
        variant: 'release',
        inventory: inventory,
      ),
      isEmpty,
    );
  });

  test('a foreign application and startup metadata both fail closed', () {
    final inventory = enumerateManifest('''
<manifest>
  <application android:name="com.sneaky.sdk.SpyApplication">
    <meta-data android:name="com.sneaky.sdk.Initializer" />
  </application>
</manifest>
''');
    final findings = checkInventory(
      manifestPath: 'fixture.xml',
      variant: 'release',
      inventory: inventory,
    );
    expect(findings, hasLength(2));
    expect(findings.any((f) => f.message.contains('SpyApplication')), isTrue);
    expect(findings.any((f) => f.message.contains('sdk.Initializer')), isTrue);
  });

  test('the application and metadata baselines are explicit', () {
    expect(permittedApplicationName, 'android.app.Application');
    expect(
      permittedMetadataAllVariants,
      containsAll([
        'io.flutter.embedding.android.NormalTheme',
        'flutterEmbedding',
      ]),
    );
  });

  test('a permission element (definition) is not a uses-permission', () {
    final inventory = enumerateManifest(
      '<manifest><permission android:name="dev.dorogoy.organizer.'
      'DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" '
      'android:protectionLevel="signature" /></manifest>',
    );
    expect(inventory.permissions, isEmpty);
    expect(inventory.components, isEmpty);
  });

  test('findings cite line 1 because the XML is machine-generated', () {
    final path = '$fixtures/release_with_internet.xml';
    final findings = checkInventory(
      manifestPath: path,
      variant: 'release',
      inventory: enumerateManifest(File(path).readAsStringSync()),
    );
    expect(findings.single.line, 1);
  });

  group('the merged-manifest locator', () {
    Directory makeIntermediates(String layout, String variant) {
      final root = Directory.systemTemp.createTempSync('manifest_seal');
      addTearDown(() => root.deleteSync(recursive: true));
      final dir = Directory(
        '${root.path}/${layout.replaceFirst('<variant>', variant)}',
      )..createSync(recursive: true);
      File('${dir.path}/AndroidManifest.xml').writeAsStringSync('<manifest />');
      return Directory(root.path);
    }

    test('finds the AGP 9 task-named layout', () {
      final found = locateMergedManifest(
        intermediates: makeIntermediates(
          'merged_manifest/debug/processDebugMainManifest',
          'debug',
        ),
        variant: 'debug',
      );
      expect(found.existsSync(), isTrue);
      expect(found.path, contains('processDebugMainManifest'));
    });

    test('finds the older merged_manifests layout', () {
      final found = locateMergedManifest(
        intermediates: makeIntermediates('merged_manifests/release', 'release'),
        variant: 'release',
      );
      expect(found.existsSync(), isTrue);
    });

    test('a stray file named merged_manifest* is skipped, not crashed on', () {
      final root = Directory.systemTemp.createTempSync('manifest_seal_stray');
      addTearDown(() => root.deleteSync(recursive: true));
      File('${root.path}/merged_manifest_junk').writeAsStringSync('junk');
      final found = locateMergedManifest(
        intermediates: Directory(root.path),
        variant: 'debug',
      );
      expect(found.existsSync(), isFalse);
    });

    test('reports the expected path when nothing was produced', () {
      final root = Directory.systemTemp.createTempSync('manifest_seal_empty');
      addTearDown(() => root.deleteSync(recursive: true));
      final found = locateMergedManifest(
        intermediates: Directory(root.path),
        variant: 'profile',
      );
      expect(found.existsSync(), isFalse);
      expect(found.path, contains('processProfileMainManifest'));
    });
  });
}
