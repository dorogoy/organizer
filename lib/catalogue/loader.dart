import 'package:core/catalogue/catalogue.dart';
import 'package:flutter/services.dart';

import '../strings/app_strings.dart';
import 'catalogue_names.g.dart';

/// Diagnostics for a bundle read that failed. Named-constant allowance in
/// AD-15's check (on the store module's file-reference terms: crash-path
/// context, never widget copy); the placeholders are substituted by value.
const String catalogueReadFailureTemplate =
    'could not read the shipped catalogue asset "@path": @cause';

/// Diagnostics for the stale-codegen drift path — the asset and the
/// generated table came from different commits. Same named-constant
/// allowance as [catalogueReadFailureTemplate].
const String catalogueStaleLookupTemplate =
    'entry "@id": no generated name lookup for it — the lookup table is stale; rerun dart run tool/gen_catalogue_lookup.dart and commit (AD-16)';

/// The substitution slots the two templates above carry.
const String catalogueAssetPathSlot = '@path';
const String catalogueCauseSlot = '@cause';
const String catalogueIdSlot = '@id';

/// The named shell catalogue loader (AD-16, AD-21): reads the shipped
/// Evergreen catalogue from the asset bundle — `rootBundle` only, so the
/// whole library arrives offline by construction and no network is ever
/// touched — parses it with the pure core parser, and resolves each
/// entry's Spanish name through the generated lookup table before handing
/// the core inert data.
///
/// Lazy by omission: nothing wires this into boot; the weave (Story 1.6)
/// is its first consumer. The [bundle] parameter exists so tests can hand
/// over a fake bundle; production callers take the default `rootBundle`.
Future<Catalogue> loadEvergreenCatalogue(
  AppStrings strings, {
  AssetBundle? bundle,
}) async {
  final source = await _readAsset(bundle ?? rootBundle);
  return parseCatalogue(source, nameOf: (id) => _resolveName(id, strings));
}

Future<String> _readAsset(AssetBundle bundle) async {
  try {
    return await bundle.loadString(catalogueAssetPath);
  } catch (error) {
    throw Exception(
      catalogueReadFailureTemplate
          .replaceFirst(catalogueAssetPathSlot, catalogueAssetPath)
          .replaceFirst(catalogueCauseSlot, error.toString()),
    );
  }
}

/// Resolves one entry's name through the generated table. A miss is the
/// stale-codegen drift path, and fails as a catalogue FormatException
/// naming the id, never as a null-check crash.
String _resolveName(String id, AppStrings strings) {
  final nameFor = catalogueNameOf[id];
  if (nameFor == null) {
    throw FormatException(
      catalogueStaleLookupTemplate.replaceFirst(catalogueIdSlot, id),
    );
  }
  return nameFor(strings);
}
