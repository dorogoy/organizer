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

  /// The Origin Context (AD-14, since Story 3.2): a manual capture's own
  /// single trimmed line — the whole context the user gave, nothing more,
  /// later re-sliced by Rescue Mode. Null for origins whose context lives
  /// elsewhere (the catalogue names shipped tasks; a Slicer output is its
  /// own fact). Written once at genesis, never updated.
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
  /// size is the fixed `instant` band, and the depth cap — no rescue
  /// of a rescue step — reads this field. Written once at the step's
  /// genesis, never updated; the parent itself may be a pool fact or
  /// a shipped catalogue entry (the id is either shape's own).
  final String? rescueOf;

  /// The Slicer's own duration tag, verbatim (Story 4.6, FR-5):
  /// non-null exactly on a rescue step, 1–60 seconds as parsed in
  /// core against the rescue contract. Every duration-consuming rule
  /// — the 🔴 ceiling, the pocket — reads the estimate; the taxonomy
  /// size governs only same-size precedence and shape counting, so an
  /// estimate never re-bands a size and a size never re-derives an
  /// estimate.
  final int? estimateSeconds;
}
