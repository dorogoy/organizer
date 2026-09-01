# Epic 3 Context: The Floor — Capture by Hand or Voice

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Let the user put something into the app it could never have known about — a favour promised to a neighbour — in about ten seconds, typed or spoken, and then never see it again until it arrives as an ordinary dealt card. No list appears, no counter moves, nothing congratulates them. This epic covers FR-27 (Manual Capture) and FR-32 (on-device dictation into the capture line), and it is what makes Epic 4's degradation surface possible: the no-Slicer state's single exit (`Anotarlo`) routes to Manual Capture, so building the Slicer first would leave that surface nowhere to go.

## Stories

- Story 3.1: On-device recognition availability, verified on the handsets
- Story 3.2: Manual Capture — one line, three sizes, and a frame instead of a rule
- Story 3.3: The capture comes back as an ordinary card
- Story 3.4: Dictation into the capture line

## Requirements & Constraints

**Manual Capture surface**

- Reachable in one tap from the Dispenser via the Lápiz entry, top-right.
- Exactly two fields: one line of text and one size from exactly three options — `30 s` · `3 min` · `10–15 min`, shown as durations, never internal taxonomy names. Nothing else is asked: no project, category, date, priority, tags, recurrence, no confirmation screen.
- Non-spatial lines (`llamar al dentista`) are accepted in silence: no validation, no refusal, no error state, no corrective message — and no second version of the screen exists. The surface's copy says nothing about dates.
- `Guardar` stays disabled until the line holds text (a blank capture would put an irreversible empty card into circulation). One secondary only — `Descartar`, which is also the exit.
- Once the user leaves the surface, the capture cannot be corrected or discarded: it belongs to the pool, and the only path back to it is being dealt.
- On `Guardar`, a pool fact is inserted with origin `manual`, the chosen size, and an Origin Context consisting of its own single line and nothing more; a `capture_created` entry is appended.

**How the capture returns**

- The three sizes ARE the 1-3-5 taxonomy — no conversion step; the composition budget arithmetic holds unchanged.
- Captures take precedence over same-size Evergreen/Epic material, offered as candidates with precedence (never as deals — `core/weave` is the only emitter). Several pending captures of the same size deal oldest-first (FIFO), read from recorded act instants, never from id bit patterns.
- The deal window is three eligible days, expressed over the one `EligibleDay(item, day)` predicate — no second definition. An eligible day on which the capture was dealt (answered or skipped) consumes the window; skipping never extends it. On 🔴 days and days of absence the window freezes and resumes where it froze — there are no "expired" captures because the schema has no overdue.
- A pending 10–15 min capture is the day's Focus Chunk "1"; the day never holds a second large item beside it. No expiry and no cap on pending captures — silently deleting one would betray the trust the window protects.
- No screen lists, counts, filters or browses captured tasks, and the read facade exposes no function that could. A dealt capture is visually and tonally indistinguishable from a sliced one; its origin never reaches the Dispenser.

**Dictation**

- On-device recognition only, with no cloud fallback on any path — a fallback is how an undeclared egress destination arrives. Recognition uses `createOnDeviceSpeechRecognizer()` gated by `isOnDeviceRecognitionAvailable()` AND `checkRecognitionSupport()`: a service being available is not the Spanish model being present (`EXTRA_PREFER_OFFLINE` is only a hint and is insufficient).
- Dictation starts only on an explicit press; nothing listens outside it. The transcript lands in the existing one-line field on the existing surface — never a confirmation screen. The keyboard is never removed (corrections need it).
- One utterance = one task; the app does not split it. Nothing is ever parsed out of the transcript — a spoken duration is just words.
- No audio exists anywhere: not written to storage, not in the export, not in any series, not recoverable once the transcript exists.
- The microphone permission is requested at the first dictation attempt, never at app entry or first run. Refusal (or system-level revocation after grant) removes the affordance, appends `permission_refused`, and the app never re-asks on its own; reversal happens in Settings only, on a row that exists only while there is something to reactivate.
- Interruption (backgrounding, call, focus loss) yields nothing — no partial transcript, no error.
- When on-device Spanish recognition is unavailable, the affordance is simply absent: no error, no greyed-out state, no install offer, no language-pack pointer.
- A dictated capture's origin is `manual`, exactly as a typed one — dictation is an input method, not a genesis path. A separate per-capture dictation boolean is stored as a pool-fact field, readable on the validator surface (Settings) only, outside origin arithmetic.

**Recognition availability verification (Story 3.1)**

