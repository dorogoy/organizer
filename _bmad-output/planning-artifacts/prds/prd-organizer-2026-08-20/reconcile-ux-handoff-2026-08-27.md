# Input reconciliation — UX handoff ledger → prd.md + addendum.md

Input: `ux-designs/ux-organizer-2026-08-21/.memlog.md` entry 197 (HANDOFF LEDGER, blocker-resolution pass closed 2026-08-27), plus the OQ resolutions that session produced (entries 79–82, 181–193).

## Verdict

All four ledger debts landed in the PRD; the three UX-resolved open questions routed to `bmad-ux` are closed with dated rulings. No ledger item was dropped or silently diverged.

## Coverage

| Ledger item | Status | Where |
|---|---|---|
| [DEBIDA] §1.1 E2 removal | Applied | §1.1 register (E1 alone), FR-11 bullets rewritten to A-slim; Changelog records the reversal of the 2026-08-26 decision |
| [DEBIDA] FR-4 presentation rewrite | Applied | FR-4 daily check-in: first opening, skippable, resolved = gone for the day; Sunday yields to SM-2 (may take slot same opening); mid-task clause scoped to while the strip is open; default 🟢 no decay (A5). Cascade: §3 glossary, §10.1 Energy row, addendum A5 |
| [RECOMENDADA] camera disable/reactivate + unified mic reactivation | Applied as FR-16 consequences + FR-32 mirror (Sergio's pick — no FR-33) | FR-16 (visibility = enabled ∧ permission-not-refused; single settings row owns toggle + reactivation), FR-32 (row only while something to reactivate), §7 (first-use rule generalized to both permissions), §10.1 unified Entry-visibility row |
| [OPCIONAL] FR-31 onboarding note | Applied | FR-31 curation bullet: product + one-time strip, no wizard, dismissed = never again; Edge-21 substance (all-active default, first day never empty) preserved |

## OQ closures absorbed (routed to `bmad-ux` in the PRD, answered there 2026-08-27)

- **OQ-3** surviving half — onboarding curation presentation → one-time strip, cluster-level switch rows.
- **OQ-11** — spatial framing, no validation, no refusal, silent acceptance; dates sub-question closed with the authorized copy (frame says nothing about dates). FR-27's two affected bullets updated; stale "open product decision" text replaced.
- **OQ-13** — absent-and-silent is the decision, no language-pack pointer; recognition-unavailability vs refused-permission distinction recorded (reactivation row only for the latter).

## Gaps

None from the ledger. Two consequential notes:

- **G1 (out of scope by the ledger's own ORDER):** `SPEC.md` (~line 70) and `ARCHITECTURE-SPINE.md` (line 13) still cite E2 and must drop it — one-line manual edits or a `bmad-architecture` touch. Logged in the memlog as deferred with owner.
- **G2 (self-correcting):** `epics.md` quotes FR-4 verbatim in its old reading; the ledger notes it self-corrects once the PRD lands.

## Consistency sweep

Zero E2 references remain in the body (Changelog history excepted, as designed); FR-1..FR-32 contiguous (32 headings); §10.1 well-formed (45 table rows × 3 cols); no stale `OQ-11 carries the copy question` / `onboarding abandoned mid-curation` / `never asks again` unqualified phrasing; OQ-12's companion reference repaired.
