import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geometry/sector_math.dart';
import '../../core/services/text_measurement_service.dart';
import '../../core/time/zone_clock.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/schedule/occurrence_adapter.dart';
import '../../domain/schedule/zone_day_projector.dart';
import '../../engine/dial_input.dart' as engine;
import '../../engine/dial_model.dart';
import '../../engine/dial_model_builder.dart';
import 'clock_controller.dart';

/// Single, authoritative provider producing immutable [DialModel]s for the app UI.
///
/// Unifies domain events, timezone clock, user preferences, focus state,
/// and surface dimensions into one reactive engine pipeline (§3.2, §3.3).
final dialModelProvider = Provider<DialModel>((ref) {
  final allEventsAsync = ref.watch(allEventsProvider);
  final allEvents = allEventsAsync.value ?? const <SectorEvent>[];
  final liveAdjustedMap = ref.watch(liveAdjustedEventsMapProvider);
  final liveAdjustedEvent = ref.watch(liveAdjustedEventProvider);
  final selectedDay = ref.watch(selectedDayProvider);
  final selectedEvent = ref.watch(selectedEventProvider);
  final currentTime =
      ref.watch(currentTimeProvider).value ?? ref.read(clockProvider).now();
  final scrubAngle = ref.watch(dialScrubAngleProvider);
  final settings = ref.watch(dialSettingsProvider);
  final isDialEditing = ref.watch(isDialEditingProvider);
  final dialSegment = ref.watch(dial12HourSegmentProvider);
  final zoneClock = ref.watch(zoneClockProvider);

  // 1. Merge in-flight live adjusted events from active drag operations
  final effectiveAllEvents = allEvents.map((e) {
    if (liveAdjustedMap.containsKey(e.id)) {
      return liveAdjustedMap[e.id]!;
    }
    if (liveAdjustedEvent != null && e.id == liveAdjustedEvent.id) {
      return liveAdjustedEvent;
    }
    return e;
  }).toList();

  // 2. Establish viewing day and reference time
  final today = DateTime(
    currentTime.year,
    currentTime.month,
    currentTime.day,
  );
  final viewingDay = DateTime(
    selectedDay.year,
    selectedDay.month,
    selectedDay.day,
  );
  final isToday = viewingDay == today;

  DateTime refTime = isToday
      ? currentTime
      : DateTime(
          viewingDay.year,
          viewingDay.month,
          viewingDay.day,
          currentTime.hour,
          currentTime.minute,
          currentTime.second,
        );

  if (scrubAngle != null) {
    final currentAngle = SectorMath.timeToDialAngle(
      currentTime,
      is24HourMode: settings.is24HourMode,
    );
    final degPerMin = settings.is24HourMode
        ? SectorMath.degreesPerMinute24H
        : SectorMath.degreesPerMinute12H;
    var diff = scrubAngle - currentAngle;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    final deltaMinutes = (diff / degPerMin).round();
    refTime = refTime.add(Duration(minutes: deltaMinutes));
  }

  // 3. Timezone snapshot
  final baseSnapshot = zoneClock.snapshot();
  final clockSnapshot = ZoneClockSnapshot.fromDateTime(
    refTime,
    tzid: baseSnapshot.tzid,
  );
  final displayLocation = clockSnapshot.localNow.location;

  // 4. Project occurrences across a 3-day window [yesterday, viewingDay, tomorrow]
  final prevOccs = ZoneDayProjector.projectAllOccurrences(
    events: effectiveAllEvents,
    targetDay: viewingDay.subtract(const Duration(days: 1)),
    displayZone: displayLocation,
    is24HourMode: settings.is24HourMode,
  );
  final currOccs = ZoneDayProjector.projectAllOccurrences(
    events: effectiveAllEvents,
    targetDay: viewingDay,
    displayZone: displayLocation,
    is24HourMode: settings.is24HourMode,
  );
  final nextOccs = ZoneDayProjector.projectAllOccurrences(
    events: effectiveAllEvents,
    targetDay: viewingDay.add(const Duration(days: 1)),
    displayZone: displayLocation,
    is24HourMode: settings.is24HourMode,
  );

  final uniqueOccurrences = <String, engine.Occurrence>{};
  for (final occ in [...prevOccs, ...currOccs, ...nextOccs]) {
    final occurrenceId =
        '${occ.event.id}_${occ.startLocal.millisecondsSinceEpoch}';
    final engineOcc = OccurrenceAdapter.fromZoneOccurrence(
      occ,
      occurrenceId: occurrenceId,
    );
    uniqueOccurrences[occurrenceId] = engineOcc;
  }


  // 5. Window Mode
  final engine.DialWindowMode windowMode;
  if (settings.is24HourMode) {
    windowMode = engine.DialWindowMode.fullDay24;
  } else if (isDialEditing) {
    windowMode = dialSegment == Dial12HourSegment.am
        ? engine.DialWindowMode.segmentAm
        : engine.DialWindowMode.segmentPm;
  } else {
    windowMode = engine.DialWindowMode.rolling;
  }

  // 6. Focus State
  final engine.DialFocus focus;
  if (scrubAngle != null) {
    focus = engine.DialFocus.scrub(scrubAngle);
  } else if (selectedEvent != null) {
    focus = engine.DialFocus.selected(selectedEvent.id);
  } else {
    focus = const engine.DialFocus.none();
  }

  // 7. Engine Preferences
  final prefs = engine.DialPrefs(
    is24HourMode: settings.is24HourMode,
    previousBlocksCount: settings.previousBlocksCount,
    futureBlocksCount: settings.futureBlocksCount,
    isFocusLensEnabled: settings.isFocusLensEnabled,
    lensMagnification: settings.lensMagnification,
    numeralSystem: settings.numeralSystem,
    showTrueTimeRing: settings.showTrueTimeRing,
    secondaryTimeZone: settings.secondaryTimeZone,
    showSubtaskPaceRing: settings.showSubtaskPaceRing,
    showHiddenBlocksIndicator: settings.showHiddenBlocksIndicator,
  );

  const surface = engine.DialSurface(
    type: engine.DialSurfaceType.app,
    size: 360.0,
    textScale: 1.0,
  );

  // 8. Build immutable DialModel
  final input = engine.DialInput.raw(
    clock: clockSnapshot,
    occurrences: uniqueOccurrences.values.toList(),
    prefs: prefs,
    window: windowMode,
    focus: focus,
    surface: surface,
  );

  return DialModelBuilder.build(
    input,
    textMeasurer: TextMeasurementService.instance,
  );
});
