/// The pool-fact contract (AD-14): an immutable fact that an item entered
/// the task pool, written once and never updated — the database refuses it
/// (AD-2).
///
/// Every pool fact carries a shell-minted UUIDv7 id, its origin set at
/// genesis, a size from the 1-3-5 taxonomy (never free minutes), and its
/// creation instant plus the local offset in force. No owner, no date-only
/// value, no assignment to a future day (AD-1).

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
}
