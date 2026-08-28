/// The clock port: the only way an instant enters the core from outside.
///
/// The core never reads a wall clock itself; it is handed an instant (AD-3).
/// Deliberately minimal — its real shape arrives with its first consumer
/// (Story 1.4).
abstract interface class ClockPort {
  /// Returns an instant, taken by the shell's adapter and handed to the core.
  DateTime instant();
}
