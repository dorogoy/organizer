# Epic 7 Context: Seeing What I Did

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Show the user the same corner of their home before and after, in two plates of equal size that let the comparison speak without anyone grading it; keep those pairs in a private, local album they can delete piece by piece; and add a cumulative account of what they have actually done that no denominator can turn into a quota. This epic reads what the decluttering and scan flows already wrote — it renders achievements, it never recomputes or scores them.

## Stories

- Story 7.1: The Before/After reward
- Story 7.2: The local Transformation Album
- Story 7.3: The cumulative impact dashboard

## Requirements & Constraints

- **Reward (FR-17):** after completing a session or project milestone on a scanned space, the user can shoot an "after" photo and receive a side-by-side diff. No negative framing — in fact no adjective about the result at all (*mejor*, *más despejado*, *casi* each reintroduce a scale). A milestone with no Before photo shows `Un trabajo estupendo` — never a one-plate diff or placeholder — and still counts for instrumentation series (c). Completed diffs are saved to the album automatically.
- **Album (FR-18):** private and local; the app never sends album contents — they leave the device only via user-initiated export. Entries deletable individually; the whole album purgeable in one action. Both album and dashboard work fully offline.
- **Dashboard (FR-23):** shows cumulative minutes, completed Micro-tasks, liberated items/volume, and album highlights. **Denominator rule, value by value:** no value on the screen admits a denominator — no "de 7 días", no average, no target, no period comparison, no rate, no percentage, no completion ratio. Reviewable form: *if a value could be given a denominator, it does not belong on this screen*.
- **Density exception:** the dashboard is the app's single declared information-density exception, written as an exception so it is not a precedent; its density must not propagate to any other surface.
- **Snowball (part of FR-23):** after ≥ 10 comfortable days — each with ≥ 1 session, ≥ 1 completed Micro-task, and no session beyond its declared pocket — a one-tap-dismissable suggestion to raise the Time Bag by ≤ 5 min may appear on the ambient strip. Suppressed when the bag is already at its 30-min top. Accepting raises it exactly 5 min, appends a settings-change log entry, and resets the run to zero; dismissing (`Está bien así.`) hides it while the run stands and never becomes permanent loss or a nag. The comfortable-day run is an internal count, never surfaced anywhere.
- **Liberated-items figures** come from the triage act's per-destination tap counts and coarse volume tags (bolsa / caja / caja grande / mueble) — displayed as approximation with unit visible (≈ 3 cajas liberadas), never a precise figure or percentage. Nothing is inferred from photos; this epic never recomputes them.
- Build-wide gates apply: the story completion gate (tests + format + analyze), the forbidden-vocabulary lint (no overdue/late/missed/streak/debt identifiers), externalized Spanish strings with no runtime concatenation, determinism in the core.

## Technical Decisions

- **Only achievement figures cross to the shell (AD-26).** Cumulative minutes, completed tasks, liberated volume, album highlights may cross and render only on the dashboard. Internal signals — decline counts, the comfortable-day run, deal windows, any skip total — never cross as numbers, under any circumstances.
- **No album table (AD-13).** The album read model is derived over stored image bytes and log acts; an independently editable manifest would let one unit delete by removing a row while another deletes by appending an event. Album mutation is log entries (`album_entry_added`, `album_entry_deleted`, per the past-tense snake_case vocabulary); deletion unlinks the app-private source file in the same operation; the purge unlinks all album files.
- **Album bytes are content-addressed blobs in app-private Files storage** (the `Files` port / `files/` adapter). Deleting a source never invalidates an already-committed export generation (retained-generation reachability).
- **Code homes:** reward surface in the UI shell's reward module; dashboard figures derived in `core/derive`, rendered by the dashboard UI. Core stays pure (no Flutter/drift/plugin imports, no `Random`, no wall-clock, no `dart:io`); shell state management is Riverpod wrapping the read facade and commands.
- **Snowball:** the comfortable-day run is a derived fact computed in the core; the suggestion is a new resident of the existing ambient strip (data, not new chrome). A session the user extended is scored against its **original** declared pocket, so an extension is never counted as a marathon. Settings changes are events, not stored state — the +5 min acceptance appends a settings-change entry.
- Read facade never returns collections of pending/captured tasks; derived signals are named as facts. Testing: core invariants under `dart test` on the machine; widget tests only where a surface consumes the read facade or a command; no golden tests.

## UX & Interaction Patterns

- **`photo-frame`:** 3:4 aspect, 14px radius at full size, 1px hairline edge. The Before/After pair is equal size, at equal height, with the same corner, 16dp apart — the moment one plate is larger, higher, or framed differently, the layout has an opinion, and an opinion is a rating. Labels `Antes` / `Después` sit **outside the frame**, never over the image. While loading: an empty frame of the right shape on the base surface — no spinner, no shimmer, no gradient. An icon-mass pastel is never a stand-in for a photograph.
- **The diff carries only the two labels:** no caption, no share action, no rating language; the pair is private and local. The secondary control **closes**: `Cerrar`, never a variant of *seguir* — the closing rule binds hardest here. Celebration must close, never scale with quantity, and never gate the next card.
- **Album thumbnails:** `photo-frame` at the 4px thumb radius (14px on a ~100dp plate eats the photograph's corners).
- **Contextual-only navigation:** the album is reached only from the reward when a transformation completes; the dashboard only from the album. Neither has an empty state — both are unreachable until a first transformation exists. No nav bars, no destination lists.
- **`dashboard-highlight-row`:** three columns at default scale, each a thumbnail plus place and short-date (day without leading zero + non-breaking space + three-letter lowercase Spanish month, no year — e.g. `12 ago`). Reflows to one column per row as soon as a caption would break beyond two lines — trigger expressed in lines, not dp, so it survives a different line breaker and a second locale. It never shrinks, never truncates, never scales the dp gaps. At 200% this reflow is the app's **one named, expected degradation** — a layout fact, not a defect to file. Tapping a highlight is a way into the album, not a browse surface.
- **The volume line carries no glyph** (glyph-adjacency rule: the system's box glyph *is* `Quedármelo`; beside a sentence about boxes released it would invert the meaning). Duration figures use the fixed format: value + non-breaking space + unit, largest unit first (`4 h 25 min`).
- **Snowball suggestion** lives on the ambient strip: sentence in support type, tappable where an accept exists and never a primary action, ✕ dismiss at 48dp; at most one strip resident visible at a time.
- All copy is authored, pinned and externalized in the single string table; the anti-shaming audit must be reviewable as a flat ARB table.

## Cross-Story Dependencies

- **Reads Epic 6's output:** per-destination counts and volume tags derive from `item_triaged` acts; nothing here recomputes them.
- **Depends on Epic 5:** Before photos exist only for scanned spaces; the reward's shoot action follows the Cámara entry's own rule — absent when the camera is disabled or its permission refused, or degrading to the Manual Capture path — never a dead button on the reward surface.
- **Ambient strip is Epic 2's component** — the snowball arrives as a new resident carried in behaviour/data, not new chrome.
- **Instrumentation series (c)** (Before/After pairs per project milestone) is written here but assembled and rendered by Epic 9's series work; the content-addressed album blobs feed Epic 9's export generations, whose coordinator/property-test rules live there.
- **Story order is the navigation order:** 7.1 → 7.2 → 7.3 — the album exists only as the reward's completion, the dashboard only behind the album.
