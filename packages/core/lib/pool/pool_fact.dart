/// The pool-fact contract (AD-14): an immutable fact that an item entered
/// the task pool, written once and never updated — the database refuses it
/// (AD-2).
///
/// Every pool fact carries a shell-minted UUIDv7 id, its origin set at
/// genesis, a size from the 1-3-5 taxonomy (never free minutes), and its
/// creation instant plus the local offset in force — and, since Story 3.2,
/// an optional Origin Context: the manual capture's own single line. No
/// owner, no date-only value, no assignment to a future day (AD-1).

library;

/// Where a pool item came from, written once at creation and never updated
/// (AD-14). Rescue steps inherit the parent's origin.
enum Origin {
  /// A task instantiated from the shipped Evergreen catalogue.
  shipped,

  /// A task typed in by hand.
  manual,

  /// A task produced by the on-device Local Slicer path.
  local,

  /// A task produced by the BYOK cloud Slicer.
  cloud,
}

/// The three-member size taxonomy (FR-27): a task is one of three sizes,
/// never a free number of minutes. Members are named for the PRD's size
/// classes, not the composition digits — the Focus Chunk is the "1" of the
/// 1-3-5 day and is filled by the 10–15 min size, Micro-maintenance is the
/// "3", and Instant Habits are the "5".
enum Size {
  /// An Instant Habit: about thirty seconds — the "5" of the 1-3-5 day.
  instant,

  /// Micro-maintenance: two to three minutes — the "3" of the 1-3-5 day.
  maintenance,

  /// The Focus Chunk size: ten to fifteen minutes — the "1" of the 1-3-5
  /// day; a day never holds two.
  focus,
}

/// The instant band's inclusive ceiling, in seconds (FR-27, Story
/// 5.7): an estimate at or under it bands `instant`, the same 60 s
/// ceiling a 🔴 day admits by.
const int bandInstantMostSeconds = 60;

/// The maintenance band's inclusive ceiling, in seconds (FR-27,
/// Story 5.7): an estimate over the instant ceiling and at or under
/// it bands `maintenance`; anything over bands `focus`. The seam at
/// 599/600 is declared totality — "61 s–9 min" leaves 9:00–9:59
/// unmapped, and it reads maintenance (closer to 9 min than to 10);
/// no producible estimate sits there (rescue ≤ 60, scan 180–300).
const int bandMaintenanceMostSeconds = 599;

/// The product's ONE duration→size rule (Story 5.7, FR-27): the
/// fixed banding an estimate maps onto a taxonomy size by — ≤ 60 s
/// → `instant`, 61–599 s → `maintenance`, ≥ 600 s → `focus`. Every
/// duration-consuming rule reads the ESTIMATE, never the size: the
/// pocket, the 🔴 filter and the session/bag ceiling all read
/// `estimateSeconds ?? estimateSecondsOf(size)`, so an estimate
/// never re-bands a size and a size never re-derives an estimate.
/// The size governs only same-size precedence and the 1-3-5 shape
/// counting — and Focus-slot eligibility, when it arrives, is by
/// candidate class, never size (Story 5.9's rule, recorded here as
/// the banding's own jurisdiction). Both Slicer landings route
/// through this one function (rescue 1–60 s, scan 180–300 s); no
/// second duration→size mapping exists anywhere.
Size sizeOfEstimateSeconds(int seconds) {
  if (seconds <= bandInstantMostSeconds) {
    return Size.instant;
  }
  if (seconds <= bandMaintenanceMostSeconds) {
    return Size.maintenance;
  }
  return Size.focus;
}

/// An immutable pool fact: an item entered the pool at an instant, with an
/// origin and a taxonomy size. Retirement is a derivation (AD-25), never a
/// deleted row; the schema offers no update path at all (AD-2). Only the
/// core constructs domain objects (AD-5) — the shell hands the port an
/// inert record.
final class PoolFact {
  const PoolFact({
    required this.id,
    required this.origin,
    required this.size,
    required this.instantUtcMicros,
    required this.offsetSeconds,
    this.originContext,
    this.dictated,
    this.rescueOf,
    this.estimateSeconds,
    this.stepText,
  });

