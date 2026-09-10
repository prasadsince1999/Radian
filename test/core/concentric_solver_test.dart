import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/concentric_solver.dart';

class TestItem extends ConcentricItem {
  final String id;
  @override
  final DateTime start;
  @override
  final DateTime end;
  @override
  int topLevel;
  @override
  int bottomLevel;

  TestItem(
    this.id,
    this.start,
    this.end, [
    this.topLevel = 0,
    this.bottomLevel = 1000,
  ]);
}

void main() {
  group('ConcentricSolver Tests', () {
    test('Non-overlapping items get full radial width (0 to 1000)', () {
      final base = DateTime(2026, 9, 7, 8, 0);
      final item1 = TestItem('1', base, base.add(const Duration(hours: 1)));
      final item2 = TestItem(
        '2',
        base.add(const Duration(hours: 2)),
        base.add(const Duration(hours: 3)),
      );

      final solved = ConcentricSolver.solve([item1, item2]);
      expect(solved[item1]!.topLevel, 0);
      expect(solved[item1]!.bottomLevel, 1000);
      expect(solved[item2]!.topLevel, 0);
      expect(solved[item2]!.bottomLevel, 1000);
    });

    test('Two overlapping items get split into two concentric tracks', () {
      final base = DateTime(2026, 9, 7, 9, 0);
      final item1 = TestItem('1', base, base.add(const Duration(hours: 2)));
      final item2 = TestItem(
        '2',
        base.add(const Duration(minutes: 30)),
        base.add(const Duration(hours: 1, minutes: 30)),
      );

      final solved = ConcentricSolver.solve([item1, item2]);
      expect(solved[item1]!.topLevel, 0);
      expect(solved[item1]!.bottomLevel, 500);
      expect(solved[item2]!.topLevel, 500);
      expect(solved[item2]!.bottomLevel, 1000);
    });

    test('Three concurrent overlapping items get split into 3 tracks', () {
      final base = DateTime(2026, 9, 7, 10, 0);
      final item1 = TestItem('1', base, base.add(const Duration(hours: 2)));
      final item2 = TestItem(
        '2',
        base.add(const Duration(minutes: 15)),
        base.add(const Duration(hours: 1)),
      );
      final item3 = TestItem(
        '3',
        base.add(const Duration(minutes: 30)),
        base.add(const Duration(hours: 1, minutes: 30)),
      );

      final solved = ConcentricSolver.solve([item1, item2, item3]);
      expect(solved[item1]!.topLevel, 0);
      expect(solved[item1]!.bottomLevel, 333);
      expect(solved[item2]!.topLevel, 333);
      expect(solved[item2]!.bottomLevel, 667);
      expect(solved[item3]!.topLevel, 667);
      expect(solved[item3]!.bottomLevel, 1000);
    });
  });
}
