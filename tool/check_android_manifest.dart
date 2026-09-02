// ignore_for_file: avoid_print
//
// The egress seal, third of three (AD-7, story 4.2): the merged
// Android manifests of all three variants may declare no permission,
// service, receiver, provider, activity or activity-alias outside an
// enumerated per-variant set — this is the check that catches a
// network SDK arriving manifest-initialised, invisible to both the
// Dart import sweep and (partially) to the resolved-graph allowlist.
// A foreign `<activity>` (or an `<activity-alias>` pointing at one)
// is the classic entry point of such an SDK, so activities are
// enumerated too: exactly the launcher,
// `dev.dorogoy.organizer.MainActivity`, with an empty alias set.
//
// Enumerated sets: the app-authored permissions are exactly
// RECORD_AUDIO in release, plus the template's dev-tooling INTERNET in
// debug/profile (hot reload, not app egress — 4-4 adding INTERNET to
// main is a deliberate allowlist edit). On top of those, one fixed
// platform baseline is enumerated below: AGP's targetSdk-34
// dynamic-receiver permission injection and the androidx
// startup/profileinstaller components that androidx.core (via the
// Flutter embedding) merges into every modern app. That baseline is
// named, minimal and version-pinned by this check itself — any other
// component, in any variant, fails. Findings cite line 1 because
// merged manifests are machine-generated XML.
//
// The check drives `process{Debug,Release,Profile}MainManifest` itself
// (through the bootstrap-injected gradle wrapper, via the shared
// gradle_runner error contract), so it needs no prior
// `flutter build`, and reads the merged manifests the tasks produced
// under `build/app/intermediates`.
//
// Output contract (the tool checks' own): one `file:line: message`
// line per finding, exit 1 when any finding exists, exit 2 when the
// environment cannot run (missing wrapper, missing local.properties,
// Gradle failure, missing merged manifest).
import 'dart:io';

import 'check_core_purity.dart';
import 'gradle_runner.dart';

/// The RECORD_AUDIO permission the main manifest declares (FR-32).
const String recordAudioPermission = 'android.permission.RECORD_AUDIO';

/// The template's dev-tooling INTERNET of the debug/profile overlays.
const String internetPermission = 'android.permission.INTERNET';

/// AGP's automatic injection for targetSdk 34+ (dynamic-receiver
/// export control, registered under the application's own id).
const String dynamicReceiverPermission =
    'dev.dorogoy.organizer.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION';

/// The app-authored permissions each variant's merged manifest may
/// carry. Grown only by explicit decision (AD-7): story 4-4's INTERNET
/// in main is a deliberate edit of this map.
const Map<String, Set<String>> permittedPermissionsByVariant = {
  'release': {recordAudioPermission},
  'debug': {recordAudioPermission, internetPermission},
  'profile': {recordAudioPermission, internetPermission},
};

/// The fixed platform baseline each variant's merged manifest carries:
/// AGP's dynamic-receiver permission above, the androidx.startup
/// InitializationProvider and the androidx.profileinstaller receiver
/// that androidx.core merges in via the Flutter embedding. These are
/// platform machinery, not app egress; a fourth component of any kind
/// is a finding.
const Set<String> permittedComponentsAllVariants = {
  'provider androidx.startup.InitializationProvider',
  'receiver androidx.profileinstaller.ProfileInstallReceiver',
};

/// The activities each variant's merged manifest may declare: exactly
/// the launcher, nothing else — a manifest-initialised SDK's classic
/// entry point is a foreign `<activity>` (or an `<activity-alias>`
/// pointing at one), so both kinds are enumerated and the alias set
/// stays empty.
const Set<String> permittedActivitiesAllVariants = {
  'activity dev.dorogoy.organizer.MainActivity',
};

/// The enumerated element kinds.
const Set<String> enumeratedElementKinds = {
  'uses-permission',
  'service',
  'receiver',
  'provider',
  'activity',
  'activity-alias',
};

/// One merged manifest's declarations.
class ManifestInventory {
  const ManifestInventory({
    required this.permissions,
    required this.components,
  });

  /// Every `uses-permission` android:name, verbatim.
  final Set<String> permissions;

  /// Every `<service>/<receiver>/<provider>` as `kind android:name`.
  final Set<String> components;
}

// `activity-alias` precedes `activity` in the alternation: a plain
// `activity` would otherwise match the prefix of an `<activity-alias>`
// element and mis-kindle it.
final RegExp _elementRegExp = RegExp(
  r'<(uses-permission|service|receiver|provider|activity-alias|activity)'
  r'\b([^>]*)>',
  dotAll: true,
);

final RegExp _nameAttributeRegExp = RegExp(r'android:name="([^"]+)"');

/// Enumerates the merged manifest's declared permissions and
/// components. RegExp over machine-generated XML, matching the repo's
/// zero-dependency check style.
ManifestInventory enumerateManifest(String manifestXml) {
  final permissions = <String>{};
  final components = <String>{};
  for (final match in _elementRegExp.allMatches(manifestXml)) {
    final kind = match.group(1)!;
    final name = _nameAttributeRegExp.firstMatch(match.group(2) ?? '');
    if (kind == 'uses-permission') {
      permissions.add(name?.group(1) ?? '');
    } else {
      components.add('$kind ${name?.group(1) ?? ''}');
    }
  }
  return ManifestInventory(permissions: permissions, components: components);
}

