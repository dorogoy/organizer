# Epic 7 Context: Seeing What I Did

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make completed work visible as a calm, ungraded fact: offer a before/after view of a scanned space, preserve completed pairs in a private local Transformation Album, and show cumulative achievements without quotas, comparisons, or deficit framing. This epic consumes scan/milestone facts and `item_triaged` acts produced by earlier capabilities; it must not infer progress from photographs. No product-brief artifact is present in the planning directory, so this context uses the available epics, PRD, architecture, and UX artifacts.

## Stories

- Story 7.1: The Before/After reward
- Story 7.2: The album substrate — the derived read model and the deletion acts
- Story 7.3: The Transformation Album — the contextual gallery
- Story 7.4: The cumulative impact dashboard
- Story 7.5: The snowball — the comfortable-day run and the Time Bag suggestion

## Requirements & Constraints

- After work on a scanned space reaches a session or project milestone, offer an after photo and a side-by-side diff. Save completed pairs automatically. If no Before photo exists, show `Un trabajo estupendo`, not a one-photo comparison or placeholder. Avoid all result grading: no negative framing, result adjectives, ratings, percentages, or sharing.
- The album is private, local, and offline. Album contents are never sent by the app and leave the device only through user-initiated export. Support individual deletion and one-action purge. The album and dashboard have no empty state: neither exists as a reachable surface before the first transformation.
- The dashboard shows cumulative minutes, completed Micro-tasks, liberated items and approximate volume, plus album highlights. Apply the denominator rule independently to every value: no target, average, period comparison, rate, percentage, completion ratio, or “of N” framing. Only completed achievements may appear; internal counts such as skips, declines, deal windows, and the comfortable-day run stay invisible.
- The snowball is one gentle ambient-strip suggestion after at least 10 comfortable days (a session, a completion, and no session beyond its declared pocket per day). It may raise the Time Bag by at most 5 minutes, never appears at the 30-minute cap, has no effect when dismissed, and must not nag. Accepting adds exactly 5 minutes, capped at 30, and starts a fresh run.
- Liberated-item figures come from `item_triaged` destination taps and optional coarse volume tags (`bolsa`, `caja`, `caja grande`, `mueble`). Display volume as an approximation with its unit, never as a precise count or percentage; infer nothing from photos. Use the repository’s test/format/analyze gate, forbidden-vocabulary lint, deterministic core, and externalized Spanish string table.

## Technical Decisions

- The album is a derived read model over image bytes and append-only log acts; there is no album table or editable album manifest. Use `album_entry_added` and `album_entry_deleted` in the log. Individual deletion appends the delete act and unlinks the app-private source in the same operation; purge unlinks all app-private album files.
- Store album bytes through the `Files` port in app-private storage. Exported album blobs are content-addressed, so deleting a local source cannot invalidate an already committed export generation. Export/import coordination and retained-generation rules belong to the single foreground coordinator.
- Keep derivation in the pure-Dart core (`core/derive`) and UI rendering in the shell; Riverpod wraps the read facade and commands. The core has no Flutter, Drift, plugin, `Random`, wall-clock, or `dart:io` dependency. Settings changes and the snowball run are derived from log facts, not stored counters; an extended session is judged by its original pocket.
- AD-26 is a hard boundary: achievement figures may cross to the dashboard, while internal signals never cross as numbers. The read facade must not expose collections of pending or captured tasks. Core invariants use machine-side Dart tests; widget tests cover read-facade/command consumers, with no golden tests.

## UX & Interaction Patterns

- Use `photo-frame`: 3:4, 1px hairline, 14px full-size radius; paired frames are equal in size and height, share the same corner, and are 16dp apart. Put `Antes` and `Después` outside the frames. Loading is the correctly shaped base-surface frame with no spinner, shimmer, gradient, or pastel placeholder.
- The diff has no caption, adjective, rating language, or share action. Its secondary action is `Cerrar`, never a continuation prompt. Celebration never scales with quantity or delays/gates the next card.
- Album thumbnails use the 4px thumb radius. Navigation is contextual: reward → album → dashboard, with no navigation bar, destination list, or browse surface. A dashboard highlight is a way into the album.
- `dashboard-highlight-row` is three columns at default scale, with thumbnail, place, and short-date. When a caption exceeds two lines, reflow to one column per row; never shrink, truncate, or scale gaps. This is the one named, expected 200% layout degradation. The volume line has no glyph, and all copy remains authored in the ARB table. The snowball is a support-type ambient-strip resident; at most one resident is visible.

## Cross-Story Dependencies

- Epic 5 supplies scanned spaces, Before photos, milestone context, and the camera’s absent/permission-refused degradation; the reward must never expose a dead camera action.
- Epic 6 supplies `item_triaged` counts and volume tags; Epic 7 reads those facts rather than recomputing them.
- Epic 2 owns the ambient strip and Time Bag; Story 7.5 adds behaviour/data as a resident without new chrome.
- Story order is 7.1 → 7.2 → 7.3 → 7.4 → 7.5: the reward creates the album entry, the substrate provides the derived model and mutation acts, the gallery exposes them, and the dashboard sits behind it. Epic 9 consumes Before/After instrumentation and export-reachable album blobs.
