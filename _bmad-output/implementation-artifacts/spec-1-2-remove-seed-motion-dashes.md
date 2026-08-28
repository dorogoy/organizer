---
title: 'Dissolve the seed glyph motion dashes (Story 1-2 amendment)'
type: 'feature'
created: '2026-08-28'
status: 'done'
review_loop_iteration: 2
baseline_commit: '38a54417717cede6cacd406bccac12ed6d7e9819'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The seed glyph carries a motion-dash lever (five loose arcs, a 56px threshold, an opt-out flag) whose only pinned rendering — the standalone 64px golden `seed_glyph_64px.png` — shows movement lines that no other seed image carries and no shipped surface uses. The human has dissolved the lever: the seed never shows movement lines.

**Approach:** Remove the motion-dash feature end-to-end (geometry constants, threshold, widget flag, dash tests), re-pin the 64px golden at rest, and amend `DESIGN.md`'s motion-dash decisions with a dated dissolution record so the future Warm Return surface (168px, previously "with motion dashes") draws the seed at rest.

## Boundaries & Constraints

**Always:**
- The seed is one drawing, scaled — at rest at every size, register, and surface; `linePaths` is always `[filaments, stem]`.
- `DESIGN.md` amendments are surgical and dated (2026-08-28): historical measurements stay readable as history; the normative rule becomes "never". The reference-PNG descriptions (line 280, reconcile doc) keep their measured facts untouched.
- All other seed geometry (pompom radius/displacement, filaments, achene, stem, axis correction), tokens, and the other nine glyphs are untouched.

**Ask First:** None — the full removal is itself the human decision (renegotiates `DESIGN.md` `{components.seed-glyph.motion-dashes}` and the Warm Return dashes-on illustration).

**Never:** No new flag, threshold, or register may reintroduce dashes. No edits to the done Story 1-2 spec (this spec is the record). No pompom/filament redraws.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Seed at any size | 24px–168px, light or dark | No dashes path; two line paths only | N/A |
| Call site passes `motionDashes` | Any | Compile error — parameter no longer exists | N/A |
| Glyph-set goldens re-run | All existing goldens | Every golden except `seed_glyph_64px.png` matches byte-identically (they were already at rest) | N/A |

</frozen-after-approval>

## Code Map

