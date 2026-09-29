import 'package:flutter/foundation.dart';

/// Zone mode for floating time specifications (routines).
enum ZoneModeType {
  /// Floats with whatever timezone the device is currently in.
  device,

  /// Locked to a specific IANA timezone (e.g. 'Asia/Kolkata').
  fixed,
}

@immutable
class ZoneMode {
  final ZoneModeType type;
  final String? tzid;

  const ZoneMode.device()
      : type = ZoneModeType.device,
        tzid = null;

  const ZoneMode.fixed(String this.tzid) : type = ZoneModeType.fixed;

  bool get isDevice => type == ZoneModeType.device;
  bool get isFixed => type == ZoneModeType.fixed;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (tzid != null) 'tzid': tzid,
      };

  factory ZoneMode.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'device';
    if (typeStr == 'fixed') {
      return ZoneMode.fixed(json['tzid'] as String? ?? 'UTC');
    }
    return const ZoneMode.device();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZoneMode &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          tzid == other.tzid;

  @override
  int get hashCode => type.hashCode ^ (tzid?.hashCode ?? 0);

  @override
  String toString() => isDevice ? 'ZoneMode.device' : 'ZoneMode.fixed($tzid)';
}

/// Precise time specification for an event block.
///
/// Distinguishes between:
/// 1. [InstantTime]: Fixed instant in UTC epoch milliseconds (e.g. meetings, one-offs, appointments).
/// 2. [FloatingTime]: Wall-clock routine defined by minute-of-day and duration (e.g. morning workout, sleep).
sealed class TimeSpec {
  const TimeSpec();

  bool get isInstant => this is InstantTime;
  bool get isFloating => this is FloatingTime;

  InstantTime? asInstant() => this is InstantTime ? this as InstantTime : null;
  FloatingTime? asFloating() =>
      this is FloatingTime ? this as FloatingTime : null;

  Map<String, dynamic> toJson();

  static TimeSpec fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type == 'floating') {
      return FloatingTime.fromJson(json);
    }
    return InstantTime.fromJson(json);
  }
}

/// An exact moment in time anchored to UTC epoch millis and tagged with origin tzid.
class InstantTime extends TimeSpec {
  final int utcMillis;
  final String tzid;
  final bool assumedZone;

  const InstantTime({
    required this.utcMillis,
    required this.tzid,
    this.assumedZone = false,
  });

  DateTime get utcDateTime =>
      DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true);

  factory InstantTime.fromDateTime(
    DateTime dt, {
    String? tzid,
    bool assumedZone = false,
  }) {
    final resolvedTz = tzid ?? (dt.isUtc ? 'UTC' : 'local');
    return InstantTime(
      utcMillis: dt.toUtc().millisecondsSinceEpoch,
      tzid: resolvedTz,
      assumedZone: assumedZone,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'instant',
        'utcMillis': utcMillis,
        'tzid': tzid,
        'assumedZone': assumedZone,
      };

  factory InstantTime.fromJson(Map<String, dynamic> json) {
    return InstantTime(
      utcMillis: (json['utcMillis'] as num).toInt(),
      tzid: json['tzid'] as String? ?? 'UTC',
      assumedZone: json['assumedZone'] as bool? ?? false,
    );
  }

  InstantTime copyWith({
    int? utcMillis,
    String? tzid,
    bool? assumedZone,
  }) {
    return InstantTime(
      utcMillis: utcMillis ?? this.utcMillis,
      tzid: tzid ?? this.tzid,
      assumedZone: assumedZone ?? this.assumedZone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstantTime &&
          runtimeType == other.runtimeType &&
          utcMillis == other.utcMillis &&
          tzid == other.tzid &&
          assumedZone == other.assumedZone;

  @override
  int get hashCode => utcMillis.hashCode ^ tzid.hashCode ^ assumedZone.hashCode;

  @override
  String toString() =>
      'InstantTime(utcMillis: $utcMillis, tzid: $tzid, assumedZone: $assumedZone)';
}

/// A recurring wall-clock routine anchored to a minute of the day.
class FloatingTime extends TimeSpec {
  final int startMinuteOfDay;
  final int durationMinutes;
  final ZoneMode zoneMode;
  final DateTime? baseDate;
  final bool assumedZone;

  const FloatingTime({
    required this.startMinuteOfDay,
    required this.durationMinutes,
    this.zoneMode = const ZoneMode.device(),
    this.baseDate,
    this.assumedZone = false,
  }) : assert(
          startMinuteOfDay >= 0 && startMinuteOfDay < 1440,
          'startMinuteOfDay must be between 0 and 1439',
        );

  factory FloatingTime.fromTimes({
    required int startHour,
    required int startMinute,
    required int durationMinutes,
    ZoneMode zoneMode = const ZoneMode.device(),
    DateTime? baseDate,
    bool assumedZone = false,
  }) {
    return FloatingTime(
      startMinuteOfDay: (startHour * 60) + startMinute,
      durationMinutes: durationMinutes,
      zoneMode: zoneMode,
      baseDate: baseDate,
      assumedZone: assumedZone,
    );
  }

  int get startHour => startMinuteOfDay ~/ 60;
  int get startMinute => startMinuteOfDay % 60;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'floating',
        'startMinuteOfDay': startMinuteOfDay,
        'durationMinutes': durationMinutes,
        'zoneMode': zoneMode.toJson(),
        if (baseDate != null) 'baseDate': baseDate!.toIso8601String(),
        'assumedZone': assumedZone,
      };

  factory FloatingTime.fromJson(Map<String, dynamic> json) {
    return FloatingTime(
      startMinuteOfDay: (json['startMinuteOfDay'] as num).toInt(),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      zoneMode: json['zoneMode'] != null
          ? ZoneMode.fromJson(json['zoneMode'] as Map<String, dynamic>)
          : const ZoneMode.device(),
      baseDate: json['baseDate'] != null
          ? DateTime.tryParse(json['baseDate'] as String)
          : null,
      assumedZone: json['assumedZone'] as bool? ?? false,
    );
  }

  FloatingTime copyWith({
    int? startMinuteOfDay,
    int? durationMinutes,
    ZoneMode? zoneMode,
    DateTime? baseDate,
    bool? assumedZone,
  }) {
    return FloatingTime(
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      zoneMode: zoneMode ?? this.zoneMode,
      baseDate: baseDate ?? this.baseDate,
      assumedZone: assumedZone ?? this.assumedZone,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FloatingTime &&
          runtimeType == other.runtimeType &&
          startMinuteOfDay == other.startMinuteOfDay &&
          durationMinutes == other.durationMinutes &&
          zoneMode == other.zoneMode &&
          baseDate == other.baseDate &&
          assumedZone == other.assumedZone;

  @override
  int get hashCode =>
      startMinuteOfDay.hashCode ^
      durationMinutes.hashCode ^
      zoneMode.hashCode ^
      (baseDate?.hashCode ?? 0) ^
      assumedZone.hashCode;

  @override
  String toString() =>
      'FloatingTime(startMinuteOfDay: $startMinuteOfDay, durationMinutes: $durationMinutes, zoneMode: $zoneMode, assumedZone: $assumedZone)';
}
