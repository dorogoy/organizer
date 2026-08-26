---
name: Anti-Overwhelm Mobile Task Organizer
description: Visual spine for a single-user Android household task dispenser. Dusty pastels on a cool near-white ground, rescued from the wellness register by printed-matter iconography. Product naming is deferred.
status: final
updated: 2026-08-26
sources:
  - "{planning_artifacts}/prds/prd-organizer-2026-08-20/prd.md"
  - "{planning_artifacts}/prds/prd-organizer-2026-08-20/addendum.md"
colors:
  # ---- FIELD TIER · palette "Aliento" at its own baseline lightness ----
  surface-base: '#F7F8F9'
  surface-raised: '#FFFFFF'
  ink-primary: '#1E2124'
  ink-secondary: '#5C6368'
  border-hairline: '#E1E5E8'
  accent-soft: '#D5E0DC'
  # ---- ICON-MASS TIER · every mass at L* 76.0 ----
  dest-keep: '#9EC3B5'
  dest-donate: '#BCB8D4'
  dest-trash: '#D9B2B6'
  icon-mass-neutral: '#B3BEBA'
  icon-mass-ochre: '#CAB9A0'
  # ---- DARK MODE · hand-authored, never an inversion ----
  surface-base-dark: '#1B1E20'
  surface-raised-dark: '#24282A'
  ink-primary-dark: '#ECEAE4'
  ink-secondary-dark: '#99A0A3'
  border-hairline-dark: '#343A3D'
  border-strong-dark: '#2A2F31'
  accent-soft-dark: '#313E3B'
  dest-keep-dark: '#7A9A8E'
  dest-donate-dark: '#8683A6'
  dest-trash-dark: '#98937E'
typography:
  task:
    fontFamily: 'Lora'
    fontSize: '26sp'
    fontWeight: '500'
    lineHeight: '1.32'
    letterSpacing: '0'
  duration:
    fontFamily: 'Lexend'
    fontSize: '15sp'
    fontWeight: '500'
    lineHeight: '1.40'
    letterSpacing: '0.01em'
  action-primary:
    fontFamily: 'Lexend'
    fontSize: '19sp'
    fontWeight: '600'
    lineHeight: '1.00'
    letterSpacing: '0.01em'
  action-secondary:
    fontFamily: 'Lexend'
    fontSize: '15sp'
    fontWeight: '400'
    lineHeight: '1.35'
    letterSpacing: '0.01em'
  support:
    fontFamily: 'Lexend'
    fontSize: '13sp'
    fontWeight: '400'
    lineHeight: '1.45'
    letterSpacing: '0.02em'
  # ---- THREE ROLES THE FIVE-ROLE RAMP DID NOT HAVE · added by the key-screens pass ----
  screen-heading:
    fontFamily: 'Lexend'
    fontSize: '19sp'
    fontWeight: '600'
    lineHeight: '1.25'
    letterSpacing: '0.01em'
  metric-numeral:
    fontFamily: 'Lexend'
    fontSize: '19sp'
    fontWeight: '500'
    lineHeight: '1.15'
    letterSpacing: '0.01em'
  caption-warm:
    fontFamily: 'Lexend'
    fontSize: '15sp'
    fontWeight: '400'
    lineHeight: '1.45'
    letterSpacing: '0.01em'
rounded:
  DEFAULT: '14px'
  full: '9999px'
  thumb: '4px'
spacing:
  base: '4dp'
  chip-to-task: '8dp'
  action-gap: '12dp'
  card-padding: '24dp'
  screen-margin: '24dp'
  task-to-actions: '32dp'
  destination-row-gap: '32dp'
  touch-target-min: '48dp'
  glyph-destination: '64px'
  glyph-min: '48px'
  glyph-dense: '36px'
  glyph-zone-marker: '24px'
  photo-pair-gap: '16dp'
# ---- FORMATS · project extension of the design-md spec token table ----
formats:
  short-date: 'day without leading zero + non-breaking space + three-letter lowercase Spanish month, no period, no year — 12 ago · 4 ago · 28 jul'
  duration: 'value + non-breaking space + unit, units s / min / h, largest unit first, no leading zeros, en dash for a range — 30 s · 3 min · 10–15 min · 4 h 25 min'
components:
  dispenser-card:
    ground: '{colors.surface-base}'
    background: '{colors.surface-raised}'
    border: '1px solid {colors.border-hairline}'
    radius: '{rounded.DEFAULT}'
    shadow: 'none'
    padding: '{spacing.card-padding}'
    side-margin: '{spacing.screen-margin}'
    air-around: 'minimum 48dp plus flex — never a fixed value'
  duration-chip:
    background: '{colors.accent-soft}'
    foreground: '{colors.ink-primary}'
    typography: '{typography.duration}'
    radius: '{rounded.full}'
    position: 'eyebrow, above the task text'
    gap-to-task: '{spacing.chip-to-task}'
  size-option:
    use: 'the three-size picker in Manual Capture — the only selector in the app'
    typography: '{typography.duration}'
    radius: '{rounded.full}'
    min-height: '{spacing.touch-target-min}'
    gap: '{spacing.action-gap}'
    selected-background: '{colors.accent-soft}'
    selected-border: '1px solid {colors.accent-soft}'
    selected-foreground: '{colors.ink-primary}'
    unselected-background: '{colors.surface-raised}'
    unselected-border: '1px solid {colors.border-hairline}'
    unselected-foreground: '{colors.ink-primary}'
    glyph: 'never — the no-glyph-inside-accent-soft rule holds here'
    selected-dark: '{colors.accent-soft-dark}'
  action-primary:
    label: 'Hecho'
    background: '{colors.accent-soft}'
    foreground: '{colors.ink-primary}'
    typography: '{typography.action-primary}'
    radius: '{rounded.DEFAULT}'
    min-height: '{spacing.touch-target-min}'
    contrast: '11.96:1'
    gap-above: '{spacing.task-to-actions}'
  action-secondary:
    label: 'Otra más fácil / Ahora no'
    background: 'none'
    foreground: '{colors.ink-secondary}'
    typography: '{typography.action-secondary}'
    border: 'none'
    underline: 'none'
    maxLines: 'unset'
    ellipsize: 'none'
    min-height: '{spacing.touch-target-min}'
    gap-above: '{spacing.action-gap}'
  action-equal-pair:
    use: 'the per-scan consent gate, and only there'
    recommended-action: 'none — this surface has zero, by construction'
    layout: 'one row, both children flex 1 1 0, identical width'
    gap: '{spacing.action-gap}'
    background: '{colors.surface-raised}'
    border: '1px solid {colors.border-hairline}'
    foreground: '{colors.ink-primary}'
    typography: '{typography.action-primary}'
    radius: '{rounded.DEFAULT}'
    min-height: '{spacing.touch-target-min}'
    fill: 'none — accent-soft is expelled from this component entirely'
    dark-mode: 'surface-raised-dark ground, 1px border-hairline-dark, ink-primary-dark label'
    residual: 'reading order cannot be made symmetric; Enviar sits in the unfavourable first slot'
  destination-flow:
    background: '{colors.surface-raised}'
    tile: 'none'
    glyph-size: '{spacing.glyph-destination}'
    row-gap: '{spacing.destination-row-gap}'
    label-ground: '{colors.surface-raised}'
    label-ink: '{colors.ink-primary}'
    keep-mass: '{colors.dest-keep}'
    donate-mass: '{colors.dest-donate}'
    trash-mass: '{colors.dest-trash}'
  destination-mark-dark:
    background: '{colors.surface-raised-dark}'
    edge-bar: '6px'
    hairline: '1px solid {colors.border-hairline-dark}'
    foreground: '{colors.ink-primary-dark}'
    keep-bar: '{colors.dest-keep-dark}'
    donate-bar: '{colors.dest-donate-dark}'
    trash-bar: '{colors.dest-trash-dark}'
  icon-glyph:
    line: '{colors.ink-primary}'
    mass-default: '{colors.icon-mass-neutral}'
    mass-layer: 'under the line layer'
    stroke-width: 'stroke-width(u) = target_px × 24 / render_px — target 1.5px at 24px'
    offset: 'translate(1.358, -1.358) in a 24 viewBox — 8% of rendered size, 45° up-right, one global vector'
    min-axial-extent: '8u measured along the offset vector'
  seed-glyph:
    filaments: '8, at every size, permanently'
    achene: 'filled, {colors.ink-primary}'
    mass: '{colors.dest-trash}'
    mass-shape: 'circle in the pompom hub, displaced off hub centre toward the leeward (dense) side, sized as large as coverage permits'
    mass-layer: 'under the line layer'
    offset: '{components.icon-glyph.offset}'
    axis: '45.0 degrees up-right — set equal to the global offset vector so the transverse component is exactly 0'
    motion-dashes: 'only where the seed is drawn at 56px or above; never at glyph scale, never in the destination trio'
    interface-minimum: '{spacing.glyph-min}'
  zone-marker:
    glyph: 'Hoja'
    size: '{spacing.glyph-zone-marker}'
    line: '{colors.ink-secondary}'
    mass: '{colors.icon-mass-ochre}'
    typography: '{typography.support}'
  photo-frame:
    use: 'the Before/After reward (FR-17) and the Transformation Album'
    aspect: '3:4'
    radius: '{rounded.DEFAULT}'
    thumb-radius: '{rounded.thumb}'
    border: '1px solid {colors.border-hairline}'
    ground-while-loading: '{colors.surface-base}'
    loading-motion: 'none — no spinner, no shimmer, no gradient'
    label-position: 'outside the frame, never over the image'
    pair-gap: '{spacing.photo-pair-gap}'
    dark-mode: 'surface-base-dark while loading, 1px border-hairline-dark'
  dashboard-highlight-row:
    use: 'the album highlights inside the FR-23 density exception, and nowhere else'
    columns: '3 at default font scale'
    gap: '{spacing.action-gap}'
    thumb-aspect: '{components.photo-frame.aspect}'
    thumb-radius: '{rounded.thumb}'
    caption: '{typography.support}'
    date: '{formats.short-date}'
    reflow: 'to one column per row as soon as a caption would break beyond two lines'
    known-degradation: 'unreflowed at 200% the columns fall to ~101dp and captions break to 4-5 lines'
