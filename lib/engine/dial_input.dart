import '../core/i18n/numeral_system.dart';
import '../core/time/zone_clock.dart';

/// Viewing window mode for the dial.
enum DialWindowMode {
  /// Rolling 24-hour horizon [now - 12h, now + 12h) centered around current time.
  rolling,

  /// Fixed 12-hour AM window (00:00 - 12:00).
  segmentAm,

  /// Fixed 12-hour PM window (12:00 - 24:00).
  segmentPm,

  /// Full 24-hour day window (00:00 - 24:00).
  fullDay24,
}

/// User focus state on the dial.
sealed class DialFocus {
  const DialFocus();

  const factory DialFocus.none() = DialFocusNone;
  const factory DialFocus.selected(String eventId) = DialFocusSelected;
  const factory DialFocus.scrub(double angleDeg) = DialFocusScrub;

  String? get selectedEventId =>
      this is DialFocusSelected ? (this as DialFocusSelected).eventId : null;
}

class DialFocusNone extends DialFocus {
  const DialFocusNone();

  @override
  String toString() => 'DialFocus.none';
}

class DialFocusSelected extends DialFocus {
  final String eventId;
  const DialFocusSelected(this.eventId);

  @override
  String toString() => 'DialFocus.selected($eventId)';
}

class DialFocusScrub extends DialFocus {
  final double angleDeg;
  const DialFocusScrub(this.angleDeg);

  @override
  String toString() => 'DialFocus.scrub($angleDeg)';
}

/// Surface environment where the dial is being drawn.
enum DialSurfaceType { app, widget, wear }

class DialSurface {
  final DialSurfaceType type;
  final double size;
  final double textScale;

  const DialSurface({
    this.type = DialSurfaceType.app,
    this.size = 320.0,
    this.textScale = 1.0,
  });

  @override
  String toString() => 'DialSurface($type, size: $size, scale: $textScale)';
}

/// Dial preferences governing capacity, limits, and lens deformation.
class DialPrefs {
  final bool is24HourMode;
  final int previousBlocksCount; // P: 0..3
  final int futureBlocksCount; // N: 0..3
  final bool isFocusLensEnabled;
  final double lensMagnification;
  final NumeralSystem numeralSystem;
  final bool showTrueTimeRing;
  final String? secondaryTimeZone;
  final bool showSubtaskPaceRing;
  final bool showHiddenBlocksIndicator;

  int get previousBlocks => previousBlocksCount;
  int get nextBlocks => futureBlocksCount;
  bool get lensEnabled => isFocusLensEnabled;

  const DialPrefs({
    this.is24HourMode = false,
    int? previousBlocksCount,
    int? previousBlocks,
    int? futureBlocksCount,
    int? nextBlocks,
    bool? isFocusLensEnabled,
    bool? lensEnabled,
    this.lensMagnification = 1.8,
    this.numeralSystem = NumeralSystem.latin,
    this.showTrueTimeRing = true,
    this.secondaryTimeZone,
    this.showSubtaskPaceRing = true,
    this.showHiddenBlocksIndicator = true,
  }) : previousBlocksCount = previousBlocksCount ?? previousBlocks ?? 1,
       futureBlocksCount = futureBlocksCount ?? nextBlocks ?? 3,
       isFocusLensEnabled = isFocusLensEnabled ?? lensEnabled ?? true;

  DialPrefs copyWith({
    bool? is24HourMode,
    int? previousBlocksCount,
    int? futureBlocksCount,
    bool? isFocusLensEnabled,
    double? lensMagnification,
    NumeralSystem? numeralSystem,
    bool? showTrueTimeRing,
    String? secondaryTimeZone,
    bool clearSecondaryTimeZone = false,
    bool? showSubtaskPaceRing,
    bool? showHiddenBlocksIndicator,
  }) {
    return DialPrefs(
      is24HourMode: is24HourMode ?? this.is24HourMode,
      previousBlocksCount: previousBlocksCount ?? this.previousBlocksCount,
      futureBlocksCount: futureBlocksCount ?? this.futureBlocksCount,
      isFocusLensEnabled: isFocusLensEnabled ?? this.isFocusLensEnabled,
      lensMagnification: lensMagnification ?? this.lensMagnification,
      numeralSystem: numeralSystem ?? this.numeralSystem,
      showTrueTimeRing: showTrueTimeRing ?? this.showTrueTimeRing,
      secondaryTimeZone: clearSecondaryTimeZone
          ? null
          : (secondaryTimeZone ?? this.secondaryTimeZone),
      showSubtaskPaceRing: showSubtaskPaceRing ?? this.showSubtaskPaceRing,
      showHiddenBlocksIndicator:
          showHiddenBlocksIndicator ?? this.showHiddenBlocksIndicator,
    );
  }

  @override
  String toString() =>
      'DialPrefs(24H: $is24HourMode, P: $previousBlocksCount, N: $futureBlocksCount, lens: $isFocusLensEnabled, mag: $lensMagnification, digits: $numeralSystem, secTZ: $secondaryTimeZone)';
}

/// Subtask occurrence within a scheduled block.
class SubtaskItemOccurrence {
  final String id;
  final String title;
  final bool isCompleted;
  final int? startMinuteOffset; // Minutes from block start
  final int? endMinuteOffset; // Minutes from block start

