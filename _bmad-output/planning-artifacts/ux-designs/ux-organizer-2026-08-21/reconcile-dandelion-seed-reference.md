---
name: Reconciliation — dandelion-seed-reference.png
description: Accounts for every visual idea carried by the one user-supplied visual taken in during Discovery, and where each one landed in DESIGN.md.
status: final
updated: 2026-08-27
input: "imports/dandelion-seed-reference.png"
record: ".memlog.md · DESIGN.md · mockups/seed-at-scale-1.html · mockups/final-verification-1.html"
---

# Reconciliation — `imports/dandelion-seed-reference.png`

**Addendum — 2026-08-27.** This accounting is final as a record of the 2026-08-25 state; four of its findings were superseded by the blocker-resolution pass of 2026-08-27, all recorded in `DESIGN.md`. (1) The teal ink (claim 15, "dropped by silence… never argued down") was **considered and rejected** by the builder — "neither is to be re-litigated". (2) The taper (claim 8) likewise **considered and rejected** — one stroke width per render size stands. (3) The at-rest 64px trio seed (§3, "nowhere written down as a decision") is now **named and accepted knowingly** as a decision. (4) The motion-dashes lever (§3, "pulled nowhere") is now **assigned** — on at 56px and above, illustration register only; Warm Return is drawn with them at 168px, the permission-to-rest screen without them. The two in-place corrections this report calls for at its close ("12-filament reference" → 17; "dense (windward)" → leeward, *sotavento*) were paid in `DESIGN.md`. Nothing else in the accounting changed.

One visual was supplied by the builder during Discovery. Everything the session decided about the third destination glyph after that point was decided against this file. This report accounts for what happened to every idea the file carries — not to praise the outcome, but to make sure nothing was quietly dropped.

**Method.** The PNG was measured, not described from memory: 283 × 257 px, sRGB. The ink mask was thresholded at grey < 175, split into connected components, and the pappus was sampled on concentric circles about the convergence point at (159, 121) to count filaments, angular gaps and tip radii. Stroke widths were measured perpendicular to the stroke. Numbers below marked *(measured)* come from that pass; numbers marked *(record)* are quoted from `.memlog.md`, `DESIGN.md` or `.working/`.

**Two corrections to the record, established by that pass, before anything else:**

1. **The reference carries 17 filaments, not ~12.** The Discovery entry describes "a PAPPUS OF ~12 DISTINCT RADIATING CURVED FILAMENTS"; `DESIGN.md` line 356 repeats it as "the 12-filament reference". Sampling a circle at r = 45 px about the hub returns 18 ink crossings, one of which is the stem — 17 filaments, visually confirmed against an annotated overlay. Every measurement in `seed-at-scale-1.html` that compares the specified glyph to "the reference" (the 64/72 px size floor, the 1.144 u tightest pair, the 8.7 px tip gap at 96 px) is computed for a 12-filament fan, which is a drawing the builder never supplied. The decision itself does not change — 8 was chosen on legibility cues, not as a ratio of the reference — but **the sparseness gap is roughly twice as large as the record states**. See *Qualitative ideas at risk*.
2. **The reference carries 7 separate motion dashes, not "5–6".** Connected-component analysis returns 9 components: the seed body, 7 detached curved dashes, and one 1-px speck. `seed-at-scale-1.html` renders 5.

Neither correction reverses a decision. Both mean the spec's own description of its source is inaccurate, and that is worth fixing in place.

---

## 1. What the reference carried

Enumerated as claims. Nineteen distinct visual ideas are present in the file. (A 1-px dark frame runs around the canvas; that is a stock-crop artifact of the file, not an idea, and is excluded.)

