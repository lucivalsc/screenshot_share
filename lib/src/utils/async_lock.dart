import 'dart:async';

/// A single-slot asynchronous lock.
///
/// Replaces the bare `bool` reentrancy flags used up to version 0.1.4, which
/// could be left stuck at `true` when an awaited operation never completed and
/// made "already running" indistinguishable from a real failure.
class AsyncLock {
  Completer<void>? _active;

  /// Whether an operation currently holds the lock.
  bool get isLocked => _active != null;

  /// Runs [action] if the lock is free, otherwise returns `null` immediately.
  ///
  /// The lock is always released, including when [action] throws.
  Future<T?> runIfFree<T>(Future<T> Function() action) async {
    if (_active != null) return null;

    final completer = Completer<void>();
    _active = completer;
    try {
      return await action();
    } finally {
      _active = null;
      completer.complete();
    }
  }

  /// Waits until the lock is free. Returns immediately when it already is.
  Future<void> waitUntilFree() async {
    while (_active != null) {
      await _active!.future;
    }
  }
}
