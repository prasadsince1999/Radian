/// Injectable clock abstraction for deterministic time in tests.
///
/// Production code uses [Clock.system]. Tests inject a [FixedClock] or
/// [TickingClock] so no test ever calls [DateTime.now()] directly.
///
/// This file has **no Flutter imports** — it belongs to the pure-Dart engine
/// layer and can be used by domain, data, and geometry code.
library;

/// Provides the current wall-clock time.
abstract class Clock {
  const Clock();

  /// The system clock — delegates to [DateTime.now()].
  static const Clock system = _SystemClock();

  /// Current instant.
  DateTime now();
}

/// Production clock backed by the OS.
class _SystemClock extends Clock {
  const _SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test clock frozen at a single instant.
///
/// ```dart
/// final clock = FixedClock(DateTime(2026, 9, 29, 14, 30));
/// expect(clock.now(), DateTime(2026, 9, 29, 14, 30));
/// ```
class FixedClock extends Clock {
  final DateTime _fixed;
  const FixedClock(this._fixed);

  @override
  DateTime now() => _fixed;
}

/// Test clock that advances by a fixed step on every call.
///
/// Useful for simulating time progression without real delays.
///
/// ```dart
/// final clock = TickingClock(
///   start: DateTime(2026, 1, 1),
///   step: Duration(minutes: 1),
/// );
/// clock.now(); // 2026-01-01 00:00
/// clock.now(); // 2026-01-01 00:01
/// ```
class TickingClock extends Clock {
  DateTime _current;
  final Duration step;

  TickingClock({required DateTime start, this.step = const Duration(seconds: 1)})
      : _current = start;

  @override
  DateTime now() {
    final result = _current;
    _current = _current.add(step);
    return result;
  }

  /// Advance without reading.
  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  /// Jump to a specific instant.
  void setNow(DateTime instant) {
    _current = instant;
  }
}
