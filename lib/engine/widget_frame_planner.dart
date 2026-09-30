import 'dart:convert';
import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import '../core/time/zone_clock.dart';
import 'dial_input.dart';
import 'dial_model.dart';
import 'dial_model_builder.dart';
import 'text_measurer.dart';

/// A time interval on the widget timeline covered by a single static dial face bitmap (§6.1, §6.2).
///
/// Within [start, end), the dial blocks, content modes, and warp breakpoints are identical.
/// The native Android AppWidget rotates its needle over this static frame using [warpTable].
class WidgetFrameInterval {
  final DateTime start;
  DateTime end;
  final DialModel model;
  final String fileName; // e.g. "0.png"

  WidgetFrameInterval({
    required this.start,
    required this.end,
    required this.model,
    required this.fileName,
  });

  int get fromMs => start.millisecondsSinceEpoch;
  int get toMs => end.millisecondsSinceEpoch;

  String get signature => model.signature;
  String get layoutSignature => model.layoutSignature;
  String get warpKey => model.warpKey;

  /// Breakpoints mapping linear natural time angle [0, 360) to stretched display angle [0, 360).
  List<List<double>> get warpTable =>
      model.warp.breakpoints.map((b) => [b.naturalDeg, b.displayDeg]).toList();

  Map<String, dynamic> toJson() => {
    'fromMs': fromMs,
    'toMs': toMs,
    'file': fileName,
    'signature': signature,
    'layoutSignature': layoutSignature,
    'warpKey': warpKey,
    'warp': warpTable,
    'center': {
      'mode': 'digital',
      'activeTitle': model.center.activeTitle,
      'activeCategory': model.center.activeCategory,
      'remainingDuration': model.center.remainingDurationFormatted,
    },
    'activeEventId': model.needle.activeEventId,
    'activeEventEndMs': _findActiveEventEndMs(),
  };

  int _findActiveEventEndMs() {
    final activeId = model.needle.activeEventId;
    if (activeId == null) return 0;
    for (final b in model.blocks) {
      if (b.eventId == activeId) {
        return b.occurrence.end.millisecondsSinceEpoch;
      }
    }
    return 0;
  }

  @override
  String toString() =>
      'WidgetFrameInterval($fileName: ${start.toIso8601String()} -> ${end.toIso8601String()}, ${model.center.activeTitle})';
}

/// The complete precomputed daily frame strip for the Android widget (§6.1).
class WidgetFrameStripPlan {
  final String dataVersion;
  final String tzid;
  final int validUntilMs;
  final List<String> themeVariants; // ['light', 'dark']
  final List<WidgetFrameInterval> frames;

  const WidgetFrameStripPlan({
    required this.dataVersion,
    required this.tzid,
    required this.validUntilMs,
    this.themeVariants = const ['light', 'dark'],
    required this.frames,
  });

  Map<String, dynamic> toJson() => {
    'dataVersion': dataVersion,
    'tzid': tzid,
    'validUntilMs': validUntilMs,
    'themeVariants': themeVariants,
    'frames': frames.map((f) => f.toJson()).toList(),
  };

