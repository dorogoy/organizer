---
title: 'Story 7.4 review patch hardening'
type: 'maintenance'
created: '2026-09-12'
status: 'done'
baseline_commit: 'aab62aa4975e294c69b6652337696bc7778e094c'
---

## Intent

Harden the completed Story 7.4 cumulative-impact dashboard using the ten accepted code-review patches and the verification gaps found while applying them. Preserve the original story's frozen product intent; this work closes a data-identity edge case, protects narrow layout constraints, and strengthens the tests and manual evidence around the existing implementation.

## Boundaries & Constraints

**Always:** keep the dashboard read-only, preserve the seven-field AD-26 crossing, retain the contextual Album-only entry, preserve the existing Spanish copy and layout rules, and use the repository's existing pure-Dart/widget test conventions.

**Never:** add a new product surface, change the log schema or write paths, weaken the denominator rule, change the reserved purge namespace, or alter the original story's frozen intent.

## Code Map

- `packages/core/lib/derive/album.dart` and `packages/core/lib/derive/impact.dart` — the live album record currently drops the add-row identity/offset relationship; preserve enough identity to recover each add act's civil-day offset without aliasing entries sharing a group and instant.
- `packages/core/test/derive/impact_test.dart` — add same-group/same-instant offset coverage and an exact `ImpactRead`/`ImpactHighlight` record-shape assertion using the existing record-field proof convention.
- `lib/ui/dashboard/dashboard_screen.dart` — `_HighlightRow` computes candidate width before measuring captions; route non-positive or non-finite candidates to the existing one-column reflow.
- `test/ui/dashboard/dashboard_screen_test.dart` — strengthen the two-entry matrix, read-only fake, highlight destination, rendered-copy denominator deny-list, and all volume plural/gender arms.
- `test/ui/album/album_screen_test.dart` — prove that same-pair entries with distinct civil-day offsets retain distinct widget keys.
- `test/ui/reward/reward_screen_test.dart` and the Dispenser screen test suite — assert contextual-only dashboard affordance absence outside Album.
- This story file's Manual Verification section — reconcile the stated capture counts and seconds with the canonical estimate table and complete row census.

## Tasks & Acceptance

**Execution:**

- [x] Preserve per-entry civil-day offset identity and add a regression test for colliding group/instant keys.
- [x] Guard non-positive caption measurement widths and cover a narrow layout constraint.
- [x] Pin the exact AD-26 crossing record shapes.
- [x] Complete the two-entry, read-only, destination, denominator, contextual-gating, and volume-locale test coverage.
- [x] Correct or fully explain the manual verification arithmetic and row census.

**Acceptance Criteria:**

- Given two live album adds with the same group and instant but different identity/offset, when impact is derived, then each highlight retains its own offset.
- Given a highlight row whose candidate width is non-positive, when it lays out, then it uses the existing one-column path without passing an invalid width to `TextPainter`.
- Given the crossing record types, when their shapes are inspected, then `ImpactRead` has exactly its seven approved fields and the highlight has only its approved fields.
- Given the review test matrix, when it runs, then the two-cell, no-write, Album destination, semantic denominator, contextual gating, and singular/plural volume arms are all exercised.
- Given the manual verification table, when its counts are recomputed from the canonical estimates, then every reported row and second is reproducible.

## Verification

- `devbox run -- make gate`
- `devbox run -- make test-core`
- `dart format --set-exit-if-changed .` and `flutter analyze` through the gate
- `wc -c` for the original story and this patch spec

**Results (2026-09-12):**

- `devbox run -- make gate` — passed: checks, code generation, 1,302 Flutter tests, format, and analysis.
- `devbox run -- make test-core` — passed: 902 core tests.
- Targeted dashboard/Album tests — passed: 33 tests; targeted impact/album core tests — passed: 31 tests.
- `wc -c` — original story 24,148 bytes; patch spec 6,459 bytes.

## Suggested Review Order

**Read-model identity**

- Preserve each add row's civil-day offset with the live album entry.
  [`album.dart:43`](../../packages/core/lib/derive/album.dart#L43)

- Consume the preserved offset directly at the cumulative-impact crossing.
  [`impact.dart:85`](../../packages/core/lib/derive/impact.dart#L85)

- Exercise colliding group/instant inputs and pin both crossing record shapes.
  [`impact_test.dart:334`](../../packages/core/test/derive/impact_test.dart#L334)

**Layout and rendered copy**

- Reflow before measuring non-positive or non-finite caption candidates.
  [`dashboard_screen.dart:441`](../../lib/ui/dashboard/dashboard_screen.dart#L441)

- Prove the two-cell geometry and narrow constraint branch.
  [`dashboard_screen_test.dart:717`](../../test/ui/dashboard/dashboard_screen_test.dart#L717)

- Audit plain, rich, and semantic dashboard copy against denominator language.
  [`dashboard_screen_test.dart:314`](../../test/ui/dashboard/dashboard_screen_test.dart#L314)

**Contextual navigation and test seams**

- Keep the Album-only dashboard affordance and thread the controller unchanged.
  [`album_screen.dart:220`](../../lib/ui/album/album_screen.dart#L220)

- Verify Album keys remain distinct for same-pair entries with different offsets.
  [`album_screen_test.dart:309`](../../test/ui/album/album_screen_test.dart#L309)

- Verify a highlight pop reveals the existing visible Album route.
  [`dashboard_screen_test.dart:973`](../../test/ui/dashboard/dashboard_screen_test.dart#L973)

- Pin absence of the contextual affordance on Reward and Dispenser surfaces.
  [`reward_screen_test.dart:335`](../../test/ui/reward/reward_screen_test.dart#L335) · [`dispenser_screen_test.dart:7679`](../../test/ui/dispenser/dispenser_screen_test.dart#L7679)

**Evidence and coverage**

- Cover every singular/plural volume sentence and read-only append counter.
  [`dashboard_screen_test.dart:856`](../../test/ui/dashboard/dashboard_screen_test.dart#L856)

- Reconcile the manual row census and canonical second totals.
  [`7-4-the-cumulative-impact-dashboard.md:118`](7-4-the-cumulative-impact-dashboard.md#L118)