| # | Claim | Evidence |
|---|---|---|
| 1 | **One whole seed, isolated** — a single detached seed, not a seed head, not a plant | one connected body; nothing else in frame but dashes |
| 2 | **A diagonal composition** — achene at lower-left, pappus upper-right, flight axis up-right | hub (159,121) → achene (68,214): chord at 45.6° above horizontal *(measured)* |
| 3 | **A dense pappus: 17 filaments** | 17 crossings at r = 45 px, stem excluded *(measured)* |
| 4 | **A one-directional swept comb over ~198° of arc**, not a radial umbrella | fan spans 211.5° → 49.1° in image coords *(measured)* |
| 5 | **Uneven angular spacing** — a density gradient across the fan | gaps range 7.0° to 17.1°; tightest cluster on the upper-left flank, widest along the up-right flight flank *(measured)* |
| 6 | **Uneven filament lengths, irregularly** — not a smooth envelope | tip radii jump non-monotonically: 90.0, 79.6, 95.9, 100.2, 99.0, 82.0, 96.5, 102.0, 83.1, 73.2 px by 5° bins *(measured)* |
| 7 | **Filaments curved, all bowing the same way** | every filament deviates from its radius in the same rotational sense *(measured)* |
| 8 | **Tapered, variable-weight strokes** | one filament: 5.53 px at r = 20 → 2.16 px at r = 90; another 3.26 → 1.15 px. Stem: 4.25 px at the achene → 2.0 px at the hub *(measured)* |
| 9 | **A solid dark knot where the filaments converge** | largest fully-dark disc at the hub r = 8 px, d ≈ 16 px, ≈ 8% of the drawing's width *(measured)* |
| 10 | **The achene is a filled solid**, not an outline | 848 contiguous ink px; no interior lightness anywhere in it *(measured)* |
| 11 | **The achene's proportions** — a shouldered teardrop, widest where the stem meets it, drawn to a fine point at the lower-left | thick core 47 px long × ≈ 28 px wide against a 102 px longest filament: ≈ 0.5–0.65 long, ≈ 0.27 wide, relative to a filament *(measured)* |
| 12 | **Achene and stem are one continuous form**, the stem slightly bowed, no joint | single unbroken ink path *(measured)* |
| 13 | **Motion conveyed by separate detached dashes** — 7 tapered crescents, none touching the seed | 7 independent components *(measured)* |
| 14 | **The dashes surround the seed, including ahead of it** — 3 above/right in the direction of travel, 1 upper-left, 1 left, 2 below | component bboxes *(measured)*. This reads as ambient air, not as a trail behind a moving object |
| 15 | **The ink is a saturated dark teal, not black** | `srgb(19,76,95)` ≈ `#134C5F`, identical in the achene fill, the stem, the filaments and the dashes *(measured)* |
| 16 | **No colour mass anywhere** — no second plate, no tint, no fill other than the one ink | histogram: ink, near-white ground, antialias between them; nothing else *(measured)* |
| 17 | **No gradient, glow, shadow or texture** | flat ink throughout *(measured)* |
| 18 | **A near-white ground, no field behind the mark, generous air** | ground `#FBFBFB`/`#FFFFFF`; ink is 5,455 of 72,731 px *(measured)* |
| 19 | **Illustration scale** — a drawing whose tightest detail is a few px across at ~200 px wide, undrawable small | tightest filament pair ≈ 7° apart at 100 px radius *(measured)* |

---

## 2. Where each one landed

**Adopted 10 · Adapted 5 · Dropped 3 · Unaddressed 1.** Two of the three drops happened by silence rather than by decision, which is called out where it occurs.

### Adopted

**1 · One whole seed, isolated — ADOPTED.**
This predates the reference and the reference confirmed it. The builder proposed "replacing the whole dandelion head with a SINGLE FLYING SEED, tilted to convey motion", and the record's assessment was that this is "semantically stronger, not merely simpler — the seed head is static, the seed in flight IS the release." The reference arrived later and settled that the seed had been the right object all along; what had been wrong was how it was reduced.

**2 · The diagonal, flight axis up-right — ADOPTED, and load-bearing.**
The 45° up-right tilt is what makes the whole icon system possible: "tilt the seed exactly 45 degrees up-right and its local axis coincides with a single GLOBAL screen offset vector (+1.358, −1.358) — one global vector serves the entire icon set." Worth recording as an observation the record does not make: **the reference's own diagonal is 45.6° (measured), which is closer to the ideal 45° than the specified geometry is.** The spec's stem runs A1 (6.350, 18.250) → H (12.400, 10.200) = 53.0°, an 8.0° deviation whose cost is priced honestly in `DESIGN.md` (perpendicular component 0.267 u, 13.9% of the offset magnitude). The reference would have paid nothing. Nobody compared the two angles.

