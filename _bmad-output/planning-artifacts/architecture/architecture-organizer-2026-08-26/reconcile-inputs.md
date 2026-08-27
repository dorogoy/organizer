# Reconcile — what the inputs required and the AD structure dropped

Checked `prd.md`, `addendum.md`, `EXPERIENCE.md` and `DESIGN.md` against the drafted spine, looking for quiet requirements the AD structure lost.

**Verdict:** two real misses, both in the same family, plus one small one. Everything else landed.

## R1 — HIGH. AD-4 defines a day and the product needs three calendar periods.

AD-4 fixed the day and routed six requirements through it. But the inputs also depend on a **week** and a **season**, and neither has an owner:

- **The week.** FR-31 rotates exactly one FlyLady zone per week over the *active* clusters. SM-2's self-report *"appears on the first opening from Sunday onward, persisting until answered that week"* — so the week's start day is load-bearing for both the rotation and the metric, and Sunday-anchored vs Monday-anchored give different answers.
- **The season.** FR-15's seasonal suggestion may appear *"never more than once per season per project"*, which requires a season boundary the spine never defines.

Two units will pick differently, exactly as they would have with the day. **Fix: widen AD-4 from "one definition of a day" to a single calendar authority owning day, week and season.**

## R2 — MEDIUM. Export state's settings-only visibility has no architectural owner.

FR-30 requires export state — destination, last success, last failure and its cause — readable **in settings only**, and `EXPERIENCE.md`'s *Export Silence* makes the absence of any trace elsewhere a specified behaviour rather than an omission: *"no reminder, no badge, no backup-age indicator, no 'last exported' line and no failure toast"*. AD-13 covers the format and the round-trip and says nothing about who may observe the export's outcome. A story wiring a failure toast would violate no AD. **Fix: add the rule to AD-13 — the export adapter surfaces its outcome to the settings surface and to nothing else, and emits no user-visible signal on failure.**

## R3 — LOW. FR-22's volume tags are absent from the act vocabulary.

`bolsa / caja / caja grande / mueble` as an optional coarse batch tag during purge steps. The vocabulary's generic shape covers it, but naming it prevents a unit inventing a numeric volume field — which FR-22 forbids (*"never as a precise figure or a percentage"*). **Fix: name the tag on the purge act.**

## Landed correctly — checked, no action

- Tone and copy as a product surface, and the flat-table audit requirement → AD-15.
- The two declared UX exceptions (FR-23's density, the consent gate's zero recommended actions) → conventions, Testing row.
- `DESIGN.md`'s token system as single source of truth → conventions.
- The 200% floor and its one named layout degradation → conventions (no `maxLines`, no ellipsis).
- §8's three independent instances, never merged → single-user model + AD-13's no-merging import.
- A5's "cap is per-session, bag is per-day; multiple pockets per day are legitimate" → AD-1, AD-4, AD-19.
- FR-19's purge-first rule and FR-5's depth cap → AD-20's single resolver.
- Origin never surfaced in the Dispenser → AD-14.
- Airplane mode as a supported condition, never an error → AD-7 (no queue, no retry) + AD-9 + the errors convention.
- FR-21's blind Quarantine timer → derived from `box_created` + the calendar authority.
