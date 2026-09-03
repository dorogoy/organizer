// The frozen provider allowlist (Story 4-4, AD-9, AD-10): the four
// entries the BYOK path may ever call, a compile-time constant in
// this module — never fetched, never re-checked at runtime, with no
// free-form endpoint or base-URL field anywhere in the app (the
// no-training gate is unenforceable if the user can point the app
// anywhere). A stale entry is corrected by shipping a build, and by
// nothing else.
//
// Machine facts only: ids, the wire kind each entry speaks, and the
// fixed model id the entry names — the fixing act spine line 102
// records (a future id change is a build, not a fetch). Rendered
// copy — provider names and the terms-verified sentences — lives in
// the ARB (AD-15), pinned to cover exactly these ids by test.
//
// Terms facts, for the record this file's dates ride on: the first
// three entries' written no-training terms were verified 2026-08-26;
// OpenRouter was admitted 2026-09-03 past the same gate, its
// upstream half enforced by the app itself per request
// (`provider.zdr: true` routes only to zero-data-retention
// endpoints; the slug below sits in OpenRouter's ZDR list).

/// Which per-provider wire an entry speaks (Story 4-4): the
/// mechanism mapping is code per provider in `byok_wire.dart`, not
/// configuration — gemini's `x-goog-api-key` + `responseSchema`,
/// OpenAI's Bearer + strict `json_schema`, Anthropic's `x-api-key` +
/// tool `input_schema`, and OpenRouter's OpenAI-compatible route
/// with the per-request ZDR routing preference.
enum SlicerWireKind {
  /// Google's generateContent endpoint, key in `x-goog-api-key`,
  /// structured output via `generationConfig.responseSchema`.
  geminiNative,

  /// OpenAI chat completions, Bearer key, strict `json_schema`
  /// response format.
  openAiChat,

  /// Anthropic messages, `x-api-key`, schema riding a forced tool's
  /// `input_schema`.
  anthropicMessages,

  /// OpenRouter's OpenAI-compatible chat completions, Bearer key,
  /// strict `json_schema`, plus `provider.zdr: true` on every
  /// request.
  openRouterChat,
}

/// One frozen allowlist entry: the provider's id (charset-valid per
/// the core's `isValidProviderId`, so the id is storable as a
/// setting and as a Files scope name), the wire it speaks, and the
/// fixed model id it is called under. Nothing else exists to say
/// about an entry — no endpoint field, no tier, no status.
final class ProviderAllowlistEntry {
  const ProviderAllowlistEntry({
    required this.id,
    required this.wireKind,
    required this.modelId,
  });

  /// The provider's id — the one string the settings row, the vault
  /// scope and this allowlist share.
  final String id;

  /// The wire the entry speaks.
  final SlicerWireKind wireKind;

  /// The fixed model id (OpenRouter's is its ZDR-list slug).
  final String modelId;
}

/// The gemini entry's id.
const String geminiProviderId = 'gemini';

/// The openai entry's id.
const String openAiProviderId = 'openai';

/// The anthropic entry's id.
const String anthropicProviderId = 'anthropic';

/// The openrouter entry's id.
const String openRouterProviderId = 'openrouter';

/// The gemini entry's fixed model id — the class story 4-1 scored.
const String geminiModelId = 'gemini-3.5-flash-lite';

/// The openai entry's fixed model id.
const String openAiModelId = 'gpt-5.6-luna';

/// The anthropic entry's fixed model id.
const String anthropicModelId = 'claude-haiku-4.5';

/// The openrouter entry's fixed model id — its ZDR-list slug for the
/// same gemini class the reference entry names.
const String openRouterModelSlug = 'google/gemini-3.5-flash-lite';

/// The frozen allowlist itself: exactly four entries, in display
/// order. Compile-time constant — the runtime has no path that adds,
/// removes or re-checks an entry.
const List<ProviderAllowlistEntry> slicerProviderAllowlist = [
  ProviderAllowlistEntry(
    id: geminiProviderId,
    wireKind: SlicerWireKind.geminiNative,
    modelId: geminiModelId,
  ),
  ProviderAllowlistEntry(
    id: openAiProviderId,
    wireKind: SlicerWireKind.openAiChat,
    modelId: openAiModelId,
  ),
  ProviderAllowlistEntry(
    id: anthropicProviderId,
    wireKind: SlicerWireKind.anthropicMessages,
    modelId: anthropicModelId,
  ),
  ProviderAllowlistEntry(
    id: openRouterProviderId,
    wireKind: SlicerWireKind.openRouterChat,
    modelId: openRouterModelSlug,
  ),
];

/// The entry whose id is [id], or null when no allowlisted entry
/// carries it — the one lookup the whole access path performs. A
/// null answer is the quiet refusal every caller folds into
/// "nothing configured": no send, no row, no error surface.
ProviderAllowlistEntry? allowlistEntryById(String id) {
  for (final entry in slicerProviderAllowlist) {
    if (entry.id == id) {
      return entry;
    }
  }
  return null;
}
