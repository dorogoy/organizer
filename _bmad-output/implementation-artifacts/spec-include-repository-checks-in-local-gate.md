---
title: 'Include Repository Checks in the Local Gate'
type: 'chore'
created: '2026-09-10'
status: 'done'
route: 'one-shot'
---

# Include Repository Checks in the Local Gate

## Intent

**Problem:** The local `make gate` target omitted the repository-wide `make check` suite, so local completion validation could pass while CI failed on build-time invariants.

**Approach:** Compose `make check` into `make gate` before the existing Flutter test, format, and analysis commands, update the target description, and remove CI's redundant standalone check while preserving its catalogue baseline.

## Suggested Review Order

- The target description names the complete local gate contract.
  [`Makefile:101`](../../Makefile#L101)

- The recursive check invocation aligns local validation with CI's build-time invariants.
  [`Makefile:102`](../../Makefile#L102)

- CI supplies the catalogue comparison baseline to the unified gate and avoids running checks twice.
  [`.github/workflows/ci.yml:37`](../../.github/workflows/ci.yml#L37)
