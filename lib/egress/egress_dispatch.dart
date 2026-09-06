import 'dart:typed_data';

import 'egress_payload.dart';
import 'image_cap.dart';

/// The transport seam (AD-7): one invocation per send over the prepared
/// payload, returning the response body. Story 4-4's ByokSlicer binds
/// the real HTTP client here — which is why this module holds no HTTP
/// import yet, and why the import seal's permit zone plus its fixture
/// tests cover both directions meanwhile.
typedef EgressTransport = Future<String> Function(EgressPayload payload);

/// The outcome of one egress send: delivered (with the response body)
/// or failed (with the cause). Sealed in this library so no third
/// outcome — and no queued or retained one — can exist as a type.
sealed class EgressResult {
  const EgressResult();
}

/// The transport answered once; [responseBody] is its body verbatim.
final class EgressDelivered extends EgressResult {
  const EgressDelivered(this.responseBody);

  /// The transport's response body.
  final String responseBody;
}

/// The egress attempt failed terminally; [cause] is whatever the cap or
/// the transport threw, verbatim, with the [stack] it was thrown with —
/// story 4-5's diagnosis surface and post-hoc debugging keep it. No
/// queue, no retry and no retained attempt exists anywhere in this
/// module — a second `send` is a fresh call by construction, because
/// the dispatch holds nothing but the injected transport.
final class EgressFailed extends EgressResult {
  EgressFailed(this.cause, [this.stack]);

  /// The failure's cause.
  final Object cause;

  /// The stack trace the cause was thrown with, when there was one.
  final StackTrace? stack;
}

/// One-shot dispatch over the injected [EgressTransport] (AD-7): on
/// the scan shapes the single-use consent token (AD-8, story 5.4) is
/// consumed first — before the resolution cap and outside the catch
/// arms, so a reused token is the programmer error it is and
/// propagates raw out of `send`, never wearing an [EgressFailed] or
/// `SlicerFailureCause` costume. One token authorizes one dispatch
/// entry, burned even when the cap rejects — nothing retries, so a
/// burned token on a failed send guards nothing, and the rule is
/// total: no path exists where a token survives contact with `send`.
/// The cap then runs inside the binding — scan shapes only, before
/// the transport is touched — and the capped reconstruction carries
/// the same token; the transport is invoked exactly once. Any failure
/// is terminal and surfaced as [EgressFailed]. AD-8's gate → mint →
/// cap → upload order stays intact, because the consumption and the
/// cap both live here, inside the send, not at the call site.
final class EgressDispatch {
  const EgressDispatch(this._transport);

  final EgressTransport _transport;

  Future<EgressResult> send(EgressPayload payload) async {
    var prepared = payload;
    if (payload is ScanImagePrompt) {
      // AD-8's one-way consumption, deliberately outside the catch
      // arms: a second send over a consumed token throws raw — a
      // programmer error no taxonomy folds — and a cap rejection has
      // still burned the token, because nothing retries and one token
      // authorizes exactly one dispatch entry.
      payload.consent.consume();
      final Uint8List capped;
      try {
        capped = await prepareImageForEgress(payload.imageBytes);
      } on Object catch (cause, stack) {
        return EgressFailed(cause, stack);
      }
      prepared = ScanImagePrompt(
        imageBytes: capped,
        prompt: payload.prompt,
        consent: payload.consent,
      );
    }
    try {
      return EgressDelivered(await _transport(prepared));
    } on Object catch (cause, stack) {
      return EgressFailed(cause, stack);
    }
  }
}
