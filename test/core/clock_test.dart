import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/clock.dart';

void main() {
  group('Clock abstraction', () {
    test('system clock returns roughly now', () {
      final before = DateTime.now();
      final result = Clock.system.now();
      final after = DateTime.now();

      expect(
        result.isAfter(before) || result.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        result.isBefore(after) || result.isAtSameMomentAs(after),
        isTrue,
      );
    });

    test('FixedClock always returns the same instant', () {
      final fixed = DateTime(2026, 9, 29, 14, 30);
      final clock = FixedClock(fixed);

      expect(clock.now(), fixed);
      expect(clock.now(), fixed);
      expect(clock.now(), fixed);
    });

    test('TickingClock advances by step on each call', () {
      final start = DateTime(2026, 1, 1);
      final clock = TickingClock(
        start: start,
        step: const Duration(minutes: 5),
      );

      expect(clock.now(), DateTime(2026, 1, 1, 0, 0));
      expect(clock.now(), DateTime(2026, 1, 1, 0, 5));
      expect(clock.now(), DateTime(2026, 1, 1, 0, 10));
    });

    test('TickingClock.advance moves time without reading', () {
      final start = DateTime(2026, 6, 15, 12, 0);
      final clock = TickingClock(start: start);

      clock.advance(const Duration(hours: 2));
      expect(clock.now(), DateTime(2026, 6, 15, 14, 0));
    });

    test('TickingClock.setNow jumps to a specific instant', () {
      final clock = TickingClock(start: DateTime(2026, 1, 1));
      final target = DateTime(2026, 12, 25, 8, 0);

      clock.setNow(target);
      expect(clock.now(), target);
    });
  });
}