**4 · The one-directional swept comb — ADOPTED.**
`seed-at-scale-1.html` constructs it explicitly: `theta(t) = 152° − 174°·(1−(1−t)^1.25)`, with the note "Los filamentos peinan todos en el mismo sentido. Ese peinado, y no el número, es lo que dice «va en el viento»." The sweep is 174° against the reference's 198° (measured) — narrower, and unremarked. The comb is one of the three cues `DESIGN.md` says survive at eight filaments, alongside the curved tip envelope and more filaments on one side.

**7 · Same-direction curved filaments — ADOPTED.** Reproduced by construction: `C1 = H + 0.32·L·dir + 0.08·L·perp`, `C2 = H + 0.68·L·dir + 0.30·L·perp`, max deviation ≈ 0.20·L. Every filament bows the same way, as in the reference.

**10 · The filled achene — ADOPTED, and it is the idea that corrected a definition error.**
This is the reference's single largest contribution to the spec. It arrived as an override, verbatim: *"SERGIO'S REFERENCE CONTRADICTS THE CLASS-2 DEFINITION, and the reference wins: the achene in imports/dandelion-seed-reference.png is FILLED. The seed was never line-only — it has always been line plus one small mass. Good news for the mixed row, bad news for the 'line-only' wording."* Independently verified in the same entry: drawn hollow it "reads as a loop dangling from a stick". Consequences that follow from this one observation:

- the illustration class could no longer be defined as line-only; `DESIGN.md` now states "Incidental small masses (the filled achene) are permitted in the illustration register — the reference image itself has one";
- it made the mixed row solvable at all, since the seed already had a mass to build on;
- it is one of the three cues that carry the glyph at the 36 px floor ("the one-way comb, the diagonal stem and the filled achene carry it").

The reference did not merely inform the spec here. It **falsified** a definition the session had already written and had already got the builder's blessing for.

**11 · The achene's proportions — ADOPTED, faithfully.**
The one place where a proportion check comes out clean. Reference: thick core 47 px long, ≈ 28 px wide, against a 102 px longest filament → ≈ 0.46 and 0.27 of a filament *(measured)*. Spec: 4.23 u long, 2.52 u wide, against L_max 8.561 u → 0.49 and 0.29. Within a few percent on both axes. This was not verified against the reference by anyone in the record; it happens to be right.

**12 · Achene and stem as one continuous bowed form — ADOPTED.** Spec: "tallo: cuadrática A1 → (8.900,13.500) → H, longitud 10.11 u", with the achene as two mirrored cubics at its foot. One form, slightly bowed, no joint — as drawn.

**17 · No gradient, glow, shadow, texture — ADOPTED**, and stated as a prohibition in both working artifacts and in `DESIGN.md`. Consistent with the reference, though it was already a house rule before the reference arrived.

**18 · Near-white ground, no field behind the mark — ADOPTED**, and reinforced by an unrelated decision: coloured destination tiles were dropped entirely ("hue lives only inside the glyph, so the two token levels never touch"), so the seed sits on `surface-base #F7F8F9` with nothing behind it. Consistent with the reference; not traceable to a decision *about* the reference.

**19 · Illustration scale — ADOPTED, and vindicated. This is the reference's second major contribution.**
The seed glyph had already been rejected once — *"La semilla no termina de convencerme de ningún modo."* The reference showed why, and the diagnosis entry is unambiguous: *"My brief to the renderer specified 'simplified silhouette, puff mass + stem, NO filaments' — which is precisely what Sergio did NOT want. The filaments are the point... This invalidates the basis on which the seed was rejected: he was shown a reduction that removed the feature he cared about."* The constraint that forced that reduction was then identified as the designer's own invention: *"the 24px constraint on the destination glyphs was MY ASSUMPTION, not a product requirement. The 3-Destination Flow is a full-screen, one-decision surface..."* Confirmed by pixel measurement afterwards: *"the previous attempt didn't fail as a drawing; it failed because it was drawn for 24px. The reframe was correct."* The trio is now specified at 64 px, with `{spacing.glyph-min}` 48 px as the interface minimum. **The reference's scale was right and the constraint was wrong**, and the record says so in those terms.

