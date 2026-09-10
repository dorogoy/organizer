---
title: 'Preserve Protocol Automation Keys Under AD-15'
type: 'bugfix'
created: '2026-09-10'
status: 'done'
route: 'one-shot'
baseline_commit: 'd70ac97942afb8ac5ea9ba705ea0daa64dc825a0'
review_loop_iteration: 1
context:
  - 'project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** CI rejected six stable, string-valued Decluttering Protocol widget keys under AD-15. Replacing their values or exposing a new public key API would break established automation selectors or couple tests to production hooks.

**Approach:** Keep the exact `ValueKey<String>` identities, move their values into narrowly named private constants, and permit only those constants in the repository scanner. Protect the exemption with a regression test that proves visible widget copy remains forbidden.

## Boundaries & Constraints

**Always:** Preserve all six existing selector strings and keep the allowance scoped to the exact file and constant names. Continue rejecting rendered literal copy.

**Ask First:** Any change to selector values, key types, or AD-15's general policy.

**Never:** Add a broad file exemption, expose test-only production APIs, or weaken localization enforcement for widget text.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Stable selector | An allowlisted private protocol key ID | Scanner passes and the existing `ValueKey<String>` remains unchanged | N/A |
| Visible copy | A widget literal follows an allowlisted declaration | Scanner reports the widget literal at its own line | CI fails with an AD-15 finding |
| Wrapped declaration | An allowlisted declaration wraps before its literal | Only a previous line ending in `=` grants the allowance | Unrelated literals remain findings |

</frozen-after-approval>

## Code Map

- `lib/ui/destinations/decluttering_protocol_screen.dart` -- Owns the six stable protocol selectors.
- `tool/check_no_literal_strings.dart` -- Enforces AD-15 and its path-and-name-scoped infrastructure allowance.
- `test/tool/check_no_literal_strings_test.dart` -- Guards the exemption boundary against visible-copy leakage.

## Tasks & Acceptance

**Execution:**
- [x] `lib/ui/destinations/decluttering_protocol_screen.dart` -- Name the selector IDs without changing their values or key types.
- [x] `tool/check_no_literal_strings.dart` -- Add an exact allowance and tighten wrapped-declaration matching.
- [x] `test/tool/check_no_literal_strings_test.dart` -- Prove selector IDs pass while adjacent visible copy fails.

**Acceptance Criteria:**
- Given the story 6.2 protocol UI, when repository checks run, then no AD-15 finding is emitted for its six automation selectors.
- Given existing widget tests or automation consumers, when they use the established string keys, then all identities remain compatible.
- Given rendered literal copy in the protocol file, when the scanner runs, then the copy is still rejected with its correct line.
- Given the complete repository, when `make gate` runs inside devbox, then checks, tests, formatting, and analysis all pass.

## Spec Change Log

- Review iteration 1: rejected a public typed-key API because it changed established selector identity and coupled tests to production hooks; retained private string keys and narrowed the scanner exemption instead.

## Verification

**Commands:**
- `devbox run -- make gate` -- passed: repository checks, 94 eval tests, codegen freshness, 1146 Flutter tests, formatting, and analysis.

## Suggested Review Order

**Compatibility boundary**

- Preserves every existing string selector while satisfying named-constant enforcement.
  [`decluttering_protocol_screen.dart:16`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L16)

**AD-15 enforcement**

- Grants only six private constants in one exact production path.
  [`check_no_literal_strings.dart:64`](../../tool/check_no_literal_strings.dart#L64)

- Prevents unrelated next-line literals from inheriting wrapped declaration allowances.
  [`check_no_literal_strings.dart:519`](../../tool/check_no_literal_strings.dart#L519)

**Regression coverage**

- Proves automation IDs pass while visible protocol copy remains banned.
  [`check_no_literal_strings_test.dart:191`](../../test/tool/check_no_literal_strings_test.dart#L191)
