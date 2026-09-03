// The slicer factory (Story 4-4, AD-9): the shell's one composition
// point for the Slicer. The Local shape's reachability is a
// compile-time constant — `bool.fromEnvironment('ORGANIZER_LOCAL_SLICER')`
// AND `kDebugMode` — so in a release build the gate is a folded
// false and the Local shape is unreachable by construction, never
// guarded at runtime. When the gate holds, Local swaps in for the
// whole Slicer (swappability exercised, not asserted); otherwise
// the BYOK shape serves. The Managed shape is never wired — it is
// the port's third shape for tests and the credits-only future its
// own file records.
//
// The http client is constructed here, inside the egress module —
// the only place an HTTP import is legal — so no call site outside
// `lib/egress/` ever names one.
import 'package:core/ports/slicer_port.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../vault/credential_vault.dart';
import 'byok_slicer.dart';
import 'local_slicer.dart';

/// The dart-define key that arms the Local shape.
const String localSlicerEnvironmentKey = 'ORGANIZER_LOCAL_SLICER';

/// The Local shape's environment flag, default false: unset, the
/// gate's first half already refuses.
const bool localSlicerEnvironmentFlag = bool.fromEnvironment(
  localSlicerEnvironmentKey,
  defaultValue: false,
);

/// The Local shape's compile-time reachability: the environment flag
/// AND the debug variant. In release `kDebugMode` is a false
/// constant, so this folds false there whatever the flag says.
const bool localSlicerReachable = localSlicerEnvironmentFlag && kDebugMode;

/// Composes the shell's Slicer. [localCannedMarker] is the ARB's
/// canned-register string — the marker the Local shape's output
/// carries; [readSelectedProvider] is the per-call settings
/// derivation reader the BYOK shape resolves through.
///
/// The one `http.Client` is constructed here and deliberately never
/// closed: one client for the whole process lifetime, owned by the
/// app root's single Slicer — no teardown exists by design, because
/// no app lifecycle event can deliver a slice after the process is
/// gone, and closing a shared client mid-flight could only ever
/// manufacture a failure no caller asked for.
SlicerPort buildSlicer({
  required CredentialVault vault,
  required SelectedProviderReader readSelectedProvider,
  required String localCannedMarker,
}) {
  if (localSlicerReachable) {
    return LocalSlicer(cannedMarker: localCannedMarker);
  }
  return ByokSlicer(
    client: http.Client(),
    vault: vault,
    readSelectedProvider: readSelectedProvider,
  );
}
