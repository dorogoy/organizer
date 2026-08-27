# Party rubric review — Architecture Spine

Date: 2026-08-27  
Intent: validate only  
Lenses: system architecture (Winston) + anti-overwhelm/product preservation (Sally)

## Gate verdict

**CHANGES REQUIRED — high severity.** The spine is unusually strong, coherent, and mechanically complete, and it preserves most of the anti-overwhelm contract structurally. It is not yet a safe single build substrate because one adopted rule contradicts an explicit FR, one product-boundary question required before Manual Capture is built has disappeared from the spine, and two source/spine contracts still permit incompatible implementations.

Deterministic gate: **PASS** (`lint_spine.py`: 0 findings).

## Tiered findings

### HIGH — AD-17 weakens FR-24's rolling 24-hour cap

**Evidence.** FR-24 requires “At most one notification per 24 h … under every code path” (`prd.md` §4.7, line 359). AD-17 instead limits emissions to “at most one per domestic day” and explicitly says this is not a rolling 24 h (`ARCHITECTURE-SPINE.md`, line 156). AD-21's own prevention text still describes the protected contract as “at most one per 24 h” (`ARCHITECTURE-SPINE.md`, line 184).

These predicates are not equivalent. With an inexact alarm or a changed chosen hour, one notification late on day N and another early on day N+1 can be emitted less than 24 hours apart while satisfying the domestic-day rule. That is exactly the escalation path SM-C3 exists to detect: notification pressure must not exceed 1/day (`prd.md` §8, line 567).

**Disposition: discuss, then update.** Choose and state one invariant. The product-preserving choice is to enforce both constraints: no more than one per domestic day **and** no emission within 24 hours of the last `invitation_emitted`; the append-only log already provides the fact needed. If the product truly accepts calendar-day rather than rolling-24-hour behavior, reconcile FR-24 and SM-C3 upstream before treating AD-17 as adopted.

### HIGH — OQ-11/OQ-12 vanish although the PRD says they must be resolved before FR-27 is built

**Evidence.** The PRD leaves open whether Manual Capture accepts non-spatial or clock-bound work, explains that either answer can create shaming or semantic mismatch, and routes the decision to UX “before FR-27 is built” (`prd.md` §9 OQ-11, lines 581–582). The spine nevertheless maps FR-27 into `core/pool` and the Weaver (`ARCHITECTURE-SPINE.md`, lines 364 and 216), fixes all captures into the 1-3-5 taxonomy (`ARCHITECTURE-SPINE.md`, lines 229 and 231), and lists its Deferred items without OQ-11/OQ-12 (`ARCHITECTURE-SPINE.md`, lines 368–379).

Two stories can now implement incompatible products: accept `llamar al dentista` and deal it under household-energy rules, or reject it at capture and risk a shaming refusal. A dated line such as `regar el jueves` can also enter a substrate that intentionally models no dates. This touches the core eligibility contract and the central anti-overwhelm promise; it is not merely unresolved copy.

**Disposition: defer explicitly as a blocking open item.** Name OQ-11/OQ-12 in the spine, identify the affected boundary (`Manual Capture -> pool -> EligibleDay/weave`), and set the revisit condition to before FR-27 implementation. Do not invent an answer in architecture.

### HIGH — the source and spine disagree on the Evergreen entry schema

**Evidence.** FR-31 says every catalogue entry carries “three fields and no more”: size, cadence, zone-or-none (`prd.md` §4.11, line 492). AD-16 requires “four fields and no more,” adding a permanent id (`ARCHITECTURE-SPINE.md`, line 150); the ID is then load-bearing for deterministic ties and cross-build continuity (`ARCHITECTURE-SPINE.md`, lines 148–150 and 193–200).

The architectural decision is technically sound, but the unreconciled “and no more” clauses make the source package non-convergent. A story built from the PRD can reject the id as non-compliant; one built from the spine must require it.

**Disposition: update upstream.** Keep AD-16's permanent id and amend FR-31's schema to four fields. This is a reconciliation fix, not a reason to weaken the spine.

### MEDIUM — the consent UI's anti-dark-pattern invariant is not carried by an enforceable architecture rule

**Evidence.** DESIGN declares the per-scan consent gate the only surface with zero recommended actions, requires equal unfilled buttons, and states that the system has exactly three UX exceptions with no fourth implied (`DESIGN.md`, lines 480–487 and 537–543). AD-8 structurally protects token lifetime and image deletion, but says nothing about equal choice presentation (`ARCHITECTURE-SPINE.md`, lines 92–96). The spine frontmatter names only PRD exceptions E1/E2 (`ARCHITECTURE-SPINE.md`, lines 12–15), while its conventions defer to `DESIGN.md` only for token transcription (`ARCHITECTURE-SPINE.md`, line 238).

This does not require duplicating visual detail in the spine. It does require a closed structural seam so a generic “primary action” component cannot make `Enviar` visually recommended while AD-8 remains technically satisfied. That would preserve privacy mechanics and still violate the user's unpressured choice.

**Disposition: update or explicitly inherit.** Bind FR-25's consent surface to the named `action-equal-pair` contract (or add a shell/widget-test guard asserting equal prominence and zero recommended action), without copying its token-level design into the architecture.