  /// The shell-minted UUIDv7 id (conventions: ids are minted in the shell,
  /// at the commit of the act or fact they name).
  final String id;

  /// Set at genesis, immutable thereafter (AD-14).
  final Origin origin;

  final Size size;

  /// The creation instant, in UTC microseconds since the epoch.
  final int instantUtcMicros;

  /// The local UTC offset in force when the fact was written, in seconds
  /// east of UTC — a day is later computed from this stored offset, never
  /// from the device's current zone (AD-4).
  final int offsetSeconds;

  /// The Origin Context (AD-14, since Story 3.2, renegotiated Story
  /// 5.7): one line of retained source text, PRD:96's shape — a
  /// manual capture's own single trimmed line (Story 3.3); a rescue
  /// step's own step text (Story 4.6); a scan step's retained space
  /// description, the Slicer's structured description of the analyzed
  /// space, at most `scanDescriptionTextMost` units and shared by every
  /// step of the slice (Story 5.7, FR-16). Null on shipped — a
  /// catalogue fact never carries one. Written once at genesis, never
  /// updated.
  final String? originContext;

  /// Whether dictation authored the line (FR-32, Story 3.4): a
  /// provenance fact, outside origin arithmetic — a dictated capture's
  /// origin is `manual` exactly as a typed one, dictation being an
  /// input method and not a genesis path. Written once at creation
  /// and never updated: keyboard correction after dictation keeps it
  /// `true`, because it records who authored the line, not its final
  /// wording. Nullable for schema v7's sake alone — old rows read
  /// `null`, deriving as not-dictated — and readable on the validator
  /// surface only (AD-26): no card anywhere marks a capture as spoken.
  final bool? dictated;

  /// The parent item this fact rescues (Story 4.6, FR-5): non-null
  /// exactly on a rescue step, naming the stuck parent whose re-slice
  /// minted it. A step's origin inherits the parent's (AD-14), its
  /// size comes from the one fixed banding (`sizeOfEstimateSeconds`
  /// — instant across the rescue band's 1–60 s), and the depth cap
  /// — no rescue of a rescue step — reads this field. Written once
  /// at the step's genesis, never updated; the parent itself may be
  /// a pool fact or a shipped catalogue entry (the id is either
  /// shape's own).
  final String? rescueOf;

  /// The Slicer's own duration tag, verbatim (Story 4.6, FR-5;
  /// renegotiated Story 5.7): non-null exactly on Slicer-authored
  /// steps — a rescue step (1–60 s, parsed in core against the
  /// rescue contract) or a scan step (180–300 s, parsed against the
  /// scan contract) — and null everywhere else, a manual capture's
  /// estimate being its size's canonical value BY RULE (the
  /// `?? estimateSecondsOf(size)` fallback every reader applies;
  /// nothing is stored on the capture path). Every
  /// duration-consuming rule — the 🔴 ceiling, the pocket, the
  /// session/bag charging — reads the estimate; the taxonomy size
  /// governs only same-size precedence and shape counting
  /// (`sizeOfEstimateSeconds`'s own jurisdiction), so an estimate
  /// never re-bands a size and a size never re-derives an estimate.
  final int? estimateSeconds;

  /// The step's own words (Story 5.7, FR-16): non-null exactly on a
  /// scan step fact — the Slicer-authored task text, distinct from
  /// the Origin Context (the space description the whole slice
  /// shares as `originContext`). A rescue step carries none: its
  /// text already lives in its `originContext`. Written once at the
  /// fact's genesis, never updated; a future re-slice composes
  /// `rescuePromptFor(originContext, stepText)` with zero joins
  /// (FR-5).
  final String? stepText;
}
