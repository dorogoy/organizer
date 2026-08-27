# Rubric walker — good-spine checklist

**Verdict:** PASS on structure and coverage; three dimensions under-decided. The paradigm is the spine's strongest asset and its main risk: it concentrates so much into one derivation that the seams around that derivation needed the adversarial pass to be closed (see `review-adversarial.md`).

## Checklist

| Criterion | Judgement |
| --- | --- |
| Fixes the real divergence points for the level below | **Partial → fixed.** Seven seams were open; the adversarial lens closed them. The remaining ADs each fail loudly if broken. |
| Every Rule enforceable, and actually prevents its stated divergence | **Pass, with teeth worth noting.** Six rules are machine-checked, not aspirational: AD-2 (SQL triggers), AD-5 (CI import check), AD-7 (single HTTP importer), AD-13 (round-trip test), AD-15 (placeholder check), AD-16 (catalogue floor count). The forbidden-vocabulary lint is the strongest single line in the document. |
| Nothing in Deferred could let two units diverge | **Pass.** Each entry carries a revisit trigger, and the act-log-growth entry explicitly states AD-1 survives its resolution — the projection table is a cache, never a plan. |
| Named tech verified-current | **Partial.** See `review-verification.md`: one critical (minSdk on split evidence) and one high (`flutter_secure_storage` asserted) — both fixed. |
| Ratifies rather than contradicts a brownfield codebase | **N/A.** Greenfield: no code, no `project-context.md`. |
| Covers the driving spec's capabilities | **Pass.** All eleven PRD feature groups mapped; FR-1…FR-32 bound in frontmatter. |
| No new AD weakens an inherited one | **N/A.** No parent spine. |
| Every dimension the altitude owns is decided, deferred, or open | **Partial → three gaps, below.** |

## Gaps

**G1 — HIGH. i18n mechanism undecided.** §6 requires *"Spanish UI with i18n-ready strings, no hardcoded copy"*, and both spines flag an unnamed second locale. AD-15 fixes the *shape* (one flat table, no runtime concatenation) but not the *mechanism* — a Dart map, ARB + `flutter_localizations`, or something else. Two units will pick differently, and the pluralisation question interacts directly with AD-15's no-concatenation rule (ICU plural forms are a controlled exception or they are not). **Fix: a convention row plus a Deferred entry naming the second locale as the trigger.**

**G2 — MEDIUM. The cold-start budget has no owner.** §7 contracts ≤ 2 s to the first card and < 500 ms Done→next. AD-1 makes the first card a derivation over the log and the catalogue asset, so the budget is an architectural property, yet no AD or convention holds it and no test asserts it. Two units can each add first-run work in good faith. **Fix: a convention row making the budget a test over the core's derivation, and a note that the catalogue asset is parsed lazily.**

**G3 — LOW. Screen-reader behaviour is absent from Deferred.** `EXPERIENCE.md` OQ-13 records that TalkBack labels, roles, state announcements and traversal order are *"never discussed anywhere in the record"*. The spine's Deferred names the UX copy questions but not this one, and unlike copy it has a structural half: a one-card surface with an ambient container is a non-trivial traversal order. **Fix: name it in Deferred.**

## Observations, not findings

- **The strongest architectural move in the document** is AD-1's reframing of §1.1 principle 2 as a storage contract: *an append-only log of user acts cannot express what the user did not do*. It converts three separate FRs (FR-6, FR-13, FR-14) from features into non-features. That is the kind of call a spine exists to make.
- **The plugin-boundary AD (AD-11) is unusually well-evidenced** — it cites a specific plugin defect and a specific API pair rather than a preference, so a later reader can re-derive the decision.
- **AD-10 is the one AD that narrows a source requirement rather than implementing it.** It is correctly marked `[ADOPTED]` and was paid upstream into the PRD in the same session, so spine and PRD do not diverge. Worth flagging for the retrospective: it is the only place the architecture changed the product's promise.