### Adapted

**3 · 17 filaments → 8, permanently, at every size — ADAPTED, with the largest single loss in this reconciliation.**
Settled by the builder's own hard rule, verbatim: **`Nunca añadir rasgos.`** Never add filaments. Eight, permanently, at every size — one drawing scaled, no fidelity ladder. The supporting measurements:

- eight is the floor for recognition: "six reads as a rake or a whisk, four as a sprout or an anchor";
- what distinguishes a dandelion seed from a starburst is not ray count but three cues — a curved tip envelope, a one-directional comb, more filaments on one side — and all three survive at eight;
- reduction *buys size*: 8 filaments drop the working floor from 64 px to 36 px;
- the rule is a **guard rail against regression**, paired deliberately with the raw total-ink metric: "the metric explains WHY someone would be tempted to fatten the pappus, and this rule forbids it outright."

The consequence is stated in the spec and accepted as intended, not tolerated: at 96 px the mean tip-to-tip gap is 13.5 px against 1.5 px lines, roughly 1:9 ink to air, so **the pappus reads as a comb, not a feather** — "the more graphic, stamp-like drawing suits the print register", and every filament is whole with its tip visible. That is a defensible aesthetic position, chosen with the trade in view.

What is *not* accurate is the size of the trade. `DESIGN.md` says the result is "visibly sparser than the 12-filament reference". Against 17 filaments: scaling the artifact's own measured mean tip gap (3.386 u at n = 8) inversely with count gives ≈ 1.59 u at n = 17, i.e. **≈ 6.4 px at 96 px against the specified 13.5 px**. The spec puts roughly twice as much air between tips as the reference does, not the ~55% more that "12" implies.

**5 · The density gradient — ADAPTED: the idea kept, the distribution replaced.**
The reference's spacing is irregular — 7.0° to 17.1°, with the tight cluster mid-arc on the upper-left flank *(measured)*. The spec replaces it with a monotonic closed form whose gaps decrease smoothly, 30.50° → 15.28°, so density increases steadily toward one end. The *presence* of a gradient is faithful; the shape of it is a function, not a drawing.

Two things to flag here, both traceable:

- The gradient is the **first cue to fail as the glyph shrinks** — "Failure order as it shrinks: the downwind density gradient (the cue that reads as *wind*) → the achene's spindle → the stem merging at the hub → the whole fan becoming one lobed mass." The cue that carries the wind is the one with the least margin.
- **A terminology conflict that will mislead an implementer.** `seed-at-scale-1.html` says "el espaciado angular se cierra hacia sotavento" and `final-verification-1.html` labels the tightest pair "par de sotavento" — the dense side is *leeward*. But the pompom-circle decision and `DESIGN.md` (frontmatter `mass-shape`, and line 352) both say "displaced off hub centre toward the **dense (windward)** side". The two words point at opposite ends of the same fan. The coverage constraint ("its entire free edge remaining under filaments") resolves it in practice, but the parenthetical should be corrected.

**6 · Uneven filament lengths — ADAPTED: the curved envelope kept, the irregularity dropped.**
Spec: `L(t)` is a two-branch power function, 8.60 u max at t = 0.40, 6.80 u at one end, 4.80 u at the other — a deliberate curved tip envelope, monotonic on each side, and one of the three cues held to be load-bearing. The reference's tip radii do not behave that way at all: they oscillate (95.9 → 100.2 → 99.0 → 82.0 → 96.5 → 102.0 → 83.1 px, measured by 5° bins). The section heading in the artifact is candid about the substitution: *"GEOMETRÍA DE LA SEMILLA FIEL (construida, no dibujada a ojo)"* — constructed, not drawn by eye. See *Qualitative ideas at risk*.

**9 · The solid dark hub knot — ADAPTED, and reoccupied rather than reproduced.**
The reference already has a small mass exactly where the filaments converge: a fully dark disc of d ≈ 16 px, ≈ 8% of the drawing's width *(measured)*. The spec puts a mass in precisely that place — but in hue, not ink: "a circle in the pompom hub, in `{colors.dest-trash}`, no stroke, under the line layer so the filaments cross over it". Nobody derived it from the reference; it was derived from hub coverage, and its virtues were argued on their own terms: a genuine mass rather than a tinted line, so it obeys the governing rule instead of needing an exemption; the hub is the widest part of the glyph so the hue can reach real presence; a circle has no axis so the axial/transverse failure cannot occur; at 8 filaments the gaps are wide enough for it to show through, "which IS the second-plate riso effect".