  /// Finds the active frame interval for a given instant.
  WidgetFrameInterval? frameFor(DateTime time) {
    final ms = time.millisecondsSinceEpoch;
    for (final frame in frames) {
      if (ms >= frame.fromMs && ms < frame.toMs) {
        return frame;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'WidgetFrameStripPlan(v:$dataVersion, $tzid, frames:${frames.length}, validUntil:$validUntilMs)';
}

/// Computes the daily "Frame Strip" of precomputed dial states (§6.1, RC5, RC6, RC10).
///
/// Features:
/// 1. Finds all schedule boundaries: block start/ends, midnight, and 12h AM/PM flips.
/// 2. De-duplicates intervals whose [DialModel.layoutSignature] and [DialModel.warpKey] are identical.
/// 3. Builds unified, deterministic frame models for 720x720 widget rendering.
class WidgetFramePlanner {
  const WidgetFramePlanner._();

  static WidgetFrameStripPlan plan({
    required ZoneClockSnapshot clock,
    required List<Occurrence> occurrences,
    required DialPrefs prefs,
    DialWindowMode? windowMode,
    Duration planningHorizon = const Duration(hours: 36),
    TextMeasurer textMeasurer = const FastTextMeasurer(),
  }) {
    final now = clock.localNow;

    // 1. Establish start of current calendar day and horizon end
    final dayStart = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      0,
      0,
      0,
    );

    final horizonEnd = dayStart.add(planningHorizon);

    // 2. Window mode for widget
    final effectiveWindow =
        windowMode ??
        (prefs.is24HourMode
            ? DialWindowMode.fullDay24
            : DialWindowMode.rolling);

    // 3. Collect all boundary instants
    final boundarySet = <DateTime>{
      dayStart,
      dayStart.add(const Duration(hours: 12)),
      dayStart.add(const Duration(hours: 24)),
      dayStart.add(const Duration(hours: 36)),
      now,
    };

    for (final occ in occurrences) {
      if (occ.isAllDay) continue;

      if (_isBetween(occ.start, dayStart, horizonEnd)) {
        boundarySet.add(occ.start);
      }
      if (_isBetween(occ.end, dayStart, horizonEnd)) {
        boundarySet.add(occ.end);
      }
    }

    // 4. Normalize and sort boundaries
    final sortedBoundaries = boundarySet.map((dt) {
      return tz.TZDateTime(
        now.location,
        dt.year,
        dt.month,
        dt.day,
        dt.hour,
        dt.minute,
        dt.second,
      );
    }).where((dt) => !dt.isBefore(dayStart) && !dt.isAfter(horizonEnd))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    // Deduplicate boundaries closer than 2 seconds
    final distinctBoundaries = <DateTime>[];
    for (final b in sortedBoundaries) {
      if (distinctBoundaries.isEmpty) {
        distinctBoundaries.add(b);
      } else {
        final diff = b.difference(distinctBoundaries.last).abs();
        if (diff >= const Duration(seconds: 2)) {
          distinctBoundaries.add(b);
        }
      }
    }

    // Ensure at least dayStart and horizonEnd are present
    if (distinctBoundaries.length < 2) {
      distinctBoundaries.clear();
      distinctBoundaries.add(dayStart);
      distinctBoundaries.add(horizonEnd);
    }

    // 5. Build and deduplicate frame intervals
    final draftFrames = <WidgetFrameInterval>[];

    for (int i = 0; i < distinctBoundaries.length - 1; i++) {
      final bStart = distinctBoundaries[i];
      final bEnd = distinctBoundaries[i + 1];

      final duration = bEnd.difference(bStart);
      if (duration.inSeconds <= 0) continue;

      // Sample safely inside the interval [bStart, bEnd)
      final sampleOffsetMs = math.min(1000, math.max(1, duration.inMilliseconds ~/ 2));
      final sampleTime = bStart.add(Duration(milliseconds: sampleOffsetMs));

      final sampleClock = ZoneClockSnapshot.fromDateTime(
        sampleTime,
        tzid: clock.tzid,
      );

      final input = DialInput.raw(
        clock: sampleClock,
        occurrences: occurrences,
        prefs: prefs,
        window: effectiveWindow,
        surface: const DialSurface(type: DialSurfaceType.widget, size: 720.0),
      );

      final model = DialModelBuilder.build(input, textMeasurer: textMeasurer);

      // Deduplication: if layoutSignature and warpKey match the previous interval,
      // simply extend the previous frame's end!
      if (draftFrames.isNotEmpty) {
        final last = draftFrames.last;
        if (last.model.layoutSignature == model.layoutSignature &&
            last.model.warpKey == model.warpKey) {
          last.end = bEnd;
          continue;
        }
      }

      draftFrames.add(
        WidgetFrameInterval(
          start: bStart,
          end: bEnd,
          model: model,
          fileName: '${draftFrames.length}.png',
        ),
      );
    }

    // Handle edge case where no frames were generated
    if (draftFrames.isEmpty) {
      final input = DialInput.raw(
        clock: clock,
        occurrences: occurrences,
        prefs: prefs,
        window: effectiveWindow,
        surface: const DialSurface(type: DialSurfaceType.widget, size: 720.0),
      );
      final model = DialModelBuilder.build(input, textMeasurer: textMeasurer);
      draftFrames.add(
        WidgetFrameInterval(
          start: dayStart,
          end: horizonEnd,
          model: model,
          fileName: '0.png',
        ),
      );
    }

    final validUntilMs = draftFrames.last.end.millisecondsSinceEpoch;

    // 6. Deterministic 64-bit data version hash
    final dataVersion = _computeDataVersion(
      tzid: clock.tzid,
      prefs: prefs,
      frames: draftFrames,
      validUntilMs: validUntilMs,
    );

    return WidgetFrameStripPlan(
      dataVersion: dataVersion,
      tzid: clock.tzid,
      validUntilMs: validUntilMs,
      themeVariants: const ['light', 'dark'],
      frames: draftFrames,
    );
  }

  static bool _isBetween(DateTime time, DateTime start, DateTime end) {
    return (time.isAfter(start) || time == start) &&
        (time.isBefore(end) || time == end);
  }

  static String _computeDataVersion({
    required String tzid,
    required DialPrefs prefs,
    required List<WidgetFrameInterval> frames,
    required int validUntilMs,
  }) {
    final sb = StringBuffer();
    sb.write('tz:$tzid;');
    sb.write('24h:${prefs.is24HourMode};');
    sb.write('valid:$validUntilMs;');
    sb.write('len:${frames.length};');

    for (final f in frames) {
      sb.write('${f.fileName}:${f.fromMs}:${f.toMs}:${f.layoutSignature};');
    }

    final bytes = utf8.encode(sb.toString());
    BigInt hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final fnvPrime = BigInt.parse('100000001b3', radix: 16);
    final mask64 = BigInt.parse('ffffffffffffffff', radix: 16);

    for (final byte in bytes) {
      hash = hash ^ BigInt.from(byte);
      hash = (hash * fnvPrime) & mask64;
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }
}