/// Compares one variant's inventory against the enumerated sets. The
/// effective component set is the platform baseline union the one
/// permitted activity; findings name the full effective permission set
/// (platform injection included). Line 1 is cited because merged
/// manifests are machine-generated XML — the element, not a source
/// line, is what a finding names.
List<Finding> checkInventory({
  required String manifestPath,
  required String variant,
  required ManifestInventory inventory,
  Map<String, Set<String>> permissionSets = permittedPermissionsByVariant,
  Set<String> componentSet = permittedComponentsAllVariants,
  Set<String> activitySet = permittedActivitiesAllVariants,
}) {
  final findings = <Finding>[];
  final permittedPermissions = {
    ...permissionSets[variant]!,
    dynamicReceiverPermission,
  };
  for (final permission
      in inventory.permissions.difference(permittedPermissions).toList()
        ..sort()) {
    findings.add(
      Finding(
        manifestPath,
        1,
        "permission '$permission' is outside variant $variant's effective "
        'set ${_sorted(permittedPermissions)} (AD-7 manifest seal — a new '
        'permission is a deliberate allowlist edit)',
      ),
    );
  }
  final permittedComponents = {...componentSet, ...activitySet};
  for (final component
      in inventory.components.difference(permittedComponents).toList()
        ..sort()) {
    findings.add(
      Finding(
        manifestPath,
        1,
        "component '$component' is outside the enumerated baseline in "
        'variant $variant (AD-7 manifest seal — no service, receiver, '
        'provider, activity or activity-alias beyond the launcher and the '
        'platform baseline may be declared)',
      ),
    );
  }
  return findings;
}

List<String> _sorted(Set<String> set) => set.toList()..sort();

/// Locates the merged manifest Gradle's `process{Variant}MainManifest`
/// task produced, under the build dir the redirected root project owns
/// (`build/app/intermediates`, AGP 9's `merged_manifest/<variant>/…`
/// layout; the older `merged_manifests/<variant>/…` shape is accepted
/// too).
File locateMergedManifest({
  required Directory intermediates,
  required String variant,
}) {
  final candidates = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File &&
          entity.uri.pathSegments.last == 'AndroidManifest.xml') {
        final normalized = entity.path.replaceAll('\\', '/');
        if (normalized.contains('/$variant/') &&
            !normalized.contains('instant_app') &&
            !normalized.contains('androidTest')) {
          candidates.add(entity);
        }
      }
    }
  }

  if (intermediates.existsSync()) {
    for (final entity in intermediates.listSync(followLinks: false)) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      // A stray file named `merged_manifest*` (never a directory Gradle
      // would produce) is skipped, not crashed on.
      if (name.startsWith('merged_manifest') && entity is Directory) {
        walk(entity);
      }
    }
  }
  candidates.sort((a, b) => a.path.compareTo(b.path));
  if (candidates.isEmpty) {
    return File(
      '${intermediates.path}/merged_manifest/$variant/'
      'process${_capitalized(variant)}MainManifest/AndroidManifest.xml',
    );
  }
  // Prefer the pathNaming that names the producing task; otherwise the
  // first sorted candidate.
  for (final candidate in candidates) {
    if (candidate.path.contains(
      'process${_capitalized(variant)}MainManifest',
    )) {
      return candidate;
    }
  }
  return candidates.first;
}

String _capitalized(String variant) =>
    variant[0].toUpperCase() + variant.substring(1);

const List<String> variants = ['debug', 'release', 'profile'];

/// Runs the whole check against [repoRoot]: drives the three manifest
/// tasks, then enumerates and compares. Returns the process exit code:
/// 0 clean, 1 findings, 2 environment failure (the shared Gradle
/// runner's StateError contract: missing wrapper, missing
/// local.properties, JVM absent, timeout, Gradle failure).
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  await runGradle(
    androidDir: '${root}android',
    args: [
      for (final variant in variants)
        ':app:process${_capitalized(variant)}MainManifest',
      '--console=plain',
    ],
  );
  final findings = <Finding>[];
  for (final variant in variants) {
    final manifest = locateMergedManifest(
      intermediates: Directory('${root}build/app/intermediates'),
      variant: variant,
    );
    if (!manifest.existsSync()) {
      stderr.writeln(
        'merged manifest for $variant not found under '
        '${root}build/app/intermediates (looked near ${manifest.path})',
      );
      return 2;
    }
    findings.addAll(
      checkInventory(
        manifestPath: manifest.path,
        variant: variant,
        inventory: enumerateManifest(manifest.readAsStringSync()),
      ),
    );
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'android manifest check FAILED: ${findings.length} finding(s) — '
      'nothing outside the per-variant enumerated sets may be declared '
      '(AD-7)',
    );
    return 1;
  }
  print('android manifest check passed (${variants.length} variants)');
  return 0;
}

Future<void> main(List<String> args) async {
  try {
    exit(await runCheck(args.isEmpty ? '' : args.first));
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exit(2);
  }
}