Scale divergence, unremarked in the record: the measured candidate is r = 1.70 u (d 3.40 u ≈ 0.40 of a filament length) and the builder's final instruction is **larger** than that, whereas the reference's knot is ≈ 0.16 of a filament length. So the specified disc is roughly 2.5× the reference's knot relative to the drawing, and in pastel rather than ink. The exact radius is the one number in the system deliberately left to draw time ("settled at draw time against the coverage rule", `DESIGN.md` Open Question 2).

**13 · Motion dashes — ADAPTED, not adopted straight, and the adaptation is better than the original idea.**
Measured behaviour: they "help at 56px and above, hurt at 36px and below (4px specks read as dirt and cost 19.4% extra ink for nothing)", and critically "they are NOT the element that survives longest — they persist as marks but stop meaning motion". Barred from the destination trio outright: "they leave the glyph's own area, collide with the neighbouring label, and contrast-weighted they push the seed to 122% of the box — the heaviest in a row that must be equal."

The real finding is inverse, and the record states it as such: **"REMOVING them turns the same illustration from 'arriving' into 'at rest'. That makes presence/absence of the dashes an expressive lever across surfaces rather than a fidelity setting."** That is a genuine upgrade on the reference's idea — the reference has one state, the spec has two. Count also reduced from 7 to 5 arcs (21.78 u of ink, 4.36 u mean), unremarked.

### Dropped

**16 · No colour mass anywhere — DROPPED. Replaced by a colour circle, and the chain is worth stating honestly.**
This was the reference's most distinctive quality and the spec does not keep it. The chain, in order:

1. The reference's arrival produced a two-class system, blessed by the builder: class 1 UI glyphs with masses and the offset; class 2 illustration, **line-only**, delicate, many strokes, large scale, exempt from the offset rule. The reference was class 2's exemplar.
2. Class 2 then failed on hue: *"Class 2 defined as LINE-ONLY cannot carry the hue: L\* 75.9 works as a fill, but inside a 1.5px line it is not a colour, it is a misprinted line."* Consequence in the mixed row: "two tinted offset glyphs and one that is neither, reading as 'the third one is missing something' or as disabled."
3. Measured rescues: the achene as the mass **failed** (6.15 u², only 7.8% of the box, "the hue reads as a pale sliver rather than colour"). A ghost-line copy — a second flat pass of the whole stroke in `dest-trash`, offset by the global vector — **worked**, but only at 8 filaments; at 12 "the ghost falls between neighbouring filaments and reads as double vision".
4. The builder then superseded the ghost line with his own solution: a circle in the pompom hub, displaced, under the line. It "dissolves the whole 'class 2 cannot carry the hue' problem rather than working around it", because it is a genuine mass and therefore needs no exemption.
5. That collapsed the class system: *"Because the seed now carries a real mass (the pompom circle) plus a filled achene, it is a CLASS-1 glyph with high line density — not an exempt class."* `DESIGN.md` records the honest form: **one class of mark at two line densities, not two classes.**

So the reference's "no colour mass anywhere" is not merely absent from the spec — it was tested, found unable to survive contact with a mixed row, and deliberately replaced. The exemption survives in one narrow place: a line-dominant illustration standing **alone** on a full-screen surface (the seven no-Slicer states, Warm Return, permission-to-rest, the scan wait), "where there is no row to match".

**15 · The dark teal ink — DROPPED, by silence.**
The reference's ink is `#134C5F` *(measured)*, a saturated dark teal used for every mark including the achene. The spec's line is `ink-primary #1E2124`, L\* 12.62, chroma 1.46 — effectively neutral near-black. The Discovery entry notices the teal ("pure line art in a single dark teal ink") and **nothing in the record ever discusses it again.** It was foreclosed by a rule set before the reference existed: "The line is near-black or grey ink; the mass is flat pastel. Pastel is ground or fill, never carries text. Ink stays dark." That rule may well be right — it is what satisfies the 200% font-scale floor by construction — but the reference's coloured ink was never weighed against it. **Unaddressed, and dropped as a side effect.**

