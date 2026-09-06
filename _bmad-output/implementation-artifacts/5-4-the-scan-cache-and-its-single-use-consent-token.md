---
title: 'Story 5.4: The scan cache and its single-use consent token'
type: 'feature'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 0
baseline_commit: '55f209aa47f0f838800a6771ae6610c40a1b3e28'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** AD-8's compile-time precondition does not exist yet: the scan request/payload shapes (`ScanSliceRequest`, `ScanImagePrompt`) carry image bytes and a prompt and nothing else, so today's code can ask for an upload no one consented to; the scan cache subdirectory has one sanctioned file (the frame) where AD-8 declares at most two (frame + capped copy) and no crash backstop; and `consent_granted` exists in no vocabulary. All invisible while nothing uploads — all load-bearing the moment 5.5–5.6 ship the first scan payload.

**Approach:** Land a core-pure `ScanConsent` — private constructor, one sanctioned minter binding the scan's `scanId`, one-way consumption — as a **required field** of both scan shapes, so absence cannot compile at any seam; the dispatch consumes the token on the scan path so the cap runs inside the binding; the `Files` port grows, additively, the capped-copy write and a blind `sweepScanCache()` run at every `app_opened`; and `consent_granted` lands as a payload-less **user-act** moment with a single sanctioned minter — instrumentation only, carrying no capability.

## Boundaries & Constraints

