# Editorial review — credential-at-rest reconciliation

This PRD and addendum exist to give product, design, architecture, and implementation readers one testable product contract plus the rationale and technical authority needed to interpret it consistently.

**Scope:** only the credential-at-rest edits in FR-28, closed OQ-9, changelog entry 2026-08-27, and addendum A14.  
**Reader:** humans.  
**Style guide:** Microsoft Writing Style Guide.  
**Structure model:** Strategic/Context (Pyramid).  
**Word metrics:** PRD 17,647 words; FR-28 711 words; Open Questions 1,033 words; Changelog 604 words; addendum 5,970 words; A14 144 words.

## Findings

| Pass | Original Text | Revised Text | Changes |
| --- | --- | --- | --- |
| structure | FR-28 credential bullet + OQ-9 closed entry + changelog 2026-08-27 + A14 (~144 words plus repeated summaries) | **CONDENSE:** Keep the complete, testable current-state contract in FR-28; keep A14 as the short correction rationale and architecture pointer; reduce OQ-9 to its outcome and owner; keep the changelog to one sentence without repeating the mechanism. | The same mechanism appears four times at different levels. The repetition creates four maintenance sites and weakens the PRD's stated rule that the body carries current rules while history stays in the changelog. Estimated saving: ~45–65 words. |
| structure | FR-28: “AndroidKeyStore holds a non-exportable wrapping key, while the provider API key exists only as a provider-scoped encrypted envelope in app-private storage” | **CONDENSE:** “The persisted credential is encrypted with an installation-bound, OS-protected key; it is never stored in preferences or included in an export (§7).” Keep the AndroidKeyStore/envelope/`withCredential` mechanism in AD-22 and A14's rationale pointer. | The product requirement should bind observable security and restore behavior; class names, storage topology, and request-scope implementation belong to the architecture authority already named by A14. This reduces coupling without losing acceptance criteria. Estimated saving: ~10–20 words in FR-28. |
| structure | A14's three-paragraph correction rationale (144 words) | **PRESERVE:** Keep A14 as a separate rationale entry, but make it the sole explanation of why the wording changed and let AD-22 remain the sole detailed mechanism authority. | A14 looks superficially duplicative, but it preserves decision provenance that does not belong in the current-rule body. Its placement at the end of the rationale addendum is appropriate. No reduction required beyond the prose fixes below. |
| prose | “AndroidKeyStore holds cryptographic keys, not an arbitrary provider credential string” | “AndroidKeyStore stores cryptographic keys; it does not store an arbitrary provider credential string directly.” | Avoids implying that AndroidKeyStore cannot protect arbitrary secret data indirectly—the exact pattern described in the next paragraph. |
| prose | FR-28: “the provider API key exists only as a provider-scoped encrypted envelope in app-private storage” | “the provider API key is persisted only as a provider-scoped encrypted envelope in app-private storage” | Removes a literal contradiction with the later statement that plaintext exists transiently while saving or sending a request. |
| prose | FR-28: “Provider selection may restore; credential availability belongs to the current installation and is checked live.” | “Provider selection may be restored. Credential availability is installation-local and is verified by live decryption.” | Fixes the unnatural use of *restore*, replaces the abstract “belongs to,” and states what “checked live” means. |
| prose | A14: “app-private Files storage” | “app-private files storage” | `Files` reads like an unexplained proper noun or API type. Lowercase is clearer unless the architecture deliberately names a concrete Android API, in which case use that API's exact name. |
| prose | A14: “Provider selection is replayable and may survive restore.” | “Provider selection is replayable and may be restored.” | “Survive restore” is ambiguous about whether the selection is retained outside the backup or reconstructed from replayable state. |
| prose | FR-28: “Plaintext exists only while saving it or sending one request to its own provider.” | “Plaintext exists only while the credential is being saved or used for one request to the selected provider.” | Gives *it* an explicit antecedent and avoids making the API key appear to own a provider. |
| prose | A14: “Each BYOK request decrypts the credential only within that request's `withCredential` scope” | “Each BYOK request decrypts the credential only for the duration of that request.” | The public PRD addendum does not need an internal method or callback name; plain language preserves the security rule and avoids binding implementation terminology outside AD-22. |

## Verdict

**PASS with editorial changes.** The correction is understandable and internally coherent, and A14 is at the right altitude as decision rationale. Before treating the PRD as the durable product authority, reduce the four-site repetition and remove implementation identifiers from FR-28/A14 where AD-22 already owns them.

Nine recommendations: three structure, six prose. Accepting the two condense recommendations saves approximately 55–85 words (0.3–0.5% of the PRD; about 6–9% of the affected credential passages). No length target was provided, and the edits carry no meaningful comprehension trade-off.

## Recheck after revision

**Verdict: PASS with minor prose cleanup still recommended.** The structural findings are closed: FR-28 now carries the capability-level contract, OQ-9 delegates instead of restating the mechanism, and A14 appropriately holds the reconciliation detail and links directly to authoritative AD-22. No new structural ambiguity was introduced.

Four earlier prose findings remain:

- FR-28's “Provider selection may restore” and “credential availability belongs to the current installation” are understandable but unnatural; “Provider selection may be restored, but credential availability is installation-local” is clearer.
- FR-28's “one request to its own provider” has an unclear possessor; use “one request to the selected provider.”
- A14 still says AndroidKeyStore holds keys “not an arbitrary provider credential string”; add “directly” to avoid implying that Keystore cannot protect the credential indirectly.
- A14 still uses “Files storage,” “may survive restore,” and the internal name `withCredential`; lowercase “files storage,” “may be restored,” and “for the duration of that request” are clearer at addendum altitude.

These are copy-edit issues, not contract blockers. The capability/mechanism split and deduplication are now sound.