**8 · Tapered, variable-weight strokes — DROPPED, by silence, and this is the most consequential unrecorded loss.**
Every stroke in the reference varies in weight: filaments 5.53 px at the hub to 1.15–2.16 px at the tips (a 2.5–4.8× taper), the stem 4.25 px at the achene to 2.0 px at the hub *(measured)*. The spec has **one** stroke width per render size — `stroke-width(u) = target_px × 24 / render_px`, target 1.5 px at 24 px — with round caps and joins. No entry in the 133-line record mentions taper, variable weight, or brush character. It is not a rejected idea; it is an unseen one. Its absence is what most separates the specified drawing from the file, because taper is what makes filaments read as *filaments* — thick where they are bundled, vanishing where they are hairs.

### Unaddressed

**14 · Where the dashes go — UNADDRESSED.**
The reference distributes its 7 dashes around the seed, three of them **ahead** of it in the direction of travel *(measured)*: this is air moving past a body, not a wake behind a projectile. The spec fixes their count (5), their ink (21.78 u), and one negative constraint ("no tocan la semilla" / never in the trio) — and says nothing about placement. Meanwhile the spec's substitute for motion inside the trio is the offset read as a *trail*, which is the opposite construction. Nobody compared the two readings.

---

## 3. Qualitative ideas at risk of being lost

This is the section the report exists for. Everything above is geometry; what follows is feeling and intent, where the record is thinnest and where the loss is real.

### The handmade quality — NOT preserved, and the spec says so in its own words

The reference is a drawing. Its filament lengths oscillate, its angular gaps run 7° to 17° with no pattern, its tightest cluster sits mid-arc where no formula would put it, and every stroke tapers. The spec replaces all of that with three closed forms — `theta(t)`, `L(t)`, and control points at fixed fractions of `L` — under a heading that states the substitution plainly: **"construida, no dibujada a ojo."** Add the fixed 8 filaments, the single global offset vector computed to `translate(1.358, −1.358)`, and the uniform stroke rule, and the honest verdict is:

> **The specified seed is more regular, more constructed and less handmade than the reference it came from.** It will read as a well-made vector mark. It will not read as something a person drew.

That is a defensible trade — regularity is what made the glyph measurable, parity-checkable and reproducible at 36 px — but it was never named as a cost anywhere in the record, and it is the cost the builder is most likely to notice first, because the file he supplied is the thing he was pointing at.

### The windblown asymmetry — PRESERVED in kind, and it is the strongest survivor

This one genuinely made it. The sweep is asymmetric by construction, the comb is one-directional, the tip envelope curves, lengths differ end to end, and the record identifies the comb rather than the count as the carrier of wind: "Ese peinado, y no el número, es lo que dice «va en el viento»." Two honest caveats: the density gradient is the **first cue to fail** as the glyph shrinks, so on the smaller surfaces the wind is the part that goes; and the direction of "the dense side" is stated two contradictory ways across the spec and the working artifacts (see claim 5).

### Something caught mid-flight rather than posed — PARTLY PRESERVED, and reversed exactly where it matters most

The reference is unambiguously mid-flight: 7 dashes, an achene trailing below and behind, a fan swept by air it is passing through. The spec disassembles the carriers of that feeling and reassigns them:

- **motion dashes: barred from the destination trio** (`DESIGN.md`: "No motion dashes in this row");
- **the offset carries motion instead** — "axial reads as a motion trail", which is why the 45° tilt exists.

Then set that against the spec's own inverse rule: *removing the dashes "turns the same drawing from arriving into at rest."* Following the spec literally, **the seed in the 3-Destination Flow — a 64 px mark, no dashes, on the app's single most important decision surface — reads as at rest.** The offset trail is a subtler substitute than 7 dashes, and the record never notices the collision between its own two statements. Whether "at rest" is wrong for `Tirar o soltar` is a legitimate design question (a settled seed is arguably the better metaphor for *letting go* than an arriving one) — but it is the **opposite** of the reference's feeling, it was arrived at as a by-product of ink-parity arithmetic rather than chosen, and it is nowhere written down as a decision.

