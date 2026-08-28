/// The store port: the core's only view of persisted facts.
///
/// Deliberately minimal — it grows with its first consumer (Story 1.3), and
/// adapters return inert row shapes, never domain objects (AD-5).
abstract interface class StorePort {}