- `lib/ui/glyphs/seed_geometry.dart:45-49` -- `motionDashThresholdPx` + doc comment; delete.
- `lib/ui/glyphs/seed_geometry.dart:136-147` -- `motionDashArcs` (5 tuples) + doc comment; delete.
- `lib/ui/glyphs/seed_glyph.dart:12-30,77-84,101` -- class doc, `motionDashes` field, `dashesForSize`, `_dashes`, `dashesPath()`, the `if (_dashes)` conditional; delete all, `linePaths` becomes `[filamentPath(), stemPath()]`.
- `lib/ui/glyphs/glyph_canvas.dart:137` -- comment cites "the seed's motion-dash threshold" as a changing input; reword (inputs that don't appear in compared fields: the battery's level).
- `test/ui/glyphs/seed_glyph_test.dart:96-136` -- the threshold test and the 56px-floor testWidgets; delete both.
- `test/ui/glyphs/seed_glyph_test.dart:162-168` -- '64px — above the threshold, dashes on'; keep pumping bare `SeedGlyph(Spacing.glyphDestination)`, retitle to the at-rest meaning. Title must NOT say "illustration register" — 64px is `Spacing.glyphDestination` (the destination-flow size); the illustration register draws at 150–168px per `DESIGN.md`.
- `test/ui/glyphs/glyph_set_test.dart:318-328` -- trio seed `SeedGlyph(64, motionDashes: false)` → `SeedGlyph(64)`; reword the reason to what the assertion checks (the destination size renders two line paths), scoped to 64px — the 24–168px sweep (new task below) is what earns the every-size claim.
- `test/ui/glyphs/goldens/seed_glyph_64px.png` -- regenerate via `--update-goldens`; the only golden whose bytes may change.
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md` -- amend 6 spots, all dated 2026-08-28: `:206` (delete the `motion-dashes` token line); `:451` (destination-flow bullet still bars trio dashes via the deleted threshold — rewrite so no live bar remains; the trio at-rest consequence stands, now trivially); `:500` (comb bullet ends "The only palliative compatible with 'one drawing, scaled' is the motion strokes" — append that the palliative was dissolved with the lever; the comb trade stands unpalliated); `:502-503` (replace the threshold lever + at-rest-by-ink-parity rationale with the dissolution record; qualify "no other seed image" as "no other pinned Flutter golden" — the mockup page's dashes-on render is history); `:550` (Warm Return 168px draws at rest; mockup page stays as history); `:589` (Do/Don't row → "Never draw motion dashes — dissolved 2026-08-28 / reintroduce them at any size, register or surface" — keep "surface" in the Don't).
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/EXPERIENCE.md:282` -- live-tense "dashes-on is now reserved for the illustration register at 56px and above (`DESIGN.md`)" -- append the dated dissolution so both spine docs agree.
- `_bmad-output/planning-artifacts/epics.md:155` -- rule row 10 "Seed glyph: exactly 8 filaments, 45° axis, motion dashes only at ≥ 56px | 1.2, 6.3" -- annotate that the dash clause was dissolved 2026-08-28 (this spec).
- `_bmad-output/planning-artifacts/epics.md:2282` -- story 6.3's acceptance guidance reserves illustration-register dashes at ≥56px -- amend so 6.3's seed (Warm Return) draws at rest; a future builder following this row must not reinstate dashes.
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/mockups/seed-at-scale-1.html:236-238` -- the promoted supersession note: add a sixth superseded item (the dashes-on/dashes-off lever dissolved 2026-08-28; Warm Return's 168px dashes-on rendering is history, the seed draws at rest) and reword the "Current" paragraph's finding clause accordingly. The page body (dashes SVG, twelve filaments) stays — history, like the rest of the superseded geometry.
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/reconcile-dandelion-seed-reference.md:12` -- the 2026-08-27 addendum's item (4) states the dash rule live-tense ("is now **assigned** — on at 56px and above… Warm Return is drawn with them at 168px"). Append a dated 2026-08-28 postscript in the addendum's own supersession style: item (4)'s assignment is itself superseded — the lever is dissolved, the seed draws at rest. Measured facts (filament counts, dash counts) stay untouched.
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/reconcile-dandelion-seed-reference.md:174` -- quotes `DESIGN.md`: "No motion dashes in this row", a sentence the destination-flow rewrite deleted. Annotate dated: the quoted sentence was dissolved into the general at-rest rule on 2026-08-28; the bar it named is now subsumed.
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/review-rubric.md:70` -- the Mechanical-notes token-resolution claim still lists `components.seed-glyph.motion-dashes` among "all resolving" references — false since the token's deletion. Append a dated correction (2026-08-28: the motion-dashes token was deleted; the count and the zero-broken-claims apply to the pre-dissolution state).
- **Generic sweep (the task behind the Verification command):** after the enumerated spots, run `rg -n -i "motion[ -]?dash" _bmad-output/planning-artifacts/` and give every remaining live-tense survivor a dated 2026-08-28 supersession unless it is a preserved measurement, an already-dated record, or a historical quote clearly marked as such. The Code Map enumerates the known spots; the sweep is the guarantee no more escape.
- `test/ui/glyphs/goldens/glyph_set/seed_64_light.png` -- was already at rest; must keep passing unregenerated (proof the rendering change is dash-only).

## Tasks & Acceptance

**Execution:**
- [x] `lib/ui/glyphs/seed_geometry.dart` -- delete `motionDashThresholdPx` and `motionDashArcs` with their comments -- the lever's data
- [x] `lib/ui/glyphs/seed_glyph.dart` -- delete the flag, gate, static helper and `dashesPath()`; fix the class doc -- the lever's API
- [x] `lib/ui/glyphs/glyph_canvas.dart` -- reword the stale comment; final form: "inputs such as the battery's level change the paths without changing any compared field" (no dangling "one", no parenthetical)
- [x] `test/ui/glyphs/seed_glyph_test.dart` -- delete the two dash tests; retitle the 64px golden test (no "illustration register"); add a size-sweep test pinning the drawing's structure across 24–168px (spacing tokens plus 96/150/168, both brightnesses): `linePaths` 2, `inkFillPaths` 1 (the achene), `massPaths` 1 (the pompom) -- length alone would pass any two paths; the parts' identity pins the claim
- [x] `test/ui/glyphs/glyph_set_test.dart` -- drop the removed argument; reword the trio reason scoped to 64px
- [x] `test/ui/glyphs/goldens/seed_glyph_64px.png` -- regenerate with `--update-goldens`, then a plain run must pass; confirm no other golden changed (`git status`)
- [x] `DESIGN.md` (path above) -- the six dated amendments per Code Map; the primary dissolution record (the `:502-503` successor bullet) names this amendment spec as the renegotiation record, in the house style of "Paid into the PRD"; the Do/Don't Do cell keeps the full triple — every size, register AND surface (do not drop "surface" from the Do side)
- [x] `EXPERIENCE.md` (path above) -- dated dissolution annotation at `:282`
- [x] `epics.md` (path above) -- annotate rule row 10 (`:155`); amend story 6.3's guidance (`:2282`) so its seed draws at rest
- [x] `mockups/seed-at-scale-1.html` (path above) -- sixth supersession item + "Current" paragraph reword
- [x] `reconcile-dandelion-seed-reference.md` (`:12` postscript, `:174` annotation) + `review-rubric.md` (`:70` dated correction) -- per Code Map
- [x] Generic planning-docs sweep per Code Map -- zero live-tense survivors remain

