/// Domain models for Health Connect & Google Health integration.
enum HealthSyncStatus {
  uninitialized,
  connected,
  syncing,
  disconnected,
  permissionRequired,
  error,
}

class HealthExerciseSession {
  final String id;
  final String title;
  final String type;
  final DateTime start;
  final DateTime end;
  final double caloriesBurned;
  final double distanceMeters;
  final String sourceApp;

  const HealthExerciseSession({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    required this.end,
    this.caloriesBurned = 0.0,
    this.distanceMeters = 0.0,
    this.sourceApp = 'Health Connect',
  });

  int get durationMinutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'caloriesBurned': caloriesBurned,
    'distanceMeters': distanceMeters,
    'sourceApp': sourceApp,
  };

  factory HealthExerciseSession.fromJson(Map<String, dynamic> json) {
    return HealthExerciseSession(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String? ?? 'workout',
      start: DateTime.parse(json['start'] as String),
      end: DateTime.parse(json['end'] as String),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      sourceApp: json['sourceApp'] as String? ?? 'Health Connect',
    );
  }
}

class DailyHealthSummary {
  final DateTime date;
  final int steps;
  final double activeCalories;
  final double totalCalories;
  final double distanceMeters;
  final int sleepDurationMinutes;
  final DateTime? sleepStart;
  final DateTime? sleepEnd;
  final int deepSleepMinutes;
  final int remSleepMinutes;
  final double hydrationMl;
  final int? restingHeartRate;
  final List<HealthExerciseSession> exerciseSessions;
  final DateTime lastSyncTime;

  const DailyHealthSummary({
    required this.date,
    this.steps = 0,
    this.activeCalories = 0.0,
    this.totalCalories = 0.0,
    this.distanceMeters = 0.0,
    this.sleepDurationMinutes = 0,
    this.sleepStart,
    this.sleepEnd,
    this.deepSleepMinutes = 0,
    this.remSleepMinutes = 0,
    this.hydrationMl = 0.0,
    this.restingHeartRate,
    this.exerciseSessions = const [],
    required this.lastSyncTime,
  });

  double get sleepHours => sleepDurationMinutes / 60.0;

  String get sleepHoursFormatted {
    final h = sleepDurationMinutes ~/ 60;
    final m = sleepDurationMinutes % 60;
    return '${h}h ${m}m';
  }

  /// Calculates sleep debt compared to target (default 8 hours = 480 minutes).
  int sleepDebtMinutes({int targetMinutes = 480}) {
    if (sleepDurationMinutes == 0) return 0;
    final debt = targetMinutes - sleepDurationMinutes;
    return debt > 0 ? debt : 0;
  }

  bool get hasSignificantSleepDebt => sleepDebtMinutes() >= 75;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().substring(0, 10),
    'steps': steps,
    'activeCalories': activeCalories,
    'totalCalories': totalCalories,
    'distanceMeters': distanceMeters,
    'sleepDurationMinutes': sleepDurationMinutes,
    'sleepStart': sleepStart?.toIso8601String(),
    'sleepEnd': sleepEnd?.toIso8601String(),
    'deepSleepMinutes': deepSleepMinutes,
    'remSleepMinutes': remSleepMinutes,
    'hydrationMl': hydrationMl,
    'restingHeartRate': restingHeartRate,
    'exerciseSessions': exerciseSessions.map((e) => e.toJson()).toList(),
    'lastSyncTime': lastSyncTime.toIso8601String(),
  };

  factory DailyHealthSummary.fromJson(Map<String, dynamic> json) {
    return DailyHealthSummary(
      date: DateTime.parse(json['date'] as String),
      steps: json['steps'] as int? ?? 0,
      activeCalories: (json['activeCalories'] as num?)?.toDouble() ?? 0.0,
      totalCalories: (json['totalCalories'] as num?)?.toDouble() ?? 0.0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      sleepDurationMinutes: json['sleepDurationMinutes'] as int? ?? 0,
      sleepStart: json['sleepStart'] != null
          ? DateTime.parse(json['sleepStart'] as String)
          : null,
      sleepEnd: json['sleepEnd'] != null
          ? DateTime.parse(json['sleepEnd'] as String)
          : null,
      deepSleepMinutes: json['deepSleepMinutes'] as int? ?? 0,
      remSleepMinutes: json['remSleepMinutes'] as int? ?? 0,
      hydrationMl: (json['hydrationMl'] as num?)?.toDouble() ?? 0.0,
      restingHeartRate: json['restingHeartRate'] as int?,
      exerciseSessions:
          (json['exerciseSessions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    HealthExerciseSession.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'] as String)
          : DateTime.now(),
    );
  }

  DailyHealthSummary copyWith({
    DateTime? date,
    int? steps,
    double? activeCalories,
    double? totalCalories,
    double? distanceMeters,
    int? sleepDurationMinutes,
    DateTime? sleepStart,
    DateTime? sleepEnd,
    int? deepSleepMinutes,
    int? remSleepMinutes,
    double? hydrationMl,
    int? restingHeartRate,
    List<HealthExerciseSession>? exerciseSessions,
    DateTime? lastSyncTime,
  }) {
    return DailyHealthSummary(
      date: date ?? this.date,
      steps: steps ?? this.steps,
      activeCalories: activeCalories ?? this.activeCalories,
      totalCalories: totalCalories ?? this.totalCalories,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      sleepDurationMinutes: sleepDurationMinutes ?? this.sleepDurationMinutes,
      sleepStart: sleepStart ?? this.sleepStart,
      sleepEnd: sleepEnd ?? this.sleepEnd,
      deepSleepMinutes: deepSleepMinutes ?? this.deepSleepMinutes,
      remSleepMinutes: remSleepMinutes ?? this.remSleepMinutes,
      hydrationMl: hydrationMl ?? this.hydrationMl,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      exerciseSessions: exerciseSessions ?? this.exerciseSessions,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}