## Good-spine checklist

| Check | Result | Assessment |
| --- | --- | --- |
| Real divergence points at initiative altitude are fixed | **Partial** | Core derivation, storage, time, egress, sessions, evolution, export, and UI-number seams are strongly fixed. Manual Capture's domain boundary is missing (finding 2). |
| Every AD Rule is enforceable and prevents its stated divergence | **Partial** | Most rules name triggers, CI checks, facade shapes, or property tests. AD-17 enforces the wrong predicate relative to FR-24 (finding 1); AD-8 does not close the consent-presentation seam (finding 4). |
| Deferred cannot let two child units diverge | **Fail** | OQ-11/OQ-12 are absent despite affecting capture acceptance and core eligibility. Existing Deferred items otherwise carry sensible revisit conditions. |
| Named technology is current and fit | **Pass with normal expiry risk** | Versions are pinned and accompanied by compatibility notes (`ARCHITECTURE-SPINE.md`, lines 244–265). The three fragile dependencies and API 37 have explicit revisit triggers (lines 375–376). No fresh web verification was performed in this document-only party review; the spine records an independent live-web verification dated 2026-08-26 (line 246). |
| Ratifies brownfield reality | **N/A / Pass** | Greenfield; no code exists. `project-context.md` confirms the same Flutter/Dart completion gate and introduces no conflicting code convention. |
| Covers source capabilities | **Partial** | Capability map covers FR-1–32 (`ARCHITECTURE-SPINE.md`, lines 350–366), but coverage is not fully reconciled where FR-24 changes semantics and FR-31 disagrees on schema. |
| Parent invariants are preserved | **N/A** | No parent spine is named or inherited. |
| Paradigm and dependency direction | **Pass** | Functional core / imperative shell and inward-only dependencies are explicit and guarded (`ARCHITECTURE-SPINE.md`, lines 28–36, 74–78, 267–290). |
| State mutation and shared-data ownership | **Pass** | Two insert-only persistence shapes, append-only evolution, cache/source-of-truth split, and adapter ownership are explicit (`ARCHITECTURE-SPINE.md`, lines 40–56, 181–200, 220–242). |
| Data model, identity, time, and migration | **Pass with reconciliation finding** | Strong rules cover immutable facts, UUID semantics, domestic periods, forward compatibility, and export round trips. Catalogue schema conflict remains (finding 3). |
| Integration, network, privacy, and security | **Pass** | Egress is closed to three payloads, native dependencies are sealed, keys remain in Keystore, scans have bounded file lifetime, and developer egress is structurally absent (`ARCHITECTURE-SPINE.md`, lines 86–120, 187–191). Consent presentation remains a product-integrity gap, not a transport-security gap. |
| Error/degradation behavior | **Pass** | No queue/retry, seven calm Slicer states, absent speech fallback, and foreground-only export behavior are assigned to explicit owners (`ARCHITECTURE-SPINE.md`, lines 86–114, 152–156, 232–235). |
| Performance envelope | **Pass** | First-card and Done-to-next budgets are named and tested over derivation; log-growth has a measured revisit threshold (`ARCHITECTURE-SPINE.md`, lines 240 and 371). |
| Accessibility and localization | **Pass / appropriately deferred** | 200% scaling has enforceable bans; Spanish ARB ownership is closed; screen-reader semantics are explicitly deferred with an interim default and revisit condition (`ARCHITECTURE-SPINE.md`, lines 236–240, 374). |
| Testing and verification strategy | **Pass** | Core, shell, property, migration, lint, manifest, dependency, export, and handset verification layers are named (`ARCHITECTURE-SPINE.md`, lines 240–242). The repository-wide completion gate additionally requires `flutter test`, format, and analyze (`project-context.md`, lines 5–7). |
| Deployment, environments, infra/provider strategy, operations | **Pass for validation altitude** | Android-only/no-backend topology, BYOK provider boundary, debug-only Local stub, release signing/update ritual, no store distribution, and validation-handset operation are decided (`ARCHITECTURE-SPINE.md`, lines 98–108, 158–162, 292–309). OQ-1 Local-vs-cloud remains explicitly deferred with a real-photo test trigger (line 370). |
| Validation-build scope preserved | **Pass** | Single-user, Android, local-first, no account/backend, BYOK-only usable path, debug-only stub, no Managed implementation, and no speculative iOS/multi-user work remain bounded (`ARCHITECTURE-SPINE.md`, lines 7, 98–108, 292–309, 370–376). |
| Anti-overwhelm promise preserved | **Partial / strong** | No stored plan or lateness, single-card read API, no pending collections, invisible internal counters, bounded sessions, calm errors, no backup nags, and one quiet validator path are structurally strong (`ARCHITECTURE-SPINE.md`, lines 40–44, 80–84, 164–179, 214–218). Findings 1, 2, and 4 are the remaining ways pressure, rejection, or dark-pattern choice could re-enter while implementation still appears compliant. |

## Recommended gate action

Resolve findings 1–3 before story decomposition or implementation. Finding 4 should be closed before the scan/consent surface is built. No changes were made to `ARCHITECTURE-SPINE.md` during this validation.