- Probe both `isOnDeviceRecognitionAvailable()` and `checkRecognitionSupport()` on each of the three validation handsets; record results per device. A handset reporting the service but not the Spanish model counts as unavailable.
- Availability is binary — no accuracy pass bar exists or is needed: poor accuracy is absorbed silently by the keyboard, which is never removed. Poor availability voids the accessibility floor's wordless-route claim (a promise about who can use the app) and is a finding to escalate, not a detail.
- The probe is a throwaway check outside the shipped app surfaces: no UI, no permission request at app entry, no dependency the app keeps.
- **Builder decision, 2026-09-01 (as executed in Story 3.1):** only the two adb-connectable handsets were probed (both returned AVAILABLE with `es-ES` installed); the third handset is field-use only and is never probed. The "three validation handsets" wording above reflects the planning docs (epics.md) as written before that decision — keep this note when regenerating this file.

## Technical Decisions

- Functional core / imperative shell; seven ports, dependencies pointing inward. This epic adds capture pool facts as a new candidate source into the resolver's candidate-precedence extension point — nothing else may emit a deal besides `core/weave`. Scaffold homes: `core/pool`, `platform/dictate`, `ui/capture`.
- Dictation runs over the hand-written Kotlin `dictate` channel (one of exactly three: notify, dictate, credentials) behind the `Recognizer` port. Plugin packages (e.g. `speech_to_text`) must not be wired for dictation: they expose neither on-device-forcing API, and no socket and no date arithmetic inside the channel.
- Both stores are insert-only, enforced by SQL triggers; the capture is a pool fact plus a `capture_created` log entry (log vocabulary is fixed, past-tense snake_case; a new kind is a new kind, never a flag).
- Origin is written once at creation and never updated; rescue steps inherit it; it never reaches the Dispenser.
- Core determinism: no `Random`, no wall-clock reads, no `dart:io`, no ambient state inside the core — FIFO ordering reads recorded act instants.
- minSdk 33 is set in part by `checkRecognitionSupport()` / `triggerModelDownload()` (API 33); the recognizer creator/availability pair is API 31.
- All copy lives in the single ARB string table — no literals; the seven authored Manual Capture strings go in verbatim and fixed strings are never re-worded.
- No network SDK enters the build; audio goes nowhere, to no one — the closed egress map gains no destination from this epic.
- The story completion gate is `flutter test` + `dart format --set-exit-if-changed .` + `flutter analyze` (one `make gate` target), run inside devbox; any new `tool/` check registers its Makefile target in the same pass.

## UX & Interaction Patterns

- The `size-option` pills: single-selection, always populated, no empty state, no "none of these"; selected is `accent-soft`, unselected is `surface-raised` with a 1px hairline; no option carries a glyph.
- The spatial frame's three-step ordering rule holds in the surface copy read in order: the title names a place (`Un rincón de la casa`), the helper lists things you can touch, the example opens with a spatial verb (`Vaciar la caja de la entrada`).
- The `microphone-glyph` capsule sits at the one-line field's end, 24px inside a 48dp tap target, line-only in `ink-primary` with the capsule as a registered mass at rest. The field placeholder names both modalities (`Escríbelo o dilo en voz alta`).
- Dictation state is declared in ink and prose — capsule mass turns `icon-mass-blue` and the caption `Escuchando…` appears — never by motion; animated states are banned.
- Settings reactivation rows follow the camera's unified pattern (row only while a reversal is possible); Settings stays a flat platform list.
- The 200% font-scale floor: nothing ellipsized or truncated — the surface grows and scrolls; every target ≥ 48dp.
- The mic/camera permission-refusal pattern is unified: entry visibility = enabled ∧ permission not refused.

## Cross-Story Dependencies

- 3.1 gates 3.4: availability is verified on real handsets before the microphone is built; it is binary and needs no pass bar.
- 3.2 writes the pool fact; 3.3 is purely about how the capture comes back — it cannot pass until 3.2's insert exists.
- Depends on Epic 1's substrate: the pool, the log, the resolver, the read facade and the ARB string table must all exist; a day only becomes "eligible" through sessions actually opened (Epic 1 opens a session on app entry), which is what the capture window counts.
- The deal window in 3.3 is expressed over Epic 2's `EligibleDay` predicate and its `warmReturnDue` sibling — one definition, owned upstream.
- Epic 4 depends on this epic: the honest-degradation surface's single exit (`Anotarlo`) is Manual Capture, and Rescue Mode later re-slices a manual capture's Origin Context (its own single line).
