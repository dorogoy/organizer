---
title: 'PR 57 — redact credentials in crash stacks'
type: 'bugfix'
created: '2026-09-11'
status: 'done'
review_loop_iteration: 0
baseline_commit: '6b933ef74462e15048a4f60424d1aa998417662c'
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** AD-22 forbids provider plaintext on a crash event, and AD-12's `crash_recorded` stack is stored verbatim and will ride a future export. Jules' PR 57 (`sentinel/redact-crash-credentials-5844308500869457182`) adds persist-time sanitization, but it is behind `main`, unreviewed, and its tests never prove the persist chokepoint or the four allowlisted wires.

**Approach:** Land credential redaction on current `main` using Jules' chokepoint — `sanitizeStackTrace` inside `appendCrashEntry` before the store write. Cover OpenAI/OpenRouter Bearer `sk-…`, Anthropic `x-api-key` / `sk-ant-…`, and Gemini `x-goog-api-key` / `AIzaSy…`. Keep the crash type stack+timestamp; do not persist the exception object.

## Boundaries & Constraints

**Always:**
- The only secret-capable field on `crash_recorded` is `stack`. Sanitize that string in `appendCrashEntry` immediately before `store.appendLogEntry`. `installCrashGuard` still passes stack-only (`details.stack` / `stackTrace`), never `details.exception` / the platform `error`.
- Redact, in that stack string: `Bearer <token>`, `Authorization: <token>`, `x-api-key` / `x-goog-api-key` header values (`:` or `=`), query `api_key=` / `key=` / `token=` values, and standalone tokens matching `sk-` (20+ alnum/`_`/`-`) or classic Gemini `AIzaSy` + 33. Replacement is a named const (e.g. `[REDACTED]`). Surrounding frames stay.
- Pattern strings and the replacement token are `const String`s on `lib/crash.dart` and listed in `namedConstantAllowance` (AD-15). Do not import `lib/egress/` into `crash.dart`.
- Apply on current `main` (PR 57's base is stale). Jules' three-file shape is the starting patch, not a merge-as-is.

**Ask First:** None.

**Never:**
- Do not persist exception/error text, add crash fields, or change `CrashEntry` / `log_entries.stack` / convertLogEntryRecord.
- Do not add a logging SDK, print channel, or third store (AD-12).
- Do not reuse `tool/check_export_redaction.dart` as a stack sanitizer (it scans JSON **property names**, not `stack` values). Do not build Epic 9 export in this story.
- Do not put credentials in URLs in egress to "make redaction easier".

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| OpenAI Bearer in stack | `Bearer sk-proj-` + 24 alnum | `Bearer [REDACTED]`; frames around it kept | N/A |
| Anthropic header + `sk-ant-` | `x-api-key: sk-ant-` + 24 alnum | header value and standalone `sk-ant-…` both `[REDACTED]` | N/A |
| Gemini header + `AIzaSy` | `x-goog-api-key: AIzaSy` + 33 alnum | header value and standalone `AIzaSy…` both `[REDACTED]` | N/A |
| Query `api_key=` | URL with `?api_key=sk-` + 24 alnum | `api_key=[REDACTED]` | N/A |
| Clean stack | `#0      build (package:organizer/x.dart:9)` | byte-identical | N/A |
| Persist chokepoint | `appendCrashEntry` with a Bearer stack | stored `entry.stack` is the redacted string — not only a unit of `sanitizeStackTrace` | N/A |
| Flutter error with keyed exception | `installCrashGuard` + `FlutterErrorDetails(exception: StateError('Bearer sk-…'), stack: clean frames)` | one `crash_recorded`; stored stack has no `sk-` / `Bearer` plaintext (exception is not stored) | N/A |
| Null stack | `appendCrashEntry(store, null)` | non-empty current stack, still sanitized | N/A |
| Failing store | `_FailingStore` + dirty stack | swallow, no throw | swallowed |

</frozen-after-approval>

## Code Map

- `lib/crash.dart:17-69` — `installCrashGuard` (stack-only, keep) + `appendCrashEntry` (sanitize `resolvedStack` before the record). New: named pattern consts + `sanitizeStackTrace`. Do not import egress.
- `test/ui/crash_test.dart:40-126` — keep field-shape / swallow / null-stack / both handlers. Add matrix cases; one must go through `appendCrashEntry` and assert `store.entries.single.stack`.
- `tool/check_no_literal_strings.dart:67-190` — `namedConstantAllowance`; insert `'lib/crash.dart': {…}` after `'lib/catalogue/loader.dart'` (`:184-190`). Header comment `:50-66` should name crash redaction patterns (crash-path context, not widget copy).
- `lib/egress/byok_wire.dart:77-87,35-42,380-401` — **read-only evidence**: keys live in `Authorization`/`Bearer `, `x-api-key`, `x-goog-api-key`; URLs have no query key; `WireStatusException.toString` is `'wire status ' + status`. Copy header *shapes*, not the module.
- `lib/egress/byok_slicer.dart:80-90,207-210` — **read-only**: HTTP failures fold to `providerUnreachable` / `networkUnreachable` and do not hit the crash log. Redaction is still required: the stack field is an untyped string and a future dump must not leak.
- `lib/egress/provider_allowlist.dart:28-41,70-119` — **read-only**: four wires (`gemini`, `openai`, `anthropic`, `openrouter`).
- `packages/core/lib/log/log_entry.dart:241,452,1135-1174` — **read-only**: `CrashEntry` is stack + timestamp; convert copies `record.stack` with no transform.
- `lib/store/substrate.drift:114` + `lib/store/drift_store.dart:57,133` — **read-only**: `stack` TEXT copied verbatim.
- `packages/core/test/no_lateness_proof_test.dart:722-728` — **read-only**: CrashEntry field pin.
- `lib/vault/credential_vault.dart:69-73,206-239` — **read-only**: crash entry is a forbidden sink; plaintext is request-local.
- `tool/check_export_redaction.dart` — **do not extend** here (name scan, not stack values).
- Jules head `b25760a32bf7fe4b0d4a24b24f58d175bae43c9d` — starting three-file patch; rebase/re-apply onto current `main`, do not merge the stale base.

## Tasks & Acceptance

**Execution:**
- [x] `lib/crash.dart` — named pattern/replacement consts + `sanitizeStackTrace`; call it in `appendCrashEntry` on the resolved stack; leave `installCrashGuard` stack-only
- [x] `test/ui/crash_test.dart` — I/O matrix, including persist-chokepoint and Flutter keyed-exception (exception is not stored)
- [x] `tool/check_no_literal_strings.dart` — allow the new crash consts; mention them in the allowance header

**Acceptance Criteria:**
- Given a stack containing each of the four allowlisted credential shapes, when `appendCrashEntry` runs, then the stored `stack` has the secret replaced and neighboring frames intact.
- Given a Flutter error whose **exception** text holds a Bearer key and whose **stack** does not, when the installed guard records it, then the stored stack contains no credential plaintext (the exception is not copied in).
- Given a stack with no credential shape, when `appendCrashEntry` runs, then `stack` is unchanged.
- Given `make check`, then the new `lib/crash.dart` consts are allowed and no other AD-15 findings appear.

## Spec Change Log

## Design Notes

Jules' two-regex shape is enough if the first covers the three header names plus `Bearer`/`Authorization` and the query keys, and the second covers `sk-…` and `AIzaSy…`. `sk-ant-` / `sk-or-` / `sk-proj-` fall under `sk-[A-Za-z0-9_-]{20,}`. Prefer slight over-redaction of `key=` in a crash stack over a leak.

`check_export_redaction` would still pass a `"stack": "Bearer sk-…"` fixture — persist-time sanitize is the seal until Epic 9 exists.

## Verification

**Commands:**
- `devbox run -- flutter test test/ui/crash_test.dart` -- expected: matrix + existing crash tests green
- `devbox run -- make check` -- expected: AD-15 allows the new crash consts
- `devbox run -- flutter test && dart format --set-exit-if-changed . && flutter analyze` -- expected: story gate green (AGENTS.md)

## Suggested Review Order

**Persist-time chokepoint**

- Sanitize the resolved stack immediately before the store write, not at export.
  [`crash.dart:68`](../../lib/crash.dart#L68)

- Guard still passes stack only — exception/error objects never become the payload.
  [`crash.dart:17`](../../lib/crash.dart#L17)

**Credential shapes**

- Header/query group 1 keeps the prefix; group 2 is the secret; `[ \t]` will not eat the next frame.
  [`crash.dart:31`](../../lib/crash.dart#L31)

- Standalone `sk-…` and classic Gemini `AIzaSy`+33 catch dumps that never named a header.
  [`crash.dart:35`](../../lib/crash.dart#L35)

**AD-15**

- Pattern strings are named consts on the crash module, never widget copy.
  [`check_no_literal_strings.dart:194`](../../tool/check_no_literal_strings.dart#L194)

**Tests**

- Wire line `Authorization: Bearer <non-sk token>` proves the first regex, not the `sk-` pass.
  [`crash_test.dart:107`](../../test/ui/crash_test.dart#L107)

- Exception credential text is not stored; stored stack equals the clean frames.
  [`crash_test.dart:234`](../../test/ui/crash_test.dart#L234)
