import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/time/time_spec.dart';

void main() {
  group('TimeSpec & ZoneMode', () {
    test('ZoneMode device serialization roundtrip', () {
      const mode = ZoneMode.device();
      final json = mode.toJson();
      expect(json['type'], 'device');
      final roundtrip = ZoneMode.fromJson(json);
      expect(roundtrip, mode);
    });

    test('ZoneMode fixed serialization roundtrip', () {
      const mode = ZoneMode.fixed('Asia/Kolkata');
      final json = mode.toJson();
      expect(json['type'], 'fixed');
      expect(json['tzid'], 'Asia/Kolkata');
      final roundtrip = ZoneMode.fromJson(json);
      expect(roundtrip, mode);
    });

    test('InstantTime serialization roundtrip', () {
      final nowUtc = DateTime.utc(2026, 9, 29, 10, 0, 0);
      final instant = InstantTime(
        utcMillis: nowUtc.millisecondsSinceEpoch,
        tzid: 'Asia/Kolkata',
        assumedZone: false,
      );

      final json = instant.toJson();
      expect(json['type'], 'instant');
      expect(json['utcMillis'], nowUtc.millisecondsSinceEpoch);
      expect(json['tzid'], 'Asia/Kolkata');

      final roundtrip = TimeSpec.fromJson(json);
      expect(roundtrip, isA<InstantTime>());
      expect(roundtrip, instant);
    });

    test('FloatingTime serialization roundtrip', () {
      final routine = FloatingTime.fromTimes(
        startHour: 7,
        startMinute: 30,
        durationMinutes: 45,
        zoneMode: const ZoneMode.device(),
        assumedZone: true,
      );

      final json = routine.toJson();
      expect(json['type'], 'floating');
      expect(json['startMinuteOfDay'], 7 * 60 + 30);
      expect(json['durationMinutes'], 45);
      expect(json['assumedZone'], true);

      final roundtrip = TimeSpec.fromJson(json);
      expect(roundtrip, isA<FloatingTime>());
      final floating = roundtrip as FloatingTime;
      expect(floating.startHour, 7);
      expect(floating.startMinute, 30);
      expect(floating.durationMinutes, 45);
      expect(floating.assumedZone, true);
    });
  });
}