Worse: the expressive lever is specified and then **never exercised.** `EXPERIENCE.md` names the four illustration surfaces (the seven no-Slicer states, Warm Return, the Anti-Marathon permission-to-rest screen, the scan wait) and does not assign dashes-on or dashes-off to any of them. The lever exists in the spine and is pulled nowhere.

### The delicacy of a thin single ink — PARTLY PRESERVED, and undercut three ways

The spec has a real mechanism for delicacy, and it is elegant: because stroke width is computed as `target_px × 24 / render_px`, the *same drawing* yields interface weight at 24 px and illustration weight at 150 px — "La delicadeza es un efecto de la regla, no un ajuste." Delicacy is a consequence of scale rather than a setting, which is exactly right.

Three things work against it:

1. **Uniform strokes.** Taper is most of what "delicate" means in the reference — hairs that vanish at the tip. A constant-width filament with a round cap is a *rod*, at any weight. (Claim 8, unaddressed.)
2. **A pastel disc under the hub.** The reference's delicacy depends partly on there being nothing but line; the specified glyph now has a colour mass at its densest point, larger relative to the drawing than anything the reference contains. This was necessary — the mixed row demanded it — but it is a change of material, not just of palette.
3. **The comb.** 1:9 ink-to-air at 96 px is airy, not delicate. Airiness and delicacy are different qualities; the spec chose the first, deliberately, and called it graphic and stamp-like. Fair. It is still not what the file feels like.

### One quality the record improved on rather than lost

Worth saying, because it is the honest counterweight: the reference has exactly one state. The spec turns the dashes into a two-state expressive register (`arriving` / `at rest`) and re-sites the whole mark from a 24 px assumption to a 48–64 px reality. Both are more than the reference asked for.

---

## 4. Verdict

**The reference survived as silhouette and grammar. It did not survive as a drawing.**

Everything structural came through: the single seed, the diagonal, the one-way swept comb, the curved tip envelope, the filled achene, the continuous stem, the achene's proportions to within a few percent, and — the reference's real victory — the scale at which the thing is allowed to be drawn. On two points the reference did not merely inform the spec, it **corrected** it: the filled achene falsified a class definition the session had already blessed, and the illustration scale exposed the 24 px constraint as the designer's assumption rather than a product requirement, which is what resurrected a glyph that had already been rejected.

Three things did not come through. **The single ink and the absence of colour mass were dropped for a reason that holds** — a hue at L\* 76 inside a 1.5 px line is a misprinted line, not a colour, and the mixed row broke; the builder's own displaced circle fixed it properly and collapsed a two-class system back into one class at two line densities, which is a better spec than the one it replaced. **The density was dropped by decision** — `Nunca añadir rasgos`, eight permanently, comb not feather, accepted as intended; the only fault here is that the record understates the gap because it counted 12 filaments in a file that has 17. **The taper and the teal were dropped by silence**, and those are the ones a future reader would never know had been there.

What a future implementer must open the PNG for, because the spec cannot tell them:

- **the taper** — how much thicker a filament is at the hub than at its tip, and the same for the stem into the achene. Nothing in `DESIGN.md` describes it.
- **the irregularity** — how unevenly real filament lengths and gaps sit. `L(t)` and `theta(t)` will produce a fan; they will not produce *this* fan.
- **the curvature near the hub** — how filaments leave the bundle before they bow, which is what makes the convergence read as a bundle rather than a pinch.
- **the achene's shoulder and point** — where the widest part sits relative to the stem, and how fine the lower-left tip goes.
- **the dashes** — their shape, their taper, and above all that three of them sit *ahead* of the seed. The spec fixes their count and their ink and says nothing about where they go.
- **the ink colour** — that the builder's mark was teal, not black. If the near-black ink ever comes up for review, this is the evidence that a coloured ink was the original intent and was never argued down.

Two corrections owed in place, both cheap: `DESIGN.md` line 356 says "12-filament reference" and should say 17; and `mass-shape` / line 352's "dense (windward) side" contradicts `sotavento` in both working artifacts and should be reconciled against the geometry.