  const SubtaskItemOccurrence({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.startMinuteOffset,
    this.endMinuteOffset,
  });

  factory SubtaskItemOccurrence.fromJson(Map<String, dynamic> json) {
    return SubtaskItemOccurrence(
      id: json['id'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      startMinuteOffset: json['startMinuteOffset'] as int?,
      endMinuteOffset: json['endMinuteOffset'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    if (startMinuteOffset != null) 'startMinuteOffset': startMinuteOffset,
    if (endMinuteOffset != null) 'endMinuteOffset': endMinuteOffset,
  };
}

/// Single occurrence of an event on the timeline in wall-clock time.
class Occurrence {
  final String id;
  final String eventId;
  final String title;
  final DateTime start;
  final DateTime end;
  final String colorHex;
  final String category;
  final String notes;
  final String? iconName;
  final int? reminderMinutes;
  final bool isAllDay;
  final List<String> subtasks;
  final List<SubtaskItemOccurrence> subtaskItems;

  const Occurrence({
    required this.id,
    required this.eventId,
    required this.title,
    required this.start,
    required this.end,
    this.colorHex = '#6366F1',
    this.category = 'General',
    this.notes = '',
    this.iconName,
    this.reminderMinutes,
    this.isAllDay = false,
    this.subtasks = const [],
    this.subtaskItems = const [],
  });

  Duration get duration => end.difference(start);

  factory Occurrence.fromJson(Map<String, dynamic> json) {
    return Occurrence(
      id: json['id'] as String,
      eventId: json['eventId'] as String? ?? json['id'] as String,
      title: json['title'] as String? ?? '',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      colorHex: json['colorHex'] as String? ?? '#6366F1',
      category: json['category'] as String? ?? 'General',
      notes: json['notes'] as String? ?? '',
      iconName: json['iconName'] as String?,
      reminderMinutes: json['reminderMinutes'] as int?,
      isAllDay: json['isAllDay'] as bool? ?? false,
      subtasks:
          (json['subtasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      subtaskItems:
          (json['subtaskItems'] as List<dynamic>?)
              ?.map(
                (s) =>
                    SubtaskItemOccurrence.fromJson(s as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  Occurrence copyWith({
    String? id,
    String? eventId,
    String? title,
    DateTime? start,
    DateTime? end,
    String? colorHex,
    String? category,
    String? notes,
    String? iconName,
    int? reminderMinutes,
    bool? isAllDay,
    List<String>? subtasks,
    List<SubtaskItemOccurrence>? subtaskItems,
  }) {
    return Occurrence(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      colorHex: colorHex ?? this.colorHex,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      iconName: iconName ?? this.iconName,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      isAllDay: isAllDay ?? this.isAllDay,
      subtasks: subtasks ?? this.subtasks,
      subtaskItems: subtaskItems ?? this.subtaskItems,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'colorHex': colorHex,
    'category': category,
    if (notes.isNotEmpty) 'notes': notes,
    if (iconName != null) 'iconName': iconName,
    if (reminderMinutes != null) 'reminderMinutes': reminderMinutes,
    'isAllDay': isAllDay,
    'subtasks': subtasks,
    'subtaskItems': subtaskItems.map((s) => s.toJson()).toList(),
  };

  @override
  String toString() => 'Occurrence($title, $start - $end)';
}

/// Complete input payload passed to the engine.
class DialInput {
  final ZoneClockSnapshot clock;
  final List<Occurrence> occurrences;
  final DialPrefs prefs;
  final DialWindowMode window;
  final DialFocus focus;
  final DialSurface surface;

  const DialInput.raw({
    required this.clock,
    required this.occurrences,
    this.prefs = const DialPrefs(),
    this.window = DialWindowMode.rolling,
    this.focus = const DialFocus.none(),
    this.surface = const DialSurface(),
  });

  factory DialInput({
    ZoneClockSnapshot? clock,
    DateTime? now,
    String tzid = 'UTC',
    required List<Occurrence> occurrences,
    DialPrefs prefs = const DialPrefs(),
    DialWindowMode window = DialWindowMode.rolling,
    DialFocus focus = const DialFocus.none(),
    DialSurface surface = const DialSurface(),
  }) {
    final effectiveClock =
        clock ??
        (now != null
            ? ZoneClockSnapshot.fromDateTime(now, tzid: tzid)
            : ZoneClock.fixedZone(tzid: tzid).snapshot());
    return DialInput.raw(
      clock: effectiveClock,
      occurrences: occurrences,
      prefs: prefs,
      window: window,
      focus: focus,
      surface: surface,
    );
  }

  DateTime get now => clock.localNow;
  double get nowMinutesOfDay => clock.wallClockMinutes;

  DialInput copyWith({
    ZoneClockSnapshot? clock,
    List<Occurrence>? occurrences,
    DialPrefs? prefs,
    DialWindowMode? window,
    DialFocus? focus,
    DialSurface? surface,
  }) {
    return DialInput(
      clock: clock ?? this.clock,
      occurrences: occurrences ?? this.occurrences,
      prefs: prefs ?? this.prefs,
      window: window ?? this.window,
      focus: focus ?? this.focus,
      surface: surface ?? this.surface,
    );
  }

  @override
  String toString() =>
      'DialInput(clock: $clock, occurrences: ${occurrences.length}, window: $window, focus: $focus)';
}