**Always:**
- The precondition is compile-time by construction: `ScanSliceRequest` and `ScanImagePrompt` each gain a required `ScanConsent` field. No runtime consent branch exists anywhere (no `hasConsent` boolean, no nullable-token-then-assert); the test suites' own compilation is the proof.
- The token binds to the scan's cache subdirectory identity (the `scanId` segment), is minted only through the single sanctioned core minter, and is consumable exactly once. Consumption is a one-way transition performed by `EgressDispatch.send`'s scan branch before the cap — one token authorizes one dispatch entry, burned even when the cap rejects (no retry exists; terminal by design). A second consumption is a `StateError` thrown **outside** the send's catch arms: a programmer error propagates raw, never wearing an `EgressFailed` or `SlicerFailureCause` costume.
- The capped copy's slot is one fixed extension-free name beside `frame.jpg` — the sniff is the mime truth (5.3), the name claims nothing. A scan's subdirectory holds at most the two sanctioned names **by construction**: only the two scan methods can target a subdirectory, and flat `write(scope, name)` cannot compose a nested path.
- Both files die with the scan: `unlinkScan` (signature untouched) is the every-terminal-path instrument; the two-file state → unlink → directory gone is pinned.
- The sweep is a blind mass-unlink of the `scan_cache` scope's children — it names nothing to any caller, so the port vocabulary still grows no listing, search or watch. It runs at **every** `app_opened` (launch and each resume), awaited at the start of the open's queued step, quiet on every error: a backstop may never break an open. Safe because every terminal path and lifecycle close already unlink — a standing child at open is by definition a crash leftover.
- `consent_granted` is a payload-less user-act moment (the spine's naming table lists it under user acts): single sanctioned minter in `scan_commands.dart`, contact for warm return (the user was actively using the app — the opposite register of `face_refused`/`permission_refused`), assigned its set in the same pass that adds the kind. The row carries no scanId and no capability; the token is never persisted, never exported (no serializer touches it; the wire body is built from bytes and prompt only), never reconstructible from the log.
- Mint ordering — after the on-device face gate, before the resolution cap — is the caller's contract (5.5 wires the mint into the flow); 5.4 ships the machinery and the pins that make the contract observable, with **zero production mint callers** (census-pinned; renegotiated additively when 5.5 lands the consent act).
- Core stays pure, egress stays sealed, substrate untouched (payload-less kind, no schema change), and every gate runs inside devbox.

**Ask First:**
- Anything growing the egress import seal's allowlists, adding an eighth degradation string, or reshaping `writeScanFrame`/`unlinkScan` (AD-23: additive only — twin method, not a generalized rewrite).
- Any change to the consumption-failure semantics (raw `StateError`).
- Any wiring of the mint, the capped-copy write, or a consent surface into the live scan flow — that is 5.5/5.6 scope.

**Never:**
- No consent UI, no settings surface, no blanket "always allow" anywhere (FR-25) — not even disabled; the settings censuses stay green untouched.
- No upload path becomes reachable: the gate-pass branch keeps its quiet close, `scan_controller.dart` is untouched, no payload leaves the device from this story.
- `scan_abandoned` (5.6's kind) is not added here. No ARB/l10n strings, no manifest, Gradle or pubspec change. No `==`/`hashCode`/`toString` overrides on the token (identity semantics; nothing leaks the binding).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Mint | sanctioned minter, clean scanId | Token bound to that scanId, unconsumed | N/A (caller contract; the adapter stays the enforcing edge for writes) |
| Scan shape without token | any construction site | Does not compile — no runtime path exists | Compile-time (AC1) |
| send, scan shape, fresh token | dispatch entry | Cap runs, transport once, capped rebuild carries the same token, token consumed | Cap/transport failures → `EgressFailed` exactly as 5.3 |
| Second send, same token | consumed token reused | `StateError` propagates raw out of `send` | Never `EgressFailed`, never a `SlicerFailureCause` |
| Cap rejection, fresh token | malformed input | `EgressFailed(malformedInput)` pre-transport as today; token burned — terminal, no retry | Unchanged 5.3 behavior |
| Rescue/genesis shapes | no token involved | Behavior byte-identical; no consent field on them | N/A |
| writeScanCappedCopy | clean scanId, bytes | Atomic write to `scan_cache/<id>/<cappedName>`, absolute path returned | N/A |
| writeScanCappedCopy, dirty scanId | traversal-shaped segment | Writes nothing, returns `absentFramePath` | Quiet refusal, never a crash |
| unlinkScan, two files present | frame + capped copy | Whole subdirectory gone; idempotent | Quiet (unchanged) |
| Sweep, crash leftovers | stale subdirs + stray files | Every child of the scope unlinked, scope dir itself remains | Quiet on every error |
| Sweep, scope missing | fresh install | No-op, quiet | N/A |
| Every app open | launch and each resume | Sweep runs exactly once per `app_opened`; never on background/end | Quiet failure folds into nothing |
| Null files seam | SessionController without files | No sweep, everything else unchanged | The optional-seam convention |
| consent_granted row | minter invoked | Exactly one payload-less row → `MomentEntry`; warm return counts it contact | Read boundary validates as a moment |

</frozen-after-approval>

## Code Map

<!-- Anchors are baseline-relative (55f209a, post-5.3); expect drift in landed files. -->

- `packages/core/lib/ports/scan_consent.dart` -- NEW: the type (private ctor, `scanId` getter, `consume()` one-way, no `==`/`toString`, not const) + the single sanctioned minter `mintScanConsent({required scanId})` + AD-8 docs.
- `packages/core/lib/ports/slicer_port.dart` -- `ScanSliceRequest` :42-51 gains `final ScanConsent consent` (required) — the app's upload seam (`SlicerPort.slice`); the other two shapes untouched.
- `packages/core/lib/ports/files_port.dart` -- header :7-14 (no listing — the sweep must stay blind), `writeScanFrame` :49-57 (doc hands the invariant and sweep to 5.4); gains `writeScanCappedCopy(scanId, bytes) → String` and `sweepScanCache() → Future<void>`.
- `packages/core/lib/log/log_entry.dart` -- kinds :86-102 + `knownByName` :105-123 + `_isMoment` :621-624 + `MomentEntry` :198; `consentGranted` joins as payload-less moment.
- `packages/core/lib/derive/warm_return.dart` -- `_isUserAct`'s `MomentEntry` arm (only `sessionEnded` today) gains `consentGranted` → contact; doc :36-40 states the same-pass rule.
- `packages/core/lib/commands/scan_commands.dart` -- `faceRefused()` :33-51 the pattern; gains `consentGranted()` — the kind's single sanctioned minter.
- `lib/egress/egress_payload.dart` -- `ScanImagePrompt` :25-33 gains required `consent`; AD-8 doc.
- `lib/egress/egress_dispatch.dart` -- `send` :56-72: scan branch consumes the token **before** the cap and outside the catch arms; capped rebuild :65 carries the token; doc :44-50 already reserves exactly this.
- `lib/egress/byok_slicer.dart` -- `_payloadOf` :102 threads `consent` through; wire untouched (token never serialized).
- `lib/files/app_files.dart` -- `scanCacheScope` :20 (doc already says "and, from 5.4, its capped copy"), `scanFrameFileName` :26; gains `scanCappedCopyName` + the two methods; dart:io's one home (store seal).
- `lib/session/session_controller.dart` -- `installSessionController` :20-40 / ctor :57-64 gains optional `FilesPort` seam (null = test seam); `handleAppOpen` :108-128 gains an awaited, quiet sweep at the start of the queued step.
- `lib/main.dart` -- `AppFiles()` :37 threaded into `installSessionController` :78.
- `tool/check_no_literal_strings.dart` -- :125-128 allowlist grows `scanCappedCopyName` (infrastructure identifier, the 5.2 pattern).
- Tests to renegotiate: `packages/core/test/ports_test.dart` :103-111 (ports census 7→8); `packages/core/test/log_test.dart` :63-82 (kinds 17→18 + `knownByName` length); `packages/core/test/no_lateness_proof_test.dart` :1097 frozen-shape census, :1896-1973 single-minter pattern, :2062 iteration; `packages/core/test/warm_return_test.dart` (user-act set pins); `packages/core/test/scan_commands_test.dart`; `test/egress/egress_dispatch_test.dart` (8 `send` sites :27-200, census :162-189); `test/egress/byok_slicer_test.dart` (~11 scan sites :600-864); `test/files/app_files_test.dart` (5.2 group :155+); `test/session/session_controller_test.dart`; NEW `packages/core/test/scan_consent_test.dart`.
- Read-only: `lib/scan/scan_controller.dart` (the mint's future home — untouched); `tool/check_egress_imports.dart` (the seal stays green untouched — the core type imports cleanly into egress); `lib/vault/credential_vault.dart` :206-240 (request-scope precedent); `Makefile` :44-60,101-104 (gates).
- Planning anchors: `ARCHITECTURE-SPINE.md` :92-96 (AD-8 verbatim), :225 (naming — `consent_granted` a user act), `epics.md` :1935-1973 (the story's ACs).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/ports/scan_consent.dart` -- NEW: `ScanConsent` (library-private constructor, `scanId` getter, `consume()` that flips once and throws `StateError` after, no equality/toString overrides, not const) plus the single sanctioned minter `mintScanConsent`, with AD-8's full contract in the library doc -- the capability exists only as this type
- [x] `packages/core/lib/ports/slicer_port.dart` -- `ScanSliceRequest` gains `final ScanConsent consent` as a required field with the AD-8 doc; the union's other two shapes untouched -- the port seam cannot be asked for a scan upload without a minted consent
- [x] `lib/egress/egress_payload.dart` -- `ScanImagePrompt` gains the same required field; doc states the compile-time precondition and that the token never serializes -- the chokepoint's scan shape is sealed the same way
- [x] `lib/egress/egress_dispatch.dart` -- scan branch: consume the token before the cap, outside the try arms (raw `StateError` on reuse); the capped reconstruction carries `consent` alongside; rewrite doc :44-50 to the fulfilled contract -- the cap provably runs inside the binding
- [x] `lib/egress/byok_slicer.dart` -- `_payloadOf` threads the consent field into the payload; nothing else changes -- the port and the chokepoint agree by construction
- [x] `packages/core/lib/ports/files_port.dart` -- add `writeScanCappedCopy` (twin of the frame write: atomic, absolute path back, quiet empty-string refusal) and `sweepScanCache` (blind mass-unlink, idempotent, quiet); update the header's no-listing doc so the sweep is explicitly named as not-a-listing; retire `writeScanFrame`'s "5.4's to govern" note -- the invariant is now governed
- [x] `lib/files/app_files.dart` -- `scanCappedCopyName` (fixed, extension-free, doc: the sniff is the mime truth) + `writeScanCappedCopy` mirroring the frame write's staging/rename/dirty-refusal path + `sweepScanCache` (list children, recursive delete each, scope dir remains, FileSystemException quiet) -- the cache's mechanics complete, dart:io stays in its one home
- [x] `tool/check_no_literal_strings.dart` -- allowlist gains `scanCappedCopyName` beside the 5.2 identifiers -- the audit stays meaningful
- [x] `packages/core/lib/log/log_entry.dart` -- `consentGranted` kind, `knownByName` row, `_isMoment` member, docs naming it a payload-less user act -- the vocabulary grows additively (AD-23)
- [x] `packages/core/lib/derive/warm_return.dart` -- `MomentEntry` arm of `_isUserAct` returns true for `consentGranted` (contact), doc updated per the same-pass rule -- a consented scan is the user using the app
- [x] `packages/core/lib/commands/scan_commands.dart` -- `consentGranted()`: exactly one payload-less content row, the kind's single sanctioned minter, doc stating instrumentation-only and no-capability (AD-8/FR-26 b) -- no second writer can appear silently
- [x] `lib/session/session_controller.dart` -- optional `FilesPort` seam on the controller and installer; `handleAppOpen`'s queued step begins with an awaited `sweepScanCache`, failures quiet -- the backstop runs at every open, never breaking it
- [x] `lib/main.dart` -- thread the standing `AppFiles` instance into `installSessionController` -- the composition root wires the one real adapter
- [x] `packages/core/test/scan_consent_test.dart` -- NEW: binding (minted scanId is the token's scanId), once-ness (consume flips; second consume throws `StateError`), no-leak surface (no `==`/`toString` override exists to override — pinned by behavior), unconsumed default -- the type's whole contract
- [x] `packages/core/test/ports_test.dart` + `log_test.dart` + `no_lateness_proof_test.dart` + `warm_return_test.dart` + `scan_commands_test.dart` -- censuses to 8 files / 18 kinds, frozen shapes, single-minter pins for `consentGranted`, `knownByName` length, user-act set, minter row shape -- every census names 5.4 in its comment
- [x] `test/egress/egress_dispatch_test.dart` -- mint at all scan sites; NEW pins: token consumed on the scan path (second `send` throws raw `StateError`), cap-rejection burns the token and stays pre-transport `EgressFailed`, rescue/genesis need no token, three-shapes census green -- the precondition and its once-ness are pinned end to end
- [x] `test/egress/byok_slicer_test.dart` -- mint at the ~11 scan sites; taxonomy legs still `malformedInput`; recorded wire bodies carry no consent trace -- the port-to-wire thread is proven
- [x] `test/files/app_files_test.dart` -- capped-copy path shape/atomicity/dirty-refusal/cross-scope isolation; two-file state unlinked whole by `unlinkScan`; sweep removes stale subdirs and stray files, leaves the scope dir, quiet on missing -- the cache lifecycle is pinned
- [x] `test/session/session_controller_test.dart` -- sweep fires on launch open and on resume, never on background/end; null seam = no sweep -- the backstop's trigger is exact
- [x] Gate -- `make gate` + `make check` green inside devbox, seals untouched

**Acceptance Criteria:**
- Given the scan request and payload shapes, when any construction site is inspected, then a `ScanConsent` is a required field at every seam — the suites compile only with a minted token, and no runtime consent branch exists anywhere in the diff (AC1, AD-8).
- Given a freshly minted token, when the dispatch's scan path runs, then the token is consumed exactly once before the cap, the capped reconstruction carries the same binding, and a reused token throws a raw `StateError` that no taxonomy folds (AC2).
- Given a scan's cache subdirectory, when its reachable states are enumerated by test, then only the frame and capped-copy names exist in it, and `unlinkScan` removes the two-file state whole (AC3, AC4 mechanics; the terminal-path wiring is 5.5/5.6's, riding the same unlink).
- Given a crash between minting and resolution, when the app next opens (launch or resume), then the sweep has unlinked every cache child, quietly, without breaking the open (AC5, NFR14).
- Given the diff, when the seals are inspected, then `writeScanFrame`/`unlinkScan` and every pre-existing capability are untouched, the ports census is the story's only structural growth, and `make check` is green with no allowlist change but the literal-audit identifier (AC6, AD-23).
- Given the `consent_granted` row, when its power is examined, then it is payload-less, minted only by its single sanctioned minter, counted contact as a user act, and reconstructs nothing: no token surface is persisted, serialized or logged (AC7).
- Given the app's settings surfaces and censuses, when they run, then they are untouched and green — no consent preference exists, and none may be added as a convenience (AC8, FR-25).

## Spec Change Log

## Design Notes

- **Why a required field, not a `send` parameter.** `send` serves three shapes; rescue and genesis are not consent-bearing (AD-8's token binds to a scan cache identity that only scans have — the rescue path is in production today and must keep working token-free). A required field on both scan shapes makes absence a compile error at every layer the request travels (port → payload → dispatch), which is strictly stronger than one parameter on the innermost function; and `SlicerPort.slice` is the upload function application code can actually call — `EgressDispatch.send` has no caller outside `lib/egress/` (pinned by the factory census).
- **One token = one dispatch entry, not one success.** Consuming before the cap means a malformed-input rejection burns the token. That is correct: nothing retries (the module's own doc), so a burned token on a failed send guards nothing — but it makes the rule total and un-testable-around: no path exists where a token survives contact with `send`.
- **The mint ships without a production caller, deliberately.** The gate-pass branch's quiet close is 5.5's to replace with the consent act; wiring a mint now would log `consent_granted` with no consent surface — a privacy decision the user never made. The census pins zero production mint sites; 5.5 renegotiates it additively, exactly as `NoSlicerCause.consentDeclined` and the consent-gate strings shipped in 4-5 ahead of their caller.
- **`consent_granted` is contact; `face_refused` is not.** The spine's naming table (:225) lists it among user acts. The non-contact precedents are refusals and crashes — the user turning away or the system failing. Granting consent mid-scan is the user actively using the app; if the process dies between consent and slice, the 48 h clock should reflect that use. `warm_return.dart`'s own doc requires the set assignment in the same pass that adds the kind.
- **The sweep is blind by design.** The port's founding doc bans a listing from the vocabulary; a mass-unlink that returns `void` and names nothing preserves that — callers cannot enumerate what they cannot see. Awaited at the queued step's start so it completes before the open releases the queue (a new scan needs a human's tap; the ordering note is recorded, not a lock).
- **Capped-copy name carries no mime claim.** 5.3 established the sniff as the single mime truth; the capped copy may re-encode to JPEG or PNG, so an extension would be a second, lying truth. Extension-free, like the invariant: two names, both sanctioned, both dying with the scan.
- **A standing child at open is not always a crash.** The scan surface deliberately holds a scan open through a transient occlusion (inactive→resumed — e.g. a notification shade pulled mid-shoot), so a standing child at the next sweep can also be a live scan, not only a crash leftover; the sweep unlinks both alike, fail-closed — the direction AD-8's every-`app_opened` sweep mandates — and the departure-cancels policy that would keep such a scan's own files alive is 5.6's to govern (recorded in the sweep docs; deferred-work entry filed separately).

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests including the updated censuses)
- `devbox run -- make check` -- expected: green with no seal edits (egress imports, store seal, core purity, literal strings + the one new identifier, string-table audit, forbidden vocabulary)

**Run evidence:**
- `devbox run -- make gate` -- exit 0: flutter test all passing (947 root tests), `dart format --set-exit-if-changed .` clean, `flutter analyze` no issues.
- `devbox run -- make check` -- exit 0: all seals green (core purity, no-literal-strings, text scaling, string-table audit, forbidden vocabulary, store seal, catalogue floor/id-diff/evolution, wire contracts, export redaction, egress imports, gradle dependencies, android manifest), eval suite green, codegen fresh.
- `devbox run -- make test-core` -- exit 0 (core suite all passing, 636 tests).
- All three re-run green after the review round 1 patches (gate grew 943 → 947 root tests with the new census/field/boundary/lifecycle pins; core suite 632 → 636).

**Manual checks (if no CLI):**
- None — no surface renders from this story; the committed suites are the evidence.

## Suggested Review Order

**The token — AD-8's capability made a type**

- The capability itself: private constructor, scanId binding, one-way consumption, no leak surface.
  [`scan_consent.dart:44`](../../packages/core/lib/ports/scan_consent.dart#L44)

- The single sanctioned minter; mint ordering is the caller's contract (5.5 wires it).
  [`scan_consent.dart:79`](../../packages/core/lib/ports/scan_consent.dart#L79)

**The compile-time precondition**

- The port seam: no scan request can be constructed without a minted consent.
  [`slicer_port.dart:68`](../../packages/core/lib/ports/slicer_port.dart#L68)

- The chokepoint's scan shape, sealed identically — the token never serializes.
  [`egress_payload.dart:49`](../../lib/egress/egress_payload.dart#L49)

- Consumption before the cap, outside the catch arms — reuse throws raw StateError.
  [`egress_dispatch.dart:72`](../../lib/egress/egress_dispatch.dart#L72)

**The cache lifecycle**

- The second sanctioned name: extension-free, because the sniff is the mime truth.
  [`app_files.dart:34`](../../lib/files/app_files.dart#L34)

- The capped-copy write — the frame write's twin: atomic, quiet refusal on dirty segments.
  [`app_files.dart:321`](../../lib/files/app_files.dart#L321)

- The blind sweep, honestly documented: crash leftovers and occlusion-held scans alike.
  [`app_files.dart:376`](../../lib/files/app_files.dart#L376)

- The port's additive growth, with the no-listing discipline restated for the sweep.
  [`files_port.dart:85`](../../packages/core/lib/ports/files_port.dart#L85)

**The backstop wiring**

- Awaited at every open's queued step start, quiet on every error, never on background.
  [`session_controller.dart:161`](../../lib/session/session_controller.dart#L161)

- The composition-root pin — deleting `files: files` from main fails this test.
  [`app_test.dart:225`](../../test/ui/app_test.dart#L225)

**Instrumentation, not capability**

- The kind: payload-less, additive, the eighteenth — no schema change.
  [`log_entry.dart:108`](../../packages/core/lib/log/log_entry.dart#L108)

- The row's single sanctioned minter; the token itself never reaches any log.
  [`scan_commands.dart:61`](../../packages/core/lib/commands/scan_commands.dart#L61)

- Contact, not absence: a granted consent is the user actively using the app.
  [`warm_return.dart:100`](../../packages/core/lib/derive/warm_return.dart#L100)

**The pins**

- Once-ness end to end: second send throws raw, transport still called exactly once.
  [`egress_dispatch_test.dart:56`](../../test/egress/egress_dispatch_test.dart#L56)

- The census the story promised: zero production minters, exactly one consumer.
  [`no_lateness_proof_test.dart:2191`](../../packages/core/test/no_lateness_proof_test.dart#L2191)

- The mint validates nothing — the adapter is the refusing edge, pinned.
  [`app_files_test.dart:340`](../../test/files/app_files_test.dart#L340)

- The sweep matrix: leftovers, fresh install, idempotence, refused-delete survival.
  [`app_files_test.dart:367`](../../test/files/app_files_test.dart#L367)

- The observer-driven trigger, both gating directions of the departure flag.
  [`session_controller_test.dart:854`](../../test/session/session_controller_test.dart#L854)

- The 48 h boundary for the new contact kind, on the suite's own clock discipline.
  [`warm_return_test.dart:163`](../../packages/core/test/warm_return_test.dart#L163)
