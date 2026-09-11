import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/geometry/fisheye_time_lens.dart';

void main() {
  group('FisheyeTimeLens', () {
    test('linear lens produces zero distortion', () {
      const lens = FisheyeTimeLens.linear();
      expect(lens.isDistorted, isFalse);
      expect(lens.warpAngle(0), 0.0);
      expect(lens.warpAngle(90), 90.0);
      expect(lens.warpAngle(180), 180.0);
      expect(lens.warpAngle(270), 270.0);

      final sector = lens.warpSector(startDeg: 45, sweepDeg: 30);
      expect(sector.startDeg, 45.0);
      expect(sector.sweepDeg, 30.0);
    });

    test('focus at 180 (6 PM) magnifies active block and squeezes opposite (12 PM)', () {
      // Focus angle is 180 (6 o'clock / bottom of dial)
      const lens = FisheyeTimeLens(magnification: 1.8, focusAngle: 180.0);
      expect(lens.isDistorted, isTrue);

      // Focus center remains unchanged
      expect(lens.warpAngle(180.0), closeTo(180.0, 0.001));

      // Opposite side (0/360 / 12 o'clock) remains unchanged
      expect(lens.warpAngle(0.0), closeTo(0.0, 0.001));

      // A 1-hour block around 6 PM (165° to 195°, total 30°)
      final activeSector = lens.warpSector(startDeg: 165.0, sweepDeg: 30.0);
      // Under magnification 1.8, 30° should expand to ~50°
      expect(activeSector.sweepDeg, greaterThan(45.0));
      expect(activeSector.sweepDeg, lessThan(55.0));

      // A 1-hour block opposite (around 12 PM: 345° to 15°, total 30°)
      final oppositeSector = lens.warpSector(startDeg: 345.0, sweepDeg: 30.0);
      // Under magnification 1.8, opposite 30° should compress to ~17°
      expect(oppositeSector.sweepDeg, lessThan(22.0));
      expect(oppositeSector.sweepDeg, greaterThan(14.0));
    });

    test('monotonicity and invertibility across full 360 degrees', () {
      const lens = FisheyeTimeLens(magnification: 2.0, focusAngle: 135.0);

      for (double deg = 0; deg < 360; deg += 5.0) {
        final warped = lens.warpAngle(deg);
        // Inverse unwarp should recover original degree
        final unwarped = lens.unwarpAngle(warped);
        expect(unwarped, closeTo(deg, 0.01));

        // Ensure within [0, 360)
        expect(warped, greaterThanOrEqualTo(0.0));
        expect(warped, lessThan(360.0));
      }
    });

    test('warpSector preserves complete circle for 360 sweep', () {
      const lens = FisheyeTimeLens(magnification: 1.75, focusAngle: 270.0);
      final fullCircle = lens.warpSector(startDeg: 0, sweepDeg: 360);
      expect(fullCircle.sweepDeg, 360.0);
    });
  });
}
