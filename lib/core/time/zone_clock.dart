import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../clock.dart';

bool _timeZonesInitialized = false;

/// Ensures the timezone database is loaded once.
void ensureTimeZonesInitialized() {
  if (!_timeZonesInitialized) {
    tz_data.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}

/// A frozen snapshot of the clock at a particular instant in a specific timezone.
class ZoneClockSnapshot {
  final DateTime utcNow;
  final tz.TZDateTime localNow;
  final String tzid;
  final int offsetMillis;
  final bool isDst;
  final int minuteOfDay;
  final double wallClockMinutes;
  final String formattedOffset;

  const ZoneClockSnapshot({
    required this.utcNow,
    required this.localNow,
    required this.tzid,
    required this.offsetMillis,
    required this.isDst,
    required this.minuteOfDay,
    required this.wallClockMinutes,
    required this.formattedOffset,
  });

  @override
  String toString() =>
      'ZoneClockSnapshot($tzid $formattedOffset, local: $localNow, DST: $isDst)';
}

/// Injectable timezone-aware clock that projects time into an explicit IANA zone.
///
/// Wraps the underlying [Clock] (which can be [FixedClock] or [TickingClock]
/// during tests) and produces [tz.TZDateTime] representations.
class ZoneClock {
  final Clock baseClock;
  final String Function() _zoneIdProvider;

  ZoneClock({
    Clock? baseClock,
    String Function()? zoneIdProvider,
  })  : baseClock = baseClock ?? Clock.system,
        _zoneIdProvider = zoneIdProvider ?? (() => 'UTC') {
    ensureTimeZonesInitialized();
  }

  /// Creates a ZoneClock pinned to a fixed IANA timezone identifier (e.g. 'Asia/Kolkata').
  factory ZoneClock.fixedZone({
    required String tzid,
    Clock? baseClock,
  }) {
    return ZoneClock(
      baseClock: baseClock,
      zoneIdProvider: () => tzid,
    );
  }

  String get currentTzid => _zoneIdProvider();

  tz.Location get location {
    ensureTimeZonesInitialized();
    try {
      return tz.getLocation(currentTzid);
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Returns the current time as a [tz.TZDateTime] in the active timezone.
  tz.TZDateTime now() {
    final utc = baseClock.now().toUtc();
    return tz.TZDateTime.from(utc, location);
  }

  /// Converts a [DateTime] to a [tz.TZDateTime] in this clock's active timezone.
  tz.TZDateTime toLocal(DateTime dt) {
    final utc = dt.toUtc();
    return tz.TZDateTime.from(utc, location);
  }

  /// Converts UTC epoch milliseconds to a [tz.TZDateTime] in this clock's active timezone.
  tz.TZDateTime fromUtcMillis(int utcMillis) {
    return tz.TZDateTime.fromMillisecondsSinceEpoch(location, utcMillis);
  }

  /// Builds a [tz.TZDateTime] for a specific local date and time in this clock's timezone.
  tz.TZDateTime localDateTime(
    int year, [
    int month = 1,
    int day = 1,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
  ]) {
    return tz.TZDateTime(
      location,
      year,
      month,
      day,
      hour,
      minute,
      second,
      millisecond,
    );
  }

  /// Takes an atomic snapshot of the current time, zone offset, and DST status.
  ZoneClockSnapshot snapshot() {
    final utc = baseClock.now().toUtc();
    final loc = location;
    final local = tz.TZDateTime.from(utc, loc);
    final offsetMs = local.timeZoneOffset.inMilliseconds;
    final minuteOfDay = (local.hour * 60) + local.minute;
    final wallClockMinutes =
        minuteOfDay + (local.second / 60.0) + (local.millisecond / 60000.0);

    final totalMinutes = local.timeZoneOffset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final absMin = totalMinutes.abs();
    final h = (absMin ~/ 60).toString().padLeft(2, '0');
    final m = (absMin % 60).toString().padLeft(2, '0');
    final formattedOffset = '$sign$h:$m';

    return ZoneClockSnapshot(
      utcNow: utc,
      localNow: local,
      tzid: loc.name,
      offsetMillis: offsetMs,
      isDst: local.timeZone.isDst,
      minuteOfDay: minuteOfDay,
      wallClockMinutes: wallClockMinutes,
      formattedOffset: formattedOffset,
    );
  }
}
