# Reviewer Gate Report — Validate Intent

**Target:** `ARCHITECTURE-SPINE.md` — Anti-Overwhelm Mobile Task Organizer (26 ADs, status final)
**Date:** 2026-08-27 · **Mode:** Validate (report only; the spine was not modified)

## Gate composition

| Pass | Verdict | Critical | High | Medium | Low | Info |
| --- | --- | --- | --- | --- | --- | --- |
| `lint_spine.py` | CLEAN | 0 | 0 | 0 | 0 | — |
| Rubric walker | PASS WITH FIXES | 0 | 0 | 3 | 6 | — |
| Verification lens | PASS | 0 | 0 | 0 | 1 | 3 |
| Adversarial lens | **FAIL** | **1** | **4** | 4 | — | — |

**Gate verdict: FAIL as final** — driven by the adversarial lens. The Stack is fully re-verified (every pinned version is the current pub.dev release as of 2026-08-27; no fabricated or superseded claims). The remaining risk is concentrated in five seams between ADs, all closable with amendments rather than a rewrite.

## Critical

- **ADV-1 · AD-19 × AD-20 — cross-04:00-session Focus Chunk occupancy is double-owned.** Two letter-compliant builds disagree on a session that spans the 04:00 boundary: one ships two answered Focus Chunks inside one domestic day (the marathon-with-a-comma AD-4 exists to prevent), the other silently loses a day's chunk.

## High

- **ADV-2 · AD-24 × AD-4 — "that day's energy" is undefined** for days with multiple `energy_set` entries and for cross-boundary sessions; FR-5's rescue counter and FR-12's capture window can advance on different day sets.
- **ADV-3 · AD-21 × AD-13 × FR-30 — export outcome has no compliant durable home.** The exhaustive seven system events plus "no other store" leave FR-30's export state volatile-only; also no act for "left the scan surface", shifting FR-26 series (b)'s denominator.
- **ADV-4 · AD-13 × AD-23 × AD-18 — tolerance is stated over derivations, not the import.** One build refuses the exact cross-version restore AD-18's update ritual depends on.
- **ADV-5 · AD-25 × FR-5 — dissolution's retire-set is undefined.** One build keeps dealing orphaned siblings of a dissolved task forever.

## Medium

- **ADV-6..ADV-9** (4) — see `reviews/validate-2026-08-27/adversarial.md`
- **RUB-1 · AD-14/AD-25 vs AD-2 — pool-fact immutability asserted but unenforced:** AD-2's insert-only triggers cover only the log table; the round-trip test cannot distinguish hard-delete from derive-retire.
- **RUB-2 · Structural Seed ERD — `ALBUM_ENTRY` drawn as an entity though its manifest is derived; `CATALOGUE_ENTRY` though it is a build-time asset; `QUARANTINE_BOX` with no stated storage home.**
- **RUB-3 · AD-21 "No other store exists" has no named guard** (absent from the five tool checks, lints and tests); guard inventory also loose ("five checks" vs AD-7's three, AD-22's CI grep unlisted).

Plus 6 low (rubric) and 1 low + 3 info (verification) in the full reviews.

## Full reviews

- `reviews/validate-2026-08-27/rubric.md`
- `reviews/validate-2026-08-27/verification.md`
- `reviews/validate-2026-08-27/adversarial.md`