---

## Brand & Style

This is an anti-overwhelm household task dispenser: one Android phone, one user, no account, offline by default. The product's whole promise is that nothing piles up, so the visual system has one job before any other — **the screen must not add weight**. The user opens this app depleted, at 21:50, after a day that already asked too much. Everything below follows from that.

The register was set by the builder in three words: *simple, sin complicación, limpio, cálido* — simple, uncomplicated, clean, warm. That lands the palette in dusty, powdery pastels, which is also exactly where every wellness and habit app in the category already lives. The antidote is not a different palette; it is a different **drawing language**. The pastels stay soft; the iconography is **printed matter** — risograph misregistration, a flat colour plate slipped off its line plate, sitting under the ink. Softest colour register paired with the most graphic mark-making. That collision is the brand.

Two rules carry the identity, and both are checkable rather than tasteful:

1. **The line is dark ink; the mass is flat pastel; the mass sits under the line.** Ink is always dark, always legible, and never scales with decoration. This satisfies the PRD's 200% system-font-scale floor by construction rather than by testing.
2. **The colour plate is misregistered on purpose**, on one global vector, at a proportion of icon size — never a fixed dp value.

Product naming is deferred; the working title is **"Anti-Overwhelm Mobile Task Organizer"**. There is no logo, no wordmark and no mascot in scope.

Reference: [`imports/dandelion-seed-reference.png`](imports/dandelion-seed-reference.png) — the builder's own drawing of what the dandelion seed means, and the source of the seed glyph's silhouette (diagonal seed, filled teardrop achene at lower-left, stem running up-right, a swept asymmetric pappus of curved filaments, separate motion dashes, one dark ink, no colour mass). Measured, not remembered: it carries **17 filaments and 7 detached dashes**, and its own diagonal runs at **45.6°** — the earlier record of "~12 filaments" and "5–6 dashes" was wrong, and the seed spec below is corrected against the measurement. It is a *shape* reference at illustration scale, not a specification: filament count, colour mass and offset are specified here. Every idea the file carries is accounted for, one claim at a time, in [`reconcile-dandelion-seed-reference.md`](reconcile-dandelion-seed-reference.md).

**Mockups illustrate; they do not specify.** Five promoted artifacts sit in [`mockups/`](mockups/) and are linked from the sections they illustrate. Each carries a note at its top naming what in it is superseded and by what; superseded exploration stays in `.working/`. **The spines win on conflict** — over the PRD, over the reference image, and over every artifact in `mockups/` and `.working/`.

## Colors

The palette is **"Aliento"** — cool near-white ground, the airiest of the five registers that were rendered, shortest hue steps, 14px corners. It was chosen *for the air*, and that choice constrains everything below. The five registers side by side are in [`mockups/color-themes-1.html`](mockups/color-themes-1.html), which is the rationale for that choice; it draws Aliento as a single tier and predates version C, and says so at the top.

**Two tiers, and the reason they exist.** The misregistered crescent only reads if the mass is dark enough against what it sits on. Measured threshold: the crescent needs **Δ L\* 18–20** against its ground at 24px. Aliento's baseline destination hues sat at Δ L\* 11.8 and read as antialiasing — a tremble, not a second plate. Dropping the *fields* to L\* 76 fixes the icons and destroys the reason Aliento was chosen. So the system splits:

| Tier | Tokens | Lightness | Role |
|---|---|---|---|
| Field | `surface-base` `surface-raised` `ink-primary` `ink-secondary` `border-hairline` `accent-soft` | Aliento baseline, L\* 88.3–100 (ink L\* 12.6) | Grounds, cards, text, hairlines, the chip and the primary action |
| Icon mass | `dest-keep` `dest-donate` `dest-trash` `icon-mass-neutral` `icon-mass-ochre` | L\* 76.0, Δ L\* 21.6 against `{colors.surface-base}` | The colour plate inside a glyph, nowhere else |

**The argument is AREA, not taste.** Fields occupy thousands of device pixels and are what produces the sensation of air. An icon mass occupies on the order of 200 device pixels at 24px. Deepening the masses by 9.7 L\* buys the print gesture and costs almost no perceived airiness. The cost is a two-level discipline that someone will eventually violate — and one seam, 9.7 L\*, wherever a glyph sits on a field of its own colour family. **That seam was not tolerated; it was removed** by dropping coloured destination tiles entirely, so hue lives only *inside* the glyph and the two tiers never touch.

**The field tier, per token.**

- **`surface-base` #F7F8F9** (L\* 97.51) — the screen's floor. Cool near-white, not cream: the warmth in this product comes from the copy and the drawing, not from the paper.
- **`surface-raised` #FFFFFF** — the dispenser card and the full-screen decision surfaces. Distinguished from the base by tone alone, never by shadow.
- **`ink-primary` #1E2124** (L\* 12.62) — task text, the duration chip's text, the primary action, every glyph's line layer. 15.21:1 on `{colors.surface-base}`, 16.18:1 on `{colors.surface-raised}`.
- **`ink-secondary` #5C6368** (L\* 41.48) — the secondary action, support copy, the quiet zone marker. 5.74:1 on `{colors.surface-base}`. Never used for a glyph's line layer in the destination trio.
- **`border-hairline` #E1E5E8** (L\* 90.71) — 1px card, button and chip edges, at the lowest contrast that still reads as an edge.
- **`accent-soft` #D5E0DC** (L\* 88.31, *agua clara*) — **this token exists so the primary action never borrows a destination's meaning.** `Hecho` cannot be filled with keep, donate or trash without the most-pressed button in the app inheriting one of the three semantics. `accent-soft` is also the fill of the duration chip, and it is **the only pastel in the system that carries text** (`{colors.ink-primary}` on it: 11.96:1). No glyph may ever sit inside it — that is the crack through which the two-tier system breaks.

  **`Hecho` is filled with `accent-soft`**, per the accepted type ramp — not the dark ink-filled button drawn in [`mockups/final-verification-1.html`](mockups/final-verification-1.html) § 5, which is superseded. Two rules fall out of that, and both are checkable in Do's and Don'ts: (1) `accent-soft` is the **sole** pastel that may carry text, and **no icon-mass-tier pastel ever carries text**; (2) **no glyph may sit inside `accent-soft`**.

**The destination trio.** Three equal-weight hues, no hierarchy, no hue readable as "the bad one". Any visual weighting of the third destination would reintroduce judgement and violate the PRD's second invariant principle (uncompromising anti-shaming). Version C, all three lifted to chroma ~15 **together**:

| Token | Hex | L\* | Chroma | Hue |
|---|---|---|---|---|
| `dest-keep` (`Quedármelo`) | #9EC3B5 | 75.84 | 15.47 | 169.0 |
| `dest-donate` (`Donar o vender`) | #BCB8D4 | 75.90 | 15.19 | 296.9 |
| `dest-trash` (`Tirar o soltar`) | #D9B2B6 | 76.05 | 15.08 | 12.6 |

