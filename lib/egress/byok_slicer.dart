// The BYOK Slicer (Story 4-4, AD-9, AD-10, AD-22): the port's one
// usable implementation. Resolves the selected provider per call
// through the injected reader (the settings derivation over the
// log), takes the provider's key inside the vault's one request
// scope — unavailable material means nothing is sent, folded to
// `credentialUnavailable` — maps the request onto its egress
// payload (the rescue prompt composed from the access layer's own
// contract; scan and genesis verbatim), and sends exactly once
// through `EgressDispatch`, whose image cap stays intact inside the
// send. The per-provider wire is `byok_wire.dart`'s; the causes
// classify from evidence — HTTP status or socket family — and
// nothing here queues, retries, meters or reports anything.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:core/ports/slicer_port.dart';
import 'package:http/http.dart' as http;

import '../vault/credential_vault.dart';
import 'byok_wire.dart';
import 'egress_dispatch.dart';
import 'egress_payload.dart';
import 'provider_allowlist.dart';

/// How the slicer learns the selected provider per call: the shell
/// hands in the settings derivation's reader (the last valid
/// `selected_provider` row over the log, or none). Reading per call
/// — never caching — is the same no-TOCTOU discipline the vault
/// holds.
typedef SelectedProviderReader = Future<String?> Function();

final class ByokSlicer implements SlicerPort {
  ByokSlicer({
    required this.client,
    required this.vault,
    required this.readSelectedProvider,
  });

  /// The one HTTP client this slicer sends through — the egress
  /// module's only legal home for one.
  final http.Client client;

  /// The credential vault (Story 4.3): every send executes inside
  /// `withCredential`'s request scope.
  final CredentialVault vault;

  /// The per-call selected-provider reader.
  final SelectedProviderReader readSelectedProvider;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    try {
      return await _slice(request);
    } on Object {
      // The port answers outcomes only — a bare throw crossing this
      // boundary would break the outcome-only contract every caller
      // (4-6's rescue path included) is written against. An
      // unexpected throw here is infrastructure refusing under the
      // read (the provider reader's storage, the vault's envelope
      // read): no provider was reached and no evidence names a finer
      // cause, so the taxonomy's no-answer bucket takes it —
      // `providerUnreachable` — and nothing is retried.
      return const SlicerFailed(SlicerFailureCause.providerUnreachable);
    }
  }

  Future<SlicerOutcome> _slice(SlicerRequest request) async {
    final selected = await readSelectedProvider();
    final entry = selected == null ? null : allowlistEntryById(selected);
    if (entry == null) {
      // No provider selected, or one the frozen allowlist does not
      // carry: nothing is sent and nothing is surfaced — the quiet
      // config-family cause.
      return const SlicerFailed(SlicerFailureCause.credentialUnavailable);
    }
    final payload = _payloadOf(request);
    final access = await vault.withCredential(
      entry.id,
      (plaintext) => EgressDispatch(
        (prepared) => sendSlicerWire(
          client: client,
          entry: entry,
          apiKey: plaintext,
          payload: prepared,
        ),
      ).send(payload),
    );
    return switch (access) {
      // Missing, corrupt or invalidated material — the operation was
      // never invoked, nothing was sent, and the three fold into the
      // one config-family cause 4-5's copy owns.
      AccessUnavailable() => const SlicerFailed(
        SlicerFailureCause.credentialUnavailable,
      ),
      AccessGranted(:final result) => _outcomeOf(entry, result),
    };
  }

  /// The request→payload mapping: three kinds onto three payloads,
  /// one-for-one, exhaustively.
  static EgressPayload _payloadOf(SlicerRequest request) => switch (request) {
    ScanSliceRequest() => ScanImagePrompt(
      imageBytes: request.imageBytes,
      prompt: request.prompt,
    ),
    GenesisSliceRequest() => ProjectGenesisText(text: request.text),
    RescueSliceRequest() => RescueResliceText(
      originContext: request.originContext,
      task: request.task,
    ),
  };

  static SlicerOutcome _outcomeOf(
    ProviderAllowlistEntry entry,
    EgressResult result,
  ) => switch (result) {
    EgressDelivered(:final responseBody) => switch (extractSliceText(
      wireKind: entry.wireKind,
      responseBody: responseBody,
    )) {
      null => const SlicerFailed(SlicerFailureCause.malformedResponse),
      final text => SlicerDelivered(text),
    },
    EgressFailed(:final cause) => SlicerFailed(_causeOf(cause)),
  };

  /// The evidence-to-cause mapping, closed over the taxonomy and
  /// split by evidence kind. HTTP status evidence: 401/403 read
  /// `invalidKey`, 429 `quotaExhausted`, and every other non-2xx
  /// status — the 5xx family and the residual 4xx alike — reads
  /// `providerUnreachable`: the provider answered the request with
  /// a refusal-to-serve, which is a reachability fact, not a
  /// malformation of a delivered answer. Socket evidence (including
  /// the http package's own client failures) reads
  /// `networkUnreachable`. Decode evidence — a delivered 2xx body
  /// that is not valid UTF-8 — reads `malformedResponse`, the
  /// taxonomy's delivered-but-unusable bucket, which is otherwise
  /// reserved for extraction failures and is never reached by
  /// transport evidence. Anything else the transport threw (a
  /// stall's `TimeoutException` included) is the provider's side of
  /// the conversation: `providerUnreachable` — the split is
  /// evidence-shaped, honest about its limits, and adds no eighth
  /// cause.
  static SlicerFailureCause _causeOf(Object cause) {
    if (cause is WireStatusException) {
      final status = cause.statusCode;
      if (status == 401 || status == 403) {
        return SlicerFailureCause.invalidKey;
      }
      if (status == 429) {
        return SlicerFailureCause.quotaExhausted;
      }
      return SlicerFailureCause.providerUnreachable;
    }
    if (cause is SocketException || cause is http.ClientException) {
      return SlicerFailureCause.networkUnreachable;
    }
    if (cause is FormatException) {
      return SlicerFailureCause.malformedResponse;
    }
    return SlicerFailureCause.providerUnreachable;
  }
}
