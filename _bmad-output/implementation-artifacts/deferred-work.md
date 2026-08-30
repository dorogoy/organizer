# Deferred Work

- source_spec: `_bmad-output/implementation-artifacts/1-1-the-sealed-scaffold.md`
  summary: Harden CI — add devbox/download caching, timeout-minutes, concurrency cancel, commit-SHA-pinned actions, a top-level permissions block, and a `BOOTSTRAP_ANDROID=0` knob so the gate-only job skips provisioning the Android SDK it never uses.
  evidence: `.github/workflows/ci.yml` re-downloads the ~1 GB Flutter tarball and the full Android SDK on every run with no timeout or cancel-on-new-commit; actions are pinned by mutable tags while the repo sha256-verifies every tarball; the bootstrap header itself says the gate never needs the Android SDK, yet `make deps` in CI installs it.

- source_spec: `_bmad-output/implementation-artifacts/1-1-the-sealed-scaffold.md`
  summary: Make the NFR12 64-bit-only APK contract rerunnable — a `tool/` guard (registered per AC-13) that builds the debug APK and asserts its `lib/` holds exactly `arm64-v8a` and `x86_64`.
  evidence: `disable-abi-filtering=true` is the only thing keeping the Flutter Gradle plugin from re-adding 32-bit ABIs; today's verification is a one-time manual `unzip -l` noted in the story's Completion Notes, so a toolchain bump can silently regress NFR12 (Story 5.1's ML Kit precondition) with every gate green.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Add a `tool/` token-literal lint so "no literal colour/type/spacing/radius value outside `tokens.dart`" (UX-DR1) is machine-enforced like AD-15's string ban, not inspection-only.
  evidence: The story ships three lints (strings, text-scaling, audit); `Color(0xFF9EC3B5)`, a raw `fontSize: 26`, or `SizedBox(width: 24)` anywhere in `lib/` passes `make check` today — AC 1's "no literal duplicated elsewhere" rests entirely on review.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Fold `make check` into `make gate` (or have CI run both), and pin the Makefile's check registration with a test asserting every `tool/check_*.dart` is reachable from the `check` target (NFR20).
  evidence: The gate (NFR17) runs only test+format+analyze, so this story's three lints sit outside the completion gate; deleting a `check`-target line also ships silently — the tool tests invoke the scripts directly, never through the Makefile.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Cover every remaining TextTheme slot from TypeRoles (labelLarge, display/headline/label variants) so no widget resolving an unwired slot falls through to Material defaults.
  evidence: `OrganizerTheme._textTheme` wires eight slots; `Theme.of(context).textTheme.labelLarge` (buttons) still returns Material 2021 defaults — un-tokened sizes/weights the day a surface uses them.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Test the glyph ink guard-rails the comments claim — destination-trio equal mass weight and Reloj's 211.2u² note — via path-area computation on the authored geometry.
  evidence: `box_glyph.dart`/`clock_glyph.dart` cite mass-area figures ("2.5× the seed", "the row's raw ink guard-rail holds") but no test computes path areas, so a redrawn mass can drift past the equal-weight rule with goldens only catching gross changes.
- source_spec: `_bmad-output/implementation-artifacts/spec-1-2-remove-seed-motion-dashes.md`
  summary: Encode the zero-match dash-term gate as a `tool/` check wired into `make check`, following `tool/check_core_purity.dart`'s pattern.
  evidence: Review round 3: the "no dash term in lib/test/tool" invariant is a hand-run `rg` command, not a guard — a reintroduced lever (even defaulted off) would pass every existing check; the repo's established pattern for invariants is a tool/ scan registered under the Makefile's check target.
- source_spec: `_bmad-output/implementation-artifacts/1-3-the-insert-only-substrate.md`
  summary: Validate log-record shape at the core's read/parse boundary (Story 1.6): item-id/item-origin travelling as a pair, stack only on `crash_recorded`, kind-subtype consistency.
  evidence: Review round 1: `LogEntryRecord` (typedef) permits half-populated item references and off-kind payloads; writers today are only the crash path (always null/null + stack), but nothing validates records at write or read time — malformed rows would accumulate silently until derivations consume them. Schema-level CHECK/FK constraints were rejected deliberately (they would break AD-23's forward-only import tolerance), so the parse layer is the right home.

- source_spec: `_bmad-output/implementation-artifacts/1-4-one-calendar-authority.md`
  summary: The `energy_set` log vocabulary kind, energy-level storage, the port DTO growth and the check-in writer land in Story 2.5, together with the mapping from stored entries to `EnergyObservation` records and the Spanish ARB copy for the check-in surface.
  evidence: Story 1.4 ships only the pure day-scoped derivation `deriveEnergyForLivePool(observations, instantUtcMicros, offsetSeconds)` over inert `EnergyObservation` records — by the spec's Never clause there is no `energy_set` kind, no stored level and no writer anywhere today, so nothing maps persisted rows into the derivation until 2.5 adds them.
- source_spec: `_bmad-output/implementation-artifacts/1-4-one-calendar-authority.md`
  summary: Period arithmetic (adjacency, iteration, ordinals — "next day", "days between", week/season ordering) grows on the one `Calendar` with its first needing consumer (1.6 weave, 1.7 zone rotation, 2.6 SM-2), never beside it.
  evidence: Review round 1: consumers will need adjacency and distance math AD-4 reserves for the Calendar; nothing records where it lands, inviting exactly the ad-hoc boundary math the authority exists to prevent.
- source_spec: `_bmad-output/implementation-artifacts/1-4-one-calendar-authority.md`
  summary: Wire `make test-core` into the story-completion gate (or CI) so the gate trio cannot pass with the `packages/core` suite red.
  evidence: Review round 1: `make gate` runs root `flutter test` + format + analyze only; the core suite — where this story's entire verification lives — is reachable only through separately invoked `make test-core`, so a core-only regression passes the gate (Makefile structure predates this story).

- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-harden-evergreen-catalogue-integrity.md`
  summary: Epic 5 curation may expose only tuple-derivable anclas, sostén, z1–z5, and fondo; plantas and coche are permanently non-curatable authorial annotations unless a new approved catalogue evolution changes the contract.
  evidence: The four-field asset has no information that can reproduce the individual A12 plantas/coche annotations, while cadence, size, and zone derive the listed groups without a fifth field or a runtime projection.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-5-harden-evergreen-catalogue-integrity.md`
  summary: Epic 5 curation must prove every optional derivable group preserves the non-daily Focus floor or specify its below-floor fallback before it can ship.
  evidence: This integrity story has no curation implementation; an optional tuple-derived group can reduce the eligible pool even though its grouping itself is representable.
- source_spec: `_bmad-output/implementation-artifacts/1-6-the-1-3-5-weave-and-the-focus-chunk-slot.md`
  summary: Decide the durability story for multi-row lifecycle batches and detach-time appends — a transactional batch-append on StorePort or an accepted-loss contract — so process death cannot leave a session_started without its first card_dealt (which nextCard then renders deal-less, and answering records done-without-deal) or lose a session_ended on detach.
  evidence: Review round 1: SessionController._appendAll awaits record-by-record and the detached/hidden session_ended is only best-effort awaited; the crash path accepts the same loss for crash rows, but session rows feed every derivation (AD-19 day attribution) and no recovery derivation exists for an open session with no dealt card.

- source_spec: `_bmad-output/implementation-artifacts/1-6-the-1-3-5-weave-and-the-focus-chunk-slot.md`
  summary: Give pool-fact reads the same distinct-flaw surfacing log reads have (LogRecordFlaw) and test unknown origin/size tokens, when the first pool writer (Epic 3 capture) or restore (Epic 9) makes malformed pool rows possible.
  evidence: Review round 1: DriftStore.readPoolFacts silently drops rows with unknown origin/size tokens with no observable flaw, while log reads carry LogRecordFlaw discipline; nothing writes pool rows today, so the drop is unreachable except via hand-built databases.

- source_spec: `_bmad-output/implementation-artifacts/1-6-the-1-3-5-weave-and-the-focus-chunk-slot.md`
  summary: Decide whether a skipped Micro-maintenance or Instant Habit draw frees the day's draw slot (the mirror of AD-20's chunk-skip rule) before Story 1.10 wires the skip control.
  evidence: Review round 1: walkLog charges dealtCountsByDay at deal time regardless of the answer, so a skipped upkeep permanently consumes one of the day's 3/5 draws; neither the story, the spine excerpt nor the tests pin the intended reading.
- source_spec: `_bmad-output/implementation-artifacts/1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md`
  summary: Scope `LogFacts.answeredItemIds` by (itemId, origin) rather than bare id when the first second-origin writer (Epic 3 capture) or restore makes id collision across origins representable.
  evidence: Review round 1: the chunk tiers 1-2 exclusion reads a bare-id set while sibling facts (dealtUnanswered) carry the origin pair; catalogue ids are unique and captured items mint UUIDs today, so the collision is unreachable except via hand-built logs, but the fact type is the contract later sources consume.

- source_spec: `_bmad-output/implementation-artifacts/1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md`
  summary: Decide tier 2's membership contract for zone-less focus entries before the first capture writer (Epic 3) lands — today `fondo` is identified by `zone == null` on a focus candidate, so a captured focus item would enter the seasonal tier by construction.
  evidence: Review round 2: `_chunkCandidateOf`'s tier 2 reads `candidate.zone == null` over the shipped catalogue, where the only zone-less focus entries are seasonal; captures are expected to arrive focus-size with no zone, so without a decided contract (a capture cluster, an assigned zone, or an explicit tier exclusion) Epic 3's items would silently join `fondo` and consume its weekly slots.

- source_spec: `_bmad-output/implementation-artifacts/spec-1-7-review-fixes.md`
  summary: Decide whether `LogFacts.dealtUnanswered` should also hold a `card_dealt` recorded outside any open session — today the walk sets the fact only inside a session, so the AD-3 guards (the pipeline's and `nextDeal`'s) are blind to an out-of-session unanswered deal.
  evidence: Review round 2 (edge-case lens): `session.dart` sets `dealtUnanswered` only `if (openSessionStart != null)`, while out-of-session card acts are tolerated for totality; no command writes a deal outside a session, so the path is unreachable today — but the fact's session-scoping is now load-bearing for two guards instead of one, and Epic 2's derived-session work should confirm the scope deliberately.

- source_spec: `_bmad-output/implementation-artifacts/1-8-one-card-on-screen.md`
  summary: Add a boot-level shell test (factory or integration test) that executes main()'s construction — beyond the 1.8 source pins — so the shipped home cannot regress while `flutter test` stays green.
  evidence: Review round 1 (verification-gap lens): every test injects `DispenserController` through the seam; `main()` itself is never executed by any test, so dropping `dispenser:` or wiring a second `openStore()` ships a blank home with the full suite green (the 1.8 source pin catches the formatted substring only).

- source_spec: `_bmad-output/implementation-artifacts/1-9-hecho.md`
  summary: Make the two-row answer batch (`card_done` + bundled `card_dealt`) atomic at the store — a mid-batch append failure or process death can orphan the answer, after which `nextCard`'s resolver fall-through displays a card no `card_dealt` row backs and every later Hecho on it appends nothing (the core guard) while the ack still shows.
  evidence: 1-9 review (Edge-Case Hunter + Blind Hunter, converging): the store port exposes only single-row `appendLogEntry`, the core command returns the two rows as content and cannot recompute a lost deal after a partial append (`_answered` sees the landed `card_done` and returns `[]`), and `read_facade.dart:39-46`'s fall-through can surface the unanswerable card; fixing needs a design decision (batch port method or core command variant) outside 1.9's no-core-change boundaries.

- source_spec: `_bmad-output/implementation-artifacts/1-9-hecho.md`
  summary: Give `DispenserController.complete` and `SessionController`'s lifecycle writes one shared serialization (or pin the display invariant "only dealt cards are shown") — a backgrounding inside the ms-wide completion window can interleave `session_ended` between the answer and its bundled deal, stranding an orphan deal row beside a closed session.
  evidence: 1-9 review (Edge-Case Hunter): the two controllers hold separate `_lifecycle`/`_writes` chains over one store with no coordinator; the insert-only substrate tolerates the orphan rows but no test pins the display invariant the ack's truthfulness rests on; 1-9's read-gating on `_writes` narrows the window without closing it.

- source_spec: `_bmad-output/implementation-artifacts/1-10-the-unsplit-secondary-control-the-skip-half.md`
  summary: The two-row skip batch (`card_skipped` + bundled `card_dealt`) has no store atomicity — a mid-batch append failure orphans the answer row.
  evidence: Edge-case review of 1-10 (the skip append loop in lib/dispenser/dispenser_controller.dart): a failure on the second iteration leaves the skip recorded without its bundled deal, diverging day-budget and least-recently-dealt accounting; 1.9 deferred the identical card_done variant — needs a batch port or core command variant, outside 1.10's no-core-change boundary.

- source_spec: `_bmad-output/implementation-artifacts/1-10-the-unsplit-secondary-control-the-skip-half.md`
  summary: 1.9's `complete` ticking-clock test derives its mint expectation from the mint itself (rows == mints[1]), so a late mint in `complete` passes green.
  evidence: Verification-gap review of 1-10 fixed the identical self-referential flaw in skip's test (now captures the pre-skip minute); the pre-existing complete twin ("complete stamps the whole batch with the instant minted at entry") retains it — a mint moved after the store reads stamps a later tick unobserved.

## Deferred from: code review of 1-10-the-unsplit-secondary-control-the-skip-half (2026-08-30)

- Lifecycle writes can split a skip batch: `DispenserController` and `SessionController` use independent queues, so `session_ended` can land between `card_skipped` and its bundled `card_dealt`. This extends the deferred 1.9 shared-serialization issue and needs a coordinator or display-invariant decision outside the story boundary.

## Deferred from: manual handset validation of 1-10-the-unsplit-secondary-control-the-skip-half (2026-08-30)

- A lost pause-time `session_ended` wedges the Dispenser on the warm close with no escape: process death after backgrounding loses the row (the accepted trade-off, `session_controller.dart:119-122`), the next cold open's `sessionStart` no-ops while a session is open (`session_commands.dart:59-61`), and `anchorDayOf` keeps charging every composition to the dead session's start day — once that day's budget is exhausted, `nextDeal` returns null on every open and the user faces the exhausted-day close string with zero affordances. Extends the 1-6 durability deferral (which names the lost `session_ended` but not this wedge): needs either a self-heal on open (closing a stale open session, or a fresh-session derivation when the anchored day is exhausted) or a decided recovery contract. Evidence: real handset 2026-08-30 — `session_started` 01:17:34 opened bare (day already exhausted), the process died without `session_ended`, and the opens at 10:06:04 and 10:12:51 appended `app_opened` alone and rendered the close; only the 10:14:44 cycle, whose pause write survived, recovered (fresh `session_started` + first deal at 10:14:45), confirmed by extracting the substrate log from the device.
- source_spec: `_bmad-output/implementation-artifacts/1-11-proof-that-lateness-cannot-be-expressed.md`
  summary: Core package tests (including Story 1.11's proofs) sit outside `make gate` — root `flutter test` discovers only `test/`; deciding whether the canonical gate gains `test-core` is a policy change AGENTS.md owns.
  evidence: `make gate` runs `flutter test` at the repo root, which lists zero `packages/core/test` files (verified empirically 2026-08-30); core tests run only via `make test-core` or explicit paths, so a schema change that trips a core freeze ships green through the gate.
- source_spec: `_bmad-output/implementation-artifacts/1-11-proof-that-lateness-cannot-be-expressed.md`
  summary: Deferral-specific 04:00 domestic-boundary variant unpinned — a chunk deferred before vs after 04:00, and a session spanning 04:00 holding a deferred chunk.
  evidence: Story 1.11's deferred-chunk test crosses civil midnight only; the 04:00 slot/charging semantics are pinned in session_test and weave_test but not for the deferral scenario itself (review r2, blind-hunter).
