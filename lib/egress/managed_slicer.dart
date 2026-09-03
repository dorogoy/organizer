// The Managed Slicer (Story 4-4, AD-9): the port's third shape —
// inert in this build. Every slice answers
// `SlicerFailed(managedUnavailable)`, and that is the whole
// implementation: no proxy, no account, no login, no registration,
// no billing code exists anywhere behind it.
//
// The shape's record, stated where it belongs (the access layer
// itself): if Managed is ever implemented, it is non-expiring
// credits, never a subscription. Adding this class changes no call
// site outside `lib/egress/` — nothing constructs it but tests and
// whatever future wiring the credits decision would bring.
import 'package:core/ports/slicer_port.dart';

final class ManagedSlicer implements SlicerPort {
  const ManagedSlicer();

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async =>
      const SlicerFailed(SlicerFailureCause.managedUnavailable);
}
