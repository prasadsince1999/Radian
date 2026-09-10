import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/polar_hit_test.dart';

class MockSector implements HitTestableSector {
  @override
  final double startAngle;
  @override
  final double sweepAngle;
  @override
  final int topLevel;
  @override
  final int bottomLevel;
  final String id;

  const MockSector({
    required this.id,
    required this.startAngle,
    required this.sweepAngle,
    this.topLevel = 0,
    this.bottomLevel = 1000,
  });
}

void main() {
  group('PolarHitTest Tests', () {
    const center = Offset(200, 200);
    const innerRadius = 50.0;
    const outerRadius = 150.0;

    test('hits 12-to-3 o\'clock (0° to 90°) sector successfully', () {
      final sector = const MockSector(
        id: 'quarter_1',
        startAngle: 0.0,
        sweepAngle: 90.0,
      );

      // Tap at 45° (approx x=200 + 70, y=200 - 70)
      final hit = PolarHitTest.findTappedSector(
        localOffset: const Offset(270, 130),
        center: center,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        sectors: [sector],
      );

      expect(hit?.id, equals('quarter_1'));
    });

    test('hits very short sub-5-minute sector clamped to minSweepAngle', () {
      // Sector with only 1.0 degree duration
      final shortSector = const MockSector(
        id: 'short_task',
        startAngle: 90.0,
        sweepAngle: 1.0,
      );

      // Tap at 92.5° (inside the 5.0° clamped window: 90° to 95°)
      final hit = PolarHitTest.findTappedSector(
        localOffset: const Offset(300, 204),
        center: center,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        sectors: [shortSector],
      );

      expect(hit?.id, equals('short_task'));
    });

    test('returns null for taps outside inner and outer radius bounds', () {
      final sector = const MockSector(
        id: 'full_ring',
        startAngle: 0.0,
        sweepAngle: 360.0,
      );

      // Dead center tap (radius < innerRadius)
      final insideHole = PolarHitTest.findTappedSector(
        localOffset: const Offset(200, 200),
        center: center,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        sectors: [sector],
      );
      expect(insideHole, isNull);

      // Far away tap (radius > outerRadius)
      final outsideDial = PolarHitTest.findTappedSector(
        localOffset: const Offset(400, 400),
        center: center,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        sectors: [sector],
      );
      expect(outsideDial, isNull);
    });
  });
}
