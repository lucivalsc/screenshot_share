import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_telegram/src/utils/async_lock.dart';

void main() {
  test('runs the action and reports its value', () async {
    final lock = AsyncLock();

    final result = await lock.runIfFree(() async => 42);

    expect(result, 42);
    expect(lock.isLocked, isFalse);
  });

  test('refuses a second caller while busy', () async {
    final lock = AsyncLock();
    final gate = Completer<void>();

    final first = lock.runIfFree(() async {
      await gate.future;
      return 'first';
    });

    // The lock is held, so the second call is rejected immediately with null
    // instead of being reported as a failure.
    expect(await lock.runIfFree(() async => 'second'), isNull);
    expect(lock.isLocked, isTrue);

    gate.complete();
    expect(await first, 'first');
    expect(lock.isLocked, isFalse);
  });

  test('releases the lock when the action throws', () async {
    final lock = AsyncLock();

    // This is the bug class that left 0.1.4's boolean flags stuck at true,
    // blocking the feature for the rest of the process lifetime.
    await expectLater(
      lock.runIfFree(() async => throw StateError('boom')),
      throwsStateError,
    );

    expect(lock.isLocked, isFalse);
    expect(await lock.runIfFree(() async => 'ok'), 'ok');
  });

  test('is reusable across sequential calls', () async {
    final lock = AsyncLock();

    for (var i = 0; i < 5; i++) {
      expect(await lock.runIfFree(() async => i), i);
    }
  });

  test('waitUntilFree resolves after the holder finishes', () async {
    final lock = AsyncLock();
    final gate = Completer<void>();

    final running = lock.runIfFree(() async {
      await gate.future;
      return true;
    });

    var freed = false;
    final waiter = lock.waitUntilFree().then((_) => freed = true);

    expect(freed, isFalse);

    gate.complete();
    await running;
    await waiter;

    expect(freed, isTrue);
    expect(lock.isLocked, isFalse);
  });
}