**Acceptance Criteria:**
- Given the seed swept across 24–168px, when the painter renders at each size, then the drawing's structure is pinned (`linePaths` 2, `inkFillPaths` 1, `massPaths` 1) and the goldens (48px, 64px) match.
- Given the widget API, when code compiles, then no `motionDashes`/`dashesForSize`/threshold symbol exists anywhere on the compiled surface (`lib/ test/ tool/`); done story specs keep their historical text by design.
- Given `rg -i "motion[ -]?dash"` over `lib/ test/ tool/`, when run, then zero matches.
- Given the planning docs under `_bmad-output/planning-artifacts/` (spines, epics, mockup note, reconcile addendum, review rubric), when read, then no live-tense dash rule survives — only dated dissolution records, dated corrections and preserved history.
- Given `git status` after `--update-goldens`, when inspected, then exactly one image changed (`seed_glyph_64px.png`) and every other golden is byte-identical.
- Given `DESIGN.md`, when read, then the motion-dash rule reads as dissolved (2026-08-28), never, any register, any surface.

## Spec Change Log

- 2026-08-28 — Review loop 1 (bad_spec): the dissolution's documentation scope was under-enumerated. Live-tense dash rules survived in `DESIGN.md:451` (destination-flow bar via the deleted threshold) and `:500` (comb bullet's "only palliative" sentence), `EXPERIENCE.md:282`, `epics.md:155` (rule row 10) and `:2282` (story 6.3 guidance that would have a future builder reinstate dashes), and the seed-at-scale mockup's supersession note still promoted the dashes-on reading as current. The verification net was also under-specified: the `rg` pattern missed the space-separated form, matrix row "any size 24–168px" had no size-sweep test, and the 64px golden retitle was left free enough to allow the factual mislabel "illustration register size" (64px is the destination size; the register is 150–168px). Amended: Code Map, Tasks and ACs now enumerate every residual dash reference across planning docs and require the sweep; Verification's pattern is now `motion[ -]?dash` plus a planning-docs pass asserting only dated/historical mentions. Known-bad avoided: two contradictory normative rules inside `DESIGN.md`, and story 6.3 following stale epics guidance to redraw Warm Return with dashes. KEEP: the code-side removal shape (`linePaths` unconditionally `[filamentPath(), stemPath()]`, constructor reduced to `size` + `key`, every dash symbol deleted); the golden-regen procedure (only `seed_glyph_64px.png` may change bytes — every other golden byte-identical is the dash-only proof); the dated, history-preserving `DESIGN.md` amendment style.
- 2026-08-28 — Review loop 2 (bad_spec): the same class recurred — the Tasks enumerated spots while the Verification commanded an outcome, so survivors outside the enumeration passed every task yet failed the spec's own planning-docs gate. Real survivors: `reconcile-dandelion-seed-reference.md:12` (the 2026-08-27 addendum's item (4) states the threshold rule live-tense) and `:174` (quotes the now-rewritten destination-flow sentence), and `review-rubric.md:70` (the Mechanical-notes token-resolution claim still lists the deleted `components.seed-glyph.motion-dashes` as resolving — false since its deletion). Also under-specified: the sweep test asserted `linePaths` length only (any two paths would pass — the parts' identity is the claim), the Do/Don't Do cell dropped "surface" from the triple, the primary dissolution record named no governing spec (house style cites the record), the `glyph_canvas.dart` comment's "without changing one" lost its antecedent, and matrix row 3 (single-changed-golden) had no AC. Amended: Code Map adds the three doc spots plus a generic sweep task; Tasks prescribe the identity-pinning sweep assertions, the final comment form, the Do-cell triple, the record citation; ACs add the single-image and structure-pinned rows; Design Notes extend the supersession declaration to the story spec's `:74` task bullet and `:140` manual check. Known-bad avoided: a reader trusting a false token-resolution claim or a live-tense threshold rule inside the reconcile addendum; a future two-path substitution passing the sweep test. KEEP: everything from loop 1, plus the sweep-test shape (eight sizes × both brightnesses) and the epics/story-6.3 amendment wording.

## Design Notes

This amendment rides the still-open Story 1-2 PR (branch `dorogoy/1-2-both-palettes-the-glyph-set-and-the-single-string-table`); the story spec stays `done` and untouched — this file is the renegotiation record. The dissolution supersedes, in that story spec: the Design Notes "Motion-dash set" paragraph, the Always bullet's "≥56px motion-dash threshold" clause, the checked task bullet at `:74` ("…≥56px motion-dash threshold"), and the manual check at `:140` ("Visually inspect … and motion-dash threshold") — a future re-verification of the story reads those as superseded by this file, not as live requirements. Done story specs are historical records by design: the "no symbol anywhere" AC means the compiled API surface (`lib/ test/ tool/`), never rewriting shipped specs.

Strings inside `lib/`, `test/` and `tool/` (test names, reasons, doc comments) must not contain the dash term — that is the zero-match gate's intent; write "at rest" phrasing instead. The term survives only in planning docs, as dated history or dissolution records.

## Verification

**Commands:**
- `devbox run -- flutter test test/ui/glyphs/ --update-goldens` -- regenerates `seed_glyph_64px.png`; `git status` must show that golden as the only changed image
- `devbox run -- make gate` -- `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` all green
- `rg -i "motion[ -]?dash" lib/ test/ tool/` -- expected: no matches
- `rg -n -i "motion[ -]?dash" _bmad-output/planning-artifacts/` -- expected: only dated dissolution records, supersession annotations and preserved historical measurements -- no live-tense rule

## Suggested Review Order

**The removal itself** *(start here — the one decision)*

- The widget is always at rest; the constructor reduced to `size` + `key`
  [`seed_glyph.dart:14`](../../lib/ui/glyphs/seed_glyph.dart#L14)

- The unconditional line layer — filaments and stem, nothing else
  [`seed_glyph.dart:77`](../../lib/ui/glyphs/seed_glyph.dart#L77)

- The landmark where the threshold and arcs used to live, now clean
  [`seed_geometry.dart:45`](../../lib/ui/glyphs/seed_geometry.dart#L45)

- The `shouldRepaint` comment keeps its cited input list true
  [`glyph_canvas.dart:137`](../../lib/ui/glyphs/glyph_canvas.dart#L137)

**The closing gates**

- The structure sweep: 8 sizes × 2 palettes, parts pinned by bounds and colour
  [`seed_glyph_test.dart:134`](../../test/ui/glyphs/seed_glyph_test.dart#L134)

- The regenerated golden — 64px, the destination size, at rest
  [`seed_glyph_test.dart:125`](../../test/ui/glyphs/seed_glyph_test.dart#L125)

- The trio's seed, now bare `SeedGlyph(64)` with the scoped reason
  [`glyph_set_test.dart:320`](../../test/ui/glyphs/glyph_set_test.dart#L320)

- The one image this change was allowed to touch
  [`seed_glyph_64px.png`](../../test/ui/glyphs/goldens/seed_glyph_64px.png)

**The paper trail** *(every planning doc, dated 2026-08-28, history kept readable)*

- The primary dissolution record, citing this spec in "Paid into the PRD" style
  [`DESIGN.md:501`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md#L501)

- The destination-flow bullet: the bar dissolved, the at-rest consequence stands
  [`DESIGN.md:451`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md#L451)

- The illustration register: history first, then the normative at-rest state
  [`DESIGN.md:548`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md#L548)

- The Do/Don't row carrying the full size-register-surface triple
  [`DESIGN.md:587`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md#L587)

- The seed-choice paragraph's superseded dashes-on reservation
  [`EXPERIENCE.md:282`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/EXPERIENCE.md#L282)

- Rule row 10 annotated — no future story treats the clause as live scope
  [`epics.md:155`](../../_bmad-output/planning-artifacts/epics.md#L155)

- Story 6.3's Warm Return seed draws at rest; reinstatement barred
  [`epics.md:2282`](../../_bmad-output/planning-artifacts/epics.md#L2282)

- The reconcile addendum's postscript, in its own supersession style
  [`reconcile-dandelion-seed-reference.md:14`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/reconcile-dandelion-seed-reference.md#L14)

- The dangling DESIGN.md quote annotated as subsumed
  [`reconcile-dandelion-seed-reference.md:176`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/reconcile-dandelion-seed-reference.md#L176)

- The rubric's token-resolution claim, corrected for the deleted token
  [`review-rubric.md:70`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/review-rubric.md#L70)

- The mockup note's sixth supersession item — the page is history twice over
  [`seed-at-scale-1.html:238`](../../_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/mockups/seed-at-scale-1.html#L238)
