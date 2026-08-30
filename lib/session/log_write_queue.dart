/// Serializes shell operations that derive from and append to the same log.
///
/// This is coordination only, never session state: every operation still
/// reads the log as its source of truth after its predecessors complete.
final class LogWriteQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then<T>((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> get settled => _tail;
}