L\* spread 0.21, chroma spread 0.39, **minimum hue separation 18.57** against a 15 threshold. Rejected: chroma ~11 across the row (separation 10.60 — equal weight, no separation); and the rose swapped in alone (separation 15.76, but at chroma 15.69 against mint's 7.34 it was visibly the loudest in the row). If the system ever reads as too present, **the lever is all three down together to chroma ~13** (#A3C2B6 / #BCB9D1 / #D5B3B6, minimum separation 16.01) — **never one alone**. Version C measured against the rejected rows is in [`mockups/final-verification-1.html`](mockups/final-verification-1.html) § 3.

**The "no red" rule, as scoped by the builder.** It targets **alarm, overdue and shame**, not a hue family. A dusty rose at L\* 76 and chroma 15 is clearly outside the alarm register and is admitted. What remains forbidden is red *as alarm*: no error fills, no overdue badge, no warning tint, no destructive-red confirmations.

- **`icon-mass-neutral` #B3BEBA** — `accent-soft` taken down to L\* 76 for the icon-mass tier. This is the default mass for the utility glyphs (Cámara, Álbum, Reloj, Ajustes, Lápiz), which carry no semantic hue.
- **`icon-mass-ochre` #CAB9A0** — the Hoja's mass, and the only hue in the system outside the destination trio. **L\* 75.94, chroma 15.02, hue 82.3**, computed by the trio's own method (CIE Lab, D65, sRGB; separation measured as distance in the a–b plane, which at equal L\* is exactly ΔE) rather than picked by eye. It lands in the system band by construction: Δ L\* **21.59** against `{colors.surface-base}`, inside the 21.5–21.7 spread the three destinations hold, so the misregistered crescent has the same headroom they do. Against `dest-trash` #D9B2B6 — the system's only other warm hue — its **separation is 17.21**, clear of the working threshold of 15; it also clears `{colors.icon-mass-neutral}` at 15.63, so the zone marker cannot be mistaken for a utility glyph either. **The separation requirement here is about system coherence, not adjacency.** The Hoja lives on the dispenser card and the rose lives in the 3-Destination Flow; the two never share a surface. But two warm masses at the same lightness that the eye could confuse would make the palette read as careless even when apart. And the Hoja must never be read as a fourth destination.

**Dark mode is in scope and is a separately authored palette — never an inversion.** Inverted dusty pastels either muddy or go neon. The dark ink is a warm off-white (`ink-primary-dark` #ECEAE4, 13.93:1 on `surface-base-dark`, 12.36:1 on `surface-raised-dark`) precisely to warm the cool ground back up; the ground is a deep desaturated neutral, never pure black. **The destination marks change SHAPE between light and dark**, not only colour. The pastel mass cannot survive as a mass in dark mode: off-white ink on a muted pastel fill lands around 4:1 and reads dirty. So each destination retires to a **6px edge bar plus a hairline on `{colors.surface-raised-dark}` with off-white ink**, identical geometry across the three so equal weight is preserved. This shape change is accepted, not a defect.

## Typography

Two Google Fonts, both variable, both bundled: **Lora** (serif, 400..700 + italic 400) and **Lexend** (sans, 300..700). The three configurations that produced the paired rule, the hero-size measurement and the duration-chip finding are rendered in [`mockups/typography-1.html`](mockups/typography-1.html), whose only stale claim is the ramp's *count* — five, where it is now eight.

**The paired rule: Lora for the task text only; Lexend for every other role.** The second face is earned for a *structural* reason, not an aesthetic one — the boundary is already in the product rather than drawn by a designer. **One role is CONTENT** (a sentence a person wrote about their own home); **every other role is MECHANISM** (the duration, the two actions, the support copy, and the three added below — a heading, a figure, a caption the app wrote). One face per side, no exceptions, no judgement calls: a one-line rule rather than a two-face palette. Lexend keeps seven of the eight roles, which is also why this does not contradict the builder's stated preference for it.

**Failure condition, to be honoured rather than negotiated:** if the system ever needs Lora in a second role, or Lexend in the task text *conditionally*, the rule is broken and the answer is **all-Lexend**. All-Lexend is a dignified retreat; all-Lora is not (a serif inside a filled colour surface goes ceremonial, and `Hecho` cannot be ceremonial when it is pressed twenty times a week). Unlisted costs of the pairing: two variable families in the APK, and embedded-serif fallback on Android is less predictable than sans.

| Role | Face | Size | Weight | Line-height | Tracking | Ink |
|---|---|---|---|---|---|---|
| `{typography.task}` | Lora | 26sp | 500 | 1.32 | 0 | `{colors.ink-primary}` |
| `{typography.duration}` | Lexend | 15sp | 500 | 1.40 | +0.01em | `{colors.ink-primary}` on `{colors.accent-soft}` |
| `{typography.action-primary}` | Lexend | 19sp | 600 | 1.00 | +0.01em | `{colors.ink-primary}` on `{colors.accent-soft}` |
| `{typography.action-secondary}` | Lexend | 15sp | 400 | 1.35 | +0.01em | `{colors.ink-secondary}` |
| `{typography.support}` | Lexend | 13sp | 400 | 1.45 | +0.02em | `{colors.ink-secondary}` |
| `{typography.screen-heading}` | Lexend | 19sp | 600 | 1.25 | +0.01em | `{colors.ink-primary}` |
| `{typography.metric-numeral}` | Lexend | 19sp | 500 | 1.15 | +0.01em | `{colors.ink-primary}` |
| `{typography.caption-warm}` | Lexend | 15sp | 400 | 1.45 | +0.01em | `{colors.ink-primary}` |

**Eight roles now, and the three additions are priced rather than waved through.** The ramp was five, and "five, not one more" held for exactly as long as the only drawn surface was the Dispenser. Drawing the other four surfaces — [`mockups/key-screens-1.html`](mockups/key-screens-1.html), which is also where the 200% column lives — broke it in three specific places, each of which was being covered by a role that means something else.

- **`{typography.screen-heading}`** — the mock reused `{typography.action-primary}` as a screen title on four surfaces. Size and weight are kept exactly (19sp/600 — nothing new on the scale); the number that makes it a separate role is the **line-height, 1.25 against 1.00**. `action-primary`'s 1.00 is only safe on a single label that never wraps, and a heading wraps — at 200% it wraps on every one of those four surfaces, so reusing the button role would have overlapped its own lines. A heading is not a button, and the line-height is where that stops being a naming quibble.
- **`{typography.metric-numeral}`** — the FR-23 dashboard carries `4 h 25 min`, `68` and `≈ 3 cajas liberadas` in `action-primary`, which puts **a `Hecho`'s typographic weight on the one screen in the app that has no primary action**. The fix is the weight, not the size: 19sp is kept, 600 drops to **500** — the weight the task text and the duration chip already use — and the line-height comes down to 1.15 because a figure does not wrap. It deliberately does **not** take the task's 26sp hero size: that size belongs to *content*, set in Lora, a figure is *mechanism*, and three hero-size figures on the single dense surface would shout precisely where this product must not.
- **`{typography.caption-warm}`** — the Before/After caption is the warmest sentence in the app and matched none of the five: `action-secondary` has the size but the wrong ink, `support` is 13sp. It is 15sp/400 in **`{colors.ink-primary}`**, at `support`'s 1.45 line-height because it wraps as prose rather than sitting on one line.

**The paired rule is untouched by all three**, because all three are Lexend: none of them is a sentence a person wrote about their own home. The failure condition is unchanged too — Lora in a second role is still the signal to retreat to all-Lexend. What is retired is the *count*: "five, not one more" is replaced by the rule that produced it — **a role is added only when an existing role would otherwise have to carry a meaning that is not its own**, and each of the three above names which meaning that was.

**Two formats, specified because they land on the densest screen in the app.** Neither existed, and both appear inside the FR-23 exception where six values already share a surface.

- **`{formats.short-date}`** — `12 ago` · `4 ago` · `28 jul`. Day with no leading zero, a non-breaking space, a three-letter lowercase Spanish month, no period, no year. Lowercase and abbreviated because the album highlight caption is `{typography.support}` at 13sp in a column that has to survive 200%, and a full month name is what makes that column break. No year is deliberate: a year turns a date into a record of how long ago, which is the deficit reading this product removes. **The consequence is honest and unsolved — see Open Questions.**
- **`{formats.duration}`** — `30 s` · `3 min` · `10–15 min` · `4 h 25 min`. Value, non-breaking space, unit; units `s` / `min` / `h`; largest unit first; no leading zeros; an en dash for a range. The non-breaking space is load-bearing at 200%, where a number and its unit on separate lines stop being a duration. This is the format behind every string that already exists — `Tengo 15 minutos ahora`, the three picker sizes, the dashboard's minutes — so it is written down rather than re-derived per surface.

Lora's italic is present in the bundled file and used by no role today.

**Hero size, measured rather than guessed.** With `Despeja la mesa del salón` at 26sp the string breaks cleanly as *"Despeja la mesa / del salón"*. At 20px it breaks as *"Despeja la mesa del / salón"*, leaving an orphan that reads timid. At 32px it stays two lines but the second runs edge-to-edge and the break moves behind an article. **The shouting slope is crossed around 30px**, and the tell is remaining whitespace and break position — not line count.

**The duration chip is 15sp, not peer size, and every part of that is load-bearing.** ABOVE the task, because reading order *is* the mechanism: cost before ask. In `{colors.ink-primary}`, because secondary ink turns the guarantee into metadata and the user stops seeing it on the night he needs it. A CHIP, because a closed shape says "quantity with edges", and because it shares `accent-soft` with `Hecho`: that shared fill is what makes the chip read as belonging to what the user is *invited to do* rather than to what they are *measured by*. Had `Hecho` gone dark-ink, the chip would have been the only `accent-soft` surface on the card and the family argument would have evaporated. SMALL (15 against 26), because at peer size it stops being permission and becomes a deadline, a clock watching you.

**Platform inheritance — what is deliberately not fixed.** All five sizes are `sp`, never `dp`: scaling belongs to the system font setting. Line-heights are multipliers, never fixed dp, or lines overlap at 200%. Touch-target height is `dp` and does **not** scale: `{spacing.touch-target-min}` is a platform constant; text grows and the box grows with it through padding.

**The 200% floor stands.** The PRD's accessibility requirement — *legible at 200% system font scale with no truncation* — is a live constraint, not scaffolding. Only the demonstration tile in [`mockups/color-themes-1.html`](mockups/color-themes-1.html) was discarded. Nothing truncates at 200% in any of the eight roles; the card grows and the screen scrolls, which is correct.

**One place breaks as LAYOUT rather than as size, and it is named here rather than discovered later.** Inside the FR-23 density exception, `{components.dashboard-highlight-row}` is the only construction in the app where 200% degrades the *maquette*. Nothing truncates, so the accessibility floor is met. But the three columns fall to **~101dp** and their captions break to **four or five lines**, and the row stops reading as a row. The stated fallback is a **reflow, not a shrink**: the row drops to **one column per row as soon as a caption would break beyond two lines**. Two lines is the threshold because it is the last width at which a `{formats.short-date}` caption still reads as one caption, and expressing the trigger in lines rather than in dp keeps it true across engines and locales. Nothing else scales: the 24 and 32dp gaps stay put, because `{spacing.touch-target-min}` is a platform constant and the rest of the scale is `dp` — **what grows is the content, never the grid.**

**The `Otra más fácil / Ahora no` caveat, in full.** At 16sp the string wraps at 200% with the slash dangling at the start of line two. It is not a width problem — *"Otra más fácil /"* measures 203px with 238px available; the engine simply refuses to break there. Non-breaking space produced three lines; zero-width space did nothing; `text-wrap: balance` broke *in front of* the slash at every size, including sizes that were previously fine. The only thing that moved it was dropping the role to **15sp** (30px doubled), which yields *"Otra más fácil /"* + *"Ahora no"*. **This was measured in Blink, and Android's line breaker is a different engine.** The rule that survives an engine change is not "15sp" — it is that **this string cannot survive intact at 200%, so the fold must be accepted and verified on a real device**. 15sp buys the good case being likely, not safe. The string is never shortened, never given `maxLines`, never ellipsized, and never hard-broken with `<br>`; folding is platform behaviour and must be left to work.

## Layout & Spacing

**One card, and mostly empty space.** The dispenser is a single `{components.dispenser-card}` on `{colors.surface-base}`: the duration chip as an eyebrow, the task alone beneath it, the primary action, the secondary action as text without a box, and the zone marker as a quiet footer. Single column always. What there is most of on the screen is space — that is the deliverable, not a by-product. This is broader than the PRD's constraint, which caps *actionable* items at one per screen; here **information** is capped too.

**One zone is exempt from that cap, and the exemption is declared rather than discovered.** The Archetype Template surface inside project genesis **shows a list**, by the builder's explicit decision. Genesis itself carries the photo path as its recommended action, with **manual entry always available beside it**: photo is an invitation, not a gate.

Counted against principle 1's letter — one recommended action plus one way out — the zone comes out over. So it is written as a **declared exception**, alongside the FR-23 density exception and the consent gate's zero recommended actions. **Principle 1 is *amended* for the genesis zone rather than satisfied by it.** The visual consequence is bounded, and checkable three ways. The list is a list of **templates**, never of pending work. It appears on that one surface and nowhere else. And it inherits the ordinary card, type and spacing rules, so none of the FR-23 dashboard's density licence transfers to it.

**Both amendments are paid into the PRD** — 2026-08-26, as the §1.1 exception register: **E1** (the template list) and **E2** (the multi-path genesis zone), with FR-11 and FR-31 carrying the consequences. The upstream edit this block used to demand is closed. The full arithmetic is in `EXPERIENCE.md` § Information Architecture.

Genesis as drawn in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 4 is superseded in structure — three top-level paths, and a template deck served one at a time — and says so at the top of that page. Its verdict box is kept as the record of how the arithmetic was reached.

**The scale is base 4dp, and Android is the justification rather than taste.** Touch targets on the platform are specified at 48dp and the density buckets are multiples of 4 and 8, so a 4dp base lands on whole device pixels at every density instead of fighting them. Steps: **4 · 8 · 12 · 16 · 24 · 32 · 48**. Nothing between steps, and nothing above 48 as a fixed value — see the third rule below.

| Token | Value | Where |
|---|---|---|
| `{spacing.base}` | 4dp | The unit. Every value below is a multiple of it |
| `{spacing.chip-to-task}` | 8dp | `{components.duration-chip}` down to the task text |
| `{spacing.action-gap}` | 12dp | `{components.action-primary}` down to `{components.action-secondary}` |
| `{spacing.card-padding}` | 24dp | Interior padding of `{components.dispenser-card}` |
| `{spacing.screen-margin}` | 24dp | Card to the screen's left and right edges |
| `{spacing.task-to-actions}` | 32dp | Task text down to the first action — the largest interior gap |
| `{spacing.destination-row-gap}` | 32dp | Between the three rows of `{components.destination-flow}` |
| `{spacing.photo-pair-gap}` | 16dp | Between the two plates of `{components.photo-frame}` in the Before/After reward |
| `{spacing.touch-target-min}` | 48dp | The floor for every tappable box; a platform constant that does not scale with font size |

**Three of these numbers are reasoning rather than decoration, and the reasoning is the part that has to survive a redesign.**

1. **The duration chip sits tight at `{spacing.chip-to-task}` — 8, not 24.** Proximity is what makes the duration read as the cost of *this* task rather than a detached statement about time in general. Space the chip away from its task and the eyebrow becomes a caption, the guarantee becomes metadata, and the user stops seeing it on the night he needs it. Separating it does not weaken its job; it destroys it. This is the same finding as the chip's ink and its size (see Typography), arriving from the layout side.
2. **`{spacing.task-to-actions}` is deliberately the largest interior gap.** It is the pause between reading and committing, and that space is doing anti-pressure work. Closing it puts `Hecho` under the thumb the instant the sentence ends, which is exactly the urgency this product exists to remove.
3. **Critical: the air around the card is a minimum plus flex, never a fixed value.** At 200% system font scale the task text reaches ~52px and wraps to three lines, so the card grows. Fixed surrounding space would either break the layout or push the card off the screen. The rule is **minimum 48dp, flexible above**: the card grows into that air, and the screen scrolls when it must. This is deliberately **not** given a `spacing` token — it is carried on `{components.dispenser-card}` as the `air-around` constraint instead, because a token is read as a fixed value and a fixed value is precisely the failure the rule exists to prevent. It is also what ties the spacing scale to the accessibility floor — the 200% requirement is not satisfied by the type ramp alone.

**Glyph sizes carry the other half of the scale**, because there is almost nothing else to place:

| Token | Size | Where |
|---|---|---|
| `{spacing.glyph-destination}` | 64px | The 3-Destination Flow — a full-screen, one-decision surface with three choices and nothing else |
| `{spacing.glyph-min}` | 48px | The interface minimum for the seed glyph anywhere else |
| `{spacing.glyph-dense}` | 36px | Only where density genuinely demands it — the seed is marginal here (see Components) |
| `{spacing.glyph-zone-marker}` | 24px | Only as a zone marker beside a word, where the mark is a place-marker rather than a glyph to be read |

`{spacing.touch-target-min}` is 48dp and does not scale with font size.

A crucial reframe sits behind the 64px number: **the 24px constraint on the destination glyphs was never a product requirement.** The 3-Destination Flow is not a nav bar; it is one decision on a whole screen. Sizing it at 64px is what made the seed glyph viable at all.

## Elevation & Depth

**Flat. There is no elevation language.** No gradients, no glow, no blurred drop shadows, anywhere, in either mode. Surfaces separate by tone (`{colors.surface-raised}` against `{colors.surface-base}`) and by a 1px `{colors.border-hairline}` edge. Hierarchy comes from layout, type size and empty space.

The only intentional depth in the whole system is **two flat plates**: the colour mass and the line layer above it, offset from each other. That is print, not lighting. Any soft shadow immediately reads as a third, contradictory depth model and cancels the misregistration idiom.

## Shapes

`{rounded.DEFAULT}` is **14px** — Aliento's own radius, and the softest of the five registers that were rendered. It carries the card, the primary action, `{components.action-equal-pair}`, `{components.photo-frame}` at full size and every rectangular surface. `{rounded.full}` (9999px) belongs to the two things that carry **a quantity of time**: `{components.duration-chip}` and the options of `{components.size-option}`. The pill is doing semantic work — a closed shape reads as "quantity with edges" — and the picker's three options *are* durations, so they take the same shape for the same reason rather than by resemblance.

`{rounded.thumb}` (**4px**) is the third and last radius, and it exists for one job: `{components.photo-frame}` at album-thumbnail size. `{rounded.DEFAULT}` on a ~100dp plate eats the corners of the photograph itself; 4px is one step of `{spacing.base}` and reads as a cut edge rather than as a small rounded card.

Nothing else is fully rounded. Glyph geometry is not governed by these radii — glyph corners follow the drawing (`stroke-linejoin: round`, `stroke-linecap: round` across the icon set).

## Components

### `dispenser-card`
`{colors.surface-raised}` on `{colors.surface-base}`, 1px `{colors.border-hairline}`, `{rounded.DEFAULT}`, no shadow. Vertical order, top to bottom: `{components.duration-chip}` as eyebrow → task text in `{typography.task}` → `{components.action-primary}` → `{components.action-secondary}` as plain text → `{components.zone-marker}` as a quiet footer. Generous vertical air between the task and the actions; the card never compresses to fit more.

### `action-primary` — `Hecho`
Full-width, `{rounded.DEFAULT}`, filled `{colors.accent-soft}`, label in `{typography.action-primary}` and `{colors.ink-primary}` (11.96:1). Minimum height `{spacing.touch-target-min}`. It is filled with `accent-soft` rather than a destination hue **on purpose** — see Colors. One recommended action per surface — everywhere but the two declared exceptions, the consent gate and the genesis zone.

### `action-secondary` — `Otra más fácil / Ahora no`
**Text only.** No box, no fill, no underline, no animation: available and never suggested. `{typography.action-secondary}` in `{colors.ink-secondary}`, touch target still `{spacing.touch-target-min}`. This single control deliberately carries two distinct product features — `Otra más fácil` is Rescue Mode (FR-5) and `Ahora no` is the guilt-free skip (FR-3). Keeping it as one control is what preserves the invariant "one recommended action plus a way out". The string is never split, shortened or truncated; see the 200% caveat in Typography.

### `duration-chip` — e.g. `Tengo 15 minutos ahora`
Pill (`{rounded.full}`) filled `{colors.accent-soft}`, text `{typography.duration}` in `{colors.ink-primary}`. Sits **above** the task as an eyebrow. The only pastel in the system with text on it.

### `destination-flow` — the 3-Destination Flow
A full-screen surface: a question, the object, three choices, nothing else. Three rows, each a 64px glyph beside its label — `Quedármelo`, `Donar o vender`, `Tirar o soltar`. Drawn at real size in [`mockups/final-verification-1.html`](mockups/final-verification-1.html) § 5, where the ink parity of the row (§ 2) was measured.

- **No coloured tiles.** Hue lives only *inside* the glyph. Labels sit on the card's light ground in `{colors.ink-primary}`, never on a pastel field.
- Masses: `{colors.dest-keep}`, `{colors.dest-donate}`, `{colors.dest-trash}`, all at L\* 76 with identical Δ L\* 21.6 against the ground, all displaced by the one global offset vector.
- **Consequence to own honestly:** with the tiles gone, colour identity rests on ~200 device px of mass per icon. For a user with reduced colour vision colour contributes almost nothing, and the entire differentiation load falls on **shape**. That is a real cost, accepted, not a detail.
- No motion dashes in this row. The five arcs measure well on ink but they leave the glyph's own area, collide with the neighbouring label, and contrast-weighted they push the seed to 122% of the box — the heaviest in a row that must be equal. Motion dashes belong to the illustration register, not to the trio — and the 64px here would otherwise clear the 56px threshold, so this is a bar rather than a size floor. **The accepted consequence, now named: the trio seed reads at rest** (see `{components.seed-glyph}`).

**`Tirar o soltar` is a confirmed, intentional change of string.** The PRD originally fixed this destination as *Trash-Recycle* / `Tirar o reciclar`; `Tirar o soltar` is deliberate, because *soltar* dodges both the deletion vocabulary of a bin and the compliance vocabulary of recycling arrows — the register the whole trio depends on, since the third choice must not read as the bad one. **Paid into the PRD** — 2026-08-26: §3 and FR-20 now own the label and its rationale, `Trash-Recycle` staying the internal concept name. The divergence this paragraph used to flag is closed.

**Equal weight, and the two metrics that police it.** Both are kept; they answer different questions.

| Glyph | Mass (u²) | Contour (u) | Raw total ink @64px | Contrast-weighted |
|---|---|---|---|---|
| `Quedármelo` · box | 79.21 | 60.58 | 113.29 | 54.23 |
| `Donar o vender` · bag | 83.48 | 47.87 | 110.41 | 48.17 |
| `Tirar o soltar` · seed | 15.23 | 80.94 | 60.76 | 53.99 |

- **Raw: `total ink = mass + contour × stroke-width`.** This is the **guard rail**, and its only job is to stop someone fattening the pappus back into a pompom. It exists because almost all of the seed's weight is *line*, not mass — anyone who measures mass alone concludes the third destination weighs nothing and starts adding fluff. By this formula the row is **not** at parity (the seed sits 46.4% below the box) and no circle diameter fixes it: raw parity would need r = 4.43u, i.e. precisely the pompom the metric exists to prevent. Read it as a brake, not as a target.
- **Contrast-weighted governs actual parity judgements**, because it matches perception: a u² of L\* 76 pastel is worth 0.2544 of a u² of L\* 12.6 line. By it **the row is at parity** — seed 53.99, box 54.23 (99.6%), bag 48.17 (88.8%) — and the lightest glyph is the *bag*, not the seed.

The box's contour debt (once 1.85× the seed's) was **closed by size, not by drawing**: at 64px stroke thins in user units while mass does not, so the box's line excess falls from 21.8% of total presence at 24px to 13.0%, and 64px permits real recalibration — moving the mass from the lid band to the body (10.20 × 7.85) cuts contour from 75.74u to 60.58u, bringing total presence within 2.6% of the bag. The box no longer dominates the eye.

### `destination-mark-dark`
In dark mode the three destinations are **not** masses. Each becomes a **6px edge bar plus a 1px hairline on `{colors.surface-raised-dark}`**, label in `{colors.ink-primary-dark}`, with identical geometry across the three. Bars: `{colors.dest-keep-dark}`, `{colors.dest-donate-dark}`, `{colors.dest-trash-dark}`.

### `icon-glyph` — the treatment, in full
Nine glyphs: **Cámara, Álbum, Caja, Bolsa, Reloj, Hoja, Ajustes, Lápiz**, and the **dandelion seed**. Caja / Bolsa / seed are the destination trio; Hoja is the FlyLady zone marker and carries `{colors.icon-mass-ochre}`; the rest are utility, carrying `{colors.icon-mass-neutral}`.

- **Two plates.** A flat colour mass with no stroke, and above it the line layer in `{colors.ink-primary}`. **The mass always sits under the line layer.** Both plates scale together; the mass is never registered inside its outline (that variant is indistinguishable from a single-layer icon at small sizes and spends the second plate for nothing).
- **One global offset vector, proportional to size.** Magnitude = 8% of the rendered icon side. In a 24 viewBox this is a constant **1.92u** at every render size (`24 × 0.08`), decomposed 45° up-right into **`translate(1.358, -1.358)`**. Never a fixed dp offset: at 48px a fixed 2px offset is smaller than the stroke, the mass is half-swallowed, and the icon reads as a rendering bug.
- **The AXIAL rule — the finding is the axis, not the sign.** The offset must run **along** a glyph's own axis, never across it. Axial reads as a **motion trail**; transverse reads as a **printing error**, with half the mass exiting sideways under no line at all. Tilting the seed 45° up-right makes its local flight axis coincide with the single global vector — one vector serves the whole set and still satisfies the seed's axial requirement, so there are **no per-icon offsets**. **`{components.seed-glyph.axis}` is 45.0°, and this is a correction:** the specified geometry ran at **53.0°**, an 8.0° mismatch against a 45° vector, which injected a transverse component of 0.267u — 13.9% of the offset magnitude — into the one glyph the axial rule governs most strictly. The claimed elegance was that tilting the seed *exactly* 45° makes its local axis coincide with the global vector. At 53° that was not true. The fix is a rotation of the **whole drawing** by 8°, so every internal measurement is untouched: the tip gaps, the 15.28° leeward pair, the 36px floor and the ink totals all stand. Only the glyph's angle to the screen changes, and the perpendicular component becomes exactly 0. **The reference's own diagonal is 45.6°** — closer to the ideal than the spec derived from it, and the two were never compared. The Lápiz is free for the same reason — its axis is already 45° up-right, so the mass slides 9.6% along its length and crosses 0% of its width.
- **If the global vector's direction is ever changed, the strictly axial glyphs break first** — the seed, and any glyph whose clearance depends on a perpendicular component of exactly 0.
- **Minimum mass, corrected.** The original rule was "no icon mass below 8u in its minor dimension" (1.92u over 8u is a 24% shift — the mass moves but stays inside). That rule was derived for *arbitrary* offset directions. **For a strictly axial glyph the quantity to police is AXIAL EXTENT, not minor dimension** — which is why forms measuring 6.30–6.67u perpendicular to their own axis are legal. The minor-dimension form of the rule still governs any glyph whose axis is not aligned with the global vector. Either way the treatment kills gears, knob racks, three-bar equalizers and anything with more than two masses.
- **Stroke: `stroke-width(u) = target_px × 24 / render_px`, targeting 1.5px at 24px.** Computed values: 1.80@20 · **1.50@24** · 1.20@36 · 0.90@40 · 1.00@48 · 0.5625@64 · 0.50@72 · 0.375@96. **1px was tested and is unrecoverable**: against L\* 76 masses the mass wins the attention split (the glyph reads as a pastel silhouette with a dirty edge instead of line art over a second plate) and the 8% offset degrades from misregistration into antialiasing. All three recovery routes cost more than accepting 1.5.
- **The glyph-adjacency rule: never place a destination glyph beside a sentence whose meaning it inverts.** Established by drawing the dashboard. The volume line `≈ 3 cajas liberadas` carries **no glyph at all**, because the system's only box glyph *is* `Quedármelo` — the first member of the destination trio — and setting it beside a sentence about boxes *released* would state the opposite of the sentence. Generalised, and checkable at review time: **a destination glyph may appear only where the destination it names is the meaning being expressed.** Where the copy expresses the inverse, or expresses a different destination, the figure or the sentence stands alone. This bites harder than it looks because shape carries the entire differentiation load of the trio (see Colors) — a box, read anywhere in this app, is read as `Quedármelo`.
- **Fine detail is out of scope for this treatment.** Glyphs must be drawn as large simple masses.
- **Weight note:** Reloj is 211.2u² of mass, 2.5× the seed and the heaviest in the utility set. That breaks no rule (only the destination trio must weigh the same) but it will dominate any nav bar it shares with the seed. Hollowing it to a ring removes its mass and removes it from the treatment — a trade, not a fix.
- **Ajustes has no construction that reads unambiguously as "settings".** The toggle survives the offset best and reads closest on Android; the dial gives the cleanest crescent but reads as a stove knob; the single-handle slider survives but its crescent crosses a 1px rail at 24px. **The gear is the only universally learned form, and it is the one this treatment forbids.** This is not fixable by drawing better: it needs a text label, or the gear admitted as a documented single-ink exception. **Unresolved — see Open Questions.**

### `seed-glyph` — `Tirar o soltar`
The third destination. Rejected on stated grounds: a papelera and recycling arrows *"implican imposición"*. The seed is the release gesture as the user's own breath — chosen, gentle, not institutional — and two of the three destinations mean the object goes on existing, which is what makes the trio genuinely equal.

Silhouette source: [`imports/dandelion-seed-reference.png`](imports/dandelion-seed-reference.png), reconciled claim by claim in [`reconcile-dandelion-seed-reference.md`](reconcile-dandelion-seed-reference.md). The filament-count ladder and the size floor are in [`mockups/seed-at-scale-1.html`](mockups/seed-at-scale-1.html) §§ 1–2 and [`mockups/final-verification-1.html`](mockups/final-verification-1.html) §§ 1 and 4 — both drawn before the corrections below, and both noted at the top of their page.

Specification:

- **Always 8 filaments, at every size.** One drawing, scaled — no fidelity ladder. Eight is verified: six reads as a rake or a whisk, four as a sprout or an anchor. What separates a dandelion seed from a starburst is not ray count but three cues — a curved tip envelope, a one-directional comb, and more filaments on one side — and all three survive at eight. Reduction also *buys size*: eight filaments drop the working floor from 64px to 36px.
- **The builder's hard rule, verbatim: "Nunca añadir rasgos."** Never add filaments. Eight, permanently. This is the durable guard against the pompom regression, and it pairs with the raw total-ink metric: the metric explains *why* someone would be tempted to fatten the pappus, and this rule forbids it outright.
- **The achene is filled**, in `{colors.ink-primary}` (6.15u², perimeter 9.83u). Drawn hollow it reads as a loop dangling from a stick.
- **The colour mass is a circle in the pompom hub** — the point where the filaments converge — in `{colors.dest-trash}`, no stroke, **under the line layer** so the filaments cross over it, and **displaced off the hub's centre toward the leeward (dense) side** of the pappus — *sotavento*, the downwind edge, where the angular spacing between filaments closes. The global 45° offset applies on top of that placement. **This is a correction:** the spec previously said "dense (windward)", contradicting both mockups, which measure the tightest filament pair "always on the downwind edge, because the angular spacing closes there". Dense and leeward are the same edge; windward was wrong wherever it appeared. Specified **as a constraint, not a number**: as large as coverage permits, subject to **its entire free edge remaining under filaments**. A circle has no axis, so the axial/transverse failure cannot occur here — any direction is safe.
- **Why the circle, and not the alternatives.** It is a genuine mass, so it obeys the governing rule instead of needing an exemption — which dissolves the "a line-only illustration cannot carry the hue" problem rather than working around it. It supersedes the ghost-line copy entirely. The hub is the widest part of the glyph, so the hue can reach real presence; the achene-as-mass rescue failed because 6.15u² was 7.8% of the box's mass and read as a pale sliver. Measured reference points at r = 1.70u (d 3.40u, 79.1% of the 4.30u hub, 9.08u², a 9.1px disc at 64px): the first size the eye files as **colour** rather than a dot, and the last that fits entirely inside the bundle zone. r = 1.10u fails as a mote — worse, the 1.92u offset exceeds its own radius, so the circle walks out of the fan instead of shifting inside it. r = 2.30u (107% of the hub) won the colour and lost the idiom: its lower-left arc emerged where only the stem sits, a bare curved edge reading as a ball behind the drawing. **The builder's final instruction is larger than 1.70u and displaced off-centre** — a fix to exactly that failure mode, exploiting the asymmetry the drawing already has.
- **Flagged honestly: the circle's radius is the one number in this system settled at draw time rather than by measurement.** It is settled against the coverage rule above, not by a token.
- **The axis is 45.0°, matching the global offset vector exactly.** `{components.seed-glyph.axis}` — corrected from the 53.0° the geometry was specified at, which put an 8.0° mismatch, and therefore a transverse component, into the strictest axial glyph in the set. See the axial rule under `{components.icon-glyph}` for the full accounting; the change is a rotation of the whole drawing, so nothing measured inside the glyph moves.
- **Size floor, verified.** 36px, and marginal: the leeward filament pair (6–7, 15.28° apart) fails first, its clear falling to 1.38px against a 1.4px marginal threshold, so the seed reads with seven filaments rather than eight. It is still unmistakably a dandelion seed — the one-way comb, the diagonal stem and the filled achene carry it. Next to fail, at 24px, is the stem/achene junction: the 1.5u stroke eats the achene's 2.52u width and the teardrop stops having a shape. Hence `{spacing.glyph-min}` as the interface minimum, `{spacing.glyph-dense}` only where density demands it, `{spacing.glyph-zone-marker}` only as a zone marker beside a word. Failure order as it shrinks: the downwind density gradient (the cue that reads as *wind*) → the achene's spindle → the stem merging at the hub → the whole fan becoming one lobed mass.
- **The comb, not the feather, is intended — and the accepted trade is twice as large as the record said.** At 96px the specified glyph's mean tip-to-tip gap is **13.5px** against 1.5px lines, roughly 1:9 ink-to-air at the broad edge: the pappus reads as a **comb**, not a feather. That 13.5px figure is correct and stands. What was wrong is the reference it was compared against. **The reference in `imports/dandelion-seed-reference.png` carries 17 filaments, not the ~12 recorded throughout this session** — measured by ring-sampling the ink mask about the hub, 18 crossings of which one is the stem, at four separate radii. Scaling the same measured tip gap inversely with count puts the **reference-equivalent gap at ~6.4px at 96px**, not the 13.5px the spec quoted as the reference's own figure. So the specified glyph puts roughly **twice** as much air between tips as the reference does, not the ~55% more that "12" implied, and the comb-not-feather consequence is about twice as pronounced as recorded. **Stated plainly because it matters who accepted what:** the builder accepted this trade on the wrong number. The decision itself does not change — 8 filaments were chosen on legibility cues, never as a ratio of the reference, and `Nunca añadir rasgos` is his own rule — but the trade he accepted is larger than it looked. The more graphic, stamp-like drawing suits the print register; that is the position, now held against the right figure. The only palliative compatible with "one drawing, scaled" is the motion strokes.
- **Motion dashes: the lever now has a threshold, and the threshold is assigned.** They were measured to help at **56px and above** and to hurt at **36px and below** (4px specks read as dirt and cost 19.4% extra ink for nothing). The rule that closes the previously-unconnected lever, carried as `{components.seed-glyph.motion-dashes}`: **motion dashes appear only where the seed is drawn at 56px or above.** Below that they are off. That means off at glyph scale everywhere — `{spacing.glyph-min}` 48px, `{spacing.glyph-dense}` 36px, `{spacing.glyph-zone-marker}` 24px — and off in `{components.destination-flow}` specifically, where 64px would clear the threshold but the ink-parity argument bars them anyway. Dashes-on therefore belongs to the illustration register alone. The lever's real value is inverse: **removing them turns the same drawing from *arriving* into *at rest*.**
- **The 64px trio seed reads AT REST, and that is now a decision rather than a by-product.** Confirmed by the builder. Dashes are barred from the destination trio on ink-parity grounds, so by the system's own inverse rule the trio seed is at rest — the opposite of the reference's mid-flight feeling, and the opposite of the release-in-flight reading the seed was chosen for. It was arrived at as arithmetic and written down nowhere; it is now named, accepted knowingly, and the ink parity of the row is what it buys.
- **Two things the reference has that this spec now rejects by decision, not by silence.** Both had fallen out of the design without ever being weighed, and both are closed by the builder's explicit `Descarta`. (1) **The reference's petrol-blue ink `#134C5F`** — a saturated dark teal used for every mark in the file, including the achene. The line layer stays `{colors.ink-primary}`. It had been foreclosed by a rule set before the reference existed ("the line is dark ink"), never argued against it; it is now considered and rejected. (2) **Tapered, variable-weight strokes** — measured in the reference at 2.5–4.8× from hub to tip, and the single largest reason the file reads as delicate. The spec keeps **one stroke width per render size**, `stroke-width(u) = target_px × 24 / render_px`, round caps and joins. Taper is now rejected rather than unseen. Neither is to be re-litigated; the cost — a well-made vector mark rather than something a person drew — is accepted.

### `zone-marker` — Hoja
The FlyLady zone marker, and the reason both open glyph slots closed with no new drawing: the seed took the destination slot, so the Hoja stayed free. Rendered quiet — `{spacing.glyph-zone-marker}` in `{colors.ink-secondary}`, label in `{typography.support}`, sitting at the foot of the dispenser card. At that size it is a place-marker, not a glyph to be read. **Its mass is `{colors.icon-mass-ochre}` — ochre**, computed rather than chosen (see Colors), and neither the neutral utility mass nor any destination hue, so the marker can be read as neither a destination nor a utility control. What has *not* been measured is how that crescent behaves at 24px under a **secondary-ink** line rather than the `{colors.ink-primary}` line the two-tier threshold was calibrated against — see Open Questions.

### `size-option` — Manual Capture's three-size picker
The only selector in the app, and the states did not exist: `{components.duration-chip}` was specified as a *display*, so there was no selected and no unselected. **Selected is `{colors.accent-soft}`** — the chip's own fill, borrowed because the options are durations and `accent-soft` is already the fill of the surface that carries a duration. **Unselected is `{colors.surface-raised}` with a 1px `{colors.border-hairline}` edge.** Both states keep `{colors.ink-primary}` and `{typography.duration}`, both are `{rounded.full}` (see Shapes), both hold `{spacing.touch-target-min}`, and they sit `{spacing.action-gap}` apart. **No option ever carries a glyph**, so the no-glyph-inside-`accent-soft` rule survives intact — which is exactly why the selected state can use that fill at all. In dark mode the selected option takes `{colors.accent-soft-dark}`.

The three options are shown as **durations** — `30 s`, `3 min`, `10–15 min`, per `{formats.duration}` — and never as the glossary's internal names. Selection is single and always populated: there is no empty state and no "none of these". Drawn in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 1.

### `action-equal-pair` — the consent gate's two answers
**The component FR-25 structurally requires, and the system had nothing between `{components.action-primary}` (filled) and `{components.action-secondary}` (no box at all).** Two buttons in one row, both `flex 1 1 0` so their widths are identical, `{spacing.action-gap}` apart, each on `{colors.surface-raised}` with a **1px `{colors.border-hairline}` edge and no fill**, label in `{typography.action-primary}` and `{colors.ink-primary}`, `{rounded.DEFAULT}`, `{spacing.touch-target-min}` minimum height. In dark mode: `{colors.surface-raised-dark}`, 1px `{colors.border-hairline-dark}`, `{colors.ink-primary-dark}`.

**`{colors.accent-soft}` is expelled from this component entirely, and that is the whole point.** Filling either button makes it the recommended one, and recommending is precisely the dark pattern FR-25 forbids. The consequence is stated rather than left implicit: **the per-scan consent gate is the only surface in the app with zero recommended actions** — a declared exception to "one recommended action plus a way out", in the same spirit as the FR-23 density exception, and written as an exception so it is not a precedent. Every surface keeps exactly one except this gate, which keeps none, and the genesis zone, which keeps more (see Layout & Spacing).

Drawn in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 2.

**The irreducible residual, recorded rather than solved: reading order.** Two buttons in a row are read left to right, so one is read first; stacked, one is on top. No arrangement removes it. The order chosen puts `Enviar` in the **first, unfavourable** slot for consent, and that is the honest direction to fail in — but it is a residual asymmetry, not a symmetry. Everything else is verifiable by inspection: identical width, height, fill, edge, type role, ink, tap count, and no delay on either.

### `photo-frame` — FR-17 and the Transformation Album
The app's only image surfaces, and no token existed for them. **Aspect 3:4, `{rounded.DEFAULT}` at full size, `{rounded.thumb}` at album-thumbnail size, a 1px `{colors.border-hairline}` edge.** Two frames in a Before/After pair are **the same size, at the same height, with the same corner**, `{spacing.photo-pair-gap}` apart. **Labels sit outside the frame, never over the image** — which is also what keeps the no-text-on-a-pastel rule intact when a photograph has not loaded yet.

**While loading: `{colors.surface-base}` inside the frame, with the hairline, and no motion.** No spinner, no shimmer, no skeleton gradient — derived rather than invented, because Elevation & Depth forbids gradients and any lighting model anywhere, and a shimmer is a moving gradient. An empty frame that is the right shape is the whole loading state.

**A rule that follows from the two-tier system:** an icon-mass pastel is never a stand-in for a photograph in the product. [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 5 used `{colors.icon-mass-ochre}` and `{colors.icon-mass-neutral}` as flat plates because an image-free artifact has no photographs; it flagged itself as scaffolding and kept all text outside those blocks. In the product, a `photo-frame` holds a photograph or it holds `{colors.surface-base}`.

### `dashboard-highlight-row` — inside the FR-23 exception only
Three album highlights in one row at default scale, `{spacing.action-gap}` apart, each a `{components.photo-frame}` thumbnail at `{rounded.thumb}` with a `{typography.support}` caption naming the place and a `{formats.short-date}` date. **It reflows to one column per row as soon as a caption would break beyond two lines** — the named, expected degradation at 200%, priced in full under Typography. It exists nowhere else in the app; the density exception is what licenses it. Drawn at both scales, default and 200%, in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 3.

### The illustration register
One class of mark at **two line densities**, not two classes. Genuinely line-dominant, delicate, many-stroke drawings at large scale are exempt from the offset rule **only when the mark stands alone on a full-screen surface** — the seven no-Slicer degradation states, Warm Return, the Anti-Marathon permission-to-rest screen, the scan wait. There is no row there to match. Inside a row of `{components.icon-glyph}`, an illustration is not exempt: it must carry a real mass, as the seed does. Incidental small masses (the filled achene) are permitted in the illustration register — the reference image itself has one.

Two of these surfaces are drawn at register scale in [`mockups/seed-at-scale-1.html`](mockups/seed-at-scale-1.html) § 4: Warm Return at 168px with motion dashes, and the permission-to-rest screen at 150px without them. That page is the origin of the dashes-on / dashes-off reading, and it draws the seed with twelve filaments — superseded, per the note at the top of the page.

## Do's and Don'ts

| Do | Don't |
|---|---|
| Keep the line dark ink and the mass flat pastel, mass **under** line | Tint a line to carry hue, or put a mass over a line |
| Let `{colors.accent-soft}` carry text — it is the **sole** pastel that may (the chip and `Hecho`) | Put text on any icon-mass-tier pastel: `dest-keep`, `dest-donate`, `dest-trash`, `icon-mass-neutral`, `icon-mass-ochre` |
| Let pastel back **glyphs** only, and keep every glyph out of `{colors.accent-soft}` | Put a glyph inside `{colors.accent-soft}` — that is the crack through which the two-tier system breaks |
| Keep the three destination hues **inside** their glyph | Let a destination hue appear as a field, tile, bar or band without its glyph in it |
| Use `{colors.accent-soft}` for the primary action | Fill `Hecho` with a destination hue — it would borrow that destination's meaning |
| Move all three destination hues together (L\*, chroma) | Adjust one destination hue alone, ever |
| Treat "no red" as *no alarm register* — a dusty rose at L\* 76 / C 15 is admitted | Use red as alarm, warning iconography, or exclamation marks anywhere |
| Separate surfaces by tone and a 1px hairline | Gradients, glow, blurred drop shadows, or any lighting model |
| Use the single global offset `translate(1.358, -1.358)`, 8% of size | Fixed-dp offsets, per-icon offsets, or a transverse offset across a glyph's axis |
| Keep stroke at `target_px × 24 / render_px`, target 1.5px @24px | 1px hairlines — tested, unrecoverable |
| Draw large simple masses; check axial extent ≥ 8u | Any icon mass below the axial threshold, or more than two masses in a glyph |
| Draw the seed with exactly **8 filaments**, at every size | **Nunca añadir rasgos** — never add filaments, and never fatten the pappus to chase a total-ink number |
| Judge trio parity by the contrast-weighted metric; keep the raw metric as the brake | Judge any glyph by mass alone |
| Set task text in Lora; everything else in Lexend | Lora in a second role, or Lexend in the task text "depending" — that is the signal to revert to all-Lexend |
| Size all type in `sp` with multiplier line-heights | `dp` type sizes, fixed dp line-heights, `maxLines`, or `ellipsize` on `{components.action-secondary}` |
| Let the 200% fold happen and verify it on a real device | Shorten, hard-break, or non-breaking-space the string `Otra más fácil / Ahora no` |
| Keep the FR-23 cumulative impact dashboard as the **single** declared *density* exception | Let that density propagate to any other surface |
| Keep the Archetype Template list on its own surface inside genesis, under the ordinary card, type and spacing rules | Let a list appear anywhere else, or let the template surface borrow the FR-23 dashboard's density licence |
| Offer the photo path as genesis' recommended action with **manual entry beside it** | Gate manual entry behind the photo path, or make the photo a precondition for anything |
| Celebrate completion identically every time | Scale celebration with quantity — no combos, no "you're on three", nothing that opens a door to more |
| Keep the duration chip tight at `{spacing.chip-to-task}` | Space the chip away from its task — proximity is what makes it the cost of *this* task |
| Keep `{spacing.task-to-actions}` the largest interior gap | Close the pause between reading and committing |
| Keep the air around the card a **minimum plus flex**, 48dp floor | A fixed value around the card — at 200% the card grows and fixed air breaks the layout |
| Keep one card and mostly empty space | Compress the card to fit more information |
| Set the seed's axis at **45.0°**, equal to the global offset vector | Any seed axis that leaves a transverse component — 53.0° was the bug, not the spec |
| Displace the hub circle toward the **leeward (dense)** edge, *sotavento* | Call the dense edge "windward" — it is the downwind edge, where the angular spacing closes |
| Draw motion dashes only at **56px and above** | Dashes at glyph scale, or anywhere in `{components.destination-flow}` — the trio seed is at rest, by decision |
| Keep the line layer in `{colors.ink-primary}`; the reference's petrol-blue `#134C5F` was **considered and rejected** | Re-open a coloured ink for the line layer |
| Keep one stroke width per render size; tapered variable-weight strokes were **considered and rejected** | Re-introduce taper, brush character or variable weight to chase the reference's delicacy |
| Give the consent gate `{components.action-equal-pair}` — two hairline buttons, **zero recommended actions** | Fill either consent button with `{colors.accent-soft}` — filling one recommends it, which is the dark pattern FR-25 forbids |
| Add a type role only when an existing role would carry a meaning that is not its own | Reuse `{typography.action-primary}` as a heading or as a figure — a button's weight on a screen with no button |
| Reflow `{components.dashboard-highlight-row}` to one column when a caption passes two lines | Shrink the grid, scale the dp gaps, or let a three-column row survive as 101dp columns of 5-line captions |
| Let the volume figure stand with **no glyph** | Place a destination glyph beside copy whose meaning it inverts — the box glyph *is* `Quedármelo` |
| Hold photographs in `{components.photo-frame}`, labels outside it | An icon-mass pastel as a stand-in for a photograph, or a shimmer/spinner inside a loading frame |

**Three exceptions are declared in this system, and no fourth is implied.** Each names the invariant it departs from. The **FR-23 dashboard** departs on information density. The **per-scan consent gate** (`{components.action-equal-pair}`) departs on the one-recommended-action rule, which it carries at zero. The **genesis zone** exceeds that same rule in the other direction, and admits the system's only list. All three are written as exceptions so that none becomes a precedent; anything else claiming an exception is a defect.

The FR-23 exception is bounded on purpose: the cumulative impact dashboard is inherently multi-value and is allowed to be the one dense surface in the app — the surface where the volume string `≈ 3 cajas liberadas` lives. Three things make it safe and all three are checkable: **no value on the screen admits a denominator** (the mechanism, stated in full in `EXPERIENCE.md`), the volume line carries **no glyph** (see the glyph-adjacency rule under `{components.icon-glyph}`), and `{components.dashboard-highlight-row}` **reflows rather than shrinks** at 200%. The weekly self-report `Esta semana, ¿cuánto te ha agobiado la casa?` is the other place where more than one value shares a surface; it is ambient and dismissible, and it inherits the ordinary card and type rules rather than the dashboard's licence.

## Open Questions

None of these is answered anywhere in the decision record; none should be filled in with a plausible value.

1. **The Ajustes glyph.** No construction reads unambiguously as "settings". The gear is the only universally learned form and this treatment forbids it. Two legitimate exits — a text label beside the toggle, or the gear admitted as a documented **single-ink** exception (line, no mass) — and neither has been chosen. **Now load-bearing rather than cosmetic:** the Dispenser's single quiet affordance (see `EXPERIENCE.md`) is the one departure from the primary surface and it has to be marked by something, so an unresolved glyph now blocks a sited surface rather than a Settings row.
2. **The pompom circle's exact radius.** Specified as a coverage constraint (larger than 1.70u, displaced toward the dense side, entire free edge under filaments). It is the one number in the system settled at draw time rather than by measurement, and the drawn value is not yet recorded.
3. **The second locale.** The PRD's FR-9 says no interrupted, incomplete or overdue state is displayed *"in either language"*. The second language is never named. Its script and typical string length bear on the 200% fold and on the type ramp.
4. **Dark-mode destination hues.** `{colors.dest-keep-dark}`, `{colors.dest-donate-dark}` and `{colors.dest-trash-dark}` were hand-authored against the *superseded* light trio, when the third slot was a light sand rather than a dusty rose. They have not been re-authored against version C, and their equal-weight parity as 6px bars has not been measured. There is no dark counterpart to `{colors.icon-mass-ochre}` either. Nor is there a dark rule for the secondary ink's three uses — `{components.action-secondary}`, `{typography.support}` and the zone-marker's line — which is why `ink-secondary-dark` and `border-strong-dark` sit defined and unreferenced: they are the unfinished edge of a dark palette never completed past the destinations. This OQ owns the whole dark-mode completion pass (widened 2026-08-26 by the rubric review).
5. **The destination labels' type role.** `Quedármelo` / `Donar o vender` / `Tirar o soltar` sit on the light ground in `{colors.ink-primary}`, but no role in the ramp was assigned to them. The three roles added by the key-screens pass do not cover this: `{typography.screen-heading}` is a heading, `{typography.metric-numeral}` is a figure and `{typography.caption-warm}` is a sentence the app wrote, and a destination label is none of the three. Still unanswered.
6. **Where the completed card goes.** The card leaves rather than changing content (Android's gesture vocabulary governs, and the app is Android-only). That it must exit the screen entirely and never fly toward a counter, pile or badge — and whether its departure runs along the global 45° offset axis, making the departure itself the celebration — is proposed but unconfirmed.
7. **System chroma.** Version C raises chroma across the whole system from ~10 to ~15, not only the destination row, and Aliento was chosen for being airy. Whether that reads as too present has not been judged in situ; the lever, if so, is all three down together to ~13. `{colors.icon-mass-ochre}` now sits in the same chroma band, so it moves with them if the lever is ever pulled — never alone.
8. **What `{formats.short-date}` does once an album entry is older than a year.** Surfaced by specifying the format, and not answerable from what exists. The format carries no year on purpose — a year turns a date into a measure of how long ago, which is the deficit reading this product removes — but the Transformation Album is permanent and local, so `12 ago` will eventually be ambiguous between two years. The three exits (a year appears only past twelve months; the album groups by year outside the caption; the date is dropped entirely and the place carries the caption alone) are all plausible and none is chosen. Nothing here should be filled in with a plausible value.
9. **Whether the Hoja's ochre crescent reads at 24px under a secondary-ink line.** Surfaced by resolving the Hoja's mass, and not answerable from what exists: the two-tier system's Δ L\* 18–20 threshold was measured for a mass sitting under an `{colors.ink-primary}` line, and the zone marker's line is `{colors.ink-secondary}` at L\* 41.48, rendered at `{spacing.glyph-zone-marker}`. The mass clears the threshold against the *ground* (Δ L\* 21.59), but the line-to-mass relationship the threshold was calibrated against is not the one on this glyph. The Hoja's axial extent at 24px has also not been measured against the 8u minimum. Nothing here should be assumed to pass by inheritance.
10. **The Micrófono glyph.** FR-32's dictation affordance on Manual Capture needs a mark, and the nine-glyph set does not have one. It must follow the two-plate treatment — mass under line, axial extent ≥ 8u, 1.5px stroke at 24px — and a capsule-plus-stem form is simple enough to survive it, but nothing is drawn or measured. One extra demand no other glyph carries: the affordance must read as *press to speak* without animation, and the static treatment has never had to express an interaction. `EXPERIENCE.md` already specifies the behaviour (Component Patterns, microphone affordance); this is the visual half, and it blocks that surface's final layout rather than its behaviour.
11. **The energy control's visual half.** `EXPERIENCE.md` gives it real behavioural rules (one tap, three values, only 🔴 narrows) and this spine gives it nothing: no component, no token, no mention — and whether 🟢🟡🔴 are literal emoji or drawn marks under the two-plate treatment is undecidable from the spines, on the surface where "the screen must not add weight" is rule zero. Emoji would be the only borrowed glyphs in the app; drawn marks add three more to the nine-glyph set. Folded into the same question: `{components.size-option}` claims to be "the only selector in the app" and the energy control also selects — either the claim narrows to the only *multi-option* selector, or the energy control is not a selector. Surfaced by the 2026-08-26 rubric review; not answerable from the record.
12. **The ambient container.** Three one-tap-dismissible suggestions (seasonal, snowball, quarantine follow-up) and the persistent Sunday self-report all live on the Dispenser per `EXPERIENCE.md` — and no spine says what any of them looks like: no card, no banner, no typography role, no placement relative to `{components.dispenser-card}`. The self-report is the sharp case: it persists until answered on the one surface where information is capped and "one card, mostly empty space" is the deliverable, so a persistent second element there is a layout decision nobody has written down. One container spec could serve all four, with the persistence difference carried in behaviour rather than chrome. Surfaced by the 2026-08-26 rubric review.
